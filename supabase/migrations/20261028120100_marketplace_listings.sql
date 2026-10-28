-- =====================================================================
-- CONNECT: Marketplace — a directory of coaches, gyms, physical
-- therapists and doctors. Contact details and location only: no booking,
-- no payments, no data sharing. Separate from coaching relationships
-- (coach_profiles / choose_captain stay as they are).
--
--   1. provider_type, listing_status enums.
--   2. marketplace_listings table.
--   3. RLS: signed-in users read approved listings; an owner reads and
--      edits their own; admins do everything. New listings start pending.
--   4. guard trigger: only an admin changes status; updated_at kept fresh.
-- =====================================================================
begin;

-- ---------------------------------------------------------------- 1. enums
create type provider_type  as enum ('coach', 'gym', 'physical_therapist', 'doctor');
create type listing_status as enum ('pending', 'approved', 'suspended');

-- ---------------------------------------------------------------- 2. table
create table public.marketplace_listings (
  id             uuid primary key default gen_random_uuid(),
  -- null for listings an admin adds on a business's behalf
  owner_id       uuid references public.profiles(id) on delete set null,
  provider_type  provider_type  not null,
  status         listing_status not null default 'pending',
  name           text not null check (length(btrim(name)) between 1 and 80),
  headline       text check (headline is null or length(headline) <= 120),
  description    text check (description is null or length(description) <= 1000),
  specialties    text[] not null default '{}',
  logo_url       text,
  -- contact
  phone          text check (phone is null or phone ~ '^\+?[0-9 ()-]{6,20}$'),
  whatsapp       text check (whatsapp is null or whatsapp ~ '^\+?[0-9 ()-]{6,20}$'),
  email          text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  website        text check (website is null or website ~* '^https?://'),
  -- location
  is_online_only boolean not null default false,
  address        text check (address is null or length(address) <= 200),
  area           text check (area is null or length(area) <= 80),
  city           text check (city is null or length(city) <= 80),
  country        text not null default 'EG' check (length(country) = 2),
  latitude       double precision check (latitude  is null or latitude  between -90  and 90),
  longitude      double precision check (longitude is null or longitude between -180 and 180),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint listing_has_contact
    check (coalesce(phone, whatsapp, email, website) is not null),
  constraint listing_has_location
    check (is_online_only or city is not null),
  constraint listing_coords_pair
    check ((latitude is null) = (longitude is null))
);

-- one live listing per owner per type
create unique index uq_marketplace_owner_type on public.marketplace_listings (owner_id, provider_type)
  where deleted_at is null and owner_id is not null;
create index idx_marketplace_browse on public.marketplace_listings (provider_type, city)
  where status = 'approved' and deleted_at is null;
create index idx_marketplace_owner on public.marketplace_listings (owner_id);

-- ---------------------------------------------------------------- 3. RLS
alter table public.marketplace_listings enable row level security;

create policy "marketplace_select_approved" on public.marketplace_listings for select
  to authenticated
  using (status = 'approved' and deleted_at is null);

create policy "marketplace_owner_select" on public.marketplace_listings for select
  using (owner_id = auth.uid());

create policy "marketplace_owner_insert" on public.marketplace_listings for insert
  with check (owner_id = auth.uid() and status = 'pending');

create policy "marketplace_owner_update" on public.marketplace_listings for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "marketplace_admin_all" on public.marketplace_listings for all
  using (public.is_admin()) with check (public.is_admin());

-- No delete policy for owners: they soft-delete by setting deleted_at.

-- ---------------------------------------------------------------- 4. guard
create or replace function public.guard_marketplace_listing()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE'
     and (new.status is distinct from old.status or new.owner_id is distinct from old.owner_id)
     and current_user in ('anon', 'authenticated') and not public.is_admin() then
    raise exception 'Only an admin can change a listing''s status or owner';
  end if;
  -- an owner's edit to an approved listing goes back to review
  if tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'approved'
     and current_user in ('anon', 'authenticated') and not public.is_admin()
     and (new.name, new.provider_type, new.phone, new.whatsapp, new.email, new.website)
         is distinct from
         (old.name, old.provider_type, old.phone, old.whatsapp, old.email, old.website) then
    new.status := 'pending';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_guard_marketplace_listing
  before update on public.marketplace_listings
  for each row execute function public.guard_marketplace_listing();

commit;
