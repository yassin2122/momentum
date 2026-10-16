-- =====================================================================
-- TRAIN: workout logging
--
-- Adapts the existing tracker tables instead of adding parallel ones:
--   workout_sessions   -> workout_logs            (+ status, edited_at, bodyweight_snapshot_kg;
--                                                   completed_at is "ended_at")
--   session_exercises  -> workout_log_exercises   (+ replaced_from_exercise_id; order_index = position, 0-based)
--   sets               -> workout_log_sets        (+ set_type, entered_weight/unit, added_kg, assist_kg, rpe;
--                                                   set_number = position + 1, hold_seconds = duration_s)
--   template_exercises -> workout_template_exercises (target_sets = default_sets)
--   user_settings      -> new table (preferred_unit)
--
-- Writes:
--   * finish_workout(jsonb)             one transaction: log + exercises + completed sets,
--                                       bodyweight snapshot, template additions, completion.
--   * create_custom_exercise(...)       custom exercises (is_custom, owner-only visibility).
--   * create_template_from_workout(...) "Save as template" from a finished workout.
--   * personal_records stay client-read-only: the PR trigger is rewritten so only
--     completed WORKING sets count, with Epley e1RM for sets of <= 10 reps.
--
-- TRAIN stays decoupled from PROGRESS: nothing here references a roadmap table.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Enums
-- ---------------------------------------------------------------------
create type public.tracking_type as enum (
  'weight_reps', 'bodyweight_reps', 'weighted_bodyweight', 'assisted_bodyweight', 'duration'
);
create type public.set_type as enum ('warmup', 'working', 'drop');
create type public.workout_status as enum ('in_progress', 'completed', 'discarded');
create type public.weight_unit as enum ('kg', 'lb');

-- ---------------------------------------------------------------------
-- 2. Exercises: tracking type, bodyweight factor, custom exercises
-- ---------------------------------------------------------------------
alter table public.exercises
  add column tracking_type public.tracking_type,
  add column bw_factor numeric(4,2) not null default 0 check (bw_factor between 0 and 2),
  add column is_custom boolean not null default false,
  add constraint exercises_custom_has_owner check (not is_custom or created_by is not null);

-- Library rows arrive from the free-exercise-db sync script, which doesn't
-- know about tracking_type. Derive it when it isn't supplied; an admin can
-- correct individual exercises afterwards. (The sync script stores
-- "body only" equipment as null.)
create or replace function public.derive_exercise_tracking_type()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.tracking_type is null then
    new.tracking_type := case
      when new.is_hold_based or new.category = 'stretching' then 'duration'
      when new.equipment is null or lower(new.equipment) in ('body only', 'bodyweight') then 'bodyweight_reps'
      else 'weight_reps'
    end::public.tracking_type;
    if new.tracking_type in ('bodyweight_reps', 'weighted_bodyweight', 'assisted_bodyweight')
       and new.bw_factor = 0 then
      new.bw_factor := 1.0;   -- full bodyweight counts toward volume
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.derive_exercise_tracking_type() from public, anon, authenticated;

create trigger trg_derive_exercise_tracking_type
  before insert on public.exercises
  for each row execute function public.derive_exercise_tracking_type();

update public.exercises set
  tracking_type = case
    when is_hold_based or category = 'stretching' then 'duration'
    when equipment is null or lower(equipment) in ('body only', 'bodyweight') then 'bodyweight_reps'
    else 'weight_reps'
  end::public.tracking_type
where tracking_type is null;
update public.exercises set bw_factor = 1.0
where tracking_type = 'bodyweight_reps' and bw_factor = 0;

alter table public.exercises alter column tracking_type set not null;

create unique index uq_exercises_custom_name_per_user
  on public.exercises (created_by, lower(name))
  where is_custom and deleted_at is null;

