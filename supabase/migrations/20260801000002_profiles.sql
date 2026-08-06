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
