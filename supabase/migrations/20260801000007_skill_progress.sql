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
