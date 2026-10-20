-- Grit v1.1 patch — exercise library: difficulty + category (FR-4)

alter table public.exercises
  add column if not exists difficulty_level smallint check (difficulty_level between 1 and 5),
  add column if not exists category text;   -- e.g. "strength","cardio","mobility","calisthenics"

create index if not exists idx_exercises_category on public.exercises (category) where deleted_at is null;
create index if not exists idx_exercises_difficulty on public.exercises (difficulty_level) where deleted_at is null;
