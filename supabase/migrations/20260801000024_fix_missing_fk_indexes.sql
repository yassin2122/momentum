-- Fix: 21 foreign key columns had no backing index. Postgres auto-indexes
-- the PRIMARY KEY side of a foreign key relationship, but never the
-- referencing column itself -- that's the schema author's job, and it was
-- missed across the original migrations. Every join through these columns
-- (fetching a workout's logged sets, a user's unlocked achievements, an
-- objective's progress, etc.) was doing a sequential scan instead of an
-- index lookup. Verified against a live query on the actual deployed
-- schema, not guessed.

create index if not exists idx_blocks_blocked_id on public.blocks (blocked_id);
create index if not exists idx_content_audit_log_admin_id on public.content_audit_log (admin_id);
create index if not exists idx_exercise_muscle_groups_muscle_group_id on public.exercise_muscle_groups (muscle_group_id);
create index if not exists idx_exercises_created_by on public.exercises (created_by);
create index if not exists idx_objectives_skill_stage_id on public.objectives (skill_stage_id);
create index if not exists idx_personal_records_set_id on public.personal_records (set_id);
create index if not exists idx_program_day_exercises_program_day_id on public.program_day_exercises (program_day_id);
create index if not exists idx_programs_created_by on public.programs (created_by);
create index if not exists idx_roadmap_personal_bests_log_exercise_id on public.roadmap_personal_bests (log_exercise_id);
create index if not exists idx_roadmap_workout_log_exercises_log_id on public.roadmap_workout_log_exercises (roadmap_workout_log_id);
create index if not exists idx_roadmap_workouts_skill_stage_id on public.roadmap_workouts (skill_stage_id);
create index if not exists idx_skill_prerequisites_prerequisite_skill_id on public.skill_prerequisites (prerequisite_skill_id);
create index if not exists idx_skill_progress_current_skill_stage_id on public.skill_progress (current_skill_stage_id);
create index if not exists idx_user_achievements_achievement_id on public.user_achievements (achievement_id);
create index if not exists idx_user_challenges_creator_id on public.user_challenges (creator_id);
create index if not exists idx_user_challenges_target_exercise_id on public.user_challenges (target_exercise_id);
create index if not exists idx_user_objective_progress_objective_id on public.user_objective_progress (objective_id);
create index if not exists idx_user_program_enrollment_current_day_id on public.user_program_enrollment (current_day_id);
create index if not exists idx_user_skill_stage_progress_skill_stage_id on public.user_skill_stage_progress (skill_stage_id);
create index if not exists idx_user_weekly_challenge_progress_challenge_id on public.user_weekly_challenge_progress (weekly_challenge_id);
create index if not exists idx_workout_log_exercises_workout_log_id on public.workout_log_exercises (workout_log_id);
create index if not exists idx_workout_log_sets_workout_log_exercise_id on public.workout_log_sets (workout_log_exercise_id);
