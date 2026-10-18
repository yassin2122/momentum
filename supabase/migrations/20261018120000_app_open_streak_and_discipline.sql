-- =====================================================================
-- Dashboard: app-open streak (3-day grace) + discipline score
-- =====================================================================
-- 1. user_activity_days — one row per day the user opened the app.
--    Client-read-only (tier 3): written only by record_app_open().
-- 2. bump_streak(user, day) — new rule: the streak grows by 1 on each new
--    active day; one or two missed days in a row keep it, the third
--    missed day in a row resets it (the next active day starts at 1).
-- 3. record_app_open(local_date) — the one entry point the client calls.
-- 4. Workout completion no longer drives the streak (trigger dropped).
-- 5. get_discipline_score(local_date) — 50% active days + 50% workouts
--    completed vs. plan, over the last 30 days (or since sign-up).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Activity days
-- ---------------------------------------------------------------------
create table public.user_activity_days (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  day        date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.user_activity_days enable row level security;
create policy "user_activity_days_owner_select" on public.user_activity_days
  for select using (user_id = (select auth.uid()));
-- writes only via record_app_open()

-- ---------------------------------------------------------------------
-- 2. Streak rule. The old one-argument version (any missed day resets,
--    server UTC date) is replaced; it was also executable by any role
--    with any user id, so the new one is locked down.
-- ---------------------------------------------------------------------
drop trigger if exists trg_workout_log_completed on public.workout_logs;
drop function if exists public.handle_workout_log_completed();
drop function if exists public.bump_streak(uuid);

create or replace function public.bump_streak(p_user_id uuid, p_day date)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_last    date;
  v_current int;
  v_longest int;
  v_gap     int;
begin
  select last_activity_date, current_streak, longest_streak
    into v_last, v_current, v_longest
  from user_streaks where user_id = p_user_id
  for update;

  if not found then
    insert into user_streaks (user_id, current_streak, longest_streak, last_activity_date)
    values (p_user_id, 1, 1, p_day)
    on conflict (user_id) do nothing;
    return;
  end if;

  if v_last is null then
    v_current := 1;
  else
    v_gap := p_day - v_last;
    if v_gap <= 0 then
      return;                       -- same day (or a clock that went back)
    elsif v_gap <= 3 then
      v_current := v_current + 1;   -- 0–2 missed days: streak survives
    else
      v_current := 1;               -- 3+ missed days in a row: lost
    end if;
  end if;

  update user_streaks
  set current_streak = v_current,
      longest_streak = greatest(v_longest, v_current),
      last_activity_date = p_day,
      updated_at = now()
  where user_id = p_user_id;
end;
$$;

revoke all on function public.bump_streak(uuid, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. record_app_open — called by the client when the app opens/resumes.
--    p_local_date is the device's calendar day, so the streak follows the
--    user's midnight rather than UTC. It is trusted only within one day
--    of the server's date (covers every time zone); anything else falls
--    back to the server date, so a wrong clock can't farm days.
--    Returns the streak as it stands after this open; a streak whose
--    grace has already run out reads 0 until the next open.
-- ---------------------------------------------------------------------
create or replace function public.record_app_open(p_local_date date default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_day  date := coalesce(p_local_date, current_date);
  v_row  user_streaks%rowtype;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if v_day < current_date - 1 or v_day > current_date + 1 then
    v_day := current_date;
  end if;

  insert into user_activity_days (user_id, day)
  values (v_user, v_day)
  on conflict do nothing;

  perform bump_streak(v_user, v_day);

  select * into v_row from user_streaks where user_id = v_user;

  return jsonb_build_object(
    'current_streak',     coalesce(v_row.current_streak, 0),
    'longest_streak',     coalesce(v_row.longest_streak, 0),
    'last_activity_date', v_row.last_activity_date,
    'local_date',         v_day
  );
end;
$$;

revoke all on function public.record_app_open(date) from public, anon;
grant execute on function public.record_app_open(date) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Discipline score (0–100), read-only, caller's own data only.
--    window      = last 30 days ending today, shortened to the days since
--                  sign-up so a new account isn't penalised.
--    active      = days with an app open in the window / window days.
--    plan        = each live template is one session per week, so the
--                  window plans  templates × window / 7  sessions.
--    workouts    = completed workout_logs in the window / planned (cap 1).
--    score       = round(100 × (0.5 × active + 0.5 × workouts)).
--    With no templates (plan is null) the score is the active part alone.
-- ---------------------------------------------------------------------
create or replace function public.get_discipline_score(p_local_date date default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user      uuid := auth.uid();
  v_day       date := coalesce(p_local_date, current_date);
  v_joined    date;
  v_window    int;
  v_from      date;
  v_active    int;
  v_done      int;
  v_templates int;
  v_planned   numeric;
  v_active_r  numeric;
  v_work_r    numeric;
  v_score     int;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if v_day < current_date - 1 or v_day > current_date + 1 then
    v_day := current_date;
  end if;

  select created_at::date into v_joined from profiles where id = v_user;
  v_window := greatest(1, least(30, v_day - coalesce(v_joined, v_day - 29) + 1));
  v_from := v_day - v_window + 1;

  select count(*) into v_active
  from user_activity_days
  where user_id = v_user and day between v_from and v_day;

  select count(*) into v_done
  from workout_logs
  where user_id = v_user
    and status = 'completed'
    and completed_at is not null
    and completed_at >= v_from::timestamptz
    and completed_at <  (v_day + 2)::timestamptz;   -- +1 day of zone slack

  select count(*) into v_templates
  from workout_templates
  where user_id = v_user and deleted_at is null;

  v_active_r := least(1, v_active::numeric / v_window);

  if v_templates > 0 then
    v_planned := v_templates * v_window / 7.0;
    v_work_r  := least(1, v_done / v_planned);
    v_score   := round(100 * (0.5 * v_active_r + 0.5 * v_work_r));
  else
    v_planned := null;
    v_work_r  := null;
    v_score   := round(100 * v_active_r);
  end if;

  return jsonb_build_object(
    'score',              v_score,
    'window_days',        v_window,
    'active_days',        v_active,
    'completed_workouts', v_done,
    'templates',          v_templates,
    'planned_workouts',   v_planned,
    'active_ratio',       v_active_r,
    'workout_ratio',      v_work_r
  );
end;
$$;

revoke all on function public.get_discipline_score(date) from public, anon;
grant execute on function public.get_discipline_score(date) to authenticated;
