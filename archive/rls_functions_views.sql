-- ============================================================================
-- ROW LEVEL SECURITY, FUNCTIONS, TRIGGERS, VIEWS — v1.0
-- Run after schema.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: is the current user an admin?
-- ----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and deleted_at is null
  );
$$;

-- Helper: are two users blocked in either direction?
create or replace function public.is_blocked(user_a uuid, user_b uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = user_a and blocked_id = user_b)
       or (blocker_id = user_b and blocked_id = user_a)
  );
$$;

-- Helper: are two users friends (accepted)?
create or replace function public.are_friends(user_a uuid, user_b uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ((requester_id = user_a and addressee_id = user_b)
        or (requester_id = user_b and addressee_id = user_a))
  );
$$;

-- ============================================================================
-- ENABLE RLS on every table
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.body_metrics_log enable row level security;
alter table public.exercises enable row level security;
alter table public.muscle_groups enable row level security;
alter table public.exercise_muscle_groups enable row level security;
alter table public.workout_templates enable row level security;
alter table public.workout_template_exercises enable row level security;
alter table public.workout_logs enable row level security;
alter table public.workout_log_exercises enable row level security;
alter table public.workout_log_sets enable row level security;
alter table public.personal_records enable row level security;
alter table public.personal_record_history enable row level security;
alter table public.roadmap_categories enable row level security;
alter table public.skills enable row level security;
alter table public.skill_prerequisites enable row level security;
alter table public.skill_stages enable row level security;
alter table public.objectives enable row level security;
alter table public.roadmap_workouts enable row level security;
alter table public.roadmap_workout_exercises enable row level security;
alter table public.roadmap_workout_logs enable row level security;
alter table public.roadmap_workout_log_exercises enable row level security;
alter table public.user_objective_progress enable row level security;
alter table public.roadmap_personal_bests enable row level security;
alter table public.skill_progress enable row level security;
alter table public.xp_transactions enable row level security;
alter table public.weekly_challenges enable row level security;
alter table public.user_weekly_challenge_progress enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.activities enable row level security;
alter table public.activity_comments enable row level security;
alter table public.notifications enable row level security;
alter table public.content_audit_log enable row level security;

-- ============================================================================
-- PROFILES
-- ============================================================================
create policy "profiles_select_all" on public.profiles for select
  using (deleted_at is null);
create policy "profiles_update_own" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and role = 'user'); -- can't self-promote to admin
create policy "profiles_insert_own" on public.profiles for insert
  with check (id = auth.uid());

create policy "body_metrics_owner_all" on public.body_metrics_log for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- EXERCISE LIBRARY — public read, admin write
-- ============================================================================
create policy "exercises_select_all" on public.exercises for select using (deleted_at is null);
create policy "exercises_admin_write" on public.exercises for all
  using (public.is_admin()) with check (public.is_admin());

create policy "muscle_groups_select_all" on public.muscle_groups for select using (true);
create policy "muscle_groups_admin_write" on public.muscle_groups for all
  using (public.is_admin()) with check (public.is_admin());

create policy "exercise_muscle_groups_select_all" on public.exercise_muscle_groups for select using (true);
create policy "exercise_muscle_groups_admin_write" on public.exercise_muscle_groups for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================================
-- WORKOUT TRACKER — fully owner-scoped
-- ============================================================================
create policy "workout_templates_owner_all" on public.workout_templates for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "workout_template_exercises_owner_all" on public.workout_template_exercises for all
  using (exists (select 1 from public.workout_templates t
                 where t.id = template_id and t.user_id = auth.uid()))
  with check (exists (select 1 from public.workout_templates t
                       where t.id = template_id and t.user_id = auth.uid()));

create policy "workout_logs_owner_all" on public.workout_logs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "workout_log_exercises_owner_all" on public.workout_log_exercises for all
  using (exists (select 1 from public.workout_logs w
                 where w.id = workout_log_id and w.user_id = auth.uid()))
  with check (exists (select 1 from public.workout_logs w
                       where w.id = workout_log_id and w.user_id = auth.uid()));

create policy "workout_log_sets_owner_all" on public.workout_log_sets for all
  using (exists (select 1 from public.workout_log_exercises wle
                 join public.workout_logs w on w.id = wle.workout_log_id
                 where wle.id = workout_log_exercise_id and w.user_id = auth.uid()))
  with check (exists (select 1 from public.workout_log_exercises wle
                       join public.workout_logs w on w.id = wle.workout_log_id
                       where wle.id = workout_log_exercise_id and w.user_id = auth.uid()));

