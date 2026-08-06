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
