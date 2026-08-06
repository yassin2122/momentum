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
