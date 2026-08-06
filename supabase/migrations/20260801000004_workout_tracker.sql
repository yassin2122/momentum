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
