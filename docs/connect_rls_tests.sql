-- =====================================================================
-- Connect RLS tests: executable companion to docs/RLS_TEST_CHECKLIST.md
--
-- WHERE TO RUN: a local stack (`supabase start`) or a Supabase branch.
-- Not the production project (see the checklist).
--
-- HOW IT WORKS: creates four throwaway users, builds a real coaching
-- relationship through the RPCs, logs a workout as the athlete, then acts
-- as each user (set local role authenticated + request.jwt.claims) and
-- checks what they can read and write. The block ALWAYS ends by raising
-- an exception, so every write (fixtures included) is rolled back. The
-- exception message IS the report: one PASS/FAIL line per check.
--
-- Run as the postgres role, e.g. psql or the SQL editor of a branch:
--   psql "$DB_URL" -f docs/connect_rls_tests.sql
-- =====================================================================
begin;

do $$
declare
  v_a   uuid := gen_random_uuid();   -- athlete
  v_c   uuid := gen_random_uuid();   -- A's Captain
  v_c2  uuid := gen_random_uuid();   -- a second approved coach
  v_u   uuid := gen_random_uuid();   -- unrelated user
  v_rel uuid;
  v_rel2 uuid;
  v_ex  uuid;
  v_log uuid := gen_random_uuid();
  v_set uuid := gen_random_uuid();
  v_own_logs bigint; v_own_sets bigint; v_own_prs bigint; v_own_streaks bigint;
  v_n   bigint;
  v_ok  boolean;
  v_res text[] := '{}';
