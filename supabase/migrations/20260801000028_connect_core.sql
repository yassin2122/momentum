-- Connect (coaching) — core tables, helpers, RLS.
-- Writes to relationships/permissions/assignments go through RPCs (file 30).
begin;

create type coach_status      as enum ('pending', 'approved', 'suspended');
create type coaching_status   as enum ('pending', 'active', 'ended', 'declined');
create type assignment_status as enum ('assigned', 'in_progress', 'completed', 'cancelled');

-- ---------------------------------------------------------------- tables
create table public.coach_profiles (
  id                uuid primary key references public.profiles(id) on delete cascade,
  headline          text,
  bio               text,
  approach          text,
  specialties       text[] not null default '{}',
  certifications    text[] not null default '{}',
  experience_years  smallint check (experience_years >= 0),
  max_athletes      smallint check (max_athletes > 0),
  accepting_athletes boolean not null default true,
  status            coach_status not null default 'pending',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_coach_profiles_status on public.coach_profiles (status) where status = 'approved';

create table public.coaching_plans (
  id            uuid primary key default gen_random_uuid(),
  coach_id      uuid not null references public.coach_profiles(id) on delete cascade,
  name          text not null,
  description   text,
  duration_days smallint,
  price_cents   int check (price_cents >= 0),   -- display only; no payments yet
  currency      char(3) not null default 'USD',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
create index idx_coaching_plans_coach on public.coaching_plans (coach_id);

create table public.coaching_relationships (
  id            uuid primary key default gen_random_uuid(),
  athlete_id    uuid not null references public.profiles(id) on delete cascade,
  coach_id      uuid not null references public.coach_profiles(id) on delete cascade,
  plan_id       uuid references public.coaching_plans(id) on delete set null,
  status        coaching_status not null default 'pending',
  requested_at  timestamptz not null default now(),
  started_at    timestamptz,
  ended_at      timestamptz,
  ended_by      uuid references public.profiles(id) on delete set null,
  constraint no_self_coaching check (athlete_id <> coach_id)
);
-- MVP rule: one open Captain (pending or active) per athlete
create unique index uq_one_open_captain on public.coaching_relationships (athlete_id)
  where status in ('pending', 'active');
create index idx_coaching_rel_coach on public.coaching_relationships (coach_id, status);
create index idx_coaching_rel_plan  on public.coaching_relationships (plan_id);

-- what the athlete allows the Captain to see (explicit, revocable)
create table public.coaching_permissions (
  relationship_id      uuid primary key references public.coaching_relationships(id) on delete cascade,
  share_workouts       boolean not null default true,   -- logs, exercises, sets, streaks
  share_prs            boolean not null default true,
  share_skill_progress boolean not null default true,   -- roadmap, XP, achievements
  share_body_metrics   boolean not null default false,
  updated_at           timestamptz not null default now()
);

create table public.coaching_goals (
  id              uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.coaching_relationships(id) on delete cascade,
  title           text not null,
  description     text,
  target_date     date,
  status          text not null default 'active' check (status in ('active', 'achieved', 'dropped')),
  created_by      uuid not null references public.profiles(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_coaching_goals_rel on public.coaching_goals (relationship_id);
create index idx_coaching_goals_creator on public.coaching_goals (created_by);

-- append-only: no update/delete policies
create table public.coaching_feedback (
  id              uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.coaching_relationships(id) on delete cascade,
  author_id       uuid not null references public.profiles(id),
  workout_log_id  uuid references public.workout_logs(id) on delete set null,
  skill_id        uuid references public.skills(id) on delete set null,
  body            text not null check (length(body) > 0),
  created_at      timestamptz not null default now()
);
create index idx_coaching_feedback_rel on public.coaching_feedback (relationship_id, created_at desc);
create index idx_coaching_feedback_author on public.coaching_feedback (author_id);
create index idx_coaching_feedback_log on public.coaching_feedback (workout_log_id);
create index idx_coaching_feedback_skill on public.coaching_feedback (skill_id);

-- coach-only; the athlete can never read these
create table public.coaching_private_notes (
  id              uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.coaching_relationships(id) on delete cascade,
  coach_id        uuid not null references public.profiles(id),
  body            text not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_coaching_notes_rel on public.coaching_private_notes (relationship_id);
create index idx_coaching_notes_coach on public.coaching_private_notes (coach_id);

-- coach assigns a program (reuses programs/program_days/program_day_exercises)
create table public.program_assignments (
  id              uuid primary key default gen_random_uuid(),
  relationship_id uuid not null references public.coaching_relationships(id) on delete cascade,
  program_id      uuid not null references public.programs(id),
  assigned_by     uuid not null references public.profiles(id),
  instructions    text,
  start_date      date not null default current_date,
  status          assignment_status not null default 'assigned',
  enrollment_id   uuid references public.user_program_enrollment(id) on delete set null,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);
create index idx_program_assign_rel on public.program_assignments (relationship_id, status);
create index idx_program_assign_program on public.program_assignments (program_id);
create index idx_program_assign_by on public.program_assignments (assigned_by);
create index idx_program_assign_enroll on public.program_assignments (enrollment_id);

-- ---------------------------------------------------------------- helpers
create or replace function public.is_coach()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coach_profiles where id = auth.uid() and status = 'approved');
$$;

create or replace function public.in_relationship(p_rel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coaching_relationships
                 where id = p_rel and (athlete_id = auth.uid() or coach_id = auth.uid()));
$$;

create or replace function public.is_active_coach_of(p_rel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.coaching_relationships
                 where id = p_rel and coach_id = auth.uid() and status = 'active');
$$;

-- scope: 'workouts' | 'prs' | 'progress' | 'body'
create or replace function public.coach_can_view(p_athlete uuid, p_scope text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.coaching_relationships r
    join public.coaching_permissions p on p.relationship_id = r.id
    where r.athlete_id = p_athlete and r.coach_id = auth.uid() and r.status = 'active'
      and case p_scope
            when 'workouts' then p.share_workouts
            when 'prs'      then p.share_prs
            when 'progress' then p.share_skill_progress
            when 'body'     then p.share_body_metrics
            else false end
  );
$$;

-- non-admins cannot approve themselves
create or replace function public.guard_coach_status()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status and not public.is_admin() then
    raise exception 'Only an admin can change coach status';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger trg_coach_profiles_guard before update on public.coach_profiles
  for each row execute function public.guard_coach_status();
create trigger trg_perm_updated before update on public.coaching_permissions
  for each row execute function public.set_updated_at();
create trigger trg_goals_updated before update on public.coaching_goals
  for each row execute function public.set_updated_at();
create trigger trg_notes_updated before update on public.coaching_private_notes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- RLS
alter table public.coach_profiles          enable row level security;
alter table public.coaching_plans          enable row level security;
alter table public.coaching_relationships  enable row level security;
alter table public.coaching_permissions    enable row level security;
alter table public.coaching_goals          enable row level security;
alter table public.coaching_feedback       enable row level security;
alter table public.coaching_private_notes  enable row level security;
alter table public.program_assignments     enable row level security;

create policy "coach_profiles_select" on public.coach_profiles for select
  using (status = 'approved' or id = auth.uid() or public.is_admin());
create policy "coach_profiles_insert_own" on public.coach_profiles for insert
  with check (id = auth.uid() and status = 'pending');
create policy "coach_profiles_update_own" on public.coach_profiles for update
  using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());

create policy "coaching_plans_select" on public.coaching_plans for select
  using (deleted_at is null and (is_active or coach_id = auth.uid()));
create policy "coaching_plans_coach_write" on public.coaching_plans for all
  using (coach_id = auth.uid()) with check (coach_id = auth.uid() and public.is_coach());

create policy "coaching_rel_select" on public.coaching_relationships for select
  using (athlete_id = auth.uid() or coach_id = auth.uid() or public.is_admin());
-- no insert/update/delete policies: RPCs only

create policy "coaching_perm_select" on public.coaching_permissions for select
  using (public.in_relationship(relationship_id));
create policy "coaching_perm_athlete_update" on public.coaching_permissions for update
  using (exists (select 1 from public.coaching_relationships r
                 where r.id = relationship_id and r.athlete_id = auth.uid()));

create policy "coaching_goals_select" on public.coaching_goals for select
  using (public.in_relationship(relationship_id));
create policy "coaching_goals_coach_insert" on public.coaching_goals for insert
  with check (created_by = auth.uid() and public.is_active_coach_of(relationship_id));
create policy "coaching_goals_coach_update" on public.coaching_goals for update
  using (public.is_active_coach_of(relationship_id));

create policy "coaching_feedback_select" on public.coaching_feedback for select
  using (public.in_relationship(relationship_id));
create policy "coaching_feedback_insert" on public.coaching_feedback for insert
  with check (author_id = auth.uid() and public.in_relationship(relationship_id)
              and exists (select 1 from public.coaching_relationships r
                          where r.id = relationship_id and r.status = 'active'));

create policy "coaching_notes_coach_all" on public.coaching_private_notes for all
  using (coach_id = auth.uid() and public.in_relationship(relationship_id))
  with check (coach_id = auth.uid() and public.is_active_coach_of(relationship_id));

create policy "program_assign_select" on public.program_assignments for select
  using (public.in_relationship(relationship_id));
-- no write policies: assign_program() / start_assigned_program() RPCs only

commit;
