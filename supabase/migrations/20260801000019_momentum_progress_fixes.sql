-- Grit v1.1 patch — Progress pillar fixes
-- Resolves: (1) skill_progress had no per-node XP, but PRODUCT.md shows every
-- roadmap node with its own XP bar ("High Pull-Up — 680/800 XP"); (2) skill
-- prerequisites had no certification-level requirement ("locked until
-- prerequisite Planet reaches the required certification level"); (3) Hidden
-- Elite Challenges need a way to be flagged and gated behind Legendary.

-- ----------------------------------------------------------------------------
-- 1. Certification-level prerequisites
-- ----------------------------------------------------------------------------
alter table public.skill_prerequisites
  add column if not exists required_status skill_status not null default 'completed';
-- e.g. Front Lever -> Back Lever might require only 'completed' on Front Lever,
-- while an elite challenge might require 'legendary' on its parent skill.

-- ----------------------------------------------------------------------------
-- 2. Hidden Elite Challenges
-- ----------------------------------------------------------------------------
alter table public.skills
  add column if not exists is_elite_challenge boolean not null default false;
-- An elite-challenge skill (Victorian, Maltese, etc.) is just a normal `skills`
-- row with is_elite_challenge = true and a skill_prerequisites row pointing at
-- its parent skill with required_status = 'legendary'. No new table needed —
-- the existing graph already expresses this once the two columns above exist.

-- ----------------------------------------------------------------------------
-- 3. Per-node (skill_stage) XP target, admin-authored
-- ----------------------------------------------------------------------------
alter table public.skill_stages
  add column if not exists xp_target int not null default 0;

-- ----------------------------------------------------------------------------
-- 4. Per-user, per-node progress (the actual missing table)
-- ----------------------------------------------------------------------------
create table public.user_skill_stage_progress (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  skill_stage_id  uuid not null references public.skill_stages(id) on delete cascade,
  status          skill_status not null default 'locked',
  current_xp      int not null default 0 check (current_xp >= 0),
  unlocked_at     timestamptz,
  completed_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, skill_stage_id)
);
create index idx_user_skill_stage_progress_user on public.user_skill_stage_progress (user_id, status);

alter table public.user_skill_stage_progress enable row level security;
create policy "user_skill_stage_progress_owner_select" on public.user_skill_stage_progress for select
  using (user_id = auth.uid());
-- deliberately no client insert/update — mutated only via award_stage_xp() below

create trigger trg_user_skill_stage_progress_updated_at before update on public.user_skill_stage_progress
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 5. RPC: award XP at the node level, roll up into skill_progress
-- ----------------------------------------------------------------------------
create or replace function public.award_stage_xp(
  p_user_id uuid, p_skill_stage_id uuid, p_amount int,
  p_source xp_source, p_reference_table text default null, p_reference_id uuid default null
) returns void language plpgsql security definer as $$
declare
  v_skill_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'XP amount must be positive';
  end if;

  select skill_id into v_skill_id from public.skill_stages where id = p_skill_stage_id;
  if v_skill_id is null then
    raise exception 'Unknown skill_stage_id';
  end if;

  insert into public.user_skill_stage_progress (user_id, skill_stage_id, current_xp, status, unlocked_at)
  values (p_user_id, p_skill_stage_id, p_amount, 'active', now())
  on conflict (user_id, skill_stage_id)
  do update set current_xp = public.user_skill_stage_progress.current_xp + p_amount,
                status = case when public.user_skill_stage_progress.status = 'locked'
                              then 'active' else public.user_skill_stage_progress.status end;

  -- also record on the skill-level ledger/rollup so existing skill_progress.current_xp
  -- and the roadmap-wide XP total stay accurate
  perform public.award_xp(p_user_id, v_skill_id, p_amount, p_source, p_reference_table, p_reference_id);
end;
$$;

-- NOTE — follow-up not built here: the full node-completion state machine
-- (objectives all satisfied -> mark node 'completed' -> unlock next node ->
-- eventually mark the whole skill 'completed'/'master'/'legendary' per the
-- three certification tiers) needs its own RPC once you finalize exactly what
-- "5 consecutive clean reps" (Master) and "strict form standards" (Legendary)
-- translate to as stored, checkable criteria. The tables above are ready for
-- it; the evaluation logic is intentionally not guessed at here.