begin
  -- -------------------------------------------------------------------
  -- Fixtures (as postgres)
  -- -------------------------------------------------------------------
  -- handle_new_user() creates the profiles rows.
  insert into auth.users (id, email, raw_user_meta_data)
  values (v_a,  'rls-athlete-' || v_a  || '@test.invalid', '{}'),
         (v_c,  'rls-coach-'   || v_c  || '@test.invalid', '{}'),
         (v_c2, 'rls-coach2-'  || v_c2 || '@test.invalid', '{}'),
         (v_u,  'rls-other-'   || v_u  || '@test.invalid', '{}');

  insert into public.coach_profiles (id, status, accepting_athletes)
  values (v_c, 'approved', true), (v_c2, 'approved', true);

  select id into v_ex from public.exercises
  where tracking_type = 'weight_reps' and not is_custom and deleted_at is null
  order by name limit 1;

  -- A chooses C (all share_* flags on except body metrics, the defaults).
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  v_rel := public.choose_captain(v_c);

  -- C accepts.
  perform set_config('request.jwt.claims', json_build_object('sub', v_c, 'role', 'authenticated')::text, true);
  perform public.respond_to_coaching_request(v_rel, true);

  -- A logs one workout: 1 exercise, 1 working set (fires PR + streak triggers).
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  perform public.finish_workout(jsonb_build_object(
    'id', v_log,
    'exercises', jsonb_build_array(jsonb_build_object(
      'id', gen_random_uuid(), 'exercise_id', v_ex, 'position', 0,
      'sets', jsonb_build_array(jsonb_build_object(
        'id', v_set, 'position', 0, 'reps', 5, 'weight_kg', 100)))))));

  -- -------------------------------------------------------------------
  -- 1. Athlete sees own data
  -- -------------------------------------------------------------------
  select count(*) into v_own_logs    from public.workout_logs     where user_id = v_a;
  select count(*) into v_own_sets    from public.workout_log_sets  where id = v_set;
  select count(*) into v_own_prs     from public.personal_records where user_id = v_a;
  select count(*) into v_own_streaks from public.user_streaks     where user_id = v_a;
  v_res := v_res || (case when v_own_logs = 1 then 'PASS' else 'FAIL' end || '  own: athlete reads own workout log');
  v_res := v_res || (case when v_own_sets = 1 then 'PASS' else 'FAIL' end || '  own: athlete reads own set');
  v_res := v_res || (case when v_own_prs  > 0 then 'PASS' else 'FAIL' end || '  own: athlete reads own PRs (' || v_own_prs || ')');

  -- -------------------------------------------------------------------
  -- 2. Active Captain sees permitted data
  -- -------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', v_c, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.workout_logs where user_id = v_a;
  v_res := v_res || (case when v_n = v_own_logs then 'PASS' else 'FAIL' end || '  captain: reads athlete logs (share_workouts on)');
  select count(*) into v_n from public.workout_log_sets where id = v_set;
  v_res := v_res || (case when v_n = 1 then 'PASS' else 'FAIL' end || '  captain: reads athlete sets');
  select count(*) into v_n from public.personal_records where user_id = v_a;
  v_res := v_res || (case when v_n = v_own_prs then 'PASS' else 'FAIL' end || '  captain: reads athlete PRs (share_prs on)');
  select count(*) into v_n from public.user_streaks where user_id = v_a;
  v_res := v_res || (case when v_n = v_own_streaks then 'PASS' else 'FAIL' end || '  captain: reads athlete streak (workouts scope)');
  select count(*) into v_n from public.body_metrics_log where user_id = v_a;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: no body metrics (share_body_metrics off by default)');

  -- -------------------------------------------------------------------
  -- 3. Captain cannot modify history (or the athlete's flags)
  -- -------------------------------------------------------------------
  begin
    insert into public.workout_logs (user_id, started_at) values (v_a, now());
    v_ok := false;
  exception when insufficient_privilege then v_ok := true;   -- 42501 = RLS violation
  end;
  v_res := v_res || (case when v_ok then 'PASS' else 'FAIL' end || '  captain: INSERT athlete workout_log rejected');

  update public.workout_logs set notes = 'edited by captain' where id = v_log;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: UPDATE athlete workout_log affects 0 rows');

  delete from public.workout_logs where id = v_log;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: DELETE athlete workout_log affects 0 rows');

  update public.workout_log_sets set reps = 50 where id = v_set;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: UPDATE athlete set affects 0 rows');

  delete from public.workout_log_sets where id = v_set;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: DELETE athlete set affects 0 rows');

  begin
    insert into public.personal_records (user_id, exercise_id, metric_type, value, achieved_at)
    values (v_a, v_ex, 'max_reps', 999, now());
    v_ok := false;
  exception when insufficient_privilege then v_ok := true;   -- 42501 = RLS violation
  end;
  v_res := v_res || (case when v_ok then 'PASS' else 'FAIL' end || '  captain: INSERT athlete PR rejected');

  update public.personal_records set value = 999 where user_id = v_a;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: UPDATE athlete PRs affects 0 rows');

  delete from public.personal_records where user_id = v_a;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: DELETE athlete PRs affects 0 rows');

  update public.coaching_permissions set share_body_metrics = true where relationship_id = v_rel;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  captain: cannot change athlete share_* flags');

  -- Confirm as postgres that nothing changed.
  execute 'reset role';
  select count(*) into v_n from public.workout_logs where id = v_log and notes is null;
  v_res := v_res || (case when v_n = 1 then 'PASS' else 'FAIL' end || '  history intact: log unchanged');
  select count(*) into v_n from public.workout_log_sets where id = v_set and reps = 5;
  v_res := v_res || (case when v_n = 1 then 'PASS' else 'FAIL' end || '  history intact: set unchanged');
  select count(*) into v_n from public.personal_records where user_id = v_a and value <> 999;
  v_res := v_res || (case when v_n = v_own_prs then 'PASS' else 'FAIL' end || '  history intact: PRs unchanged');
  select count(*) into v_n from public.coaching_permissions where relationship_id = v_rel and not share_body_metrics;
  v_res := v_res || (case when v_n = 1 then 'PASS' else 'FAIL' end || '  flags intact: share_body_metrics still off');

  -- -------------------------------------------------------------------
  -- 4. Unrelated user sees nothing
  -- -------------------------------------------------------------------
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
  select (select count(*) from public.workout_logs where user_id = v_a)
       + (select count(*) from public.workout_log_sets where id = v_set)
       + (select count(*) from public.personal_records where user_id = v_a)
       + (select count(*) from public.user_streaks where user_id = v_a)
       + (select count(*) from public.coaching_relationships where id = v_rel)
       + (select count(*) from public.coaching_permissions where relationship_id = v_rel)
    into v_n;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  unrelated: sees none of the athlete''s data or relationship');
  v_res := v_res || (case when not public.coach_can_view(v_a, 'workouts') then 'PASS' else 'FAIL' end
                     || '  unrelated: coach_can_view(athlete) is false');

  -- -------------------------------------------------------------------
  -- 5. Blocked when a flag is off (athlete flips it; scopes are independent)
  -- -------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  update public.coaching_permissions set share_workouts = false where relationship_id = v_rel;
  get diagnostics v_n = row_count;
  v_res := v_res || (case when v_n = 1 then 'PASS' else 'FAIL' end || '  athlete: can turn share_workouts off');

  perform set_config('request.jwt.claims', json_build_object('sub', v_c, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.workout_logs where user_id = v_a;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  flag off: captain reads 0 logs');
  select count(*) into v_n from public.workout_log_sets where id = v_set;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  flag off: captain reads 0 sets');
  select count(*) into v_n from public.personal_records where user_id = v_a;
  v_res := v_res || (case when v_n = v_own_prs then 'PASS' else 'FAIL' end || '  flag off: PRs still visible (share_prs is a separate scope)');

  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  update public.coaching_permissions set share_prs = false where relationship_id = v_rel;
  perform set_config('request.jwt.claims', json_build_object('sub', v_c, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.personal_records where user_id = v_a;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  flag off: captain reads 0 PRs after share_prs off');

  -- Turn both back on so the "ended" test below is about the status only.
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  update public.coaching_permissions set share_workouts = true, share_prs = true where relationship_id = v_rel;

  -- -------------------------------------------------------------------
  -- 6. Only one open relationship per athlete
  -- -------------------------------------------------------------------
  begin
    perform public.choose_captain(v_c2);
    v_ok := false;
  exception when unique_violation then v_ok := true;
  end;
  v_res := v_res || (case when v_ok then 'PASS' else 'FAIL' end || '  one-captain: second request while active is rejected');

  -- -------------------------------------------------------------------
  -- 7. Ending the relationship removes access immediately
  -- -------------------------------------------------------------------
  perform public.end_coaching(v_rel);   -- as the athlete

  perform set_config('request.jwt.claims', json_build_object('sub', v_c, 'role', 'authenticated')::text, true);
  select (select count(*) from public.workout_logs where user_id = v_a)
       + (select count(*) from public.workout_log_sets where id = v_set)
       + (select count(*) from public.personal_records where user_id = v_a)
       + (select count(*) from public.user_streaks where user_id = v_a)
    into v_n;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  ended: former captain reads 0 rows (flags still on)');
  v_res := v_res || (case when not public.coach_can_view(v_a, 'workouts') then 'PASS' else 'FAIL' end
                     || '  ended: coach_can_view is false');

  -- A new, still-pending request grants nothing either.
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  v_rel2 := public.choose_captain(v_c2);
  perform set_config('request.jwt.claims', json_build_object('sub', v_c2, 'role', 'authenticated')::text, true);
  select count(*) into v_n from public.workout_logs where user_id = v_a;
  v_res := v_res || (case when v_n = 0 then 'PASS' else 'FAIL' end || '  pending: requested coach reads 0 logs before accepting');

  -- -------------------------------------------------------------------
  -- Report + rollback (always)
  -- -------------------------------------------------------------------
  execute 'reset role';
  raise exception E'CONNECT RLS TEST REPORT (rolled back)\n%\n% failed of %',
    array_to_string(v_res, E'\n'),
    (select count(*) from unnest(v_res) r where r like 'FAIL%'),
    cardinality(v_res);
end;
$$;

rollback;
