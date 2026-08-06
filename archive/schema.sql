-- ============================================================================
-- CALISTHENICS PROGRESSION PLATFORM — BACKEND v1.0
-- Pure Supabase: PostgreSQL + Supabase Auth + RLS + PostgREST + RPC + Realtime
-- ============================================================================
-- Apply in order. Each numbered section is a logical migration; split into
-- separate files (001_..sql, 002_..sql, ...) if your migration tool wants
-- one statement-group per file — the order below is the dependency order.
-- ============================================================================


-- ============================================================================
-- 0. EXTENSIONS
-- ============================================================================
create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "pg_trgm";       -- fuzzy search on exercise/skill names
create extension if not exists "btree_gist";    -- for exclusion constraints if needed later


-- ============================================================================
-- 1. ENUMS
-- ============================================================================
create type user_role as enum ('user', 'admin');

create type gender_type as enum ('male', 'female', 'unspecified');

create type skill_status as enum (
  'locked', 'available', 'active', 'completed', 'master', 'legendary'
);

create type objective_status as enum ('not_started', 'in_progress', 'completed');

create type objective_target_type as enum ('reps', 'hold_seconds', 'sets');

create type xp_source as enum (
  'roadmap_workout', 'objective_completion', 'personal_best',
  'weekly_challenge', 'skill_unlock'
);

create type pr_metric_type as enum ('max_weight', 'max_reps', 'max_hold_seconds');

create type friend_request_status as enum ('pending', 'accepted', 'rejected');

create type activity_type as enum (
  'skill_unlocked', 'skill_completed', 'workout_completed',
  'achievement_unlocked', 'personal_best'
);

create type notification_type as enum (
  'friend_request', 'friend_accepted', 'activity_comment', 'achievement_unlocked',
  'post_like', 'post_comment'
);

create type achievement_category as enum (
  'beginner', 'consistency', 'pull', 'push', 'core', 'legs', 'legendary', 'hidden'
);

create type challenge_status as enum ('in_progress', 'completed');

create type audit_action as enum ('insert', 'update', 'delete');


-- ============================================================================
-- 2. PROFILES  (extends auth.users — 1:1, PK = auth.users.id)
-- ============================================================================
create table public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  username       text not null unique,
  display_name   text,
  avatar_url     text,
  bio            text,
  height_cm      numeric(5,2),
  weight_kg      numeric(5,2),
  gender         gender_type not null default 'unspecified',
  birthday       date,
  role           user_role not null default 'user',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint username_format check (username ~ '^[a-z0-9_]{3,20}$')
);

create index idx_profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);
create index idx_profiles_deleted_at on public.profiles (deleted_at) where deleted_at is not null;

-- historical weight/height log (profile fields hold the "latest" values)
create table public.body_metrics_log (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  weight_kg   numeric(5,2),
  height_cm   numeric(5,2),
  logged_at   date not null default current_date,
  created_at  timestamptz not null default now(),
  constraint at_least_one_metric check (weight_kg is not null or height_cm is not null)
);
create index idx_body_metrics_user_date on public.body_metrics_log (user_id, logged_at desc);


-- ============================================================================
-- 3. EXERCISE LIBRARY  (global, admin-managed, shared by both systems)
-- ============================================================================
create table public.muscle_groups (
  id    smallint primary key generated always as identity,
  name  text not null unique
);

