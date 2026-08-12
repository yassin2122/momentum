-- Fix: 20 additional missing FK indexes, found after correcting a query bug
-- in migration 0024's verification step (unparenthesized OR let cross-table
-- column-name matches produce false "index already exists" results).
-- Re-verified against the live schema with the corrected query -- this list
-- is now confirmed accurate, not estimated.

create index if not exists idx_activity_comments_user_id on public.activity_comments (user_id);
create index if not exists idx_objectives_exercise_id on public.objectives (exercise_id);
create index if not exists idx_personal_record_history_exercise_id on public.personal_record_history (exercise_id);
create index if not exists idx_personal_records_exercise_id on public.personal_records (exercise_id);
create index if not exists idx_post_comments_user_id on public.post_comments (user_id);
create index if not exists idx_post_likes_user_id on public.post_likes (user_id);
create index if not exists idx_program_day_exercises_exercise_id on public.program_day_exercises (exercise_id);
create index if not exists idx_roadmap_personal_bests_exercise_id on public.roadmap_personal_bests (exercise_id);
create index if not exists idx_roadmap_personal_bests_skill_id on public.roadmap_personal_bests (skill_id);
create index if not exists idx_roadmap_workout_exercises_exercise_id on public.roadmap_workout_exercises (exercise_id);
create index if not exists idx_roadmap_workout_log_exercises_exercise_id on public.roadmap_workout_log_exercises (exercise_id);
create index if not exists idx_roadmap_workout_logs_roadmap_workout_id on public.roadmap_workout_logs (roadmap_workout_id);
create index if not exists idx_roadmap_workout_logs_skill_id on public.roadmap_workout_logs (skill_id);
create index if not exists idx_skill_progress_skill_id on public.skill_progress (skill_id);
create index if not exists idx_user_challenge_participants_user_id on public.user_challenge_participants (user_id);
create index if not exists idx_user_program_enrollment_program_id on public.user_program_enrollment (program_id);
create index if not exists idx_weekly_challenges_skill_id on public.weekly_challenges (skill_id);
create index if not exists idx_workout_log_exercises_exercise_id on public.workout_log_exercises (exercise_id);
create index if not exists idx_workout_logs_template_id on public.workout_logs (template_id);
create index if not exists idx_workout_template_exercises_exercise_id on public.workout_template_exercises (exercise_id);
create index if not exists idx_xp_transactions_skill_id on public.xp_transactions (skill_id);
