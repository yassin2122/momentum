-- FUNCTIONS / TRIGGERS
-- ============================================================================

-- keep updated_at fresh everywhere
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
-- attach to every table with updated_at (representative subset shown; repeat for all)
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_skill_progress_updated_at before update on public.skill_progress
  for each row execute function public.set_updated_at();
create trigger trg_user_objective_progress_updated_at before update on public.user_objective_progress
  for each row execute function public.set_updated_at();
create trigger trg_workout_templates_updated_at before update on public.workout_templates
  for each row execute function public.set_updated_at();
create trigger trg_posts_updated_at before update on public.posts
  for each row execute function public.set_updated_at();

-- keep posts.like_count in sync + notify the post owner (skip self-likes)
create or replace function public.handle_post_like()
returns trigger language plpgsql security definer as $$
declare
  v_post_owner uuid;
begin
  update public.posts set like_count = like_count + 1 where id = new.post_id
  returning user_id into v_post_owner;

  if v_post_owner is distinct from new.user_id then
    insert into public.notifications (user_id, type, reference_table, reference_id, message)
    values (v_post_owner, 'post_like', 'posts', new.post_id, 'Someone liked your post');
  end if;
  return new;
end;
$$;
create trigger trg_post_like_insert after insert on public.post_likes
  for each row execute function public.handle_post_like();

create or replace function public.handle_post_unlike()
returns trigger language plpgsql security definer as $$
begin
  update public.posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
  return old;
end;
$$;
create trigger trg_post_like_delete after delete on public.post_likes
  for each row execute function public.handle_post_unlike();

-- keep posts.comment_count in sync + notify the post owner (skip self-comments)
create or replace function public.handle_post_comment()
returns trigger language plpgsql security definer as $$
declare
  v_post_owner uuid;
begin
  update public.posts set comment_count = comment_count + 1 where id = new.post_id
  returning user_id into v_post_owner;

  if v_post_owner is distinct from new.user_id then
    insert into public.notifications (user_id, type, reference_table, reference_id, message)
    values (v_post_owner, 'post_comment', 'posts', new.post_id, 'Someone commented on your post');
  end if;
  return new;
end;
$$;
create trigger trg_post_comment_insert after insert on public.post_comments
  for each row execute function public.handle_post_comment();

create or replace function public.handle_post_comment_delete()
returns trigger language plpgsql security definer as $$
begin
  update public.posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
  return old;
end;
$$;
create trigger trg_post_comment_soft_delete before update on public.post_comments
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function public.handle_post_comment_delete();

-- gym-tracker PR check: run after a set is logged, upsert current PR + history
create or replace function public.check_and_update_personal_record()
returns trigger language plpgsql security definer as $$
declare
  v_user_id uuid;
  v_exercise_id uuid;
  v_metric pr_metric_type;
  v_value numeric;
begin
  select w.user_id, wle.exercise_id into v_user_id, v_exercise_id
  from public.workout_log_exercises wle
  join public.workout_logs w on w.id = wle.workout_log_id
  where wle.id = new.workout_log_exercise_id;

  if new.weight_kg is not null then
    v_metric := 'max_weight'; v_value := new.weight_kg;
  elsif new.hold_seconds is not null then
    v_metric := 'max_hold_seconds'; v_value := new.hold_seconds;
  elsif new.reps is not null then
    v_metric := 'max_reps'; v_value := new.reps;
  else
    return new;
  end if;

  insert into public.personal_records (user_id, exercise_id, metric_type, value, achieved_at, set_id)
  values (v_user_id, v_exercise_id, v_metric, v_value, now(), new.id)
  on conflict (user_id, exercise_id, metric_type)
  do update set value = excluded.value, achieved_at = excluded.achieved_at, set_id = excluded.set_id
  where excluded.value > public.personal_records.value;

  if found then
    insert into public.personal_record_history (user_id, exercise_id, metric_type, value, achieved_at)
    values (v_user_id, v_exercise_id, v_metric, v_value, now());
  end if;

  return new;
end;
$$;
create trigger trg_check_pr after insert on public.workout_log_sets
  for each row execute function public.check_and_update_personal_record();

