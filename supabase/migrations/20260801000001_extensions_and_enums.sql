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


