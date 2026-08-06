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