-- Global library: readable by everyone. Custom exercises: creator only.
drop policy if exists "exercises_select_all" on public.exercises;
create policy "exercises_select_visible" on public.exercises for select
  using (deleted_at is null and (not is_custom or created_by = (select auth.uid())));
-- "exercises_admin_write" is unchanged; users create custom exercises only
-- through create_custom_exercise() below.

create or replace function public.create_custom_exercise(
  p_name text,
  p_tracking_type public.tracking_type,
  p_equipment text default null,
  p_bw_factor numeric default null
) returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_bw numeric;
  v_row public.exercises%rowtype;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if length(v_name) = 0 or length(v_name) > 80 then
    raise exception 'Exercise name must be 1-80 characters' using errcode = '22023';
  end if;
  if exists (select 1 from exercises
             where is_custom and created_by = v_user and deleted_at is null
               and lower(name) = lower(v_name)) then
    raise exception 'You already have an exercise named "%"', v_name using errcode = '23505';
  end if;

  if p_tracking_type in ('bodyweight_reps', 'weighted_bodyweight', 'assisted_bodyweight') then
    v_bw := coalesce(p_bw_factor, 1.0);
    if v_bw < 0 or v_bw > 2 then
      raise exception 'Bodyweight factor must be between 0 and 2' using errcode = '22023';
    end if;
  else
    v_bw := 0;
  end if;

  insert into exercises (name, slug, equipment, tracking_type, bw_factor, is_custom, created_by,
                         is_hold_based)
  values (v_name, 'custom-' || replace(gen_random_uuid()::text, '-', ''),
          nullif(btrim(coalesce(p_equipment, '')), ''), p_tracking_type, v_bw, true, v_user,
          p_tracking_type = 'duration')
  returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id, 'name', v_row.name, 'tracking_type', v_row.tracking_type,
    'bw_factor', v_row.bw_factor, 'equipment', v_row.equipment, 'is_custom', v_row.is_custom
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Workout tables
-- ---------------------------------------------------------------------
alter table public.workout_logs
  add column status public.workout_status not null default 'in_progress',
  add column edited_at timestamptz,
  add column bodyweight_snapshot_kg numeric(5,2);
update public.workout_logs set status = 'completed' where completed_at is not null;

alter table public.workout_log_exercises
  add column replaced_from_exercise_id uuid references public.exercises(id);
create index idx_workout_log_exercises_replaced_from
  on public.workout_log_exercises (replaced_from_exercise_id);

alter table public.workout_log_sets
  add column set_type public.set_type not null default 'working',
  add column entered_weight numeric(7,2),
  add column entered_unit public.weight_unit,
  add column added_kg numeric(6,2),
  add column assist_kg numeric(6,2),
  add column rpe numeric(3,1) check (rpe between 1 and 10),
  add constraint workout_log_sets_entered_pair
    check ((entered_weight is null) = (entered_unit is null));