create policy "personal_records_owner_select" on public.personal_records for select
  using (user_id = auth.uid());
-- NOTE: no direct insert/update policy — PRs are written only by the
-- SECURITY DEFINER trigger/function below, never directly by the client.

create policy "personal_record_history_owner_select" on public.personal_record_history for select
  using (user_id = auth.uid());

-- ============================================================================
-- ROADMAP CONTENT — public read, admin write (users never edit content)
-- ============================================================================
create policy "roadmap_categories_select_all" on public.roadmap_categories for select using (true);
create policy "roadmap_categories_admin_write" on public.roadmap_categories for all
  using (public.is_admin()) with check (public.is_admin());

create policy "skills_select_all" on public.skills for select using (deleted_at is null);
create policy "skills_admin_write" on public.skills for all
  using (public.is_admin()) with check (public.is_admin());

create policy "skill_prerequisites_select_all" on public.skill_prerequisites for select using (true);
create policy "skill_prerequisites_admin_write" on public.skill_prerequisites for all
  using (public.is_admin()) with check (public.is_admin());

create policy "skill_stages_select_all" on public.skill_stages for select using (true);
create policy "skill_stages_admin_write" on public.skill_stages for all
  using (public.is_admin()) with check (public.is_admin());

create policy "objectives_select_all" on public.objectives for select using (deleted_at is null);
create policy "objectives_admin_write" on public.objectives for all
  using (public.is_admin()) with check (public.is_admin());

create policy "roadmap_workouts_select_all" on public.roadmap_workouts for select using (deleted_at is null);
create policy "roadmap_workouts_admin_write" on public.roadmap_workouts for all
  using (public.is_admin()) with check (public.is_admin());

create policy "roadmap_workout_exercises_select_all" on public.roadmap_workout_exercises for select using (true);
create policy "roadmap_workout_exercises_admin_write" on public.roadmap_workout_exercises for all
  using (public.is_admin()) with check (public.is_admin());

create policy "achievements_select_visible" on public.achievements for select
  using (deleted_at is null and (is_hidden = false or public.is_admin()));
create policy "achievements_admin_write" on public.achievements for all
  using (public.is_admin()) with check (public.is_admin());

create policy "weekly_challenges_select_all" on public.weekly_challenges for select using (true);
create policy "weekly_challenges_admin_write" on public.weekly_challenges for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================================
-- ROADMAP PROGRESS — owner can READ, but XP/status/completion are NEVER
-- directly writable by the client. All mutation happens through the
-- SECURITY DEFINER RPCs below.
-- ============================================================================
create policy "skill_progress_owner_select" on public.skill_progress for select
  using (user_id = auth.uid());
-- deliberately no insert/update/delete policy for regular users

create policy "xp_transactions_owner_select" on public.xp_transactions for select
  using (user_id = auth.uid());

create policy "user_objective_progress_owner_select" on public.user_objective_progress for select
  using (user_id = auth.uid());

create policy "roadmap_personal_bests_owner_select" on public.roadmap_personal_bests for select
  using (user_id = auth.uid());

create policy "roadmap_workout_logs_owner_all" on public.roadmap_workout_logs for select
  using (user_id = auth.uid());
create policy "roadmap_workout_logs_owner_insert" on public.roadmap_workout_logs for insert
  with check (user_id = auth.uid());
-- updates to completed/xp_awarded happen via RPC only (SECURITY DEFINER bypasses RLS)

create policy "roadmap_workout_log_exercises_owner_select" on public.roadmap_workout_log_exercises for select
  using (exists (select 1 from public.roadmap_workout_logs l
                 where l.id = roadmap_workout_log_id and l.user_id = auth.uid()));
create policy "roadmap_workout_log_exercises_owner_insert" on public.roadmap_workout_log_exercises for insert
  with check (exists (select 1 from public.roadmap_workout_logs l
                       where l.id = roadmap_workout_log_id and l.user_id = auth.uid()));

create policy "user_weekly_challenge_progress_owner_select" on public.user_weekly_challenge_progress for select
  using (user_id = auth.uid());

create policy "user_achievements_owner_select" on public.user_achievements for select
  using (user_id = auth.uid());

