-- Grit v1.1 patch — Connect pillar additions
-- Resolves the activity-feed conflict from PRODUCT.md: the auto-generated
-- feed (workouts, PRs, unlocks, achievements, streaks) and user photo posts
-- BOTH ship in v1, side by side. This file wires the feed events that were
-- previously left dormant.

-- ----------------------------------------------------------------------------
-- 1. Peer-to-peer friend challenges (distinct from admin-authored weekly_challenges)
-- ----------------------------------------------------------------------------
create table public.user_challenges (
  id                 uuid primary key default gen_random_uuid(),
  creator_id         uuid not null references public.profiles(id) on delete cascade,
  title              text not null,
  metric_type        text not null,   -- e.g. 'most_workouts','most_pull_ups','longest_streak','most_xp'
  target_exercise_id uuid references public.exercises(id),  -- only used for exercise-specific metrics
  starts_at          date not null,
  ends_at            date not null,
  created_at         timestamptz not null default now(),
  constraint valid_challenge_window check (ends_at > starts_at)
);

create table public.user_challenge_participants (
  id              uuid primary key default gen_random_uuid(),
  challenge_id    uuid not null references public.user_challenges(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  progress_value  numeric(10,2) not null default 0,
  joined_at       timestamptz not null default now(),
  unique (challenge_id, user_id)
);

alter table public.user_challenges enable row level security;
alter table public.user_challenge_participants enable row level security;

create policy "user_challenges_visible" on public.user_challenges for select
  using (
    creator_id = auth.uid()
    or exists (select 1 from public.user_challenge_participants p
               where p.challenge_id = id and p.user_id = auth.uid())
    or public.are_friends(auth.uid(), creator_id)
  );
create policy "user_challenges_creator_insert" on public.user_challenges for insert
  with check (creator_id = auth.uid());

create policy "user_challenge_participants_visible" on public.user_challenge_participants for select
  using (
    user_id = auth.uid()
    or exists (select 1 from public.user_challenges c where c.id = challenge_id and c.creator_id = auth.uid())
    or exists (select 1 from public.user_challenges c where c.id = challenge_id
               and public.are_friends(auth.uid(), c.creator_id))
  );
create policy "user_challenge_participants_self_insert" on public.user_challenge_participants for insert
  with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. Leaderboards — implemented as SECURITY DEFINER RPCs, not views, because
--    xp_transactions RLS is owner-only; a plain view would just re-apply that
--    RLS per caller and only ever show their own row. These RPCs deliberately
--    expose only user_id/username/total_xp (no other columns) across users.
-- ----------------------------------------------------------------------------
create or replace function public.get_global_xp_leaderboard(p_limit int default 50)
returns table(user_id uuid, username text, total_xp bigint)
language sql stable security definer as $$
  select x.user_id, p.username, sum(x.amount)::bigint as total_xp
  from public.xp_transactions x
  join public.profiles p on p.id = x.user_id and p.deleted_at is null
  group by x.user_id, p.username
  order by total_xp desc
  limit p_limit;
$$;

create or replace function public.get_friends_xp_leaderboard(p_limit int default 50)
returns table(user_id uuid, username text, total_xp bigint)
language sql stable security definer as $$
  select x.user_id, p.username, sum(x.amount)::bigint as total_xp
  from public.xp_transactions x
  join public.profiles p on p.id = x.user_id and p.deleted_at is null
  where x.user_id = auth.uid() or public.are_friends(auth.uid(), x.user_id)
  group by x.user_id, p.username
  order by total_xp desc
  limit p_limit;
$$;

-- ----------------------------------------------------------------------------
-- 3. Activity-feed wiring — achievements, gym-tracker PRs, roadmap PRs
--    (roadmap workout_completed and roadmap skill events already write to
--    `activities` via complete_roadmap_workout(); gym-tracker workout_completed
--    was just wired in the Train-pillar migration via handle_workout_log_completed())
-- ----------------------------------------------------------------------------
create or replace function public.handle_achievement_unlocked()
returns trigger language plpgsql security definer as $$
begin
  insert into public.activities (user_id, activity_type, reference_table, reference_id)
  values (new.user_id, 'achievement_unlocked', 'user_achievements', new.id);
  return new;
end;
$$;
create trigger trg_achievement_unlocked after insert on public.user_achievements
  for each row execute function public.handle_achievement_unlocked();

-- extend the existing gym-tracker PR trigger to also post to the feed when a
-- record is actually bested (mirrors the `found` check already in that function)
create or replace function public.check_and_update_personal_record()
returns trigger language plpgsql security definer as $$
declare
  v_user_id uuid;
  v_exercise_id uuid;
  v_metric pr_metric_type;
  v_value numeric;
begin
  select w.user_id, wle.exercise_id into v_user_id, v_exercise_id
  from public.workout_log_exercises wle
  join public.workout_logs w on w.id = wle.workout_log_id
  where wle.id = new.workout_log_exercise_id;

  if new.weight_kg is not null then
    v_metric := 'max_weight'; v_value := new.weight_kg;
  elsif new.hold_seconds is not null then
    v_metric := 'max_hold_seconds'; v_value := new.hold_seconds;
  elsif new.reps is not null then
    v_metric := 'max_reps'; v_value := new.reps;
  else
    return new;
  end if;

  insert into public.personal_records (user_id, exercise_id, metric_type, value, achieved_at, set_id)
  values (v_user_id, v_exercise_id, v_metric, v_value, now(), new.id)
  on conflict (user_id, exercise_id, metric_type)
  do update set value = excluded.value, achieved_at = excluded.achieved_at, set_id = excluded.set_id
  where excluded.value > public.personal_records.value;

  if found then
    insert into public.personal_record_history (user_id, exercise_id, metric_type, value, achieved_at)
    values (v_user_id, v_exercise_id, v_metric, v_value, now());

    insert into public.activities (user_id, activity_type, reference_table, reference_id)
    values (v_user_id, 'personal_best', 'personal_records', new.id);
  end if;

  return new;
end;
$$;
-- trigger already exists from the base migration (trg_check_pr) and points at
-- this function name, so replacing the function body is sufficient — no need
-- to re-create the trigger itself.

-- roadmap-specific PR upsert + feed post (no writer existed for
-- roadmap_personal_bests before this patch)
create or replace function public.record_roadmap_personal_best(
  p_skill_id uuid, p_exercise_id uuid, p_metric_type pr_metric_type,
  p_value numeric, p_log_exercise_id uuid default null
) returns void language plpgsql security definer as $$
begin
  insert into public.roadmap_personal_bests
    (user_id, skill_id, exercise_id, metric_type, value, achieved_at, log_exercise_id)
  values (auth.uid(), p_skill_id, p_exercise_id, p_metric_type, p_value, now(), p_log_exercise_id)
  on conflict (user_id, skill_id, exercise_id, metric_type)
  do update set value = excluded.value, achieved_at = excluded.achieved_at,
                log_exercise_id = excluded.log_exercise_id
  where excluded.value > public.roadmap_personal_bests.value;

  if found then
    insert into public.activities (user_id, activity_type, reference_table, reference_id)
    values (auth.uid(), 'personal_best', 'roadmap_personal_bests',
            (select id from public.roadmap_personal_bests
             where user_id = auth.uid() and skill_id = p_skill_id
               and exercise_id = p_exercise_id and metric_type = p_metric_type));
  end if;
end;
$$;

-- NOTE — not built here: skill_unlocked / skill_completed activity events
-- depend on the node-completion state machine flagged as a follow-up in the
-- Progress-pillar migration (0019). Wire those in once that logic exists.
