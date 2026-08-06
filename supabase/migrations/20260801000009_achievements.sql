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
