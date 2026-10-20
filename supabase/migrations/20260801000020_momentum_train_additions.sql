-- Grit v1.1 patch — Train pillar additions

-- ----------------------------------------------------------------------------
-- 1. Programs (PPL, Upper/Lower, Full Body, Beginner plans, etc.)
-- ----------------------------------------------------------------------------
create table public.programs (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  category       text,             -- "Push Pull Legs", "Upper Lower", "Bodybuilding", ...
  description    text,
  duration_weeks smallint,
  days_per_week  smallint,
  is_official    boolean not null default true,   -- admin-authored; user-created programs are v1.2
  created_by     uuid references public.profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create table public.program_days (
  id           uuid primary key default gen_random_uuid(),
  program_id   uuid not null references public.programs(id) on delete cascade,
  day_order    smallint not null,
  name         text not null,       -- "Push Day"
  is_rest_day  boolean not null default false,
  unique (program_id, day_order)
);

create table public.program_day_exercises (
  id                    uuid primary key default gen_random_uuid(),
  program_day_id        uuid not null references public.program_days(id) on delete cascade,
  exercise_id           uuid not null references public.exercises(id),
  order_index           smallint not null,
  group_key             smallint,     -- shared group_key = superset/circuit
  is_warmup             boolean not null default false,
  target_sets           smallint,
  target_reps           smallint,
  target_hold_seconds   smallint,
  notes                 text
);

create table public.user_program_enrollment (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  program_id     uuid not null references public.programs(id),
  current_day_id uuid references public.program_days(id),
  started_at     timestamptz not null default now(),
  completed_at   timestamptz,
  is_active      boolean not null default true
);
create index idx_user_program_enrollment_active on public.user_program_enrollment (user_id) where is_active;

alter table public.programs enable row level security;
alter table public.program_days enable row level security;
alter table public.program_day_exercises enable row level security;
alter table public.user_program_enrollment enable row level security;

create policy "programs_select_all" on public.programs for select using (deleted_at is null);
create policy "programs_admin_write" on public.programs for all
  using (public.is_admin()) with check (public.is_admin());

create policy "program_days_select_all" on public.program_days for select using (true);
create policy "program_days_admin_write" on public.program_days for all
  using (public.is_admin()) with check (public.is_admin());

create policy "program_day_exercises_select_all" on public.program_day_exercises for select using (true);
create policy "program_day_exercises_admin_write" on public.program_day_exercises for all
  using (public.is_admin()) with check (public.is_admin());

create policy "user_program_enrollment_owner_all" on public.user_program_enrollment for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. Supersets / circuits / warmups on the tracker's own templates + logs
-- ----------------------------------------------------------------------------
alter table public.workout_template_exercises add column if not exists group_key smallint;
alter table public.workout_template_exercises add column if not exists is_warmup boolean not null default false;
alter table public.workout_log_exercises add column if not exists group_key smallint;
alter table public.workout_log_exercises add column if not exists is_warmup boolean not null default false;

-- ----------------------------------------------------------------------------
-- 3. Streaks
-- ----------------------------------------------------------------------------
create table public.user_streaks (
  user_id           uuid primary key references public.profiles(id) on delete cascade,
  current_streak    int not null default 0,
  longest_streak    int not null default 0,
  last_activity_date date,
  updated_at        timestamptz not null default now()
);
alter table public.user_streaks enable row level security;
create policy "user_streaks_owner_select" on public.user_streaks for select using (user_id = auth.uid());
-- writes only via bump_streak() below

create or replace function public.bump_streak(p_user_id uuid)
returns void language plpgsql security definer as $$
declare
  v_last date;
  v_current int;
  v_longest int;
begin
  select last_activity_date, current_streak, longest_streak
    into v_last, v_current, v_longest
  from public.user_streaks where user_id = p_user_id;

  if v_last is null then
    insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_date)
    values (p_user_id, 1, 1, current_date)
    on conflict (user_id) do nothing;
    return;
  end if;

  if v_last = current_date then
    return; -- already logged today, no change
  elsif v_last = current_date - 1 then
    v_current := v_current + 1;
  else
    v_current := 1; -- streak broken
  end if;

  v_longest := greatest(v_longest, v_current);

  update public.user_streaks
  set current_streak = v_current, longest_streak = v_longest,
      last_activity_date = current_date, updated_at = now()
  where user_id = p_user_id;

  if v_current in (7, 30, 100, 365) then
    insert into public.activities (user_id, activity_type, reference_table, reference_id, metadata)
    values (p_user_id, 'streak_milestone', 'user_streaks', p_user_id, jsonb_build_object('days', v_current));
  end if;
end;
$$;

-- call bump_streak() whenever a gym-tracker session or roadmap workout completes
create or replace function public.handle_workout_log_completed()
returns trigger language plpgsql security definer as $$
begin
  if new.completed_at is not null and (old.completed_at is null) then
    perform public.bump_streak(new.user_id);
    insert into public.activities (user_id, activity_type, reference_table, reference_id)
    values (new.user_id, 'workout_completed', 'workout_logs', new.id);
  end if;
  return new;
end;
$$;
create trigger trg_workout_log_completed after update on public.workout_logs
  for each row execute function public.handle_workout_log_completed();

-- ----------------------------------------------------------------------------
-- 4. Session-level aggregate records (volume, total reps, longest workout —
--    these are NOT exercise-specific, so they don't belong in personal_records)
-- ----------------------------------------------------------------------------
create type aggregate_metric_type as enum (
  'longest_workout_seconds', 'best_week_volume_kg', 'total_lifetime_volume_kg'
);

create table public.user_aggregate_records (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  metric_type  aggregate_metric_type not null,
  value        numeric(14,2) not null,
  achieved_at  timestamptz not null default now(),
  unique (user_id, metric_type)
);
alter table public.user_aggregate_records enable row level security;
create policy "user_aggregate_records_owner_select" on public.user_aggregate_records for select
  using (user_id = auth.uid());
-- NOTE: no writer function built yet — needs a decision on the volume/1RM
-- formula (Epley vs. Brzycki) before implementing; flagging rather than guessing.