-- ---------------------------------------------------------------------
-- 4. User settings
-- ---------------------------------------------------------------------
create table public.user_settings (
  user_id         uuid primary key references public.profiles(id) on delete cascade,
  preferred_unit  public.weight_unit not null default 'kg',
  updated_at      timestamptz not null default now()
);
alter table public.user_settings enable row level security;
create policy "user_settings_owner_all" on public.user_settings for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 5. Personal records: completed working sets only
-- ---------------------------------------------------------------------
create or replace function public.upsert_personal_record(
  p_user uuid, p_exercise uuid, p_metric public.pr_metric_type,
  p_value numeric, p_set uuid, p_at timestamptz
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if p_value is null or p_value <= 0 then
    return;
  end if;

  insert into personal_records (user_id, exercise_id, metric_type, value, achieved_at, set_id)
  values (p_user, p_exercise, p_metric, p_value, p_at, p_set)
  on conflict (user_id, exercise_id, metric_type)
  do update set value = excluded.value, achieved_at = excluded.achieved_at, set_id = excluded.set_id
  where excluded.value > personal_records.value;

  if found then
    insert into personal_record_history (user_id, exercise_id, metric_type, value, achieved_at)
    values (p_user, p_exercise, p_metric, p_value, p_at);
  end if;
end;
$$;
revoke execute on function public.upsert_personal_record(uuid, uuid, public.pr_metric_type, numeric, uuid, timestamptz)
  from public, anon, authenticated;

-- Same rules as PrDetector in mobile/lib/features/workouts/domain/services.
create or replace function public.check_and_update_personal_record()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid;
  v_exercise uuid;
  v_tracking public.tracking_type;
  v_at timestamptz;
begin
  -- Warm-up and drop sets never count; neither do uncompleted sets.
  if not new.completed or new.set_type <> 'working' then
    return new;
  end if;

  select w.user_id, wle.exercise_id, e.tracking_type, coalesce(w.completed_at, now())
    into v_user, v_exercise, v_tracking, v_at
  from workout_log_exercises wle
  join workout_logs w on w.id = wle.workout_log_id
  join exercises e on e.id = wle.exercise_id
  where wle.id = new.workout_log_exercise_id;

  if v_tracking = 'weight_reps' then
    perform upsert_personal_record(v_user, v_exercise, 'max_weight', new.weight_kg, new.id, v_at);
    if new.weight_kg is not null and new.reps between 1 and 10 then
      perform upsert_personal_record(v_user, v_exercise, 'estimated_1rm',
        round(new.weight_kg * (1 + new.reps / 30.0), 2), new.id, v_at);
    end if;
  elsif v_tracking = 'weighted_bodyweight' then
    perform upsert_personal_record(v_user, v_exercise, 'max_weight', new.added_kg, new.id, v_at);
  elsif v_tracking in ('bodyweight_reps', 'assisted_bodyweight') then
    perform upsert_personal_record(v_user, v_exercise, 'max_reps', new.reps, new.id, v_at);
  elsif v_tracking = 'duration' then
    perform upsert_personal_record(v_user, v_exercise, 'max_hold_seconds', new.hold_seconds, new.id, v_at);
  end if;

  return new;
end;
$$;
-- trg_check_pr (after insert on workout_log_sets) already points at this name.
revoke execute on function public.check_and_update_personal_record() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. edited_at on completed workouts
-- ---------------------------------------------------------------------
create or replace function public.touch_workout_log_edited()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.status = 'completed' then
    new.edited_at := now();
  end if;
  return new;
end;
$$;
revoke execute on function public.touch_workout_log_edited() from public, anon, authenticated;
create trigger trg_workout_log_edited
  before update on public.workout_logs
  for each row execute function public.touch_workout_log_edited();

create or replace function public.touch_parent_workout_log()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_log uuid;
  v_wle uuid;
begin
  if tg_table_name = 'workout_log_sets' then
    if tg_op = 'DELETE' then v_wle := old.workout_log_exercise_id; else v_wle := new.workout_log_exercise_id; end if;
    select workout_log_id into v_log from workout_log_exercises where id = v_wle;
  else
    if tg_op = 'DELETE' then v_log := old.workout_log_id; else v_log := new.workout_log_id; end if;
  end if;

  -- In-progress logs (i.e. inside finish_workout) are left alone.
  update workout_logs set edited_at = now() where id = v_log and status = 'completed';
  return null;
end;
$$;
revoke execute on function public.touch_parent_workout_log() from public, anon, authenticated;
create trigger trg_workout_log_exercises_edited
  after insert or update or delete on public.workout_log_exercises
  for each row execute function public.touch_parent_workout_log();
create trigger trg_workout_log_sets_edited
  after insert or update or delete on public.workout_log_sets
  for each row execute function public.touch_parent_workout_log();

-- ---------------------------------------------------------------------
-- 7. finish_workout: the one write path for a finished session
-- ---------------------------------------------------------------------
-- Security invoker: every insert goes through the owner RLS policies above.
-- Idempotent on the client-generated workout id, so the offline retry
-- queue can resend safely.
create or replace function public.finish_workout(p_workout jsonb)
returns jsonb
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_log_id uuid := (p_workout ->> 'id')::uuid;
  v_template uuid := nullif(p_workout ->> 'template_id', '')::uuid;
  v_started timestamptz := coalesce((p_workout ->> 'started_at')::timestamptz, now());
  v_completed timestamptz := coalesce((p_workout ->> 'completed_at')::timestamptz, now());
  v_existing public.workout_logs%rowtype;
  v_bw numeric;
  v_ex jsonb;
  v_set jsonb;
  v_add jsonb;
  v_exercise uuid;
  v_wle uuid;
  v_next int;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if v_log_id is null then
    raise exception 'Workout id is required' using errcode = '22023';
  end if;

  select * into v_existing from workout_logs where id = v_log_id;
  if found then
    return jsonb_build_object('workout_log_id', v_log_id,
                              'bodyweight_snapshot_kg', v_existing.bodyweight_snapshot_kg,
                              'already_saved', true);
  end if;

  -- Template deleted while training: keep the workout, skip template sync.
  if v_template is not null and not exists (
       select 1 from workout_templates
       where id = v_template and user_id = v_user and deleted_at is null) then
    v_template := null;
  end if;

  select weight_kg into v_bw
  from body_metrics_log
  where user_id = v_user and weight_kg is not null
  order by logged_at desc, created_at desc
  limit 1;

  insert into workout_logs (id, user_id, template_id, started_at, status, bodyweight_snapshot_kg, notes)
  values (v_log_id, v_user, v_template, v_started, 'in_progress', v_bw, p_workout ->> 'notes');

  for v_ex in select value from jsonb_array_elements(coalesce(p_workout -> 'exercises', '[]'::jsonb)) loop
    v_exercise := (v_ex ->> 'exercise_id')::uuid;
    -- RLS-visible only: blocks referencing another user's custom exercise.
    if not exists (select 1 from exercises where id = v_exercise) then
      raise exception 'Unknown exercise %', v_exercise using errcode = '23503';
    end if;

    insert into workout_log_exercises (id, workout_log_id, exercise_id, order_index, notes,
                                       replaced_from_exercise_id)
    values ((v_ex ->> 'id')::uuid, v_log_id, v_exercise, (v_ex ->> 'position')::smallint,
            v_ex ->> 'notes', nullif(v_ex ->> 'replaced_from_exercise_id', '')::uuid)
    returning id into v_wle;

    for v_set in select value from jsonb_array_elements(coalesce(v_ex -> 'sets', '[]'::jsonb)) loop
      insert into workout_log_sets (id, workout_log_exercise_id, set_number, set_type, reps,
                                    weight_kg, entered_weight, entered_unit, added_kg, assist_kg,
                                    hold_seconds, rpe, completed)
      values ((v_set ->> 'id')::uuid, v_wle, (v_set ->> 'position')::smallint + 1,
              coalesce(v_set ->> 'set_type', 'working')::public.set_type,
              (v_set ->> 'reps')::smallint,
              (v_set ->> 'weight_kg')::numeric,
              (v_set ->> 'entered_weight')::numeric,
              (v_set ->> 'entered_unit')::public.weight_unit,
              (v_set ->> 'added_kg')::numeric,
              (v_set ->> 'assist_kg')::numeric,
              (v_set ->> 'duration_s')::smallint,
              (v_set ->> 'rpe')::numeric,
              true);
    end loop;
  end loop;

  -- Exercises added during a template workout join the template now, and
  -- only now: a discarded workout never reaches this function.
  if v_template is not null then
    for v_add in select value from jsonb_array_elements(coalesce(p_workout -> 'template_additions', '[]'::jsonb)) loop
      v_exercise := (v_add ->> 'exercise_id')::uuid;
      if exists (select 1 from exercises where id = v_exercise)
         and not exists (select 1 from workout_template_exercises
                         where template_id = v_template and exercise_id = v_exercise) then
        select coalesce(max(order_index), -1) + 1 into v_next
        from workout_template_exercises where template_id = v_template;
        insert into workout_template_exercises (template_id, exercise_id, order_index, target_sets)
        values (v_template, v_exercise, v_next, nullif(v_add ->> 'default_sets', '')::smallint);
      end if;
    end loop;
    update workout_templates set updated_at = now() where id = v_template;
  end if;

  -- Fires handle_workout_log_completed (streak).
  update workout_logs
  set status = 'completed',
      completed_at = v_completed,
      duration_seconds = greatest(0, extract(epoch from (v_completed - v_started)))::int
  where id = v_log_id;

  return jsonb_build_object('workout_log_id', v_log_id,
                            'bodyweight_snapshot_kg', v_bw,
                            'already_saved', false);
end;
$$;

-- ---------------------------------------------------------------------
-- 8. Save a finished workout as a new template
-- ---------------------------------------------------------------------
create or replace function public.create_template_from_workout(p_workout_log_id uuid, p_name text)
returns uuid
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_template uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if length(v_name) = 0 or length(v_name) > 80 then
    raise exception 'Template name must be 1-80 characters' using errcode = '22023';
  end if;
  if not exists (select 1 from workout_logs
                 where id = p_workout_log_id and user_id = v_user and status = 'completed') then
    raise exception 'Workout not found' using errcode = 'P0002';
  end if;

  -- enforce_max_workout_templates() raises on the 8th template.
  insert into workout_templates (user_id, name) values (v_user, v_name)
  returning id into v_template;

  insert into workout_template_exercises (template_id, exercise_id, order_index, target_sets)
  select v_template, wle.exercise_id,
         (row_number() over (order by wle.order_index) - 1)::smallint,
         (select count(*) from workout_log_sets s where s.workout_log_exercise_id = wle.id)::smallint
  from workout_log_exercises wle
  where wle.workout_log_id = p_workout_log_id;

  return v_template;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. Previous performance for an exercise (the "Last: 60 kg x 8" line)
-- ---------------------------------------------------------------------
create or replace function public.get_last_exercise_performance(p_exercise_id uuid)
returns jsonb
language sql stable security invoker
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'position', s.set_number - 1, 'set_type', s.set_type, 'reps', s.reps,
           'weight_kg', s.weight_kg, 'entered_weight', s.entered_weight,
           'entered_unit', s.entered_unit, 'added_kg', s.added_kg,
           'assist_kg', s.assist_kg, 'duration_s', s.hold_seconds)
         order by s.set_number), '[]'::jsonb)
  from workout_log_sets s
  where s.workout_log_exercise_id = (
    select wle.id
    from workout_log_exercises wle
    join workout_logs w on w.id = wle.workout_log_id
    where w.user_id = (select auth.uid()) and w.status = 'completed'
      and wle.exercise_id = p_exercise_id
    order by w.completed_at desc, wle.order_index
    limit 1);
$$;

-- ---------------------------------------------------------------------
-- 10. Grants for client-callable functions
-- ---------------------------------------------------------------------
revoke execute on function public.create_custom_exercise(text, public.tracking_type, text, numeric) from public, anon;
revoke execute on function public.finish_workout(jsonb) from public, anon;
revoke execute on function public.create_template_from_workout(uuid, text) from public, anon;
revoke execute on function public.get_last_exercise_performance(uuid) from public, anon;
grant execute on function public.create_custom_exercise(text, public.tracking_type, text, numeric) to authenticated;
grant execute on function public.finish_workout(jsonb) to authenticated;
grant execute on function public.create_template_from_workout(uuid, text) to authenticated;
grant execute on function public.get_last_exercise_performance(uuid) to authenticated;

commit;
