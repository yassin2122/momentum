-- =====================================================================
-- CONNECT: Captain Hub — invitations, hub summary, listing toggle, fixes
--
-- Adds what the Captain Hub spec needs on top of migrations 28–32:
--   1. coach_profiles.is_listed  — a Captain can hide from the directory
--      and still coach the athletes they invite.
--   2. coaching_plans.currency defaults to EGP (Egypt-only launch).
--   3. coaching_relationships.source / invitation_id — how it started.
--   4. coaching_invitations + create / revoke / preview / accept RPCs.
--      Codes are single-use, expire, and only their SHA-256 is stored.
--   5. get_coach_card(coach)       — one Captain's public card, listed or not.
--   6. get_captain_hub()           — everything the Captain Hub screen shows.
--   7. get_client_workouts(athlete) — workout summaries, gated by
--      coach_can_view(athlete, 'workouts').
--   Fixes:
--   8. respond_to_coaching_request re-checks capacity on accept (it was only
--      checked when the request was made) and requires an approved Captain.
--   9. Suspension cuts access immediately: is_active_coach_of() and
--      coach_can_view() now also require coach_profiles.status = 'approved'.
--  10. A suspended Captain can no longer post feedback.
--  11. Invite acceptance notifies the Captain (not the athlete).
--  12. Approving a Captain from the Supabase dashboard works (the status
--      guard used to block it, since the dashboard has no signed-in user).
--
-- Coaches still get no write policy on any athlete table. All lifecycle
-- changes stay RPC-only.
-- =====================================================================
begin;

-- ---------------------------------------------------------------- 1–3
alter table public.coach_profiles
  add column is_listed boolean not null default true;

alter table public.coaching_plans
  alter column currency set default 'EGP';

alter table public.coaching_relationships
  add column source text not null default 'directory'
    check (source in ('directory', 'invite')),
  add column invitation_id uuid;

-- ---------------------------------------------------------------- 4. table
create table public.coaching_invitations (
  id           uuid primary key default gen_random_uuid(),
  coach_id     uuid not null references public.coach_profiles(id) on delete cascade,
  code_hash    text not null unique,            -- sha256(normalized code), hex
  code_hint    text not null,                   -- last 4 chars, for the Captain's list
  note         text check (note is null or length(note) <= 80),
  expires_at   timestamptz not null,
  accepted_by  uuid references public.profiles(id) on delete set null,
  accepted_at  timestamptz,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now(),
  constraint invite_closed_once check (accepted_at is null or revoked_at is null)
);
create index idx_coaching_invites_coach on public.coaching_invitations (coach_id, created_at desc);
create index idx_coaching_invites_accepted_by on public.coaching_invitations (accepted_by);

alter table public.coaching_relationships
  add constraint coaching_relationships_invitation_fk
  foreign key (invitation_id) references public.coaching_invitations(id) on delete set null;
create index idx_coaching_rel_invitation on public.coaching_relationships (invitation_id);

alter table public.coaching_invitations enable row level security;
-- The Captain sees their own invites. No write policies: RPCs only.
-- Athletes never read this table; they go through preview/accept by code.
create policy "coach_read_coaching_invitations" on public.coaching_invitations for select
  using (coach_id = auth.uid());

