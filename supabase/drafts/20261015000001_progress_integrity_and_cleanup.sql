-- =====================================================================
-- Progress integrity + cleanup  (DB audit 2026-10-15)
--
--  1. XP never unlocks anything (award_xp / award_stage_xp refuse locked
--     skills/stages and never create rows).
--  2. complete_roadmap_workout and record_roadmap_personal_best validate
--     input server-side instead of trusting the client.
--  3. Skill and stage progress rows reach every user: new users, skills
--     added later, prerequisites added later, stages added later.
--     Availability is prerequisite-based; the entry stage of a planet opens
--     when the planet is unlocked. Later stages stay locked until objective
--     completion logic exists (designed separately — NOT in this migration).
--  4. notification_type enum: social values removed.
--  5. RLS performance: (select auth.uid()), overlapping ALL policies split,
--     missing FK index.
--  6. coaching_permissions.relationship_id is immutable.
--
-- Signatures of every client-facing RPC are unchanged.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 3. Progress rows for every user
-- ---------------------------------------------------------------------

-- Creates missing stage rows for users who have a row for this skill,
-- opens the entry stage (lowest stage_order) when the skill is not locked,
-- and re-locks an untouched entry stage (0 XP) if the skill is locked.
create or replace function public.sync_stage_entry(p_skill_id uuid, p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_first uuid;
begin
  select id into v_first
  from skill_stages
  where skill_id = p_skill_id
  order by stage_order
  limit 1;

  if v_first is null then
    return;
  end if;

  insert into user_skill_stage_progress (user_id, skill_stage_id, status)
  select sp.user_id, st.id, 'locked'
  from skill_progress sp
  join skill_stages st on st.skill_id = sp.skill_id
  where sp.skill_id = p_skill_id
    and (p_user_id is null or sp.user_id = p_user_id)
  on conflict (user_id, skill_stage_id) do nothing;

  update user_skill_stage_progress u
  set status = 'available', unlocked_at = coalesce(u.unlocked_at, now())
  from skill_progress sp
  where u.skill_stage_id = v_first
    and sp.skill_id = p_skill_id
    and sp.user_id = u.user_id
    and (p_user_id is null or u.user_id = p_user_id)
    and u.status = 'locked'
    and sp.status <> 'locked';

  update user_skill_stage_progress u
  set status = 'locked', unlocked_at = null
  from skill_progress sp
  where u.skill_stage_id = v_first
    and sp.skill_id = p_skill_id
    and sp.user_id = u.user_id
    and (p_user_id is null or u.user_id = p_user_id)
    and u.status = 'available'
    and u.current_xp = 0
    and sp.status = 'locked';
end;
$$;

-- Ensures every live user has a skill_progress row for this skill, then sets
-- availability from prerequisites (prerequisite status >= required_status).
-- Only untouched rows ('available', 0 XP) are ever re-locked.
create or replace function public.refresh_skill_availability(p_skill_id uuid, p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from skills where id = p_skill_id and deleted_at is null and is_active) then
    return;
  end if;

  insert into skill_progress (user_id, skill_id, status)
  select p.id, p_skill_id, 'locked'
  from profiles p
  where p.deleted_at is null
    and (p_user_id is null or p.id = p_user_id)
  on conflict (user_id, skill_id) do nothing;

  update skill_progress sp
  set status = 'available', unlocked_at = coalesce(sp.unlocked_at, now())
  where sp.skill_id = p_skill_id
    and (p_user_id is null or sp.user_id = p_user_id)
    and sp.status = 'locked'
    and not exists (
      select 1
      from skill_prerequisites pr
      left join skill_progress psp
        on psp.skill_id = pr.prerequisite_skill_id and psp.user_id = sp.user_id
      where pr.skill_id = p_skill_id
        and (psp.status is null or psp.status < pr.required_status)
    );

  update skill_progress sp
  set status = 'locked', unlocked_at = null
  where sp.skill_id = p_skill_id
    and (p_user_id is null or sp.user_id = p_user_id)
    and sp.status = 'available'
    and sp.current_xp = 0
    and exists (
      select 1
      from skill_prerequisites pr
      left join skill_progress psp
        on psp.skill_id = pr.prerequisite_skill_id and psp.user_id = sp.user_id
      where pr.skill_id = p_skill_id
        and (psp.status is null or psp.status < pr.required_status)
    );

  perform sync_stage_entry(p_skill_id, p_user_id);
end;
$$;

-- New users: one refresh per active skill (replaces the old one-shot insert
-- that ran before any skills existed and never ran again).
create or replace function public.initialize_user_skill_progress(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
begin
  for r in
    select id from skills where deleted_at is null and is_active order by sort_order
  loop
    perform refresh_skill_availability(r.id, p_user_id);
  end loop;
end;
$$;

-- When a user's skill status changes: open/close its entry stage, and
-- re-evaluate every skill that lists it as a prerequisite.
create or replace function public.on_skill_progress_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
begin
  perform sync_stage_entry(new.skill_id, new.user_id);
  for r in
    select distinct skill_id from skill_prerequisites where prerequisite_skill_id = new.skill_id
  loop
    perform refresh_skill_availability(r.skill_id, new.user_id);
  end loop;
  return null;
end;
$$;

drop trigger if exists trg_skill_progress_status_change on public.skill_progress;
create trigger trg_skill_progress_status_change
  after update of status on public.skill_progress
  for each row
  when (old.status is distinct from new.status)
  execute function public.on_skill_progress_status_change();

-- Content changes: new/re-activated skills and prerequisite edits.
create or replace function public.on_skill_content_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'skills' then
    perform refresh_skill_availability(new.id);
  elsif tg_op = 'DELETE' then
    perform refresh_skill_availability(old.skill_id);
  else
    perform refresh_skill_availability(new.skill_id);
    if tg_op = 'UPDATE' and old.skill_id is distinct from new.skill_id then
      perform refresh_skill_availability(old.skill_id);
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_skills_refresh_availability on public.skills;
create trigger trg_skills_refresh_availability
  after insert or update of is_active, deleted_at on public.skills
  for each row
  execute function public.on_skill_content_change();

drop trigger if exists trg_skill_prerequisites_refresh on public.skill_prerequisites;
create trigger trg_skill_prerequisites_refresh
  after insert or update or delete on public.skill_prerequisites
  for each row
  execute function public.on_skill_content_change();

-- Stages: statement-level so a seed that inserts all stages of a planet in
-- one statement opens the true entry stage, regardless of row order.
create or replace function public.on_skill_stages_inserted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
begin
  for r in select distinct skill_id from new_rows loop
    perform sync_stage_entry(r.skill_id);
  end loop;
  return null;
end;
$$;

drop trigger if exists trg_skill_stages_sync on public.skill_stages;
create trigger trg_skill_stages_sync
  after insert on public.skill_stages
  referencing new table as new_rows
  for each statement
  execute function public.on_skill_stages_inserted();


-- ---------------------------------------------------------------------
-- 1. XP never unlocks anything
-- ---------------------------------------------------------------------
create or replace function public.award_xp(
  p_user_id uuid,
  p_skill_id uuid,
  p_amount integer,
  p_source xp_source,
  p_reference_table text default null,
  p_reference_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status skill_status;
begin
  if p_amount <= 0 then
    raise exception 'XP amount must be positive';
  end if;

  select status into v_status
  from skill_progress
  where user_id = p_user_id and skill_id = p_skill_id
  for update;

  if v_status is null or v_status = 'locked' then
    raise exception 'Skill is locked for this user — XP cannot unlock a skill';
  end if;

  insert into xp_transactions (user_id, skill_id, amount, source, reference_table, reference_id)
  values (p_user_id, p_skill_id, p_amount, p_source, p_reference_table, p_reference_id);

  -- 'available' -> 'active' only means "started training an unlocked skill".
  -- XP never moves a skill to completed / master / legendary.
  update skill_progress
  set current_xp = current_xp + p_amount,
      status = case when status = 'available' then 'active'::skill_status else status end
  where user_id = p_user_id and skill_id = p_skill_id;
end;
$$;

create or replace function public.award_stage_xp(
  p_user_id uuid,
  p_skill_stage_id uuid,
  p_amount integer,
  p_source xp_source,
  p_reference_table text default null,
  p_reference_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_skill_id uuid;
  v_status skill_status;
begin
  if p_amount <= 0 then
    raise exception 'XP amount must be positive';
  end if;

  select st.skill_id, u.status into v_skill_id, v_status
  from skill_stages st
  left join user_skill_stage_progress u
    on u.skill_stage_id = st.id and u.user_id = p_user_id
  where st.id = p_skill_stage_id;

  if v_skill_id is null then
    raise exception 'Unknown skill_stage_id';
  end if;
  if v_status is null or v_status = 'locked' then
    raise exception 'Stage is locked for this user — XP cannot unlock a stage';
  end if;

  update user_skill_stage_progress
  set current_xp = current_xp + p_amount,
      status = case when status = 'available' then 'active'::skill_status else status end
  where user_id = p_user_id and skill_stage_id = p_skill_stage_id;

  perform award_xp(p_user_id, v_skill_id, p_amount, p_source, p_reference_table, p_reference_id);
end;
$$;


-- ---------------------------------------------------------------------
-- 2. Server-side validation of roadmap results
-- ---------------------------------------------------------------------
-- p_exercise_results: [{exercise_id, achieved_sets?, achieved_reps?,
--   achieved_hold_seconds?, order_index?}]. order_index is only required
--   when the same exercise appears twice in one roadmap workout.
create or replace function public.complete_roadmap_workout(
  p_roadmap_workout_id uuid,
  p_exercise_results jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_skill_id uuid;
  v_stage_id uuid;
  v_xp_reward int;
  v_snapshot jsonb;
  v_skill_status skill_status;
  v_stage_status skill_status;
  v_log_id uuid;
  v_all_met boolean;
  v_results jsonb := '{}'::jsonb;
  v_seen uuid[] := '{}';
  v_match uuid[];
  r jsonb;
  v_ex uuid;
  v_oi int;
  v_sets int;
  v_reps int;
  v_hold int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select skill_id, skill_stage_id, xp_reward
    into v_skill_id, v_stage_id, v_xp_reward
  from roadmap_workouts
  where id = p_roadmap_workout_id and deleted_at is null;

  if v_skill_id is null then
    raise exception 'Roadmap workout not found';
  end if;

  select status into v_skill_status
  from skill_progress where user_id = v_uid and skill_id = v_skill_id;
  if v_skill_status is null or v_skill_status = 'locked' then
    raise exception 'This skill is locked';
  end if;

  if v_stage_id is not null then
    select status into v_stage_status
    from user_skill_stage_progress where user_id = v_uid and skill_stage_id = v_stage_id;
    if v_stage_status is null or v_stage_status = 'locked' then
      raise exception 'This stage is locked';
    end if;
  end if;

  if p_exercise_results is null or jsonb_typeof(p_exercise_results) <> 'array' then
    raise exception 'p_exercise_results must be a JSON array';
  end if;
  if jsonb_array_length(p_exercise_results) > 100 then
    raise exception 'Too many exercise results';
  end if;

  for r in select value from jsonb_array_elements(p_exercise_results) loop
    v_ex   := (r->>'exercise_id')::uuid;
    v_oi   := (r->>'order_index')::int;
    v_sets := (r->>'achieved_sets')::int;
    v_reps := (r->>'achieved_reps')::int;
    v_hold := (r->>'achieved_hold_seconds')::int;

    if v_ex is null then
      raise exception 'Every result needs an exercise_id';
    end if;
    if (v_sets is not null and (v_sets < 0 or v_sets > 100))
       or (v_reps is not null and (v_reps < 0 or v_reps > 1000))
       or (v_hold is not null and (v_hold < 0 or v_hold > 3600)) then
      raise exception 'Result values out of range for exercise %', v_ex;
    end if;

    select array_agg(id) into v_match
    from roadmap_workout_exercises
    where roadmap_workout_id = p_roadmap_workout_id
      and exercise_id = v_ex
      and (v_oi is null or order_index = v_oi);

    if v_match is null then
      raise exception 'Exercise % is not part of this roadmap workout', v_ex;
    elsif array_length(v_match, 1) > 1 then
      raise exception 'Exercise % appears more than once in this workout — send order_index', v_ex;
    elsif v_match[1] = any(v_seen) then
      raise exception 'Duplicate result for exercise %', v_ex;
    end if;

    v_seen := v_seen || v_match[1];
    v_results := v_results || jsonb_build_object(
      v_match[1]::text,
      jsonb_build_object('s', v_sets, 'r', v_reps, 'h', v_hold)
    );
  end loop;

  select jsonb_agg(to_jsonb(rwe) order by rwe.order_index) into v_snapshot
  from roadmap_workout_exercises rwe
  where rwe.roadmap_workout_id = p_roadmap_workout_id;

  insert into roadmap_workout_logs
    (user_id, roadmap_workout_id, skill_id, workout_snapshot, completed, xp_awarded, completed_at)
  values
    (v_uid, p_roadmap_workout_id, v_skill_id, coalesce(v_snapshot, '[]'::jsonb), false, 0, null)
  returning id into v_log_id;

  -- One log row per prescribed exercise; requirement checked against the
  -- workout's targets, never taken from the client.
  insert into roadmap_workout_log_exercises
    (roadmap_workout_log_id, exercise_id, order_index,
     achieved_sets, achieved_reps, achieved_hold_seconds, met_requirement)
  select
    v_log_id, rwe.exercise_id, rwe.order_index,
    (v_results -> rwe.id::text ->> 's')::smallint,
    (v_results -> rwe.id::text ->> 'r')::smallint,
    (v_results -> rwe.id::text ->> 'h')::smallint,
    (v_results ? rwe.id::text)
      and (rwe.required_sets is null
           or coalesce((v_results -> rwe.id::text ->> 's')::int, 0) >= rwe.required_sets)
      and (rwe.required_reps is null
           or coalesce((v_results -> rwe.id::text ->> 'r')::int, 0) >= rwe.required_reps)
      and (rwe.required_hold_seconds is null
           or coalesce((v_results -> rwe.id::text ->> 'h')::int, 0) >= rwe.required_hold_seconds)
  from roadmap_workout_exercises rwe
  where rwe.roadmap_workout_id = p_roadmap_workout_id;

  select coalesce(bool_and(met_requirement), false) into v_all_met
  from roadmap_workout_log_exercises
  where roadmap_workout_log_id = v_log_id;

  if v_all_met then
    update roadmap_workout_logs
    set completed = true,
        completed_at = now(),
        xp_awarded = greatest(coalesce(v_xp_reward, 0), 0)
    where id = v_log_id;

    if coalesce(v_xp_reward, 0) > 0 then
      if v_stage_id is not null then
        perform award_stage_xp(v_uid, v_stage_id, v_xp_reward, 'roadmap_workout', 'roadmap_workout_logs', v_log_id);
      else
        perform award_xp(v_uid, v_skill_id, v_xp_reward, 'roadmap_workout', 'roadmap_workout_logs', v_log_id);
      end if;
    end if;
  end if;

  return v_log_id;
end;
$$;

create or replace function public.record_roadmap_personal_best(
  p_skill_id uuid,
  p_exercise_id uuid,
  p_metric_type pr_metric_type,
  p_value numeric,
  p_log_exercise_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_status skill_status;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_value is null or p_value <= 0 then
    raise exception 'Value must be positive';
  end if;
  if p_value > case p_metric_type
                 when 'max_hold_seconds' then 3600
                 when 'max_reps' then 1000
                 else 1000
               end then
    raise exception 'Value out of range';
  end if;

  select status into v_status
  from skill_progress where user_id = v_uid and skill_id = p_skill_id;
  if v_status is null or v_status = 'locked' then
    raise exception 'This skill is locked';
  end if;

  if not exists (
       select 1
       from roadmap_workout_exercises rwe
       join roadmap_workouts rw on rw.id = rwe.roadmap_workout_id
       where rw.skill_id = p_skill_id and rw.deleted_at is null and rwe.exercise_id = p_exercise_id)
     and not exists (
       select 1 from objectives o
       where o.skill_id = p_skill_id and o.deleted_at is null and o.exercise_id = p_exercise_id) then
    raise exception 'Exercise is not part of this skill';
  end if;

  if p_log_exercise_id is not null and not exists (
       select 1
       from roadmap_workout_log_exercises le
       join roadmap_workout_logs l on l.id = le.roadmap_workout_log_id
       where le.id = p_log_exercise_id
         and l.user_id = v_uid
         and l.skill_id = p_skill_id
         and le.exercise_id = p_exercise_id) then
    raise exception 'Log entry not found';
  end if;

  insert into roadmap_personal_bests
    (user_id, skill_id, exercise_id, metric_type, value, achieved_at, log_exercise_id)
  values
    (v_uid, p_skill_id, p_exercise_id, p_metric_type, p_value, now(), p_log_exercise_id)
  on conflict (user_id, skill_id, exercise_id, metric_type)
  do update set value = excluded.value,
                achieved_at = excluded.achieved_at,
                log_exercise_id = excluded.log_exercise_id
  where excluded.value > roadmap_personal_bests.value;
end;
$$;


-- ---------------------------------------------------------------------
-- 4. notification_type: drop social values
-- ---------------------------------------------------------------------
delete from public.notifications
where type::text in ('friend_request', 'friend_accepted', 'activity_comment',
                     'post_like', 'post_comment', 'nudge', 'friend_challenge');

alter type public.notification_type rename to notification_type_old;

create type public.notification_type as enum (
  'achievement_unlocked',
  'coach_request',
  'coach_accepted',
  'coach_declined',
  'coach_feedback',
  'program_assigned'
);

alter table public.notifications
  alter column type type public.notification_type
  using type::text::public.notification_type;

drop type public.notification_type_old;


-- ---------------------------------------------------------------------
-- 6. coaching_permissions.relationship_id is immutable
-- ---------------------------------------------------------------------
create or replace function public.guard_coaching_permissions_relationship()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.relationship_id is distinct from old.relationship_id then
    raise exception 'relationship_id cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_coaching_permissions_guard on public.coaching_permissions;
create trigger trg_coaching_permissions_guard
  before update on public.coaching_permissions
  for each row
  execute function public.guard_coaching_permissions_relationship();


-- ---------------------------------------------------------------------
-- 5. RLS performance
-- ---------------------------------------------------------------------

-- 5a. Admin FOR ALL policies overlapped every public SELECT policy.
--     Split into insert/update/delete; reads stay with the select policies.
--     (Admins working in the Supabase dashboard bypass RLS and are unaffected.)
do $$
declare
  t text;
begin
  foreach t in array array[
    'exercises', 'muscle_groups', 'exercise_muscle_groups', 'roadmap_categories',
    'skills', 'skill_prerequisites', 'skill_stages', 'objectives',
    'roadmap_workouts', 'roadmap_workout_exercises', 'achievements', 'weekly_challenges'
  ] loop
    execute format('drop policy if exists %I on public.%I', t || '_admin_write', t);
    execute format('create policy %I on public.%I for insert with check ((select public.is_admin()))',
                   t || '_admin_insert', t);
    execute format('create policy %I on public.%I for update using ((select public.is_admin())) with check ((select public.is_admin()))',
                   t || '_admin_update', t);
    execute format('create policy %I on public.%I for delete using ((select public.is_admin()))',
                   t || '_admin_delete', t);
  end loop;
end $$;

-- 5b. Programs: admin + coach FOR ALL policies merged into one policy per
--     write command. Reads stay with *_select_visible (can_view_program
--     already covers the creator).
drop policy if exists programs_admin_write on public.programs;
drop policy if exists programs_coach_write on public.programs;

create policy programs_insert on public.programs for insert
  with check ((select public.is_admin())
              or (created_by = (select auth.uid()) and not is_official and (select public.is_coach())));
create policy programs_update on public.programs for update
  using ((select public.is_admin())
         or (created_by = (select auth.uid()) and not is_official and (select public.is_coach())))
  with check ((select public.is_admin())
              or (created_by = (select auth.uid()) and not is_official and (select public.is_coach())));
create policy programs_delete on public.programs for delete
  using ((select public.is_admin())
         or (created_by = (select auth.uid()) and not is_official and (select public.is_coach())));

drop policy if exists program_days_admin_write on public.program_days;
drop policy if exists program_days_coach_write on public.program_days;

create policy program_days_insert on public.program_days for insert
  with check ((select public.is_admin()) or exists (
    select 1 from public.programs p
    where p.id = program_days.program_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));
create policy program_days_update on public.program_days for update
  using ((select public.is_admin()) or exists (
    select 1 from public.programs p
    where p.id = program_days.program_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())))
  with check ((select public.is_admin()) or exists (
    select 1 from public.programs p
    where p.id = program_days.program_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));
create policy program_days_delete on public.program_days for delete
  using ((select public.is_admin()) or exists (
    select 1 from public.programs p
    where p.id = program_days.program_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));

drop policy if exists program_day_exercises_admin_write on public.program_day_exercises;
drop policy if exists program_day_exercises_coach_write on public.program_day_exercises;

create policy program_day_exercises_insert on public.program_day_exercises for insert
  with check ((select public.is_admin()) or exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_exercises.program_day_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));
create policy program_day_exercises_update on public.program_day_exercises for update
  using ((select public.is_admin()) or exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_exercises.program_day_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())))
  with check ((select public.is_admin()) or exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_exercises.program_day_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));
create policy program_day_exercises_delete on public.program_day_exercises for delete
  using ((select public.is_admin()) or exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_exercises.program_day_id
      and p.created_by = (select auth.uid()) and not p.is_official and (select public.is_coach())));

