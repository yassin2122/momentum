-- =====================================================================
-- CONNECT → TRAIN: a coach sends a workout straight into the athlete's
-- own templates.
--
--   1. workout_templates.assigned_by / assigned_note / assigned_at —
--      marks a template that arrived from a coach, so the app can tag it
--      "From Coach <name>" and show the note. Null for the athlete's own.
--   2. send_workout_to_athlete(relationship, name, exercises, note)
--      — the coach's only way to create it. Active relationship and an
--      approved coach required (is_active_coach_of). Notifies the athlete.
--
-- Once delivered, the template belongs to the athlete like any other: they
-- can edit, rename or delete it, and it counts toward the 7-template cap
-- (enforce_max_workout_templates still applies — a full list makes the send
-- fail with a clear message to the coach).
--
-- No coach RLS policy is added on workout_templates or any athlete log: the
-- coach writes only through this RPC, and cannot read or change the
-- template afterwards.
-- =====================================================================
begin;

-- ---------------------------------------------------------------- 1. columns
alter table public.workout_templates
  add column assigned_by   uuid references public.profiles(id) on delete set null,
  add column assigned_note text check (assigned_note is null or length(assigned_note) <= 500),
  add column assigned_at   timestamptz;

create index idx_workout_templates_assigned_by on public.workout_templates (assigned_by);

-- ---------------------------------------------------------------- 2. RPC
-- p_exercises: ordered jsonb array of
--   { "exercise_id": uuid, "target_sets": int?, "target_reps": int?,
--     "target_hold_seconds": int?, "notes": text? }
create or replace function public.send_workout_to_athlete(
  p_relationship_id uuid,
  p_name            text,
  p_exercises       jsonb,
  p_note            text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_athlete  uuid;
  v_coach    text;
  v_name     text := btrim(coalesce(p_name, ''));
  v_note     text := nullif(btrim(coalesce(p_note, '')), '');
  v_template uuid;
  v_item     jsonb;
  v_exercise uuid;
  v_order    smallint := 0;
begin
  if not public.is_active_coach_of(p_relationship_id) then
    raise exception 'Not your active athlete';
  end if;
  if v_name = '' or length(v_name) > 60 then
    raise exception 'Workout name must be 1 to 60 characters';
  end if;
  if v_note is not null and length(v_note) > 500 then
    raise exception 'Note must be 500 characters or fewer';
  end if;
  if p_exercises is null or jsonb_typeof(p_exercises) <> 'array'
     or jsonb_array_length(p_exercises) = 0 then
    raise exception 'Add at least one exercise';
  end if;
  if jsonb_array_length(p_exercises) > 30 then
    raise exception 'A workout can have at most 30 exercises';
  end if;

  select r.athlete_id into v_athlete
  from coaching_relationships r where r.id = p_relationship_id;

  select coalesce(nullif(p.display_name, ''), p.username, 'Your Coach') into v_coach
  from profiles p where p.id = auth.uid();

  begin
    insert into workout_templates (user_id, name, assigned_by, assigned_note, assigned_at)
    values (v_athlete, v_name, auth.uid(), v_note, now())
    returning id into v_template;
  exception when raise_exception then
    if sqlerrm like 'Maximum of 7 workout templates%' then
      raise exception 'This athlete already has 7 templates. Ask them to delete one, then send again';
    end if;
    raise;
  end;

  for v_item in select value from jsonb_array_elements(p_exercises) loop
    v_exercise := nullif(v_item ->> 'exercise_id', '')::uuid;
    -- Library exercises only: a coach's custom exercise is invisible to
    -- the athlete (exercises_select_visible), so it can't be sent.
    if v_exercise is null or not exists (
         select 1 from exercises e
         where e.id = v_exercise and e.deleted_at is null and not e.is_custom) then
      raise exception 'Unknown or custom exercise in workout';
    end if;
    insert into workout_template_exercises
      (template_id, exercise_id, order_index, target_sets, target_reps, target_hold_seconds, notes)
    values (
      v_template, v_exercise, v_order,
      nullif(v_item ->> 'target_sets', '')::smallint,
      nullif(v_item ->> 'target_reps', '')::smallint,
      nullif(v_item ->> 'target_hold_seconds', '')::smallint,
      nullif(btrim(coalesce(v_item ->> 'notes', '')), '')
    );
    v_order := v_order + 1;
  end loop;

  insert into notifications (user_id, type, reference_table, reference_id, message)
  values (v_athlete, 'program_assigned', 'workout_templates', v_template,
          left(v_coach || ' sent you a workout: ' || v_name, 200));

  return v_template;
end;
$$;

revoke execute on function public.send_workout_to_athlete(uuid, text, jsonb, text) from public, anon;
grant  execute on function public.send_workout_to_athlete(uuid, text, jsonb, text) to authenticated;

commit;
