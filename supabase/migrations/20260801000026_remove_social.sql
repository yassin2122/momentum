-- Momentum — remove legacy social layer
-- Connect = online coaching (Captain). No feed, posts, likes, comments,
-- friends, blocks, friend challenges, or leaderboards.
-- Forward-only: earlier migrations are NOT edited.
-- Kept on purpose: notifications table (reusable for coaching), weekly_challenges
-- (admin-authored, not social), user_streaks, XP, PRs, achievements.

begin;

-- ----------------------------------------------------------------------------
-- 1. Rewrite functions that wrote to `activities` (must happen BEFORE the drop)
-- ----------------------------------------------------------------------------

-- achievement trigger only existed to feed `activities`
drop trigger if exists trg_achievement_unlocked on public.user_achievements;
drop function if exists public.handle_achievement_unlocked();

create or replace function public.bump_streak(p_user_id uuid)
returns void language plpgsql security definer as $$
declare
  v_last date;
  v_current int;
  v_longest int;
begin
  select last_activity_date, current_streak, longest_streak
    into v_last, v_current, v_longest
  from public.user_streaks where user_id = p_user_id;

  if v_last is null then
    insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_date)
    values (p_user_id, 1, 1, current_date)
    on conflict (user_id) do nothing;
    return;
  end if;

  if v_last = current_date then
    return;
  elsif v_last = current_date - 1 then
    v_current := v_current + 1;
  else
    v_current := 1;
  end if;

  v_longest := greatest(v_longest, v_current);

  update public.user_streaks
  set current_streak = v_current, longest_streak = v_longest,
      last_activity_date = current_date, updated_at = now()
  where user_id = p_user_id;
end;
$$;

create or replace function public.handle_workout_log_completed()
returns trigger language plpgsql security definer as $$
begin
  if new.completed_at is not null and old.completed_at is null then
    perform public.bump_streak(new.user_id);
  end if;
  return new;
end;
$$;

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

create or replace function public.record_roadmap_personal_best(
  p_skill_id uuid, p_exercise_id uuid, p_metric_type pr_metric_type,
  p_value numeric, p_log_exercise_id uuid default null
) returns void language plpgsql security definer as $$
begin
  insert into public.roadmap_personal_bests
    (user_id, skill_id, exercise_id, metric_type, value, achieved_at, log_exercise_id)
  values (auth.uid(), p_skill_id, p_exercise_id, p_metric_type, p_value, now(), p_log_exercise_id)
  on conflict (user_id, skill_id, exercise_id, metric_type)
  do update set value = excluded.value, achieved_at = excluded.achieved_at,
                log_exercise_id = excluded.log_exercise_id
  where excluded.value > public.roadmap_personal_bests.value;
end;
$$;

create or replace function public.complete_roadmap_workout(
  p_roadmap_workout_id uuid,
  p_exercise_results jsonb
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

  return v_log_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- 2. Drop social views, RPCs, tables (policies/triggers/indexes go with tables)
-- ----------------------------------------------------------------------------
drop view if exists public.v_friend_activity_feed;

drop function if exists public.get_friends_xp_leaderboard(int);
drop function if exists public.get_global_xp_leaderboard(int);

drop table if exists public.user_challenge_participants cascade;
drop table if exists public.user_challenges cascade;
drop table if exists public.post_likes cascade;
drop table if exists public.post_comments cascade;
drop table if exists public.posts cascade;
drop table if exists public.activity_comments cascade;
drop table if exists public.activities cascade;
drop table if exists public.friendships cascade;
drop table if exists public.blocks cascade;

drop function if exists public.handle_post_like();
drop function if exists public.handle_post_unlike();
drop function if exists public.handle_post_comment();
drop function if exists public.handle_post_comment_delete();
drop function if exists public.are_friends(uuid, uuid);
drop function if exists public.is_blocked(uuid, uuid);

-- ----------------------------------------------------------------------------
-- 3. Social-only enums
--    (notification_type keeps its old values — Postgres cannot drop enum
--     values; they are harmless and the table is reused for coaching.)
-- ----------------------------------------------------------------------------
drop type if exists friend_request_status;
drop type if exists activity_type;

-- ----------------------------------------------------------------------------
-- 4. Storage: post-media policies (bucket itself: see note below)
-- ----------------------------------------------------------------------------
drop policy if exists "post_media_owner_write" on storage.objects;
drop policy if exists "post_media_owner_delete" on storage.objects;
-- NOTE: Supabase blocks deleting buckets via SQL. Remove the empty
-- `post-media` bucket from Dashboard > Storage after applying this.

commit;