-- 5c. coaching_plans: the coach FOR ALL policy overlapped coaching_plans_select
--     (which already lets a coach read their own non-deleted plans).
drop policy if exists coaching_plans_coach_write on public.coaching_plans;

create policy coaching_plans_coach_insert on public.coaching_plans for insert
  with check (coach_id = (select auth.uid()) and (select public.is_coach()));
create policy coaching_plans_coach_update on public.coaching_plans for update
  using (coach_id = (select auth.uid()))
  with check (coach_id = (select auth.uid()) and (select public.is_coach()));
create policy coaching_plans_coach_delete on public.coaching_plans for delete
  using (coach_id = (select auth.uid()));

-- 5d. Every remaining policy: evaluate auth.uid() once per query, not per row.
do $$
declare
  p record;
  v_sql text;
begin
  for p in
    select tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') like '%auth.uid()%' or coalesce(with_check, '') like '%auth.uid()%')
      and coalesce(qual, '') not like '%SELECT auth.uid()%'
      and coalesce(with_check, '') not like '%SELECT auth.uid()%'
  loop
    v_sql := format('alter policy %I on public.%I', p.policyname, p.tablename);
    if p.qual is not null then
      v_sql := v_sql || ' using (' || replace(p.qual, 'auth.uid()', '(select auth.uid())') || ')';
    end if;
    if p.with_check is not null then
      v_sql := v_sql || ' with check (' || replace(p.with_check, 'auth.uid()', '(select auth.uid())') || ')';
    end if;
    execute v_sql;
  end loop;
end $$;

-- 5e. Missing FK index
create index if not exists idx_coaching_relationships_ended_by
  on public.coaching_relationships (ended_by);


-- ---------------------------------------------------------------------
-- Grants: every new function here is internal (trigger / called by other
-- SECURITY DEFINER functions). Nobody calls them through the API.
-- ---------------------------------------------------------------------
revoke execute on function public.sync_stage_entry(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.refresh_skill_availability(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.on_skill_progress_status_change() from public, anon, authenticated;
revoke execute on function public.on_skill_content_change() from public, anon, authenticated;
revoke execute on function public.on_skill_stages_inserted() from public, anon, authenticated;
revoke execute on function public.guard_coaching_permissions_relationship() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3b. One-time backfill for existing users and skills
-- ---------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in select id from public.skills where deleted_at is null and is_active order by sort_order loop
    perform public.refresh_skill_availability(r.id);
  end loop;
end $$;