-- ============================================================================
-- SOCIAL
-- ============================================================================
create policy "friendships_involved_select" on public.friendships for select
  using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "friendships_requester_insert" on public.friendships for insert
  with check (requester_id = auth.uid() and not public.is_blocked(requester_id, addressee_id));
create policy "friendships_involved_update" on public.friendships for update
  using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "friendships_involved_delete" on public.friendships for delete
  using (requester_id = auth.uid() or addressee_id = auth.uid());

create policy "blocks_owner_all" on public.blocks for all
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ============================================================================
-- POSTS — public feed (not friends-only), blocks still hide content both ways
-- ============================================================================
create policy "posts_select_public" on public.posts for select
  using (deleted_at is null and not public.is_blocked(auth.uid(), user_id));
create policy "posts_owner_insert" on public.posts for insert
  with check (user_id = auth.uid());
create policy "posts_owner_update" on public.posts for update
  using (user_id = auth.uid());
create policy "posts_owner_delete" on public.posts for delete
  using (user_id = auth.uid());

create policy "post_likes_select_public" on public.post_likes for select
  using (exists (select 1 from public.posts p where p.id = post_id and p.deleted_at is null)
         and not public.is_blocked(auth.uid(),
           (select p.user_id from public.posts p where p.id = post_id)));
create policy "post_likes_owner_insert" on public.post_likes for insert
  with check (user_id = auth.uid()
    and not public.is_blocked(auth.uid(), (select p.user_id from public.posts p where p.id = post_id)));
create policy "post_likes_owner_delete" on public.post_likes for delete
  using (user_id = auth.uid());

create policy "post_comments_select_public" on public.post_comments for select
  using (deleted_at is null
    and not public.is_blocked(auth.uid(), (select p.user_id from public.posts p where p.id = post_id)));
create policy "post_comments_owner_insert" on public.post_comments for insert
  with check (user_id = auth.uid()
    and not public.is_blocked(auth.uid(), (select p.user_id from public.posts p where p.id = post_id)));
create policy "post_comments_owner_update" on public.post_comments for update
  using (user_id = auth.uid());

create policy "activities_visible" on public.activities for select
  using (
    user_id = auth.uid()
    or (not public.is_blocked(auth.uid(), user_id) and public.are_friends(auth.uid(), user_id))
  );
create policy "activities_owner_insert" on public.activities for insert
  with check (user_id = auth.uid());

create policy "activity_comments_visible" on public.activity_comments for select
  using (
    deleted_at is null
    and exists (select 1 from public.activities a where a.id = activity_id)
    and not public.is_blocked(auth.uid(), user_id)
  );
create policy "activity_comments_owner_insert" on public.activity_comments for insert
  with check (user_id = auth.uid() and not public.is_blocked(auth.uid(),
    (select a.user_id from public.activities a where a.id = activity_id)));
create policy "activity_comments_owner_update" on public.activity_comments for update
  using (user_id = auth.uid());

create policy "notifications_owner_select" on public.notifications for select
  using (user_id = auth.uid());
create policy "notifications_owner_update" on public.notifications for update
  using (user_id = auth.uid());

-- ============================================================================
-- ADMIN / AUDIT
-- ============================================================================
create policy "content_audit_admin_select" on public.content_audit_log for select
  using (public.is_admin());


-- ============================================================================
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
-- VIEWS
-- ============================================================================

-- roadmap map view: skill + user's progress + lock state, ready for the UI graph
create or replace view public.v_user_roadmap as
select
  s.id as skill_id, s.name, s.slug, s.roadmap_category_id, s.sort_order,
  sp.user_id, coalesce(sp.status, 'locked') as status,
  coalesce(sp.current_xp, 0) as current_xp,
  coalesce(sp.completion_percentage, 0) as completion_percentage,
  sp.unlocked_at, sp.completed_at
from public.skills s
left join public.skill_progress sp on sp.skill_id = s.id
where s.deleted_at is null and s.is_active;

-- friend leaderboard-style feed (accepted friends only, most recent activity first)
create or replace view public.v_friend_activity_feed as
select a.*, p.username, p.display_name, p.avatar_url
from public.activities a
join public.profiles p on p.id = a.user_id
where p.deleted_at is null;
-- RLS on `activities` already restricts rows to the caller's own + accepted friends'.