-- normalize: upper-case, keep only A–Z / 0–9 (so "abcde-fghij" == "ABCDEFGHIJ")
create or replace function public.invite_code_hash(p_code text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select encode(sha256(convert_to(regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g'), 'UTF8')), 'hex');
$$;

-- ---------------------------------------------------------------- 4. RPCs
-- Captain: new single-use code. The plain code is returned only here.
create or replace function public.create_coaching_invitation(
  p_note text default null, p_valid_days int default 7
) returns table(invitation_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  -- no 0/O/1/I/L, so a code read aloud or typed by hand is unambiguous
  c_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  -- uuid v4 bytes that carry no fixed version/variant bits
  c_byte_idx constant int[] := array[0, 1, 2, 3, 4, 5, 9, 10, 11, 12];
  v_raw    text;
  v_bytes  bytea;
  v_exp    timestamptz;
  v_id     uuid;
  i        int;
begin
  if not public.is_coach() then
    raise exception 'Only an approved Captain can create invites';
  end if;
  if p_valid_days is null or p_valid_days not between 1 and 30 then
    raise exception 'An invite can be valid for 1 to 30 days';
  end if;
  if (select count(*) from coaching_invitations ci
      where ci.coach_id = auth.uid() and ci.accepted_at is null
        and ci.revoked_at is null and ci.expires_at > now()) >= 20 then
    raise exception 'You have 20 open invites. Revoke one before creating another';
  end if;

  v_exp := now() + make_interval(days => p_valid_days);
  loop
    v_raw := '';
    v_bytes := uuid_send(gen_random_uuid());
    foreach i in array c_byte_idx loop
      v_raw := v_raw || substr(c_alphabet, (get_byte(v_bytes, i) % length(c_alphabet)) + 1, 1);
    end loop;
    begin
      insert into coaching_invitations (coach_id, code_hash, code_hint, note, expires_at)
      values (auth.uid(), public.invite_code_hash(v_raw), right(v_raw, 4),
              nullif(btrim(p_note), ''), v_exp)
      returning id into v_id;
      exit;
    exception when unique_violation then
      -- astronomically rare hash collision: draw a new code
    end;
  end loop;

  return query select v_id, substr(v_raw, 1, 5) || '-' || substr(v_raw, 6, 5), v_exp;
end;
$$;

create or replace function public.revoke_coaching_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update coaching_invitations set revoked_at = now()
  where id = p_invitation_id and coach_id = auth.uid()
    and accepted_at is null and revoked_at is null;
  if not found then raise exception 'Invite not found or already closed'; end if;
end;
$$;

-- Athlete: who sent this code? Public card fields only; same error for
-- unknown / expired / used / revoked so codes can't be probed for state.
create or replace function public.preview_coaching_invitation(p_code text)
returns table(coach_id uuid, username text, display_name text, avatar_url text,
              headline text, specialties text[], experience_years smallint,
              expires_at timestamptz)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  return query
  select c.id, p.username, p.display_name, p.avatar_url, c.headline,
         c.specialties, c.experience_years, ci.expires_at
  from coaching_invitations ci
  join coach_profiles c on c.id = ci.coach_id and c.status = 'approved'
  join profiles p on p.id = c.id and p.deleted_at is null
  where ci.code_hash = public.invite_code_hash(p_code)
    and ci.accepted_at is null and ci.revoked_at is null and ci.expires_at > now();
  if not found then raise exception 'This invite code is invalid or has expired'; end if;
end;
$$;

-- Athlete: accept. The Captain already said yes by sending the invite, so
-- the relationship starts active. The athlete picks what is shared.
create or replace function public.accept_coaching_invitation(
  p_code text,
  p_share_workouts boolean default true, p_share_prs boolean default true,
  p_share_skill_progress boolean default true, p_share_body_metrics boolean default false
) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_inv   coaching_invitations%rowtype;
  v_max   smallint;
  v_open  coaching_relationships%rowtype;
  v_rel   uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to accept an invite'; end if;

  select * into v_inv from coaching_invitations
  where code_hash = public.invite_code_hash(p_code)
    and accepted_at is null and revoked_at is null and expires_at > now()
  for update;
  if not found then raise exception 'This invite code is invalid or has expired'; end if;
  if v_inv.coach_id = auth.uid() then raise exception 'Cannot coach yourself'; end if;

  -- lock the Captain row so concurrent accepts can't overshoot capacity
  select max_athletes into v_max from coach_profiles
  where id = v_inv.coach_id and status = 'approved' for update;
  if not found then raise exception 'This invite code is invalid or has expired'; end if;
  if v_max is not null and (select count(*) from coaching_relationships
                            where coach_id = v_inv.coach_id and status = 'active') >= v_max then
    raise exception 'Coach is at capacity';
  end if;

  select * into v_open from coaching_relationships
  where athlete_id = auth.uid() and status in ('pending', 'active');

  if found and v_open.coach_id <> v_inv.coach_id then
    raise exception 'You already have a Captain or a pending request. End it before accepting this invite';
  elsif found and v_open.status = 'active' then
    raise exception 'This Captain is already coaching you';
  elsif found then
    -- athlete had already requested this Captain: the invite completes it
    update coaching_relationships
    set status = 'active', started_at = now(), source = 'invite', invitation_id = v_inv.id
    where id = v_open.id;
    update coaching_permissions
    set share_workouts = p_share_workouts, share_prs = p_share_prs,
        share_skill_progress = p_share_skill_progress, share_body_metrics = p_share_body_metrics
    where relationship_id = v_open.id;
    v_rel := v_open.id;
  else
    insert into coaching_relationships (athlete_id, coach_id, status, started_at, source, invitation_id)
    values (auth.uid(), v_inv.coach_id, 'active', now(), 'invite', v_inv.id)
    returning id into v_rel;
    insert into coaching_permissions (relationship_id, share_workouts, share_prs,
                                      share_skill_progress, share_body_metrics)
    values (v_rel, p_share_workouts, p_share_prs, p_share_skill_progress, p_share_body_metrics);
  end if;

  update coaching_invitations set accepted_by = auth.uid(), accepted_at = now()
  where id = v_inv.id;
  return v_rel;
end;
$$;

-- ---------------------------------------------------------------- 5. coach card
-- Directory now hides unlisted Captains (same return shape as before).
create or replace function public.get_coach_directory(p_specialty text default null, p_limit int default 50)
returns table(coach_id uuid, username text, display_name text, avatar_url text, headline text,
              specialties text[], experience_years smallint, accepting_athletes boolean, athlete_count bigint)
language sql stable security definer set search_path = public, pg_temp as $$
  select c.id, p.username, p.display_name, p.avatar_url, c.headline, c.specialties,
         c.experience_years,
         (c.accepting_athletes and (c.max_athletes is null or
           (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active') < c.max_athletes)),
         (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active')
  from coach_profiles c
  join profiles p on p.id = c.id and p.deleted_at is null
  where c.status = 'approved' and c.is_listed
    and (p_specialty is null or p_specialty = any(c.specialties))
  order by 9 desc
  limit p_limit;
$$;

-- One approved Captain's public card, listed or not (an invited athlete's
-- Captain may be unlisted). Adds bio/approach/certifications for the profile.
create or replace function public.get_coach_card(p_coach_id uuid)
returns table(coach_id uuid, username text, display_name text, avatar_url text, headline text,
              bio text, approach text, specialties text[], certifications text[],
              experience_years smallint, accepting_athletes boolean, athlete_count bigint)
language sql stable security definer set search_path = public, pg_temp as $$
  select c.id, p.username, p.display_name, p.avatar_url, c.headline, c.bio, c.approach,
         c.specialties, c.certifications, c.experience_years,
         (c.accepting_athletes and (c.max_athletes is null or
           (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active') < c.max_athletes)),
         (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active')
  from coach_profiles c
  join profiles p on p.id = c.id and p.deleted_at is null
  where c.id = p_coach_id and c.status = 'approved';
$$;

-- ---------------------------------------------------------------- 9. suspension
create or replace function public.is_active_coach_of(p_rel uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.coaching_relationships r
                 join public.coach_profiles c on c.id = r.coach_id and c.status = 'approved'
                 where r.id = p_rel and r.coach_id = auth.uid() and r.status = 'active');
$$;

create or replace function public.coach_can_view(p_athlete uuid, p_scope text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1
    from public.coaching_relationships r
    join public.coaching_permissions p on p.relationship_id = r.id
    join public.coach_profiles c on c.id = r.coach_id and c.status = 'approved'
    where r.athlete_id = p_athlete and r.coach_id = auth.uid() and r.status = 'active'
      and case p_scope
            when 'workouts' then p.share_workouts
            when 'prs'      then p.share_prs
            when 'progress' then p.share_skill_progress
            when 'body'     then p.share_body_metrics
            else false end
  );
$$;

-- ---------------------------------------------------------------- 10. feedback
drop policy "coaching_feedback_insert" on public.coaching_feedback;
create policy "coaching_feedback_insert" on public.coaching_feedback for insert
  with check (
    author_id = auth.uid() and (
      public.is_active_coach_of(relationship_id)
      or exists (select 1 from public.coaching_relationships r
                 where r.id = relationship_id and r.athlete_id = auth.uid() and r.status = 'active')
    )
  );

-- ---------------------------------------------------------------- 8. accept fix
create or replace function public.respond_to_coaching_request(p_relationship_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_max smallint;
begin
  if p_accept then
    select max_athletes into v_max from coach_profiles
    where id = auth.uid() and status = 'approved' for update;   -- serializes accepts
    if not found then raise exception 'Your Captain profile is not active'; end if;
    if v_max is not null and (select count(*) from coaching_relationships
                              where coach_id = auth.uid() and status = 'active') >= v_max then
      raise exception 'You are at your athlete limit. Raise it or end a coaching relationship first';
    end if;
  end if;

  update coaching_relationships
  set status = case when p_accept then 'active'::coaching_status else 'declined'::coaching_status end,
      started_at = case when p_accept then now() end,
      ended_at   = case when p_accept then null else now() end,
      ended_by   = case when p_accept then null else auth.uid() end
  where id = p_relationship_id and coach_id = auth.uid() and status = 'pending';
  if not found then raise exception 'No pending request found'; end if;
end;
$$;

-- ---------------------------------------------------------------- 11. notifications
create or replace function public.notify_coaching_event()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_table_name = 'coaching_relationships' then
    if tg_op = 'INSERT' and new.status = 'active' then          -- invite accepted
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.coach_id, 'coach_accepted', tg_table_name, new.id, 'An athlete accepted your invite');
    elsif tg_op = 'INSERT' then
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.coach_id, 'coach_request', tg_table_name, new.id, 'New coaching request');
    elsif new.status is distinct from old.status and new.status = 'active' and new.source = 'invite' then
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.coach_id, 'coach_accepted', tg_table_name, new.id, 'An athlete accepted your invite');
    elsif new.status is distinct from old.status and new.status = 'active' then
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.athlete_id, 'coach_accepted', tg_table_name, new.id, 'Your Captain accepted your request');
    elsif new.status is distinct from old.status and new.status = 'declined' then
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.athlete_id, 'coach_declined', tg_table_name, new.id, 'Your coaching request was declined');
    end if;
  elsif tg_table_name = 'coaching_feedback' then
    insert into notifications (user_id, type, reference_table, reference_id, message)
    select case when r.athlete_id = new.author_id then r.coach_id else r.athlete_id end,
           'coach_feedback', tg_table_name, new.id, 'New coaching feedback'
    from coaching_relationships r where r.id = new.relationship_id;
  elsif tg_table_name = 'program_assignments' then
    insert into notifications (user_id, type, reference_table, reference_id, message)
    select r.athlete_id, 'program_assigned', tg_table_name, new.id, 'Your Captain assigned you a program'
    from coaching_relationships r where r.id = new.relationship_id;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------- 6. hub
-- Everything the Captain Hub shows, in one call. Null when the caller has
-- no Captain profile. Workout stats only for athletes sharing workouts.
create or replace function public.get_captain_hub()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'profile', jsonb_build_object(
      'status', c.status, 'is_listed', c.is_listed,
      'accepting_athletes', c.accepting_athletes, 'max_athletes', c.max_athletes,
      'headline', c.headline, 'bio', c.bio, 'approach', c.approach,
      'specialties', to_jsonb(c.specialties), 'certifications', to_jsonb(c.certifications),
      'experience_years', c.experience_years),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
               'relationship_id', r.id, 'athlete_id', r.athlete_id,
               'display_name', p.display_name, 'username', p.username,
               'avatar_url', p.avatar_url, 'requested_at', r.requested_at)
             order by r.requested_at)
      from coaching_relationships r join profiles p on p.id = r.athlete_id
      where r.coach_id = c.id and r.status = 'pending'), '[]'::jsonb),
    'clients', coalesce((
      select jsonb_agg(jsonb_build_object(
               'relationship_id', r.id, 'athlete_id', r.athlete_id,
               'display_name', p.display_name, 'username', p.username,
               'avatar_url', p.avatar_url, 'started_at', r.started_at, 'source', r.source,
               'share_workouts', perm.share_workouts,
               'last_workout_at', case when perm.share_workouts then (
                  select max(w.started_at) from workout_logs w
                  where w.user_id = r.athlete_id and w.status = 'completed') end,
               'workouts_last_7_days', case when perm.share_workouts then (
                  select count(*) from workout_logs w
                  where w.user_id = r.athlete_id and w.status = 'completed'
                    and w.started_at > now() - interval '7 days') end,
               'open_assignments', (
                  select count(*) from program_assignments a
                  where a.relationship_id = r.id and a.status in ('assigned', 'in_progress')))
             order by r.started_at desc)
      from coaching_relationships r
      join profiles p on p.id = r.athlete_id
      join coaching_permissions perm on perm.relationship_id = r.id
      where r.coach_id = c.id and r.status = 'active' and c.status = 'approved'), '[]'::jsonb),
    'invitations', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', ci.id, 'code_hint', ci.code_hint, 'note', ci.note,
               'expires_at', ci.expires_at, 'created_at', ci.created_at)
             order by ci.created_at desc)
      from coaching_invitations ci
      where ci.coach_id = c.id and ci.accepted_at is null
        and ci.revoked_at is null and ci.expires_at > now()), '[]'::jsonb),
    'invites_accepted', (select count(*) from coaching_invitations ci
                         where ci.coach_id = c.id and ci.accepted_at is not null))
  from coach_profiles c
  where c.id = auth.uid();
