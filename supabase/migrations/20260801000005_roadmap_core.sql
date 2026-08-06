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