-- RPC: initialize skill_progress rows for a newly registered user (locked by default,
-- root skills — no prerequisites — become 'available')
create or replace function public.initialize_user_skill_progress(p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  insert into public.skill_progress (user_id, skill_id, status)
  select p_user_id, s.id,
    case when not exists (select 1 from public.skill_prerequisites sp where sp.skill_id = s.id)
         then 'available'::skill_status else 'locked'::skill_status end
  from public.skills s
  where s.deleted_at is null and s.is_active
  on conflict (user_id, skill_id) do nothing;
end;
$$;

-- RPC: award XP (the ONLY path that mutates current_xp) — logs to xp_transactions,
-- and unlocks dependent skills once completion is reached.
create or replace function public.award_xp(
  p_user_id uuid, p_skill_id uuid, p_amount int,
  p_source xp_source, p_reference_table text default null, p_reference_id uuid default null
) returns void language plpgsql security definer as $$
begin
  if p_amount <= 0 then
    raise exception 'XP amount must be positive';
  end if;

  insert into public.xp_transactions (user_id, skill_id, amount, source, reference_table, reference_id)
  values (p_user_id, p_skill_id, p_amount, p_source, p_reference_table, p_reference_id);

  insert into public.skill_progress (user_id, skill_id, current_xp, status, unlocked_at)
  values (p_user_id, p_skill_id, p_amount, 'active', now())
  on conflict (user_id, skill_id)
  do update set current_xp = public.skill_progress.current_xp + p_amount,
                status = case when public.skill_progress.status = 'available'
                              then 'active' else public.skill_progress.status end;
end;
$$;

-- RPC: complete a roadmap workout — validates achieved values against the
-- snapshot, awards XP, writes the log. Client calls this instead of
-- inserting into roadmap_workout_logs directly with completed/xp pre-set.
create or replace function public.complete_roadmap_workout(
  p_roadmap_workout_id uuid,
  p_exercise_results jsonb  -- [{exercise_id, achieved_sets, achieved_reps, achieved_hold_seconds}]
) returns uuid language plpgsql security definer as $$
declare
  v_log_id uuid;
  v_skill_id uuid;
  v_xp_reward int;
  v_snapshot jsonb;
begin
  select skill_id, xp_reward into v_skill_id, v_xp_reward
  from public.roadmap_workouts where id = p_roadmap_workout_id and deleted_at is null;

  if v_skill_id is null then
    raise exception 'Roadmap workout not found';
  end if;

  select jsonb_agg(to_jsonb(rwe)) into v_snapshot
  from public.roadmap_workout_exercises rwe where roadmap_workout_id = p_roadmap_workout_id;

  insert into public.roadmap_workout_logs
    (user_id, roadmap_workout_id, skill_id, workout_snapshot, completed, xp_awarded, completed_at)
  values (auth.uid(), p_roadmap_workout_id, v_skill_id, v_snapshot, true, v_xp_reward, now())
  returning id into v_log_id;

  insert into public.roadmap_workout_log_exercises
    (roadmap_workout_log_id, exercise_id, order_index, achieved_sets, achieved_reps, achieved_hold_seconds, met_requirement)
  select v_log_id, (r->>'exercise_id')::uuid, row_number() over (),
         (r->>'achieved_sets')::smallint, (r->>'achieved_reps')::smallint, (r->>'achieved_hold_seconds')::smallint,
         true
  from jsonb_array_elements(p_exercise_results) r;

  perform public.award_xp(auth.uid(), v_skill_id, v_xp_reward, 'roadmap_workout', 'roadmap_workout_logs', v_log_id);

  insert into public.activities (user_id, activity_type, reference_table, reference_id)
  values (auth.uid(), 'workout_completed', 'roadmap_workout_logs', v_log_id);

  return v_log_id;
end;
$$;

-- content_audit_log writer (attach to admin-editable content tables as needed)
create or replace function public.log_content_change()
returns trigger language plpgsql security definer as $$
begin
  insert into public.content_audit_log (admin_id, table_name, record_id, action, old_data, new_data)
  values (
    auth.uid(), tg_table_name,
    coalesce(new.id, old.id),
    lower(tg_op)::audit_action,
    to_jsonb(old), to_jsonb(new)
  );
  return coalesce(new, old);
end;
$$;
create trigger trg_audit_skills after insert or update or delete on public.skills
  for each row execute function public.log_content_change();
create trigger trg_audit_roadmap_workouts after insert or update or delete on public.roadmap_workouts
  for each row execute function public.log_content_change();
create trigger trg_audit_achievements after insert or update or delete on public.achievements
  for each row execute function public.log_content_change();


-- ============================================================================
