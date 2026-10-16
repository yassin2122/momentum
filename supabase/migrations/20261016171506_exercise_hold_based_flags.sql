-- =====================================================================
-- TRAIN: is_hold_based for the free-exercise-db library
--
-- Decisions from docs/hold_based_candidates.md review:
--   true  : the 12 "likely" holds + every static stretch (stretching, force = static)
--   false : the name-matched non-holds (hang cleans, leverage machines, ...)
--   untouched: the 8 "ambiguous" rows, left for a manual decision
--
-- The workout logger chooses timer vs reps from exercises.tracking_type,
-- not is_hold_based, and derive_exercise_tracking_type() only runs on
-- insert. So rows set to true also get tracking_type = 'duration' here,
-- except exercises that already have logged sets, so existing history is
-- never reinterpreted under a different tracking type.
-- Custom (user-created) exercises are never touched.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Hold-based: true
-- ---------------------------------------------------------------------
with targets as (
  select e.id
  from public.exercises e
  where not e.is_custom
    and e.slug not in (   -- the 8 ambiguous rows: unchanged
      'isometric-wipers', 'prone-manual-hamstring', 'iron-cross', 'cable-iron-cross',
      'iron-crosses-stretch', 'pelvic-tilt-into-bridge', 'push-up-to-side-plank', 'dead-bug'
    )
    and (
      e.slug in (
        'plank', 'side-bridge', 'isometric-chest-squeezes',
        'isometric-neck-exercise-front-and-back', 'isometric-neck-exercise-sides',
        'plate-pinch', 'standing-olympic-plate-hand-squeeze', 'crucifix',
        'downward-facing-balance', 'one-handed-hang', 'superman', 'stomach-vacuum'
      )
      or (e.category = 'stretching' and e.force = 'static')
    )
)
update public.exercises e
set is_hold_based = true,
    tracking_type = case
      when exists (select 1 from public.workout_log_exercises wle where wle.exercise_id = e.id)
        then e.tracking_type
      else 'duration'::public.tracking_type
    end,
    updated_at = now()
from targets t
where e.id = t.id;

-- ---------------------------------------------------------------------
-- 2. Hold-based: false (name matched a hold keyword, but these are reps)
-- ---------------------------------------------------------------------
update public.exercises
set is_hold_based = false, updated_at = now()
where not is_custom
  and is_hold_based
  and slug in (
    'alternating-hang-clean', 'bottoms-up-clean-from-the-hang-position',
    'double-kettlebell-alternating-hang-clean', 'hang-clean', 'hang-clean-below-the-knees',
    'hang-snatch', 'hang-snatch-below-knees', 'kettlebell-hang-clean',
    'smith-machine-hang-power-clean',
    'hanging-bar-good-morning', 'hanging-leg-raise', 'hanging-pike',
    'leverage-chest-press', 'leverage-deadlift', 'leverage-decline-chest-press',
    'leverage-high-row', 'leverage-incline-chest-press', 'leverage-iso-row',
    'leverage-shoulder-press', 'leverage-shrug',
    'barbell-glute-bridge', 'butt-lift-bridge', 'london-bridges',
    'physioball-hip-bridge', 'single-leg-glute-bridge',
    'handstand-push-ups'
  );

commit;
