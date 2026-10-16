-- =====================================================================
-- TRAIN: exercise library read model + favorites
--
-- features/exercises/data/datasources/exercise_remote_datasource.dart
-- queries three objects that no migration created:
--   * exercise_library_view         one flattened row per exercise
--   * exercise_library_facets_view  distinct filter values
--   * favorites                     per-user favorite exercises
--
-- Column names in the views are the ones the Dart code selects, mapped
-- onto the real tables:
--   exercise_type     <- exercises.category
--   difficulty        <- exercises.level        (beginner/intermediate/expert)
--   mechanics         <- exercises.mechanic
--   primary_muscle    <- muscle_groups.name     (is_primary link; alphabetically
--                                                first if there were ever several)
--   secondary_muscles <- muscle_groups.name[]   (non-primary links)
--   equipment         <- array[exercises.equipment], '{}' when null
--   images            <- exercises.images        (relative paths; the app
--                                                prefixes the image base URL)
--   instructions      <- exercises.description  (the sync script stores the
--                                                joined instructions there)
--
-- Depends on 20261016000001_train_workout_logging.sql (exercises.is_custom).
-- Both views are security_invoker, so the exercises RLS select policy
-- (global rows + the caller's own custom exercises) still applies.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Equipment: "body only" -> "bodyweight"
-- ---------------------------------------------------------------------
-- The sync script used to store free-exercise-db's "body only" as null,
-- which made bodyweight exercises indistinguishable from the ones whose
-- source equipment really is unknown (null upstream). Backfill by slug:
-- these are exactly the free-exercise-db exercises with equipment
-- "body only". The script now writes "bodyweight" directly.
update public.exercises
set equipment = 'bodyweight', updated_at = now()
where equipment is null
  and slug in (
  '3-4-sit-up', '90-90-hamstring', 'air-bike', 'all-fours-quad-stretch',
  'alternate-heel-touchers', 'bench-dips', 'bench-jump', 'bent-knee-hip-raise',
  'body-tricep-press', 'body-up', 'bodyweight-squat', 'bottoms-up',
  'butt-lift-bridge', 'butt-ups', 'chin-up', 'clock-push-up',
  'close-grip-push-up-off-of-a-dumbbell', 'cocoons', 'cross-body-crunch', 'crunch-hands-overhead',
  'crunch-legs-on-exercise-ball', 'crunches', 'dead-bug', 'decline-crunch',
  'decline-oblique-crunch', 'decline-reverse-crunch', 'dips-triceps-version', 'double-leg-butt-kick',
  'elbow-to-knee', 'fast-skipping', 'flat-bench-leg-pull-in', 'flat-bench-lying-leg-raise',
  'flutter-kicks', 'freehand-jump-squat', 'frog-sit-ups', 'front-leg-raises',
  'glute-kickback', 'gorilla-chin-crunch', 'groiners', 'handstand-push-ups',
  'hanging-leg-raise', 'hanging-pike', 'hip-circles-prone', 'hyperextensions-with-no-hyperextension-bench',
  'inchworm', 'incline-push-up', 'incline-push-up-close-grip', 'incline-push-up-medium',
  'incline-push-up-reverse-grip', 'incline-push-up-wide', 'isometric-chest-squeezes', 'isometric-neck-exercise-front-and-back',
  'isometric-neck-exercise-sides', 'isometric-wipers', 'jackknife-sit-up', 'janda-sit-up',
  'knee-circles', 'knee-tuck-jump', 'lateral-bound', 'leg-lift',
  'leg-pull-in', 'lower-back-curl', 'lying-crossover', 'lying-glute',
  'lying-prone-quadriceps', 'natural-glute-ham-raise', 'oblique-crunches', 'oblique-crunches-on-the-floor',
  'overhead-triceps', 'plank', 'plyo-push-up', 'pullups',
  'push-up-to-side-plank', 'push-up-wide', 'push-ups-close-triceps-position', 'push-ups-with-feet-elevated',
  'pushups', 'pushups-close-and-wide-hand-positions', 'rear-leg-raises', 'reverse-crunch',
  'rocket-jump', 'russian-twist', 'scissor-kick', 'scissors-jump',
  'seated-biceps', 'seated-flat-bench-leg-pull-in', 'seated-front-deltoid', 'seated-glute',
  'seated-leg-tucks', 'side-bridge', 'side-jackknife', 'side-leg-raises',
  'single-arm-push-up', 'single-leg-butt-kick', 'single-leg-glute-bridge', 'sit-up',
  'spider-crawl', 'split-jump', 'standing-hip-circles', 'standing-long-jump',
  'standing-towel-triceps-extension', 'star-jump', 'step-up-with-knee-raise', 'stomach-vacuum',
  'superman', 'toe-touchers', 'tuck-crunch', 'v-bar-pullup',
  'wide-grip-rear-pull-up', 'wind-sprints', 'wrist-circles'
  );

update public.exercises
set equipment = 'bodyweight', updated_at = now()
where lower(equipment) = 'body only';

-- ---------------------------------------------------------------------
-- 2. exercise_library_view
-- ---------------------------------------------------------------------
create view public.exercise_library_view
with (security_invoker = true) as
select
  e.id,
  e.name,
  e.slug,
  e.description,
  e.category                                   as exercise_type,
  e.level                                      as difficulty,
  e.mechanic                                   as mechanics,
  e.force,
  e.is_custom,
  pm.name                                      as primary_muscle,
  pm.id                                        as primary_muscle_id,
  coalesce(sm.names, '{}'::text[])             as secondary_muscles,
  case when e.equipment is null then '{}'::text[]
       else array[e.equipment] end             as equipment,
  coalesce(e.images, '{}'::text[])             as images,
  e.description                                as instructions
from public.exercises e
left join lateral (
  select mg.id, mg.name
  from public.exercise_muscle_groups emg
  join public.muscle_groups mg on mg.id = emg.muscle_group_id
  where emg.exercise_id = e.id and emg.is_primary
  order by mg.name
  limit 1
) pm on true
left join lateral (
  select array_agg(mg.name order by mg.name) as names
  from public.exercise_muscle_groups emg
  join public.muscle_groups mg on mg.id = emg.muscle_group_id
  where emg.exercise_id = e.id and not emg.is_primary
) sm on true
where e.deleted_at is null;

-- ---------------------------------------------------------------------
-- 3. exercise_library_facets_view
-- ---------------------------------------------------------------------
-- One row per distinct (primary_muscle, equipment, exercise_type,
-- difficulty) tuple, with equipment[] already unnested. Exercises with
-- no equipment still contribute a row (equipment null) so their muscle,
-- type and difficulty show up as filter options.
create view public.exercise_library_facets_view
with (security_invoker = true) as
select distinct
  v.primary_muscle,
  eq.equipment,
  v.exercise_type,
  v.difficulty
from public.exercise_library_view v
left join lateral unnest(v.equipment) as eq(equipment) on true;

revoke all on public.exercise_library_view, public.exercise_library_facets_view from anon;
grant select on public.exercise_library_view, public.exercise_library_facets_view to authenticated;

-- ---------------------------------------------------------------------
-- 4. favorites (user-owned)
-- ---------------------------------------------------------------------
create table public.favorites (
  user_id      uuid not null references auth.users(id) on delete cascade,
  exercise_id  uuid not null references public.exercises(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (user_id, exercise_id)
);
create index idx_favorites_exercise_id on public.favorites (exercise_id);

alter table public.favorites enable row level security;

create policy "favorites_select_own" on public.favorites for select
  using (user_id = (select auth.uid()));

-- The exists() runs under the exercises RLS policy, so a user can't
-- favorite (and so confirm the existence of) someone else's custom exercise.
create policy "favorites_insert_own" on public.favorites for insert
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.exercises e where e.id = exercise_id)
  );

create policy "favorites_delete_own" on public.favorites for delete
  using (user_id = (select auth.uid()));

-- No update policy: a favorite is either there or not.
revoke all on public.favorites from anon;
revoke update on public.favorites from authenticated;
grant select, insert, delete on public.favorites to authenticated;

commit;
