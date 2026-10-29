-- =====================================================================
-- CONNECT: Gym Partner Platform (phase 1).
--
-- Builds on marketplace_listings (20261028120100): a gym's public card is
-- its `provider_type = 'gym'` listing; everything gym-specific hangs off
-- `gyms`. Grit stores only what the gym or its visitors enter here — no
-- membership, attendance or payment data.
--
--   1. enums
--   2. marketplace_listings: owner publish switch (is_published)
--   3. gyms, gym_staff, gym_staff_invites
--   4. helpers: gym_role, gym_has_role, gym_is_public
--   5. gym_branches, gym_offers, gym_photos (+ gym-media bucket)
--   6. coach affiliation: gym_coaches, gym_coach_invitations
--   7. gym_partnerships (admin-controlled) + AI entitlement / usage
--   8. gym_inquiries, gym_profile_views
--   9. RLS policies
--  10. RPCs
--  11. guards + grants
--
-- Access model:
--   * Public (signed-in) users see a gym only when its listing is
--     approved by Grit AND published by the gym (gym_is_public).
--   * Staff rights are per gym, from gym_staff.role:
--       owner      everything, incl. staff
--       manager    profile, branches, offers, coaches, inquiries
--       marketing  profile, gallery, offers
--       front_desk inquiries only
--   * Coaches join only by accepting an invite (or the gym approving their
--     code request). Affiliation never exposes a coach's clients, plans or
--     messages to the gym: no policy here touches any coaching table.
--   * Partnership status and AI allowances change only via is_admin().
--     AI usage is recorded only by the server (service_role) through
--     consume_ai_allowance — the app can read usage, never write it.
-- =====================================================================
begin;

-- ---------------------------------------------------------------- 1. enums
create type gym_staff_role         as enum ('owner', 'manager', 'marketing', 'front_desk');
create type gym_coach_role         as enum ('coach', 'head_coach');
create type gym_invite_kind        as enum ('gym_invite', 'coach_request');
create type gym_invite_status      as enum ('pending', 'accepted', 'declined', 'cancelled', 'expired');
create type gym_partnership_status as enum ('pending_review', 'active', 'suspended', 'expired', 'cancelled');
create type gym_inquiry_status     as enum ('new', 'contacted', 'closed');
create type gym_contact_method     as enum ('whatsapp', 'call', 'in_app');

-- ------------------------------------------- 2. marketplace_listings switch
-- The owner's own "show my listing" switch, separate from Grit's review
-- status. Existing listings stay visible (default true); gyms start false.
alter table public.marketplace_listings
  add column is_published boolean not null default true;

drop policy "marketplace_select_approved" on public.marketplace_listings;
create policy "marketplace_select_approved" on public.marketplace_listings for select
  to authenticated
  using (status = 'approved' and is_published and deleted_at is null);

-- ---------------------------------------------------------------- 3. gyms
create table public.gyms (
  id               uuid primary key default gen_random_uuid(),
  listing_id       uuid not null unique references public.marketplace_listings(id) on delete restrict,
  owner_id         uuid not null references public.profiles(id) on delete restrict,
  is_multi_branch  boolean not null default false,
  cover_path       text check (cover_path is null or length(cover_path) <= 300),
  facilities       text[] not null default '{}' check (cardinality(facilities) <= 40),
  equipment        text[] not null default '{}' check (cardinality(equipment) <= 60),
  services         text[] not null default '{}' check (cardinality(services) <= 30),
  -- coach join code: only the hash is stored (same scheme as coaching_invitations)
  coach_code_hash       text unique,
  coach_code_hint       text,
  coach_code_expires_at timestamptz,
  -- first time the owner asked to publish (draft vs unpublished)
  submitted_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_gyms_owner on public.gyms (owner_id);

create table public.gym_staff (
  gym_id     uuid not null references public.gyms(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       gym_staff_role not null,
  added_by   uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (gym_id, user_id)
);
create unique index uq_gym_staff_one_owner on public.gym_staff (gym_id) where role = 'owner';
create index idx_gym_staff_user on public.gym_staff (user_id);

-- Staff join by a single-use code the owner shares (no email lookup).
create table public.gym_staff_invites (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid not null references public.gyms(id) on delete cascade,
  role        gym_staff_role not null check (role <> 'owner'),
  code_hash   text not null unique,
  code_hint   text not null,
  created_by  uuid references public.profiles(id) on delete set null,
  expires_at  timestamptz not null,
  accepted_by uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);
create index idx_gym_staff_invites_gym on public.gym_staff_invites (gym_id);

-- ---------------------------------------------------------------- 4. helpers
create or replace function public.gym_role(p_gym uuid)
returns gym_staff_role language sql stable security definer set search_path = public, pg_temp as $$
  select s.role from public.gym_staff s where s.gym_id = p_gym and s.user_id = auth.uid();
$$;

create or replace function public.gym_has_role(p_gym uuid, variadic p_roles text[])
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select s.role::text = any(p_roles) from public.gym_staff s
                   where s.gym_id = p_gym and s.user_id = auth.uid()), false);
$$;

create or replace function public.gym_is_public(p_gym uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.gyms g
    join public.marketplace_listings l on l.id = g.listing_id
    where g.id = p_gym and l.status = 'approved' and l.is_published and l.deleted_at is null);
$$;

