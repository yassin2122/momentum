-- =====================================================================
-- CONNECT: Doctors & Physiotherapists marketplace (discovery only).
--
-- Builds on marketplace_listings (20261028120100): a provider's public
-- card is their `doctor` / `physical_therapist` listing. Name, headline
-- (professional title), bio (description), specialties, photo (logo_url),
-- contacts and location stay on the listing; everything health-specific
-- hangs off it here.
--
-- There is NO booking in this phase: no slots, appointments, payments,
-- consultations, medical records or AI. A provider may add an external
-- booking link; Grit never sees what happens there.
--
--   1. enums
--   2. health_profiles (1:1 with a health listing)
--   3. health_credentials (verified vs provider-submitted)
--   4. saved_providers (a user's favourites)
--   5. storage: health-media (public photos), health-credentials (private)
--   6. helpers + RLS
--   7. RPCs
--   8. guards + grants
--
-- Privacy / consent:
--   * Health listings are no longer readable straight from
--     marketplace_listings by other users (the approved-listing policy now
--     skips doctor / physical_therapist). The public sees them only through
--     get_health_directory / get_health_provider, which return a phone or
--     WhatsApp number ONLY when the provider switched it on.
--   * Credential documents live in a private bucket: the owner and Grit
--     admins can open them; they are never returned to other users.
--   * "Verified" is set only by an admin. Editing a verified credential, or
--     changing the listing phone, drops the verification.
-- =====================================================================
begin;

-- ---------------------------------------------------------------- 1. enums
create type health_credential_kind   as enum ('license', 'degree', 'certification', 'membership');
-- submitted = shown as provider-submitted, no document; pending = document
-- uploaded, waiting for Grit; verified / rejected = Grit's decision.
create type health_credential_status as enum ('submitted', 'pending', 'verified', 'rejected');

-- ------------------------------------------------------- 2. health_profiles
create table public.health_profiles (
  listing_id        uuid primary key references public.marketplace_listings(id) on delete cascade,
  photo_path        text check (photo_path is null or length(photo_path) <= 300),
  experience_years  int  check (experience_years is null or experience_years between 0 and 70),
  languages         text[] not null default '{}' check (cardinality(languages) <= 8),
  services          text[] not null default '{}' check (cardinality(services) <= 20),
  service_modes     text[] not null default '{clinic}'
                    check (service_modes <@ array['clinic', 'home']::text[] and cardinality(service_modes) >= 1),
  clinic_name       text check (clinic_name is null or length(btrim(clinic_name)) between 1 and 120),
  availability_note text check (availability_note is null or length(availability_note) <= 200),
  consultation_fee  numeric(10, 2) check (consultation_fee is null or consultation_fee between 0 and 1000000),
  fee_currency      text not null default 'EGP' check (fee_currency ~ '^[A-Z]{3}$'),
  booking_url       text check (booking_url is null or (booking_url ~* '^https://' and length(booking_url) <= 500)),
  show_phone        boolean not null default false,
  show_whatsapp     boolean not null default false,
  -- set by an admin after checking the number; cleared when it changes
  phone_verified_at timestamptz,
  submitted_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------- 3. health_credentials
create table public.health_credentials (
  id            uuid primary key default gen_random_uuid(),
  listing_id    uuid not null references public.health_profiles(listing_id) on delete cascade,
  kind          health_credential_kind not null,
  title         text not null check (length(btrim(title)) between 2 and 120),
  issuer        text check (issuer is null or length(btrim(issuer)) between 2 and 120),
  year          int  check (year is null or year between 1950 and 2100),
  -- private object in health-credentials (`<listing_id>/<file>`)
  document_path text check (document_path is null or length(document_path) <= 300),
  status        health_credential_status not null default 'submitted',
  review_note   text check (review_note is null or length(review_note) <= 300),
  verified_at   timestamptz,
  verified_by   uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_health_credentials_listing on public.health_credentials (listing_id);
create index idx_health_credentials_verified_by on public.health_credentials (verified_by);

-- ------------------------------------------------------- 4. saved_providers
create table public.saved_providers (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);
create index idx_saved_providers_listing on public.saved_providers (listing_id);

-- ---------------------------------------------------------------- 6. helpers
create or replace function public.is_health_type(p provider_type)
returns boolean language sql immutable set search_path = public, pg_temp as $$
  select p in ('doctor', 'physical_therapist');
$$;

-- A provider other users can see: approved by Grit, shown by the provider,
-- submitted, not deleted.
create or replace function public.health_is_public(p_listing uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from marketplace_listings l join health_profiles h on h.listing_id = l.id
    where l.id = p_listing and public.is_health_type(l.provider_type)
      and l.status = 'approved' and l.is_published and l.deleted_at is null
      and h.submitted_at is not null);
$$;

create or replace function public.health_owns(p_listing uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from marketplace_listings l
    where l.id = p_listing and l.owner_id = auth.uid() and l.deleted_at is null
      and public.is_health_type(l.provider_type));
$$;

-- storage folder → listing the caller owns
create or replace function public.health_folder_owned(p_folder text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select p_folder ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and public.health_owns(p_folder::uuid);
$$;

-- Other users read health listings only through the RPCs below (they apply
-- the provider's contact consent). Gyms and other types are unchanged.
drop policy "marketplace_select_approved" on public.marketplace_listings;
create policy "marketplace_select_approved" on public.marketplace_listings for select
  to authenticated
  using (status = 'approved' and is_published and deleted_at is null
         and not public.is_health_type(provider_type));

alter table public.health_profiles    enable row level security;
alter table public.health_credentials enable row level security;
alter table public.saved_providers    enable row level security;

create policy "health_profiles_owner_select" on public.health_profiles for select
  using (public.health_owns(listing_id));
create policy "health_profiles_owner_update" on public.health_profiles for update
  using (public.health_owns(listing_id)) with check (public.health_owns(listing_id));
create policy "health_profiles_admin_all" on public.health_profiles for all
  using (public.is_admin()) with check (public.is_admin());

create policy "health_credentials_owner_select" on public.health_credentials for select
  using (public.health_owns(listing_id));
create policy "health_credentials_owner_insert" on public.health_credentials for insert
  with check (public.health_owns(listing_id));
create policy "health_credentials_owner_update" on public.health_credentials for update
  using (public.health_owns(listing_id)) with check (public.health_owns(listing_id));
create policy "health_credentials_owner_delete" on public.health_credentials for delete
  using (public.health_owns(listing_id));
create policy "health_credentials_admin_all" on public.health_credentials for all
  using (public.is_admin()) with check (public.is_admin());

create policy "saved_providers_own_select" on public.saved_providers for select
  using (user_id = auth.uid());
create policy "saved_providers_own_insert" on public.saved_providers for insert
  with check (user_id = auth.uid() and public.health_is_public(listing_id));
create policy "saved_providers_own_delete" on public.saved_providers for delete
  using (user_id = auth.uid());

-- ---------------------------------------------------------------- 5. storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('health-media', 'health-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
       ('health-credentials', 'health-credentials', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "health_media_owner_insert" on storage.objects for insert
  with check (bucket_id = 'health-media' and public.health_folder_owned((storage.foldername(name))[1]));
create policy "health_media_owner_update" on storage.objects for update
  using (bucket_id = 'health-media' and public.health_folder_owned((storage.foldername(name))[1]));
create policy "health_media_owner_delete" on storage.objects for delete
  using (bucket_id = 'health-media' and public.health_folder_owned((storage.foldername(name))[1]));

create policy "health_credentials_obj_owner_insert" on storage.objects for insert
  with check (bucket_id = 'health-credentials' and public.health_folder_owned((storage.foldername(name))[1]));
create policy "health_credentials_obj_owner_select" on storage.objects for select
  using (bucket_id = 'health-credentials'
         and (public.health_folder_owned((storage.foldername(name))[1]) or public.is_admin()));
create policy "health_credentials_obj_owner_delete" on storage.objects for delete
  using (bucket_id = 'health-credentials' and public.health_folder_owned((storage.foldername(name))[1]));

-- ---------------------------------------------------------------- 7. RPCs

-- Provider: create a private draft profile (listing + health profile).
create or replace function public.create_health_profile(
  p_kind provider_type, p_name text, p_specialty text, p_city text, p_phone text
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null or coalesce((select is_anonymous from auth.users where id = auth.uid()), false) then
    raise exception 'Create a Grit account first';
  end if;
  if not public.is_health_type(p_kind) then raise exception 'Choose doctor or physiotherapist'; end if;
  if length(btrim(coalesce(p_specialty, ''))) < 2 then raise exception 'Add your main specialty'; end if;
  if exists (select 1 from marketplace_listings where owner_id = auth.uid() and provider_type = p_kind and deleted_at is null) then
    raise exception 'You already have a profile of this type';
  end if;
  insert into marketplace_listings (owner_id, provider_type, status, is_published, name, specialties, phone, city)
  values (auth.uid(), p_kind, 'pending', false, btrim(p_name), array[btrim(p_specialty)], nullif(btrim(p_phone), ''), btrim(p_city))
  returning id into v_id;
  insert into health_profiles (listing_id) values (v_id);
  return v_id;
end;
$$;

-- Provider: send the profile to Grit's review and show it once approved.
create or replace function public.submit_health_profile(p_listing uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare l marketplace_listings%rowtype; h health_profiles%rowtype;
begin
  if not public.health_owns(p_listing) then raise exception 'Not found'; end if;
  select * into l from marketplace_listings where id = p_listing;
  select * into h from health_profiles where listing_id = p_listing;
  if l.status = 'suspended' then raise exception 'This profile is suspended. Contact Grit support'; end if;
  if length(btrim(coalesce(l.headline, ''))) < 3 then raise exception 'Add your professional title, e.g. Sports medicine physician'; end if;
  if length(btrim(coalesce(l.description, ''))) < 40 then raise exception 'Write a short biography (at least 40 characters)'; end if;
  if cardinality(l.specialties) = 0 then raise exception 'Add at least one specialty'; end if;
  if not ((h.show_phone and l.phone is not null) or (h.show_whatsapp and l.whatsapp is not null)
          or l.website is not null or h.booking_url is not null) then
    raise exception 'Share at least one way to reach you: phone, WhatsApp, website or booking link';
  end if;
  perform set_config('grit.gym_publish', 'on', true);
  update marketplace_listings set is_published = true where id = p_listing;
  update health_profiles set submitted_at = coalesce(submitted_at, now()) where listing_id = p_listing;
end;
$$;

-- Provider: hide or show a submitted profile.
create or replace function public.set_health_profile_visible(p_listing uuid, p_visible boolean)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.health_owns(p_listing) then raise exception 'Not found'; end if;
  if p_visible and not exists (select 1 from health_profiles where listing_id = p_listing and submitted_at is not null) then
    raise exception 'Submit your profile for review first';
  end if;
  perform set_config('grit.gym_publish', 'on', true);
  update marketplace_listings set is_published = p_visible where id = p_listing;
end;
$$;

-- Public directory. Fees and specialties are exactly what providers entered;
-- `license_verified` is true only when Grit verified a licence.
create or replace function public.get_health_directory(
  p_search text default null, p_kind provider_type default null, p_specialty text default null,
  p_mode text default null, p_verified_only boolean default false, p_city text default null,
  p_limit int default 50
) returns table(
  listing_id uuid, kind provider_type, name text, headline text, specialties text[], photo_url text,
  area text, city text, service_modes text[], consultation_fee numeric, fee_currency text,
  license_verified boolean, is_saved boolean
)
language sql stable security definer set search_path = public, pg_temp as $$
  select l.id, l.provider_type, l.name, l.headline, l.specialties, l.logo_url, l.area, l.city,
         h.service_modes, h.consultation_fee, h.fee_currency,
         exists (select 1 from health_credentials c where c.listing_id = l.id and c.kind = 'license' and c.status = 'verified'),
         exists (select 1 from saved_providers s where s.listing_id = l.id and s.user_id = auth.uid())
  from marketplace_listings l join health_profiles h on h.listing_id = l.id
  where public.is_health_type(l.provider_type) and l.status = 'approved' and l.is_published
    and l.deleted_at is null and h.submitted_at is not null
    and (p_kind is null or l.provider_type = p_kind)
    and (p_city is null or l.city ilike p_city)
    and (p_mode is null or p_mode = any (h.service_modes))
    and (p_specialty is null or exists (select 1 from unnest(l.specialties) s where s ilike '%' || p_specialty || '%'))
    and (not p_verified_only or exists (select 1 from health_credentials c where c.listing_id = l.id and c.kind = 'license' and c.status = 'verified'))
    and (p_search is null or l.name ilike '%' || p_search || '%' or coalesce(l.headline, '') ilike '%' || p_search || '%'
         or exists (select 1 from unnest(l.specialties) s where s ilike '%' || p_search || '%'))
  order by 12 desc, l.name
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

-- One provider's public profile (or the owner's own preview). Phone and
-- WhatsApp are included only with the provider's consent; credential
-- documents are never included.
create or replace function public.get_health_provider(p_listing uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare l marketplace_listings%rowtype; h health_profiles%rowtype; v_owner boolean;
begin
  v_owner := public.health_owns(p_listing);
  if not (v_owner or public.health_is_public(p_listing)) then raise exception 'This provider isn''t listed right now'; end if;
  select * into l from marketplace_listings where id = p_listing;
  select * into h from health_profiles where listing_id = p_listing;
  return jsonb_build_object(
    'listing_id', l.id, 'kind', l.provider_type, 'name', l.name, 'headline', l.headline,
    'description', l.description, 'specialties', to_jsonb(l.specialties), 'photo_url', l.logo_url,
    'phone', case when h.show_phone then l.phone end,
    'phone_verified', h.show_phone and h.phone_verified_at is not null,
    'whatsapp', case when h.show_whatsapp then l.whatsapp end,
    'website', l.website, 'booking_url', h.booking_url,
    'address', l.address, 'area', l.area, 'city', l.city, 'latitude', l.latitude, 'longitude', l.longitude,
    'clinic_name', h.clinic_name, 'availability_note', h.availability_note,
    'consultation_fee', h.consultation_fee, 'fee_currency', h.fee_currency,
    'services', to_jsonb(h.services), 'languages', to_jsonb(h.languages),
    'experience_years', h.experience_years, 'service_modes', to_jsonb(h.service_modes),
    'is_saved', exists (select 1 from saved_providers s where s.listing_id = l.id and s.user_id = auth.uid()),
    'is_preview', v_owner and not public.health_is_public(p_listing),
    'credentials', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', c.kind, 'title', c.title, 'issuer', c.issuer, 'year', c.year,
        'verified', c.status = 'verified', 'verified_at', c.verified_at)
        order by (c.status = 'verified') desc, c.kind, c.year desc nulls last)
      from health_credentials c where c.listing_id = l.id and c.status <> 'rejected'), '[]'::jsonb));
end;
$$;

-- Saved providers that are still listed (same columns as the directory).
create or replace function public.get_my_saved_providers()
returns table(
  listing_id uuid, kind provider_type, name text, headline text, specialties text[], photo_url text,
  area text, city text, service_modes text[], consultation_fee numeric, fee_currency text,
  license_verified boolean, is_saved boolean
)
language sql stable security definer set search_path = public, pg_temp as $$
  select l.id, l.provider_type, l.name, l.headline, l.specialties, l.logo_url, l.area, l.city,
         h.service_modes, h.consultation_fee, h.fee_currency,
         exists (select 1 from health_credentials c where c.listing_id = l.id and c.kind = 'license' and c.status = 'verified'),
         true
  from saved_providers s join marketplace_listings l on l.id = s.listing_id join health_profiles h on h.listing_id = l.id
  where s.user_id = auth.uid() and public.health_is_public(l.id)
  order by s.created_at desc;
$$;

-- ---------------------------------------------------------------- 8. guards
-- Owners can't verify themselves or fake a submission/verification time.
create or replace function public.guard_health_profile()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if current_user in ('anon', 'authenticated') and not public.is_admin() then
    if new.phone_verified_at is distinct from old.phone_verified_at
       or new.submitted_at is distinct from old.submitted_at then
      if current_setting('grit.gym_publish', true) is distinct from 'on' then
        raise exception 'Only Grit can change review fields';
      end if;
    end if;
    if new.listing_id is distinct from old.listing_id then raise exception 'A profile can''t move'; end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_guard_health_profile before update on public.health_profiles
  for each row execute function public.guard_health_profile();

-- Credential status follows the evidence: no document = provider-submitted,
-- document = waiting for Grit. Only an admin sets verified / rejected.
create or replace function public.guard_health_credential()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if current_user in ('anon', 'authenticated') and not public.is_admin() then
    if tg_op = 'INSERT' then
      if (select count(*) from public.health_credentials where listing_id = new.listing_id) >= 20 then
        raise exception 'You can add up to 20 qualifications';
      end if;
      new.status := case when new.document_path is null then 'submitted' else 'pending' end::health_credential_status;
      new.verified_at := null; new.verified_by := null; new.review_note := null;
    else
      if new.listing_id is distinct from old.listing_id then raise exception 'A qualification can''t move'; end if;
      if (new.kind, new.title, new.issuer, new.year, new.document_path)
         is distinct from (old.kind, old.title, old.issuer, old.year, old.document_path)
         or new.status is distinct from old.status then
        new.status := case when new.document_path is null then 'submitted' else 'pending' end::health_credential_status;
        new.verified_at := null; new.verified_by := null;
      end if;
      if new.review_note is distinct from old.review_note then new.review_note := old.review_note; end if;
    end if;
  elsif new.status = 'verified' and (tg_op = 'INSERT' or old.status is distinct from 'verified') then
    new.verified_at := now(); new.verified_by := auth.uid();
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_guard_health_credential before insert or update on public.health_credentials
  for each row execute function public.guard_health_credential();

-- A changed listing phone is no longer the number Grit checked.
create or replace function public.reset_health_phone_verification()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if public.is_health_type(new.provider_type) and new.phone is distinct from old.phone then
    perform set_config('grit.gym_publish', 'on', true);
    update public.health_profiles set phone_verified_at = null where listing_id = new.id;
  end if;
  return new;
end;
$$;
create trigger trg_reset_health_phone after update of phone on public.marketplace_listings
  for each row execute function public.reset_health_phone_verification();

-- ---------------------------------------------------------------- grants
revoke all on public.health_profiles, public.health_credentials, public.saved_providers from anon;
grant select, update on public.health_profiles to authenticated;
grant select, insert, update, delete on public.health_credentials to authenticated;
grant select, insert, delete on public.saved_providers to authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'create_health_profile(provider_type, text, text, text, text)',
    'submit_health_profile(uuid)',
    'set_health_profile_visible(uuid, boolean)',
    'get_health_directory(text, provider_type, text, text, boolean, text, int)',
    'get_health_provider(uuid)',
    'get_my_saved_providers()'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['health_is_public(uuid)', 'health_owns(uuid)', 'health_folder_owned(text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end;
$$;

commit;
