-- Security hardening from Supabase advisor (23 definer-exec, 14 search_path, 2 extensions)
begin;

-- 1. INTERNAL / trigger-only functions: nobody can call them through the API.
--    (Triggers and other SECURITY DEFINER functions still run them fine.)
--    NOTE: award_xp(p_user_id ...) was callable by any user for ANY user id.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('award_xp','award_stage_xp','bump_streak',
                               'check_and_update_personal_record','handle_new_user',
                               'handle_workout_log_completed','initialize_user_skill_progress',
                               'log_content_change','notify_coaching_event')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.f);
  end loop;
end $$;

-- 2. CLIENT RPCs: signed-in users only.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('assign_program','choose_captain','complete_roadmap_workout',
                               'end_coaching','get_coach_directory','record_roadmap_personal_best',
                               'respond_to_coaching_request','start_assigned_program')
  loop
    execute format('revoke execute on function %s from public, anon', r.f);
    execute format('grant  execute on function %s to authenticated', r.f);
  end loop;
end $$;

-- 3. RLS helpers: used inside policies, so authenticated must keep EXECUTE; anon does not.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('is_admin','is_coach','in_relationship','is_active_coach_of',
                               'coach_can_view','can_view_program')
  loop
    execute format('revoke execute on function %s from public, anon', r.f);
    execute format('grant  execute on function %s to authenticated', r.f);
  end loop;
end $$;

-- 4. Pin search_path on every flagged function
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('enforce_max_workout_templates','is_admin','set_updated_at',
                               'initialize_user_skill_progress','award_xp','log_content_change',
                               'handle_new_user','award_stage_xp','record_roadmap_personal_best',
                               'bump_streak','handle_workout_log_completed',
                               'check_and_update_personal_record','complete_roadmap_workout',
                               'guard_coach_status')
  loop
    execute format('alter function %s set search_path = public, pg_temp', r.f);
  end loop;
end $$;

-- 5. Extensions out of public
create schema if not exists extensions;
alter extension pg_trgm    set schema extensions;
alter extension btree_gist set schema extensions;

commit;