$$;

-- ---------------------------------------------------------------- 7. client workouts
-- Completed workouts for one athlete: the athlete themself, or their active
-- approved Captain with the workouts scope on. Anyone else gets 0 rows.
create or replace function public.get_client_workouts(p_athlete uuid, p_limit int default 20)
returns table(workout_log_id uuid, started_at timestamptz, completed_at timestamptz,
              duration_seconds int, exercise_count bigint, working_sets bigint,
              volume_kg numeric, exercise_names text[])
language sql stable security definer set search_path = public, pg_temp as $$
  select w.id, w.started_at, w.completed_at, w.duration_seconds,
         (select count(*) from workout_log_exercises e where e.workout_log_id = w.id),
         (select count(*) from workout_log_exercises e
            join workout_log_sets s on s.workout_log_exercise_id = e.id
           where e.workout_log_id = w.id and s.completed and s.set_type = 'working'),
         (select coalesce(sum(s.reps * s.weight_kg), 0) from workout_log_exercises e
            join workout_log_sets s on s.workout_log_exercise_id = e.id
           where e.workout_log_id = w.id and s.completed and s.set_type = 'working'
             and s.reps is not null and s.weight_kg is not null),
         array(select x.name from workout_log_exercises e join exercises x on x.id = e.exercise_id
               where e.workout_log_id = w.id order by e.order_index)
  from workout_logs w
  where w.user_id = p_athlete and w.status = 'completed'
    and (p_athlete = auth.uid() or public.coach_can_view(p_athlete, 'workouts'))
  order by w.started_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

-- ---------------------------------------------------------------- 12. approval guard
-- The guard from migration 28 blocked the Supabase dashboard too: the
-- dashboard runs as a database role with no JWT, so is_admin() is false.
-- API users (anon/authenticated) still need is_admin(); direct database
-- roles (dashboard, service role) may approve or suspend.
create or replace function public.guard_coach_status()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status
     and current_user in ('anon', 'authenticated') and not public.is_admin() then
    raise exception 'Only an admin can change coach status';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- grants
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and p.proname in ('create_coaching_invitation', 'revoke_coaching_invitation',
                               'preview_coaching_invitation', 'accept_coaching_invitation',
                               'get_coach_card', 'get_captain_hub', 'get_client_workouts')
  loop
    execute format('revoke execute on function %s from public, anon', r.f);
    execute format('grant  execute on function %s to authenticated', r.f);
  end loop;
end $$;
-- internal helper: only used inside the definer RPCs above
revoke execute on function public.invite_code_hash(text) from public, anon, authenticated;

commit;