create table public.exercises (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  slug             text not null unique,
  description      text,
  is_hold_based    boolean not null default false,   -- true = timed hold (e.g. L-sit) vs reps
  equipment        text,
  video_url        text,
  image_url        text,
  created_by       uuid references public.profiles(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
create index idx_exercises_name_trgm on public.exercises using gin (name gin_trgm_ops);
create index idx_exercises_deleted_at on public.exercises (deleted_at) where deleted_at is not null;

create table public.exercise_muscle_groups (
  exercise_id      uuid not null references public.exercises(id) on delete cascade,
  muscle_group_id  smallint not null references public.muscle_groups(id) on delete cascade,
  primary key (exercise_id, muscle_group_id)
);


-- ============================================================================
-- 4. WORKOUT TRACKER  (independent secondary system — NO XP, NO roadmap link)
-- ============================================================================
create table public.workout_templates (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  category    text,                                   -- e.g. "Push Pull Legs", "Upper Lower"
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index idx_workout_templates_user on public.workout_templates (user_id) where deleted_at is null;

-- enforce "max 7 templates per user" (active, non-deleted)
create or replace function public.enforce_max_workout_templates()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.workout_templates
      where user_id = new.user_id and deleted_at is null) >= 7 then
    raise exception 'Maximum of 7 workout templates per user';
  end if;
  return new;
end;
$$;
create trigger trg_max_workout_templates
  before insert on public.workout_templates
  for each row execute function public.enforce_max_workout_templates();

create table public.workout_template_exercises (
  id                  uuid primary key default gen_random_uuid(),
  template_id         uuid not null references public.workout_templates(id) on delete cascade,
  exercise_id         uuid not null references public.exercises(id),
  order_index         smallint not null,
  target_sets         smallint,
  target_reps         smallint,
  target_hold_seconds smallint,
  notes               text,
  unique (template_id, order_index)
);

create table public.workout_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  template_id     uuid references public.workout_templates(id) on delete set null,
  started_at      timestamptz not null default now(),
  completed_at    timestamptz,
  duration_seconds int,
  notes           text,
  created_at      timestamptz not null default now()
);
create index idx_workout_logs_user_date on public.workout_logs (user_id, started_at desc);

create table public.workout_log_exercises (
  id              uuid primary key default gen_random_uuid(),
  workout_log_id  uuid not null references public.workout_logs(id) on delete cascade,
  exercise_id     uuid not null references public.exercises(id),
  order_index     smallint not null,
  notes           text
);

create table public.workout_log_sets (
  id                        uuid primary key default gen_random_uuid(),
  workout_log_exercise_id   uuid not null references public.workout_log_exercises(id) on delete cascade,
  set_number                smallint not null,
  reps                      smallint,
  weight_kg                 numeric(6,2),
  hold_seconds              smallint,
  completed                 boolean not null default true,
  created_at                timestamptz not null default now(),
  constraint reps_or_hold check (reps is not null or hold_seconds is not null)
);

-- gym-tracker personal records (fully separate from roadmap PRs, per decision)
create table public.personal_records (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  exercise_id   uuid not null references public.exercises(id),
  metric_type   pr_metric_type not null,
  value         numeric(8,2) not null,
  achieved_at   timestamptz not null default now(),
  set_id        uuid references public.workout_log_sets(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (user_id, exercise_id, metric_type)
);

create table public.personal_record_history (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  exercise_id   uuid not null references public.exercises(id),
  metric_type   pr_metric_type not null,
  value         numeric(8,2) not null,
  achieved_at   timestamptz not null default now()
);
create index idx_pr_history_user_exercise on public.personal_record_history (user_id, exercise_id, metric_type, achieved_at desc);


-- ============================================================================
-- 5. ROADMAP CORE  (skill graph — admin-managed content)
-- ============================================================================
create table public.roadmap_categories (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,      -- Pull / Push / Core / Legs
  slug         text not null unique,
  description  text,
  icon_url     text,
  sort_order   smallint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.skills (
  id                    uuid primary key default gen_random_uuid(),
  roadmap_category_id   uuid not null references public.roadmap_categories(id),
  name                  text not null,
  slug                  text not null unique,
  description           text,
  difficulty_level      smallint not null default 1 check (difficulty_level between 1 and 5),
  icon_url              text,
  video_url             text,
  sort_order            smallint not null default 0,
  is_active             boolean not null default true,
  content_version       int not null default 1,   -- bumped whenever admin edits requirements
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);
create index idx_skills_category on public.skills (roadmap_category_id) where deleted_at is null;

create table public.skill_prerequisites (
  skill_id               uuid not null references public.skills(id) on delete cascade,
  prerequisite_skill_id  uuid not null references public.skills(id) on delete cascade,
  primary key (skill_id, prerequisite_skill_id),
  constraint no_self_prerequisite check (skill_id <> prerequisite_skill_id)
);

create table public.skill_stages (
  id           uuid primary key default gen_random_uuid(),
  skill_id     uuid not null references public.skills(id) on delete cascade,
  stage_order  smallint not null,
  name         text not null,
  description  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (skill_id, stage_order)
);

-- skill-level milestones, distinct from any single workout's requirements
create table public.objectives (
  id               uuid primary key default gen_random_uuid(),
  skill_id         uuid not null references public.skills(id) on delete cascade,
  skill_stage_id   uuid references public.skill_stages(id) on delete set null,
  exercise_id      uuid references public.exercises(id),
  title            text not null,             -- "10 strict pull-ups"
  description      text,
  target_type      objective_target_type not null,
  target_value     numeric(8,2) not null,
  xp_reward        int not null default 0,
  sort_order       smallint not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
create index idx_objectives_skill on public.objectives (skill_id) where deleted_at is null;


-- ============================================================================
-- 6. ROADMAP WORKOUTS + LOGS  (fixed, coach-designed content + user activity)
-- ============================================================================
create table public.roadmap_workouts (
  id               uuid primary key default gen_random_uuid(),
  skill_id         uuid not null references public.skills(id) on delete cascade,
  skill_stage_id   uuid references public.skill_stages(id) on delete set null,
  name             text not null,             -- "Workout A"
  description      text,
  xp_reward        int not null default 0,
  sort_order       smallint not null default 0,
  content_version  int not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);
create index idx_roadmap_workouts_skill on public.roadmap_workouts (skill_id) where deleted_at is null;

create table public.roadmap_workout_exercises (
  id                    uuid primary key default gen_random_uuid(),
  roadmap_workout_id    uuid not null references public.roadmap_workouts(id) on delete cascade,
  exercise_id           uuid not null references public.exercises(id),
  order_index           smallint not null,
  required_sets         smallint,
  required_reps         smallint,
  required_hold_seconds smallint,
  notes                 text,
  unique (roadmap_workout_id, order_index)
);

-- one row per completed/in-progress attempt; snapshots the requirement at
-- completion time so later admin edits never corrupt historical logs
create table public.roadmap_workout_logs (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  roadmap_workout_id uuid not null references public.roadmap_workouts(id),
  skill_id           uuid not null references public.skills(id),
  workout_snapshot   jsonb not null,     -- copy of required exercises at log time
  completed          boolean not null default false,
  xp_awarded         int not null default 0,
  started_at         timestamptz not null default now(),
  completed_at       timestamptz,
  created_at         timestamptz not null default now()
);
create index idx_roadmap_workout_logs_user on public.roadmap_workout_logs (user_id, skill_id, started_at desc);

create table public.roadmap_workout_log_exercises (
  id                        uuid primary key default gen_random_uuid(),
  roadmap_workout_log_id    uuid not null references public.roadmap_workout_logs(id) on delete cascade,
  exercise_id               uuid not null references public.exercises(id),
  order_index               smallint not null,
  achieved_sets             smallint,
  achieved_reps             smallint,
  achieved_hold_seconds     smallint,
  met_requirement           boolean not null default false
);

-- objective progress, independent of any single workout
create table public.user_objective_progress (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  objective_id  uuid not null references public.objectives(id) on delete cascade,
  status        objective_status not null default 'not_started',
  best_value    numeric(8,2),
  completed_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, objective_id)
);
create index idx_user_objective_progress_user on public.user_objective_progress (user_id, status);

-- roadmap-specific personal bests (fully separate from gym-tracker PRs)
create table public.roadmap_personal_bests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  skill_id      uuid not null references public.skills(id),
  exercise_id   uuid not null references public.exercises(id),
  metric_type   pr_metric_type not null,
  value         numeric(8,2) not null,
  achieved_at   timestamptz not null default now(),
  log_exercise_id uuid references public.roadmap_workout_log_exercises(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (user_id, skill_id, exercise_id, metric_type)
);


-- ============================================================================
-- 7. SKILL PROGRESS  (ONE row per user per skill — no global XP table)
-- ============================================================================
create table public.skill_progress (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.profiles(id) on delete cascade,
  skill_id                 uuid not null references public.skills(id) on delete cascade,
  status                   skill_status not null default 'locked',
  current_xp               int not null default 0 check (current_xp >= 0),
  current_skill_stage_id   uuid references public.skill_stages(id) on delete set null,
  completion_percentage    numeric(5,2) not null default 0 check (completion_percentage between 0 and 100),
  unlocked_at              timestamptz,
  completed_at             timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (user_id, skill_id)
);
create index idx_skill_progress_user on public.skill_progress (user_id, status);

-- append-only XP ledger — the audit trail behind current_xp
create table public.xp_transactions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  skill_id        uuid not null references public.skills(id),
  amount          int not null,
  source          xp_source not null,
  reference_table text,
  reference_id    uuid,
  created_at      timestamptz not null default now()
);
create index idx_xp_transactions_user_skill on public.xp_transactions (user_id, skill_id, created_at desc);


-- ============================================================================
-- 8. WEEKLY CHALLENGES
-- ============================================================================
create table public.weekly_challenges (
  id            uuid primary key default gen_random_uuid(),
  skill_id      uuid references public.skills(id) on delete cascade,  -- null = roadmap-wide
  title         text not null,
  description   text,
  target_type   objective_target_type not null,
  target_value  numeric(8,2) not null,
  xp_reward     int not null default 0,
  week_start    date not null,
  week_end      date not null,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint valid_week check (week_end > week_start)
);
create index idx_weekly_challenges_active on public.weekly_challenges (week_start, week_end) where is_active;

create table public.user_weekly_challenge_progress (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  weekly_challenge_id   uuid not null references public.weekly_challenges(id) on delete cascade,
  progress_value        numeric(8,2) not null default 0,
  status                challenge_status not null default 'in_progress',
  completed_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (user_id, weekly_challenge_id)
);


-- ============================================================================
-- 9. ACHIEVEMENTS
-- ============================================================================
create table public.achievements (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text not null,
  category     achievement_category not null,
  icon_url     text,
  criteria     jsonb not null,     -- structured rule, evaluated by a generic RPC
  xp_reward    int,
  is_hidden    boolean not null default false,
  sort_order   smallint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create table public.user_achievements (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  achievement_id  uuid not null references public.achievements(id) on delete cascade,
  unlocked_at     timestamptz not null default now(),
  unique (user_id, achievement_id)
);
create index idx_user_achievements_user on public.user_achievements (user_id);


-- ============================================================================
-- 10. SOCIAL
-- ============================================================================
create table public.friendships (
  id             uuid primary key default gen_random_uuid(),
  requester_id   uuid not null references public.profiles(id) on delete cascade,
  addressee_id   uuid not null references public.profiles(id) on delete cascade,
  status         friend_request_status not null default 'pending',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (requester_id, addressee_id),
  constraint no_self_friend check (requester_id <> addressee_id)
);
create index idx_friendships_addressee on public.friendships (addressee_id, status);

create table public.blocks (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

-- Public photo feed — the primary social feature. Visible to all app users
-- (not friends-only), single photo per post.
create table public.posts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  image_url    text not null,
  caption      text,
  like_count   int not null default 0,      -- denormalized counter, kept in sync by trigger
  comment_count int not null default 0,     -- denormalized counter, kept in sync by trigger
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index idx_posts_feed on public.posts (created_at desc) where deleted_at is null;
create index idx_posts_user on public.posts (user_id, created_at desc) where deleted_at is null;

create table public.post_likes (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (post_id, user_id)
);

create table public.post_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  content     text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index idx_post_comments_post on public.post_comments (post_id, created_at);

create table public.activities (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  activity_type   activity_type not null,
  reference_table text,
  reference_id    uuid,
  metadata        jsonb,
  created_at      timestamptz not null default now()
);
create index idx_activities_user_date on public.activities (user_id, created_at desc);

create table public.activity_comments (
  id           uuid primary key default gen_random_uuid(),
  activity_id  uuid not null references public.activities(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  content      text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index idx_activity_comments_activity on public.activity_comments (activity_id, created_at);

create table public.notifications (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  type            notification_type not null,
  reference_table text,
  reference_id    uuid,
  message         text not null,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);
create index idx_notifications_user_unread on public.notifications (user_id, is_read, created_at desc);


-- ============================================================================
-- 11. ADMIN / AUDIT
-- ============================================================================
create table public.content_audit_log (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid not null references public.profiles(id),
  table_name  text not null,
  record_id   uuid not null,
  action      audit_action not null,
  old_data    jsonb,
  new_data    jsonb,
  created_at  timestamptz not null default now()
);
create index idx_content_audit_table_record on public.content_audit_log (table_name, record_id, created_at desc);
