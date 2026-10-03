-- Connect — RPCs (all state changes) + notification triggers + realtime.
begin;

-- Coach directory (security definer so athlete_count can be computed)
create or replace function public.get_coach_directory(p_specialty text default null, p_limit int default 50)
returns table(coach_id uuid, username text, display_name text, avatar_url text, headline text,
              specialties text[], experience_years smallint, accepting_athletes boolean, athlete_count bigint)
language sql stable security definer set search_path = public as $$
  select c.id, p.username, p.display_name, p.avatar_url, c.headline, c.specialties,
         c.experience_years,
         (c.accepting_athletes and (c.max_athletes is null or
           (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active') < c.max_athletes)),
         (select count(*) from coaching_relationships r where r.coach_id = c.id and r.status = 'active')
  from coach_profiles c
  join profiles p on p.id = c.id and p.deleted_at is null
  where c.status = 'approved'
    and (p_specialty is null or p_specialty = any(c.specialties))
  order by 9 desc
  limit p_limit;
$$;

-- Athlete: "Choose Captain" (athlete sets what is shared at this moment)
create or replace function public.choose_captain(
  p_coach_id uuid, p_plan_id uuid default null,
  p_share_workouts boolean default true, p_share_prs boolean default true,
  p_share_skill_progress boolean default true, p_share_body_metrics boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_coach coach_profiles%rowtype;
  v_rel uuid;
begin
  select * into v_coach from coach_profiles where id = p_coach_id and status = 'approved';
  if not found then raise exception 'Coach not available'; end if;
  if p_coach_id = auth.uid() then raise exception 'Cannot coach yourself'; end if;
  if not v_coach.accepting_athletes then raise exception 'Coach is not accepting athletes'; end if;
  if v_coach.max_athletes is not null and
     (select count(*) from coaching_relationships where coach_id = p_coach_id and status = 'active') >= v_coach.max_athletes then
    raise exception 'Coach is at capacity';
  end if;
  if p_plan_id is not null and not exists
     (select 1 from coaching_plans where id = p_plan_id and coach_id = p_coach_id and is_active and deleted_at is null) then
    raise exception 'Invalid plan';
  end if;

  insert into coaching_relationships (athlete_id, coach_id, plan_id)
  values (auth.uid(), p_coach_id, p_plan_id) returning id into v_rel;   -- unique index blocks a 2nd open Captain

  insert into coaching_permissions (relationship_id, share_workouts, share_prs, share_skill_progress, share_body_metrics)
  values (v_rel, p_share_workouts, p_share_prs, p_share_skill_progress, p_share_body_metrics);
  return v_rel;
end;
$$;

-- Coach: accept / decline
create or replace function public.respond_to_coaching_request(p_relationship_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update coaching_relationships
  set status = case when p_accept then 'active'::coaching_status else 'declined'::coaching_status end,
      started_at = case when p_accept then now() end,
      ended_at   = case when p_accept then null else now() end,
      ended_by   = case when p_accept then null else auth.uid() end
  where id = p_relationship_id and coach_id = auth.uid() and status = 'pending';
  if not found then raise exception 'No pending request found'; end if;
end;
$$;

-- Either side can end it; access stops immediately (coach_can_view needs 'active')
create or replace function public.end_coaching(p_relationship_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update coaching_relationships
  set status = 'ended', ended_at = now(), ended_by = auth.uid()
  where id = p_relationship_id and status in ('pending', 'active')
    and (athlete_id = auth.uid() or coach_id = auth.uid());
  if not found then raise exception 'Relationship not found or already closed'; end if;
end;
$$;

-- Coach: assign one of their own programs
create or replace function public.assign_program(
  p_relationship_id uuid, p_program_id uuid,
  p_start_date date default current_date, p_instructions text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_active_coach_of(p_relationship_id) then raise exception 'Not your active athlete'; end if;
  if not exists (select 1 from programs where id = p_program_id and created_by = auth.uid()
                 and not is_official and deleted_at is null) then
    raise exception 'Program not found or not yours';
  end if;
  insert into program_assignments (relationship_id, program_id, assigned_by, start_date, instructions)
  values (p_relationship_id, p_program_id, auth.uid(), p_start_date, p_instructions)
  returning id into v_id;
  return v_id;
end;
$$;

-- Athlete: start an assigned program (reuses user_program_enrollment)
create or replace function public.start_assigned_program(p_assignment_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_prog uuid; v_enroll uuid; v_first uuid;
begin
  select a.program_id into v_prog
  from program_assignments a join coaching_relationships r on r.id = a.relationship_id
  where a.id = p_assignment_id and r.athlete_id = auth.uid() and a.status = 'assigned';
  if not found then raise exception 'Assignment not found'; end if;

  select id into v_first from program_days where program_id = v_prog order by day_order limit 1;
  update user_program_enrollment set is_active = false where user_id = auth.uid() and is_active;
  insert into user_program_enrollment (user_id, program_id, current_day_id)
  values (auth.uid(), v_prog, v_first) returning id into v_enroll;

  update program_assignments set status = 'in_progress', enrollment_id = v_enroll where id = p_assignment_id;
  return v_enroll;
end;
$$;

-- ---------------- notifications
create or replace function public.notify_coaching_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'coaching_relationships' then
    if tg_op = 'INSERT' then
      insert into notifications (user_id, type, reference_table, reference_id, message)
      values (new.coach_id, 'coach_request', tg_table_name, new.id, 'New coaching request');
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
create trigger trg_notify_rel after insert or update on public.coaching_relationships
  for each row execute function public.notify_coaching_event();
create trigger trg_notify_feedback after insert on public.coaching_feedback
  for each row execute function public.notify_coaching_event();
create trigger trg_notify_assignment after insert on public.program_assignments
  for each row execute function public.notify_coaching_event();

alter publication supabase_realtime add table public.coaching_feedback;
alter publication supabase_realtime add table public.coaching_relationships;

commit;
