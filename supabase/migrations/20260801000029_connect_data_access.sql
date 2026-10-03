-- Connect — Captain READ-ONLY access to athlete data (permission-gated),
-- and coach-authored programs. Coaches get NO write policy on any athlete log,
-- so historical records stay trustworthy.
begin;

-- ---------------- workouts scope
create policy "coach_read_workout_logs" on public.workout_logs for select
  using (public.coach_can_view(user_id, 'workouts'));
create policy "coach_read_workout_log_exercises" on public.workout_log_exercises for select
  using (exists (select 1 from public.workout_logs w
                 where w.id = workout_log_id and public.coach_can_view(w.user_id, 'workouts')));
create policy "coach_read_workout_log_sets" on public.workout_log_sets for select
  using (exists (select 1 from public.workout_log_exercises e
                 join public.workout_logs w on w.id = e.workout_log_id
                 where e.id = workout_log_exercise_id and public.coach_can_view(w.user_id, 'workouts')));
create policy "coach_read_streaks" on public.user_streaks for select
  using (public.coach_can_view(user_id, 'workouts'));

-- ---------------- prs scope
create policy "coach_read_prs" on public.personal_records for select
  using (public.coach_can_view(user_id, 'prs'));
create policy "coach_read_pr_history" on public.personal_record_history for select
  using (public.coach_can_view(user_id, 'prs'));
create policy "coach_read_roadmap_pbs" on public.roadmap_personal_bests for select
  using (public.coach_can_view(user_id, 'prs'));

-- ---------------- progress scope
create policy "coach_read_skill_progress" on public.skill_progress for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_stage_progress" on public.user_skill_stage_progress for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_objective_progress" on public.user_objective_progress for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_xp" on public.xp_transactions for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_achievements" on public.user_achievements for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_roadmap_logs" on public.roadmap_workout_logs for select
  using (public.coach_can_view(user_id, 'progress'));
create policy "coach_read_roadmap_log_exercises" on public.roadmap_workout_log_exercises for select
  using (exists (select 1 from public.roadmap_workout_logs l
                 where l.id = roadmap_workout_log_id and public.coach_can_view(l.user_id, 'progress')));

-- ---------------- body scope
create policy "coach_read_body_metrics" on public.body_metrics_log for select
  using (public.coach_can_view(user_id, 'body'));

-- ---------------- coach-authored programs
-- Existing select policies were "everyone sees everything"; coach programs
-- must be private to the coach and their assigned athletes.
create or replace function public.can_view_program(p_program uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.programs p
    where p.id = p_program and p.deleted_at is null
      and (p.is_official
           or p.created_by = auth.uid()
           or exists (select 1 from public.program_assignments a
                      join public.coaching_relationships r on r.id = a.relationship_id
                      where a.program_id = p.id and r.athlete_id = auth.uid()
                        and a.status <> 'cancelled'))
  );
$$;

drop policy if exists "programs_select_all" on public.programs;
drop policy if exists "program_days_select_all" on public.program_days;
drop policy if exists "program_day_exercises_select_all" on public.program_day_exercises;

create policy "programs_select_visible" on public.programs for select
  using (public.can_view_program(id));
create policy "program_days_select_visible" on public.program_days for select
  using (public.can_view_program(program_id));
create policy "program_day_exercises_select_visible" on public.program_day_exercises for select
  using (exists (select 1 from public.program_days d
                 where d.id = program_day_id and public.can_view_program(d.program_id)));

create policy "programs_coach_write" on public.programs for all
  using (created_by = auth.uid() and not is_official and public.is_coach())
  with check (created_by = auth.uid() and not is_official and public.is_coach());
create policy "program_days_coach_write" on public.program_days for all
  using (exists (select 1 from public.programs p where p.id = program_id
                 and p.created_by = auth.uid() and not p.is_official and public.is_coach()))
  with check (exists (select 1 from public.programs p where p.id = program_id
                 and p.created_by = auth.uid() and not p.is_official and public.is_coach()));
create policy "program_day_exercises_coach_write" on public.program_day_exercises for all
  using (exists (select 1 from public.program_days d join public.programs p on p.id = d.program_id
                 where d.id = program_day_id and p.created_by = auth.uid()
                   and not p.is_official and public.is_coach()))
  with check (exists (select 1 from public.program_days d join public.programs p on p.id = d.program_id
                 where d.id = program_day_id and p.created_by = auth.uid()
                   and not p.is_official and public.is_coach()));

commit;