-- storage paths are "<gym_id>/<file>"; false for anything that isn't a uuid
create or replace function public.gym_media_writable(p_folder text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select p_folder ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and public.gym_has_role(p_folder::uuid, 'owner', 'manager', 'marketing');
$$;

-- -------------------------------------------- 5. branches, offers, photos
create table public.gym_branches (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references public.gyms(id) on delete cascade,
  name          text not null check (length(btrim(name)) between 1 and 60),
  address       text check (address is null or length(address) <= 200),
  area          text check (area is null or length(area) <= 80),
  city          text not null check (length(btrim(city)) between 1 and 80),
  latitude      double precision check (latitude  is null or latitude  between -90  and 90),
  longitude     double precision check (longitude is null or longitude between -180 and 180),
  phone         text check (phone is null or phone ~ '^\+?[0-9 ()-]{6,20}$'),
  -- [{ "days": [1,2,3,4,5], "open": "06:00", "close": "23:00" }, …] or [] when unset
  opening_hours jsonb not null default '[]' check (jsonb_typeof(opening_hours) = 'array'),
  open_24h      boolean not null default false,
  hours_note    text check (hours_note is null or length(hours_note) <= 120),
  facilities    text[] not null default '{}' check (cardinality(facilities) <= 40),
  is_published  boolean not null default true,
  sort_order    smallint not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint branch_coords_pair check ((latitude is null) = (longitude is null)),
  constraint branch_published_has_hours
    check (not is_published or open_24h or jsonb_array_length(opening_hours) > 0)
);
create index idx_gym_branches_gym on public.gym_branches (gym_id) where deleted_at is null;

create table public.gym_offers (
  id             uuid primary key default gen_random_uuid(),
  gym_id         uuid not null references public.gyms(id) on delete cascade,
  name           text not null check (length(btrim(name)) between 1 and 60),
  -- as entered by the gym; null = "ask the gym"
  price_amount   numeric(10, 2) check (price_amount is null or price_amount >= 0),
  currency       char(3) not null default 'EGP',
  duration_days  int check (duration_days is null or duration_days between 1 and 730),
  duration_label text check (duration_label is null or length(duration_label) <= 40),
  benefits       text[] not null default '{}' check (cardinality(benefits) <= 10),
  -- empty = every branch
  branch_ids     uuid[] not null default '{}',
  is_visible     boolean not null default true,
  sort_order     smallint not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);
create index idx_gym_offers_gym on public.gym_offers (gym_id) where deleted_at is null;

create table public.gym_photos (
  id           uuid primary key default gen_random_uuid(),
  gym_id       uuid not null references public.gyms(id) on delete cascade,
  storage_path text not null unique check (length(storage_path) <= 300),
  sort_order   smallint not null default 0,
  created_at   timestamptz not null default now()
);
create index idx_gym_photos_gym on public.gym_photos (gym_id);

-- Public gallery/logo/cover bucket: JPG/PNG/WebP up to 8 MB, path <gym_id>/<file>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gym-media', 'gym-media', true, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "gym_media_staff_insert" on storage.objects for insert
  with check (bucket_id = 'gym-media' and public.gym_media_writable((storage.foldername(name))[1]));
create policy "gym_media_staff_update" on storage.objects for update
  using (bucket_id = 'gym-media' and public.gym_media_writable((storage.foldername(name))[1]));
create policy "gym_media_staff_delete" on storage.objects for delete
  using (bucket_id = 'gym-media' and public.gym_media_writable((storage.foldername(name))[1]));

-- ------------------------------------------------------- 6. coach affiliation
create table public.gym_coach_invitations (
  id           uuid primary key default gen_random_uuid(),
  gym_id       uuid not null references public.gyms(id) on delete cascade,
  kind         gym_invite_kind not null,
  coach_id     uuid not null references public.profiles(id) on delete cascade,
  role         gym_coach_role not null default 'coach',
  branch_ids   uuid[] not null default '{}',
  message      text check (message is null or length(message) <= 300),
  status       gym_invite_status not null default 'pending',
  created_by   uuid references public.profiles(id) on delete set null,
  expires_at   timestamptz not null,
  responded_by uuid references public.profiles(id) on delete set null,
  responded_at timestamptz,
  created_at   timestamptz not null default now()
);
-- one open invitation per gym and coach
create unique index uq_gym_coach_invite_open on public.gym_coach_invitations (gym_id, coach_id)
  where status = 'pending';
create index idx_gym_coach_invites_coach on public.gym_coach_invitations (coach_id);

create table public.gym_coaches (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references public.gyms(id) on delete cascade,
  coach_id      uuid not null references public.profiles(id) on delete cascade,
  role          gym_coach_role not null default 'coach',
  branch_ids    uuid[] not null default '{}',
  status        text not null default 'active' check (status in ('active', 'ended')),
  invitation_id uuid references public.gym_coach_invitations(id) on delete set null,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  ended_by      uuid references public.profiles(id) on delete set null
);
create unique index uq_gym_coaches_active on public.gym_coaches (gym_id, coach_id) where status = 'active';
create index idx_gym_coaches_coach on public.gym_coaches (coach_id) where status = 'active';

-- ------------------------------------------- 7. partnerships + AI usage
create table public.gym_partnerships (
  id                   uuid primary key default gen_random_uuid(),
  gym_id               uuid not null references public.gyms(id) on delete cascade,
  status               gym_partnership_status not null default 'pending_review',
  starts_on            date,
  ends_on              date,
  -- business terms: change these rows, not the app
  ai_monthly_allowance int not null default 0 check (ai_monthly_allowance >= 0),
  ai_per_coach_cap     int check (ai_per_coach_cap is null or ai_per_coach_cap >= 0),
  ai_features          text[] not null default '{ai_plan_builder,ai_progress_summary}',
  contract_ref         text check (contract_ref is null or length(contract_ref) <= 60),
  requested_by         uuid references public.profiles(id) on delete set null,
  decided_by           uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint partnership_dates check (ends_on is null or starts_on is null or ends_on >= starts_on),
  constraint partnership_active_dated check (status <> 'active' or starts_on is not null)
);
-- one open partnership (pending / active / suspended) per gym
create unique index uq_gym_partnership_open on public.gym_partnerships (gym_id)
  where status in ('pending_review', 'active', 'suspended');

create table public.ai_usage_events (
  id             uuid primary key default gen_random_uuid(),
  coach_id       uuid not null references public.profiles(id) on delete cascade,
  gym_id         uuid references public.gyms(id) on delete set null,
  partnership_id uuid references public.gym_partnerships(id) on delete set null,
  feature        text not null check (feature in ('ai_plan_builder', 'ai_progress_summary',
                                                  'ai_workout_adjustment', 'ai_coaching_assistant')),
  units          int not null default 1 check (units between 1 and 100),
  created_at     timestamptz not null default now()
);
create index idx_ai_usage_gym_month on public.ai_usage_events (gym_id, created_at);
create index idx_ai_usage_coach_month on public.ai_usage_events (coach_id, created_at);

-- The partnership a coach's AI runs on right now: active, in date, and the
-- coach affiliated with that gym. Oldest affiliation first.
create or replace function public.coach_ai_partnership(p_coach uuid)
returns table(partnership_id uuid, gym_id uuid, monthly_allowance int, per_coach_cap int, features text[])
language sql stable security definer set search_path = public, pg_temp as $$
  select p.id, p.gym_id, p.ai_monthly_allowance, p.ai_per_coach_cap, p.ai_features
  from public.gym_coaches gc
  join public.gym_partnerships p on p.gym_id = gc.gym_id
  where gc.coach_id = p_coach and gc.status = 'active'
    and p.status = 'active'
    and p.starts_on <= current_date and (p.ends_on is null or p.ends_on >= current_date)
    and exists (select 1 from public.coach_profiles cp where cp.id = p_coach and cp.status = 'approved')
  order by gc.started_at
  limit 1;
$$;

-- ------------------------------------------- 8. inquiries + profile views
create table public.gym_inquiries (
  id             uuid primary key default gen_random_uuid(),
  gym_id         uuid not null references public.gyms(id) on delete cascade,
  branch_id      uuid references public.gym_branches(id) on delete set null,
  offer_id       uuid references public.gym_offers(id) on delete set null,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  name           text not null check (length(btrim(name)) between 1 and 80),
  phone          text check (phone is null or phone ~ '^\+?[0-9 ()-]{6,20}$'),
  contact_method gym_contact_method not null default 'whatsapp',
  message        text check (message is null or length(message) <= 500),
  status         gym_inquiry_status not null default 'new',
  handled_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint inquiry_reachable check (contact_method = 'in_app' or phone is not null)
);
create index idx_gym_inquiries_gym on public.gym_inquiries (gym_id, status, created_at desc);
create index idx_gym_inquiries_user on public.gym_inquiries (user_id, created_at);

-- One row per signed-in viewer per gym per day. No client policies: the
-- app writes through record_gym_view and reads counts from the overview.
create table public.gym_profile_views (
  gym_id    uuid not null references public.gyms(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_on date not null default current_date,
  primary key (gym_id, viewer_id, viewed_on)
);

-- ---------------------------------------------------------------- 9. RLS
alter table public.gyms                  enable row level security;
alter table public.gym_staff             enable row level security;
alter table public.gym_staff_invites     enable row level security;
alter table public.gym_branches          enable row level security;
alter table public.gym_offers            enable row level security;
alter table public.gym_photos            enable row level security;
alter table public.gym_coach_invitations enable row level security;
alter table public.gym_coaches           enable row level security;
alter table public.gym_partnerships      enable row level security;
alter table public.ai_usage_events       enable row level security;
alter table public.gym_inquiries         enable row level security;
alter table public.gym_profile_views     enable row level security;

-- gyms: public when listed; staff always; profile staff edit; admin all.
-- The coach code hash is never selected by the app (RPCs return the code).
create policy "gyms_select_public" on public.gyms for select to authenticated
  using (public.gym_is_public(id));
create policy "gyms_select_staff" on public.gyms for select
  using (public.gym_has_role(id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gyms_staff_update" on public.gyms for update
  using (public.gym_has_role(id, 'owner', 'manager', 'marketing'))
  with check (public.gym_has_role(id, 'owner', 'manager', 'marketing'));
create policy "gyms_admin_all" on public.gyms for all
  using (public.is_admin()) with check (public.is_admin());

-- marketplace listing of a gym: staff read + edit (status/owner/publish
-- stay guarded by triggers).
create policy "marketplace_gym_staff_select" on public.marketplace_listings for select
  using (provider_type = 'gym' and exists (
    select 1 from public.gyms g where g.listing_id = marketplace_listings.id
      and public.gym_has_role(g.id, 'owner', 'manager', 'marketing', 'front_desk')));
create policy "marketplace_gym_staff_update" on public.marketplace_listings for update
  using (provider_type = 'gym' and exists (
    select 1 from public.gyms g where g.listing_id = marketplace_listings.id
      and public.gym_has_role(g.id, 'owner', 'manager', 'marketing')))
  with check (provider_type = 'gym' and exists (
    select 1 from public.gyms g where g.listing_id = marketplace_listings.id
      and public.gym_has_role(g.id, 'owner', 'manager', 'marketing')));

-- staff: every staff member sees the team; changes via RPCs only.
create policy "gym_staff_select" on public.gym_staff for select
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gym_staff_admin_all" on public.gym_staff for all
  using (public.is_admin()) with check (public.is_admin());

create policy "gym_staff_invites_owner_select" on public.gym_staff_invites for select
  using (public.gym_has_role(gym_id, 'owner'));

-- branches / offers / photos: public when the gym is; staff read; profile
-- staff write.
create policy "gym_branches_select_public" on public.gym_branches for select to authenticated
  using (deleted_at is null and is_published and public.gym_is_public(gym_id));
create policy "gym_branches_select_staff" on public.gym_branches for select
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gym_branches_staff_insert" on public.gym_branches for insert
  with check (public.gym_has_role(gym_id, 'owner', 'manager'));
create policy "gym_branches_staff_update" on public.gym_branches for update
  using (public.gym_has_role(gym_id, 'owner', 'manager'))
  with check (public.gym_has_role(gym_id, 'owner', 'manager'));

create policy "gym_offers_select_public" on public.gym_offers for select to authenticated
  using (deleted_at is null and is_visible and public.gym_is_public(gym_id));
create policy "gym_offers_select_staff" on public.gym_offers for select
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gym_offers_staff_insert" on public.gym_offers for insert
  with check (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing'));
create policy "gym_offers_staff_update" on public.gym_offers for update
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing'))
  with check (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing'));

create policy "gym_photos_select_public" on public.gym_photos for select to authenticated
  using (public.gym_is_public(gym_id));
create policy "gym_photos_select_staff" on public.gym_photos for select
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gym_photos_staff_insert" on public.gym_photos for insert
  with check (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing')
              and split_part(storage_path, '/', 1) = gym_id::text);
create policy "gym_photos_staff_update" on public.gym_photos for update
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing'))
  with check (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing')
              and split_part(storage_path, '/', 1) = gym_id::text);
create policy "gym_photos_staff_delete" on public.gym_photos for delete
  using (public.gym_has_role(gym_id, 'owner', 'manager', 'marketing'));

-- coach invitations: the coach and the gym's owner/manager read; RPCs write.
create policy "gym_coach_invites_select" on public.gym_coach_invitations for select
  using (coach_id = auth.uid() or public.gym_has_role(gym_id, 'owner', 'manager'));

-- affiliations: coach, staff, and the public card of a listed gym.
create policy "gym_coaches_select_party" on public.gym_coaches for select
  using (coach_id = auth.uid() or public.gym_has_role(gym_id, 'owner', 'manager', 'marketing', 'front_desk'));
create policy "gym_coaches_select_public" on public.gym_coaches for select to authenticated
  using (status = 'active' and public.gym_is_public(gym_id));

-- partnerships: owner/manager read; admin everything; request via RPC.
create policy "gym_partnerships_staff_select" on public.gym_partnerships for select
  using (public.gym_has_role(gym_id, 'owner', 'manager'));
create policy "gym_partnerships_admin_all" on public.gym_partnerships for all
  using (public.is_admin()) with check (public.is_admin());

-- AI usage: a coach reads their own; owner/manager read their gym's
-- (feature + units + coach only, there is no content). Server writes.
create policy "ai_usage_coach_select" on public.ai_usage_events for select
  using (coach_id = auth.uid());
create policy "ai_usage_gym_select" on public.ai_usage_events for select
  using (gym_id is not null and public.gym_has_role(gym_id, 'owner', 'manager'));

-- inquiries: the sender reads their own; owner/manager/front desk read;
-- writes via submit_gym_inquiry / set_gym_inquiry_status.
create policy "gym_inquiries_select" on public.gym_inquiries for select
  using (user_id = auth.uid() or public.gym_has_role(gym_id, 'owner', 'manager', 'front_desk'));

-- --------------------------------------------------------------- 10. RPCs

-- Owner: create a gym (listing + gym + owner seat). Starts as a private draft.
create or replace function public.create_gym(
  p_name text, p_city text, p_phone text, p_email text default null,
  p_multi_branch boolean default false
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_listing uuid; v_gym uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to set up a gym'; end if;
  if exists (select 1 from gym_staff where user_id = auth.uid() and role = 'owner') then
    raise exception 'You already own a gym on Grit';
  end if;
  insert into marketplace_listings (owner_id, provider_type, status, is_published, name, phone, email, city)
  values (auth.uid(), 'gym', 'pending', false, btrim(p_name), nullif(btrim(p_phone), ''),
          nullif(btrim(p_email), ''), btrim(p_city))
  returning id into v_listing;
  insert into gyms (listing_id, owner_id, is_multi_branch)
  values (v_listing, auth.uid(), coalesce(p_multi_branch, false))
  returning id into v_gym;
  insert into gym_staff (gym_id, user_id, role, added_by) values (v_gym, auth.uid(), 'owner', auth.uid());
  return v_gym;
end;
$$;

-- Gyms the caller works at (entry point for the admin area).
create or replace function public.get_my_gyms()
returns table(gym_id uuid, name text, logo_url text, role gym_staff_role)
language sql stable security definer set search_path = public, pg_temp as $$
  select g.id, l.name, l.logo_url, s.role
  from gym_staff s join gyms g on g.id = s.gym_id join marketplace_listings l on l.id = g.listing_id
  where s.user_id = auth.uid() and l.deleted_at is null
  order by s.created_at;
$$;

-- Publish / unpublish. Publishing checks the listing is complete; Grit's
-- review (status) still decides when it goes live.
create or replace function public.set_gym_published(p_gym uuid, p_publish boolean)
returns text
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_listing marketplace_listings%rowtype; v_gym gyms%rowtype;
begin
  if not public.gym_has_role(p_gym, 'owner', 'manager') then
    raise exception 'Only the owner or a manager can publish this gym';
  end if;
  select * into v_gym from gyms where id = p_gym;
  select * into v_listing from marketplace_listings where id = v_gym.listing_id;
  if v_listing.status = 'suspended' then raise exception 'This listing is suspended by Grit'; end if;
  if p_publish then
    if v_listing.description is null or length(btrim(v_listing.description)) < 20 then
      raise exception 'Add a description of at least 20 characters before publishing';
    end if;
    if v_gym.cover_path is null then raise exception 'Add a cover photo before publishing'; end if;
    if not exists (select 1 from gym_branches b where b.gym_id = p_gym and b.deleted_at is null and b.is_published) then
      raise exception 'Add at least one branch with opening hours before publishing';
    end if;
  end if;
  perform set_config('grit.gym_publish', 'on', true);
  update marketplace_listings set is_published = p_publish where id = v_gym.listing_id;
  if p_publish and v_gym.submitted_at is null then
    update gyms set submitted_at = now() where id = p_gym;
  end if;
  return public.gym_listing_state(p_gym);
end;
$$;

-- draft · pending_review · published · unpublished · suspended
create or replace function public.gym_listing_state(p_gym uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select case
    when l.status = 'suspended' then 'suspended'
    when not l.is_published and g.submitted_at is null then 'draft'
    when not l.is_published then 'unpublished'
    when l.status = 'pending' then 'pending_review'
    else 'published' end
  from gyms g join marketplace_listings l on l.id = g.listing_id where g.id = p_gym;
$$;

-- Public directory of listed gyms (search + facility filter).
create or replace function public.get_gym_directory(
  p_search text default null, p_city text default null, p_facility text default null, p_limit int default 50
) returns table(
  gym_id uuid, name text, headline text, logo_url text, cover_path text, area text, city text,
  facilities text[], branch_count int, offers_from numeric, currency text, is_partner boolean
)
language sql stable security definer set search_path = public, pg_temp as $$
  select g.id, l.name, l.headline, l.logo_url, g.cover_path, l.area, l.city, g.facilities,
         (select count(*)::int from gym_branches b where b.gym_id = g.id and b.deleted_at is null and b.is_published),
         (select min(o.price_amount) from gym_offers o
           where o.gym_id = g.id and o.deleted_at is null and o.is_visible and o.price_amount is not null),
         (select o.currency::text from gym_offers o
           where o.gym_id = g.id and o.deleted_at is null and o.is_visible and o.price_amount is not null
           order by o.price_amount limit 1),
         exists (select 1 from gym_partnerships p where p.gym_id = g.id and p.status = 'active'
                 and p.starts_on <= current_date and (p.ends_on is null or p.ends_on >= current_date))
  from gyms g join marketplace_listings l on l.id = g.listing_id
  where public.gym_is_public(g.id)
    and (p_city is null or l.city ilike p_city)
    and (p_facility is null or p_facility = any(g.facilities))
    and (p_search is null or l.name ilike '%' || p_search || '%' or l.area ilike '%' || p_search || '%'
         or exists (select 1 from unnest(g.facilities) f where f ilike '%' || p_search || '%'))
  order by 12 desc, 2
  limit least(coalesce(p_limit, 50), 100);
$$;

-- Coaches shown on a listed gym's page (approved coach profiles only).
create or replace function public.get_gym_public_coaches(p_gym uuid)
returns table(coach_id uuid, display_name text, username text, avatar_url text, headline text, role gym_coach_role)
language sql stable security definer set search_path = public, pg_temp as $$
  select gc.coach_id, p.display_name, p.username, p.avatar_url, cp.headline, gc.role
  from gym_coaches gc
  join profiles p on p.id = gc.coach_id
  join coach_profiles cp on cp.id = gc.coach_id and cp.status = 'approved'
  where gc.gym_id = p_gym and gc.status = 'active' and public.gym_is_public(p_gym)
  order by (gc.role = 'head_coach') desc, gc.started_at;
$$;

-- Any signed-in viewer except the gym's own staff; one count per day.
create or replace function public.record_gym_view(p_gym uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.gym_is_public(p_gym) or public.gym_role(p_gym) is not null then
    return;
  end if;
  insert into gym_profile_views (gym_id, viewer_id) values (p_gym, auth.uid())
  on conflict do nothing;
end;
$$;

-- A member asks the gym about joining. Rate-limited per sender.
create or replace function public.submit_gym_inquiry(
  p_gym uuid, p_name text, p_phone text, p_contact_method gym_contact_method,
  p_message text default null, p_branch uuid default null, p_offer uuid default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to contact a gym'; end if;
  if not public.gym_is_public(p_gym) then raise exception 'This gym isn''t taking inquiries right now'; end if;
  if p_branch is not null and not exists (
       select 1 from gym_branches b where b.id = p_branch and b.gym_id = p_gym and b.deleted_at is null) then
    raise exception 'Unknown branch';
  end if;
  if p_offer is not null and not exists (
       select 1 from gym_offers o where o.id = p_offer and o.gym_id = p_gym and o.deleted_at is null) then
    raise exception 'Unknown offer';
  end if;
  if (select count(*) from gym_inquiries i where i.user_id = auth.uid() and i.gym_id = p_gym
      and i.created_at > now() - interval '1 day') >= 3 then
    raise exception 'You''ve already contacted this gym today. They''ll get back to you';
  end if;
  if (select count(*) from gym_inquiries i where i.user_id = auth.uid()
      and i.created_at > now() - interval '1 day') >= 15 then
    raise exception 'Too many inquiries today. Try again tomorrow';
  end if;
  insert into gym_inquiries (gym_id, branch_id, offer_id, user_id, name, phone, contact_method, message)
  values (p_gym, p_branch, p_offer, auth.uid(), btrim(p_name), nullif(btrim(p_phone), ''),
          p_contact_method, nullif(btrim(p_message), ''))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_gym_inquiry_status(p_inquiry uuid, p_status gym_inquiry_status)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_gym uuid;
begin
  select gym_id into v_gym from gym_inquiries where id = p_inquiry;
  if v_gym is null or not public.gym_has_role(v_gym, 'owner', 'manager', 'front_desk') then
    raise exception 'Inquiry not found';
  end if;
  update gym_inquiries set status = p_status, handled_by = auth.uid(), updated_at = now() where id = p_inquiry;
end;
$$;

-- Admin overview for one gym (any staff role; counts only).
create or replace function public.get_gym_admin_overview(p_gym uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_role gym_staff_role; v jsonb; v_month timestamptz := date_trunc('month', now());
begin
  v_role := public.gym_role(p_gym);
  if v_role is null then raise exception 'You don''t work at this gym'; end if;
  select jsonb_build_object(
    'gym_id', g.id, 'name', l.name, 'logo_url', l.logo_url, 'cover_path', g.cover_path,
    'role', v_role, 'listing_state', public.gym_listing_state(g.id),
    'branch_count', (select count(*) from gym_branches b where b.gym_id = g.id and b.deleted_at is null),
    'offer_count', (select count(*) from gym_offers o where o.gym_id = g.id and o.deleted_at is null and o.is_visible),
    'photo_count', (select count(*) from gym_photos ph where ph.gym_id = g.id),
    'has_description', coalesce(length(btrim(l.description)) >= 20, false),
    'staff_count', (select count(*) from gym_staff s where s.gym_id = g.id),
    'coach_count', (select count(*) from gym_coaches gc where gc.gym_id = g.id and gc.status = 'active'),
    'pending_invites', (select count(*) from gym_coach_invitations i where i.gym_id = g.id
                          and i.status = 'pending' and i.expires_at > now()),
    'views_30d', (select count(*) from gym_profile_views pv where pv.gym_id = g.id
                    and pv.viewed_on > current_date - 30),
    'views_14d', (select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'views',
                     (select count(*) from gym_profile_views pv where pv.gym_id = g.id and pv.viewed_on = d::date))
                     order by d), '[]'::jsonb)
                  from generate_series((current_date - 13)::timestamp, current_date::timestamp, interval '1 day') d),
    'inquiries_new', case when v_role in ('owner', 'manager', 'front_desk') then
                       (select count(*) from gym_inquiries i where i.gym_id = g.id and i.status = 'new') end,
    'inquiries_month', case when v_role in ('owner', 'manager', 'front_desk') then
                       (select count(*) from gym_inquiries i where i.gym_id = g.id and i.created_at >= v_month) end,
    'partnership', (select to_jsonb(x) from (
        select p.id, p.status, p.starts_on, p.ends_on, p.ai_monthly_allowance, p.ai_per_coach_cap, p.ai_features,
               (select coalesce(sum(u.units), 0) from ai_usage_events u
                 where u.partnership_id = p.id and u.created_at >= v_month) as ai_used_month
        from gym_partnerships p where p.gym_id = g.id
        order by (p.status in ('pending_review', 'active', 'suspended')) desc, p.created_at desc limit 1) x)
  ) into v
  from gyms g join marketplace_listings l on l.id = g.listing_id where g.id = p_gym;
  return v;
end;
$$;

-- Coaches + invitations for the admin Coaches screen (owner/manager).
create or replace function public.get_gym_coaches_admin(p_gym uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_month timestamptz := date_trunc('month', now());
begin
  if not public.gym_has_role(p_gym, 'owner', 'manager') then raise exception 'Not allowed'; end if;
  return jsonb_build_object(
    'coaches', coalesce((select jsonb_agg(jsonb_build_object(
        'id', gc.id, 'coach_id', gc.coach_id, 'display_name', p.display_name, 'username', p.username,
        'avatar_url', p.avatar_url, 'role', gc.role, 'branch_ids', gc.branch_ids, 'started_at', gc.started_at,
        'ai_used_month', (select coalesce(sum(u.units), 0) from ai_usage_events u
                          where u.coach_id = gc.coach_id and u.gym_id = p_gym and u.created_at >= v_month))
        order by gc.started_at)
      from gym_coaches gc join profiles p on p.id = gc.coach_id
      where gc.gym_id = p_gym and gc.status = 'active'), '[]'::jsonb),
    'invitations', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'kind', i.kind, 'coach_id', i.coach_id, 'display_name', p.display_name,
        'username', p.username, 'avatar_url', p.avatar_url, 'role', i.role, 'branch_ids', i.branch_ids,
        'status', case when i.status = 'pending' and i.expires_at <= now() then 'expired' else i.status::text end,
        'created_at', i.created_at, 'expires_at', i.expires_at, 'responded_at', i.responded_at)
        order by i.created_at desc)
      from gym_coach_invitations i join profiles p on p.id = i.coach_id
      where i.gym_id = p_gym and i.created_at > now() - interval '90 days'), '[]'::jsonb),
    'code_hint', (select g.coach_code_hint from gyms g where g.id = p_gym),
    'code_expires_at', (select g.coach_code_expires_at from gyms g where g.id = p_gym));
end;
$$;

-- Owner/manager invite an approved Grit coach by the email on their
-- account. Nothing is emailed: the coach sees it in Coach Hub.
create or replace function public.invite_gym_coach(
  p_gym uuid, p_email text, p_role gym_coach_role default 'coach',
  p_branch_ids uuid[] default '{}', p_message text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp, auth as $$
declare v_coach uuid; v_id uuid;
begin
  if not public.gym_has_role(p_gym, 'owner', 'manager') then
    raise exception 'Only the owner or a manager can invite coaches';
  end if;
  select u.id into v_coach from auth.users u
    join public.coach_profiles cp on cp.id = u.id and cp.status = 'approved'
    where lower(u.email) = lower(btrim(p_email));
  if v_coach is null then
    raise exception 'No approved Grit coach uses that email. Share your gym''s coach code instead';
  end if;
  if exists (select 1 from gym_coaches gc where gc.gym_id = p_gym and gc.coach_id = v_coach and gc.status = 'active') then
    raise exception 'This coach is already at your gym';
  end if;
  if exists (select 1 from unnest(coalesce(p_branch_ids, '{}')) b
             where not exists (select 1 from gym_branches gb where gb.id = b and gb.gym_id = p_gym)) then
    raise exception 'Unknown branch';
  end if;
  -- an expired pending invite gives way to the new one
  update gym_coach_invitations set status = 'expired'
    where gym_id = p_gym and coach_id = v_coach and status = 'pending' and expires_at <= now();
  if exists (select 1 from gym_coach_invitations i where i.gym_id = p_gym and i.coach_id = v_coach and i.status = 'pending') then
    raise exception 'There''s already an open invitation or request for this coach';
  end if;
  insert into gym_coach_invitations (gym_id, kind, coach_id, role, branch_ids, message, created_by, expires_at)
  values (p_gym, 'gym_invite', v_coach, coalesce(p_role, 'coach'), coalesce(p_branch_ids, '{}'),
          nullif(btrim(p_message), ''), auth.uid(), now() + interval '14 days')
  returning id into v_id;
  return v_id;
end;
$$;

-- Owner/manager: new 8-character coach code, valid 7 days. Returned once.
create or replace function public.rotate_gym_coach_code(p_gym uuid)
returns table(code text, expires_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  c_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  c_byte_idx constant int[] := array[0, 1, 2, 3, 4, 5, 9, 10];
  v_raw text; v_bytes bytea; v_exp timestamptz := now() + interval '7 days'; i int;
begin
  if not public.gym_has_role(p_gym, 'owner', 'manager') then raise exception 'Not allowed'; end if;
  loop
    v_raw := '';
    v_bytes := uuid_send(gen_random_uuid());
    foreach i in array c_byte_idx loop
      v_raw := v_raw || substr(c_alphabet, (get_byte(v_bytes, i) % length(c_alphabet)) + 1, 1);
    end loop;
    begin
      update gyms set coach_code_hash = public.invite_code_hash(v_raw), coach_code_hint = right(v_raw, 4),
                      coach_code_expires_at = v_exp
      where id = p_gym;
      exit;
    exception when unique_violation then
    end;
  end loop;
  return query select substr(v_raw, 1, 4) || '-' || substr(v_raw, 5, 4), v_exp;
end;
$$;

-- Coach: ask to join a gym with its code. The gym then approves.
create or replace function public.request_gym_affiliation(p_code text)
returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_gym uuid; v_id uuid;
begin
  if not public.is_coach() then raise exception 'Only an approved coach can join a gym'; end if;
  select g.id into v_gym from gyms g
    where g.coach_code_hash = public.invite_code_hash(p_code) and g.coach_code_expires_at > now();
  if v_gym is null then raise exception 'That code isn''t valid. Ask the gym for a new one'; end if;
  if exists (select 1 from gym_coaches gc where gc.gym_id = v_gym and gc.coach_id = auth.uid() and gc.status = 'active') then
    raise exception 'You''re already at this gym';
  end if;
  update gym_coach_invitations set status = 'expired'
    where gym_id = v_gym and coach_id = auth.uid() and status = 'pending' and expires_at <= now();
  if exists (select 1 from gym_coach_invitations i where i.gym_id = v_gym and i.coach_id = auth.uid() and i.status = 'pending') then
    raise exception 'You already have an open invitation from this gym. Check Coach Hub';
  end if;
  insert into gym_coach_invitations (gym_id, kind, coach_id, created_by, expires_at)
  values (v_gym, 'coach_request', auth.uid(), auth.uid(), now() + interval '14 days')
  returning id into v_id;
  return v_id;
end;
$$;

-- Accept / decline. A gym invite is answered by the coach; a coach's code
-- request by the gym's owner/manager. Accepting creates the affiliation.
create or replace function public.respond_gym_invitation(p_invitation uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v gym_coach_invitations%rowtype;
begin
  select * into v from gym_coach_invitations where id = p_invitation for update;
  if not found then raise exception 'Invitation not found'; end if;
  if (v.kind = 'gym_invite' and v.coach_id <> auth.uid())
     or (v.kind = 'coach_request' and not public.gym_has_role(v.gym_id, 'owner', 'manager')) then
    raise exception 'Invitation not found';
  end if;
  if v.status <> 'pending' then raise exception 'This invitation is no longer open'; end if;
  if v.expires_at <= now() then
    update gym_coach_invitations set status = 'expired' where id = v.id;
    raise exception 'This invitation has expired';
  end if;
  if p_accept and not exists (select 1 from coach_profiles cp where cp.id = v.coach_id and cp.status = 'approved') then
    raise exception 'The coach needs an approved Grit coach profile first';
  end if;
  update gym_coach_invitations
    set status = case when p_accept then 'accepted'::gym_invite_status else 'declined'::gym_invite_status end,
        responded_by = auth.uid(), responded_at = now()
    where id = v.id;
  if p_accept and not exists (select 1 from gym_coaches gc where gc.gym_id = v.gym_id and gc.coach_id = v.coach_id and gc.status = 'active') then
    insert into gym_coaches (gym_id, coach_id, role, branch_ids, invitation_id)
    values (v.gym_id, v.coach_id, v.role, v.branch_ids, v.id);
  end if;
end;
$$;

-- Withdraw an open invitation: the gym its invite, the coach their request.
create or replace function public.cancel_gym_invitation(p_invitation uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v gym_coach_invitations%rowtype;
begin
  select * into v from gym_coach_invitations where id = p_invitation for update;
  if not found or not ((v.kind = 'gym_invite' and public.gym_has_role(v.gym_id, 'owner', 'manager'))
                       or (v.kind = 'coach_request' and v.coach_id = auth.uid())) then
    raise exception 'Invitation not found';
  end if;
  if v.status <> 'pending' then raise exception 'This invitation is no longer open'; end if;
  update gym_coach_invitations set status = 'cancelled', responded_by = auth.uid(), responded_at = now()
    where id = v.id;
end;
$$;

-- Either side ends an affiliation. AI access stops immediately.
create or replace function public.end_gym_affiliation(p_affiliation uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v gym_coaches%rowtype;
begin
  select * into v from gym_coaches where id = p_affiliation for update;
  if not found or v.status <> 'active'
     or not (v.coach_id = auth.uid() or public.gym_has_role(v.gym_id, 'owner', 'manager')) then
    raise exception 'Not found';
  end if;
  update gym_coaches set status = 'ended', ended_at = now(), ended_by = auth.uid() where id = v.id;
end;
$$;

-- Coach Hub: my gym invitations / requests and affiliations.
create or replace function public.get_my_gym_affiliations()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'affiliations', coalesce((select jsonb_agg(jsonb_build_object(
        'id', gc.id, 'gym_id', gc.gym_id, 'gym_name', l.name, 'logo_url', l.logo_url,
        'role', gc.role, 'started_at', gc.started_at) order by gc.started_at)
      from gym_coaches gc join gyms g on g.id = gc.gym_id join marketplace_listings l on l.id = g.listing_id
      where gc.coach_id = auth.uid() and gc.status = 'active'), '[]'::jsonb),
    'invitations', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'kind', i.kind, 'gym_id', i.gym_id, 'gym_name', l.name, 'logo_url', l.logo_url,
        'role', i.role, 'message', i.message, 'branch_names',
          (select coalesce(jsonb_agg(b.name order by b.sort_order), '[]'::jsonb) from gym_branches b
            where b.id = any(i.branch_ids)),
        'invited_by', (select p.display_name from profiles p where p.id = i.created_by),
        'created_at', i.created_at, 'expires_at', i.expires_at) order by i.created_at desc)
      from gym_coach_invitations i join gyms g on g.id = i.gym_id join marketplace_listings l on l.id = g.listing_id
      where i.coach_id = auth.uid() and i.status = 'pending' and i.expires_at > now()), '[]'::jsonb));
$$;

-- Coach: what AI the caller gets through a gym partnership right now.
create or replace function public.get_my_ai_entitlement()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare r record; v_month timestamptz := date_trunc('month', now()); v_gym_used int; v_my_used int;
begin
  select * into r from public.coach_ai_partnership(auth.uid());
  if not found then return jsonb_build_object('eligible', false); end if;
  select coalesce(sum(units), 0) into v_gym_used from ai_usage_events
    where partnership_id = r.partnership_id and created_at >= v_month;
  select coalesce(sum(units), 0) into v_my_used from ai_usage_events
    where partnership_id = r.partnership_id and coach_id = auth.uid() and created_at >= v_month;
  return jsonb_build_object(
    'eligible', true, 'gym_id', r.gym_id,
    'gym_name', (select l.name from gyms g join marketplace_listings l on l.id = g.listing_id where g.id = r.gym_id),
    'features', r.features, 'monthly_allowance', r.monthly_allowance, 'gym_used', v_gym_used,
    'per_coach_cap', r.per_coach_cap, 'my_used', v_my_used,
    'resets_on', (date_trunc('month', now()) + interval '1 month')::date);
end;
$$;

-- SERVER ONLY (service_role, e.g. the future AI Edge Function): check and
-- record one AI request atomically. Returns allowed + remaining.
create or replace function public.consume_ai_allowance(p_coach uuid, p_feature text, p_units int default 1)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; v_month timestamptz := date_trunc('month', now()); v_gym_used int; v_my_used int;
begin
  select * into r from public.coach_ai_partnership(p_coach);
  if not found then return jsonb_build_object('allowed', false, 'reason', 'no_entitlement'); end if;
  if not (p_feature = any(r.features)) then
    return jsonb_build_object('allowed', false, 'reason', 'feature_not_included');
  end if;
  perform 1 from gym_partnerships where id = r.partnership_id for update;  -- serialize per partnership
  select coalesce(sum(units), 0) into v_gym_used from ai_usage_events
    where partnership_id = r.partnership_id and created_at >= v_month;
  select coalesce(sum(units), 0) into v_my_used from ai_usage_events
    where partnership_id = r.partnership_id and coach_id = p_coach and created_at >= v_month;
  if v_gym_used + p_units > r.monthly_allowance then
    return jsonb_build_object('allowed', false, 'reason', 'gym_allowance_used');
  end if;
  if r.per_coach_cap is not null and v_my_used + p_units > r.per_coach_cap then
    return jsonb_build_object('allowed', false, 'reason', 'coach_cap_used');
  end if;
  insert into ai_usage_events (coach_id, gym_id, partnership_id, feature, units)
  values (p_coach, r.gym_id, r.partnership_id, p_feature, p_units);
  return jsonb_build_object('allowed', true,
    'gym_remaining', r.monthly_allowance - v_gym_used - p_units,
    'coach_remaining', case when r.per_coach_cap is null then null else r.per_coach_cap - v_my_used - p_units end);
end;
$$;

-- Owner: ask Grit for a partnership. Grit reviews and sets the terms.
create or replace function public.request_gym_partnership(p_gym uuid)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  if not public.gym_has_role(p_gym, 'owner') then raise exception 'Only the owner can request a partnership'; end if;
  if exists (select 1 from gym_partnerships where gym_id = p_gym and status in ('pending_review', 'active', 'suspended')) then
    raise exception 'Your gym already has a partnership request or partnership';
  end if;
  insert into gym_partnerships (gym_id, status, requested_by) values (p_gym, 'pending_review', auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- Staff: owner creates a single-use staff code (role ≠ owner), valid 7 days.
create or replace function public.create_gym_staff_invite(p_gym uuid, p_role gym_staff_role)
returns table(invite_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  c_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  c_byte_idx constant int[] := array[0, 1, 2, 3, 4, 5, 9, 10, 11, 12];
  v_raw text; v_bytes bytea; v_exp timestamptz := now() + interval '7 days'; v_id uuid; i int;
begin
  if not public.gym_has_role(p_gym, 'owner') then raise exception 'Only the owner can add staff'; end if;
  if p_role = 'owner' then raise exception 'A gym has one owner'; end if;
  loop
    v_raw := '';
    v_bytes := uuid_send(gen_random_uuid());
    foreach i in array c_byte_idx loop
      v_raw := v_raw || substr(c_alphabet, (get_byte(v_bytes, i) % length(c_alphabet)) + 1, 1);
    end loop;
    begin
      insert into gym_staff_invites (gym_id, role, code_hash, code_hint, created_by, expires_at)
      values (p_gym, p_role, public.invite_code_hash(v_raw), right(v_raw, 4), auth.uid(), v_exp)
      returning id into v_id;
      exit;
    exception when unique_violation then
    end;
  end loop;
  return query select v_id, substr(v_raw, 1, 5) || '-' || substr(v_raw, 6, 5), v_exp;
end;
$$;

create or replace function public.accept_gym_staff_invite(p_code text)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v gym_staff_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select * into v from gym_staff_invites
    where code_hash = public.invite_code_hash(p_code) and accepted_at is null and revoked_at is null
      and expires_at > now()
    for update;
  if not found then raise exception 'That code isn''t valid. Ask the owner for a new one'; end if;
  if exists (select 1 from gym_staff where gym_id = v.gym_id and user_id = auth.uid()) then
    raise exception 'You''re already on this gym''s team';
  end if;
  insert into gym_staff (gym_id, user_id, role, added_by) values (v.gym_id, auth.uid(), v.role, v.created_by);
  update gym_staff_invites set accepted_by = auth.uid(), accepted_at = now() where id = v.id;
  return v.gym_id;
end;
$$;

-- Owner changes a teammate's role or removes them (never the owner seat).
create or replace function public.set_gym_staff_role(p_gym uuid, p_user uuid, p_role gym_staff_role)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.gym_has_role(p_gym, 'owner') then raise exception 'Only the owner can change roles'; end if;
  if p_role = 'owner' or p_user = auth.uid() then raise exception 'Use ownership transfer to change the owner'; end if;
  update gym_staff set role = p_role where gym_id = p_gym and user_id = p_user and role <> 'owner';
  if not found then raise exception 'Not on the team'; end if;
end;
$$;

create or replace function public.remove_gym_staff(p_gym uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not (public.gym_has_role(p_gym, 'owner') or p_user = auth.uid()) then raise exception 'Not allowed'; end if;
  delete from gym_staff where gym_id = p_gym and user_id = p_user and role <> 'owner';
end;
$$;

-- Team list with names for Settings (any staff role).
create or replace function public.get_gym_staff(p_gym uuid)
returns table(user_id uuid, display_name text, username text, avatar_url text, role gym_staff_role, created_at timestamptz)
language sql stable security definer set search_path = public, pg_temp as $$
  select s.user_id, p.display_name, p.username, p.avatar_url, s.role, s.created_at
  from gym_staff s join profiles p on p.id = s.user_id
  where s.gym_id = p_gym and public.gym_role(p_gym) is not null
  order by (s.role = 'owner') desc, s.created_at;
$$;

-- ------------------------------------------------------- 11. guards + grants

-- gyms: owner_id / listing_id / code fields / submitted_at are not editable
-- from the app (the RPCs above set them).
create or replace function public.guard_gym_row()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if current_user in ('anon', 'authenticated') and not public.is_admin() and (
       new.owner_id is distinct from old.owner_id or new.listing_id is distinct from old.listing_id
       or ((new.coach_code_hash is distinct from old.coach_code_hash
            or new.coach_code_hint is distinct from old.coach_code_hint
            or new.coach_code_expires_at is distinct from old.coach_code_expires_at
            or new.submitted_at is distinct from old.submitted_at)
           and current_setting('grit.gym_rpc', true) is distinct from 'on')) then
    raise exception 'That field can''t be changed here';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_guard_gym_row before update on public.gyms
  for each row execute function public.guard_gym_row();

-- The definer RPCs that set guarded gym fields mark themselves first.
-- (Definer functions run as the owner, so current_user isn't
-- 'authenticated' there and the guard already lets them through; the
-- setting is belt-and-braces for future invoker callers.)

-- marketplace_listings: is_published only through set_gym_published.
create or replace function public.guard_listing_publish()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.is_published is distinct from old.is_published
     and current_user in ('anon', 'authenticated') and not public.is_admin()
     and current_setting('grit.gym_publish', true) is distinct from 'on' then
    raise exception 'Use publish / unpublish to change this';
  end if;
  return new;
end;
$$;
create trigger trg_guard_listing_publish before update on public.marketplace_listings
  for each row execute function public.guard_listing_publish();

-- offers may only point at their own gym's branches
create or replace function public.guard_gym_offer()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if exists (select 1 from unnest(new.branch_ids) b
             where not exists (select 1 from public.gym_branches gb where gb.id = b and gb.gym_id = new.gym_id)) then
    raise exception 'An offer can only list this gym''s branches';
  end if;
  if tg_op = 'UPDATE' and new.gym_id is distinct from old.gym_id then
    raise exception 'An offer can''t move to another gym';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_guard_gym_offer before insert or update on public.gym_offers
  for each row execute function public.guard_gym_offer();

create or replace function public.guard_gym_branch()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' and new.gym_id is distinct from old.gym_id then
    raise exception 'A branch can''t move to another gym';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_guard_gym_branch before insert or update on public.gym_branches
  for each row execute function public.guard_gym_branch();

-- at most 12 gallery photos per gym
create or replace function public.guard_gym_photo_count()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if (select count(*) from public.gym_photos where gym_id = new.gym_id) >= 12 then
    raise exception 'A gym can have up to 12 gallery photos';
  end if;
  return new;
end;
$$;
create trigger trg_guard_gym_photo_count before insert on public.gym_photos
  for each row execute function public.guard_gym_photo_count();

create or replace function public.touch_gym_partnership()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' and new.status is distinct from old.status then new.decided_by := auth.uid(); end if;
  return new;
end;
$$;
create trigger trg_touch_gym_partnership before update on public.gym_partnerships
  for each row execute function public.touch_gym_partnership();

-- The coach-code hash must never reach the app (an 8-character code is
-- cheap to brute-force from its hash): column-level select on gyms.
revoke select on public.gyms from anon, authenticated;
grant select (id, listing_id, owner_id, is_multi_branch, cover_path, facilities, equipment, services,
              coach_code_hint, coach_code_expires_at, submitted_at, created_at, updated_at)
  on public.gyms to authenticated;
revoke select on public.gym_staff_invites from anon, authenticated;
grant select (id, gym_id, role, code_hint, created_by, expires_at, accepted_by, accepted_at, revoked_at, created_at)
  on public.gym_staff_invites to authenticated;
revoke all on public.gym_profile_views from anon, authenticated;

-- grants: app RPCs to signed-in users only; usage recording to the server.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('create_gym', 'get_my_gyms', 'set_gym_published', 'gym_listing_state',
                               'get_gym_directory', 'get_gym_public_coaches', 'record_gym_view',
                               'submit_gym_inquiry', 'set_gym_inquiry_status', 'get_gym_admin_overview',
                               'get_gym_coaches_admin', 'invite_gym_coach', 'rotate_gym_coach_code',
                               'request_gym_affiliation', 'respond_gym_invitation', 'cancel_gym_invitation',
                               'end_gym_affiliation', 'get_my_gym_affiliations', 'get_my_ai_entitlement',
                               'request_gym_partnership', 'create_gym_staff_invite', 'accept_gym_staff_invite',
                               'set_gym_staff_role', 'remove_gym_staff', 'get_gym_staff',
                               'gym_role', 'gym_has_role', 'gym_is_public', 'gym_media_writable')
  loop
    execute format('revoke execute on function %s from public, anon', r.f);
    execute format('grant  execute on function %s to authenticated', r.f);
  end loop;
end $$;

revoke execute on function public.consume_ai_allowance(uuid, text, int) from public, anon, authenticated;
grant  execute on function public.consume_ai_allowance(uuid, text, int) to service_role;
revoke execute on function public.coach_ai_partnership(uuid) from public, anon, authenticated;

commit;
