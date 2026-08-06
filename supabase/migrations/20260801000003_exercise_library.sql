-- 3. EXERCISE LIBRARY  (global, admin-managed, shared by both systems)
-- ============================================================================
create table public.muscle_groups (
  id    smallint primary key generated always as identity,
  name  text not null unique
);

create table public.exercises (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  slug             text not null unique,
  description      text,
  is_hold_based    boolean not null default false,   -- true = timed hold (e.g. L-sit) vs reps
  equipment        text,
  video_url        text,
  image_url        text,
  created_by       uuid references public.profiles(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
create index idx_exercises_name_trgm on public.exercises using gin (name gin_trgm_ops);
create index idx_exercises_deleted_at on public.exercises (deleted_at) where deleted_at is not null;

create table public.exercise_muscle_groups (
  exercise_id      uuid not null references public.exercises(id) on delete cascade,
  muscle_group_id  smallint not null references public.muscle_groups(id) on delete cascade,
  primary key (exercise_id, muscle_group_id)
);


-- ============================================================================
