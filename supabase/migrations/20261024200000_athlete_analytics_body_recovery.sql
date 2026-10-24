-- =====================================================================
-- TRAIN · Athlete Analytics — body progress + recovery check-ins
--
-- Backs the Analytics screens opened from the Dashboard's Analytics
-- button. Muscle-group distribution and the muscle hologram need no
-- schema: they read completed workout_log_sets + exercise_muscle_groups.
--
--   1. body_metrics_log gains optional body measurements (body fat %,
--      neck, chest, waist, hips, arm, thigh, calf) and a note.
--      Existing rows, finish_workout's bodyweight snapshot and the
--      Captain 'body' scope (coach_read_body_metrics) keep working as-is.
--   2. body_goals — one optional bodyweight goal per athlete. Owner
--      CRUD; a Captain can read it only with the 'body' scope on.
--   3. progress_photos + private `progress-photos` bucket. Owner only —
--      there is deliberately NO coach policy: photos are never shared
--      through Connect. Paths are <user_id>/<file>.
--   4. recovery_checkins — one quick check-in per athlete per local
--      date (sleep, soreness, energy, fatigue). Owner only.
--
-- All new tables are tier 1 (user-owned). Nothing here touches a
-- client-read-only progress table, and coaches get no write policy.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Body measurements on the existing weight log
-- ---------------------------------------------------------------------
alter table public.body_metrics_log
  add column if not exists body_fat_pct numeric(4,1),
  add column if not exists neck_cm      numeric(5,1),
  add column if not exists chest_cm     numeric(5,1),
  add column if not exists waist_cm     numeric(5,1),
  add column if not exists hips_cm      numeric(5,1),
  add column if not exists arm_cm       numeric(5,1),
  add column if not exists thigh_cm     numeric(5,1),
  add column if not exists calf_cm      numeric(5,1),
  add column if not exists note         text;

alter table public.body_metrics_log drop constraint if exists at_least_one_metric;
alter table public.body_metrics_log add constraint at_least_one_metric check (
  weight_kg is not null or height_cm is not null or body_fat_pct is not null
  or neck_cm is not null or chest_cm is not null or waist_cm is not null
  or hips_cm is not null or arm_cm is not null or thigh_cm is not null
  or calf_cm is not null
);

-- NOT VALID: enforced for every new/changed row without re-checking
-- history that was saved before these limits existed.
alter table public.body_metrics_log add constraint body_metrics_plausible check (
  (weight_kg    is null or weight_kg    between 20 and 400) and
  (height_cm    is null or height_cm    between 80 and 260) and
  (body_fat_pct is null or body_fat_pct between 2 and 70) and
  (neck_cm      is null or neck_cm      between 15 and 80) and
  (chest_cm     is null or chest_cm     between 40 and 250) and
  (waist_cm     is null or waist_cm     between 30 and 250) and
  (hips_cm      is null or hips_cm      between 40 and 250) and
  (arm_cm       is null or arm_cm       between 10 and 80) and
  (thigh_cm     is null or thigh_cm     between 20 and 120) and
  (calf_cm      is null or calf_cm      between 15 and 80) and
  (note         is null or char_length(note) <= 280)
) not valid;

-- ---------------------------------------------------------------------
-- 2. Optional bodyweight goal
-- ---------------------------------------------------------------------
create table if not exists public.body_goals (
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  target_weight_kg numeric(5,2) not null check (target_weight_kg between 20 and 400),
  -- Bodyweight when the goal was set, so progress has a fixed origin.
  start_weight_kg  numeric(5,2) check (start_weight_kg between 20 and 400),
  target_date      date,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.body_goals enable row level security;

drop policy if exists "body_goals_owner_all" on public.body_goals;
create policy "body_goals_owner_all" on public.body_goals for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "coach_read_body_goals" on public.body_goals;
create policy "coach_read_body_goals" on public.body_goals for select
  using (public.coach_can_view(user_id, 'body'));

drop trigger if exists trg_body_goals_updated_at on public.body_goals;
create trigger trg_body_goals_updated_at before update on public.body_goals
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 3. Private progress photos
-- ---------------------------------------------------------------------
create table if not exists public.progress_photos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  pose         text not null default 'front'
               check (pose in ('front', 'side', 'back', 'other')),
  taken_on     date not null default current_date,
  note         text check (note is null or char_length(note) <= 280),
  created_at   timestamptz not null default now(),
  -- The object must live in the owner's own folder of the bucket.
  constraint progress_photo_path_owned
    check (split_part(storage_path, '/', 1) = user_id::text)
);
create index if not exists idx_progress_photos_user_date
  on public.progress_photos (user_id, taken_on desc, created_at desc);

alter table public.progress_photos enable row level security;

drop policy if exists "progress_photos_owner_all" on public.progress_photos;
create policy "progress_photos_owner_all" on public.progress_photos for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('progress-photos', 'progress-photos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "progress_photos_owner_read" on storage.objects;
create policy "progress_photos_owner_read" on storage.objects for select
  using (bucket_id = 'progress-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "progress_photos_owner_write" on storage.objects;
create policy "progress_photos_owner_write" on storage.objects for insert
  with check (bucket_id = 'progress-photos'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "progress_photos_owner_update" on storage.objects;
create policy "progress_photos_owner_update" on storage.objects for update
  using (bucket_id = 'progress-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'progress-photos'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "progress_photos_owner_delete" on storage.objects;
create policy "progress_photos_owner_delete" on storage.objects for delete
  using (bucket_id = 'progress-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------
-- 4. Daily recovery check-ins
--    Scales are 1–5: soreness 1 = none, 5 = very sore; energy 1 = very
--    low, 5 = high; fatigue 1 = fresh, 5 = exhausted; sleep_quality
--    1 = poor, 5 = great.
-- ---------------------------------------------------------------------
create table if not exists public.recovery_checkins (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  checkin_date  date not null,
  sleep_hours   numeric(3,1) not null check (sleep_hours between 0 and 16),
  sleep_quality smallint check (sleep_quality between 1 and 5),
  soreness      smallint not null check (soreness between 1 and 5),
  energy        smallint not null check (energy between 1 and 5),
  fatigue       smallint not null check (fatigue between 1 and 5),
  note          text check (note is null or char_length(note) <= 280),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint recovery_checkins_one_per_day unique (user_id, checkin_date)
);

alter table public.recovery_checkins enable row level security;

drop policy if exists "recovery_checkins_owner_all" on public.recovery_checkins;
create policy "recovery_checkins_owner_all" on public.recovery_checkins for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop trigger if exists trg_recovery_checkins_updated_at on public.recovery_checkins;
create trigger trg_recovery_checkins_updated_at before update on public.recovery_checkins
  for each row execute function public.set_updated_at();

commit;
