-- Migration: Store all free-exercise-db fields that were missing
-- Adds: force, mechanic, images[], level (original string)
-- Fixes: exercise_muscle_groups gets is_primary flag

-- 1. Add missing columns to exercises
alter table public.exercises
  add column if not exists force      text check (force in ('push', 'pull', 'static')),
  add column if not exists mechanic   text check (mechanic in ('compound', 'isolation')),
  add column if not exists images     text[],          -- array of relative image paths
  add column if not exists level      text check (level in ('beginner', 'intermediate', 'expert'));

-- 2. Add is_primary flag to exercise_muscle_groups
--    We need to drop and recreate the PK to allow multiple rows per (exercise, muscle) pair
--    Actually we keep the unique constraint but add the column differently:
--    The PK is (exercise_id, muscle_group_id) - a muscle can't be both primary AND secondary
--    So we just add the column (default false) and update via sync
alter table public.exercise_muscle_groups
  add column if not exists is_primary boolean not null default false;

-- 3. Indexes for new filterable columns
create index if not exists idx_exercises_force    on public.exercises (force)    where deleted_at is null;
create index if not exists idx_exercises_mechanic on public.exercises (mechanic) where deleted_at is null;
create index if not exists idx_exercises_level    on public.exercises (level)    where deleted_at is null;
