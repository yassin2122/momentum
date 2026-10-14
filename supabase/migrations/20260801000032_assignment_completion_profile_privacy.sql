-- 32: (a) mark assigned programs finished, (b) hide private profile fields
begin;

-- ---------------------------------------------------------------- (a)
-- Athlete, or the Captain while the relationship is active, marks it finished.
create or replace function public.complete_assignment(p_assignment_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_enroll uuid;
begin
  update program_assignments a
  set status = 'completed', completed_at = now()
  from coaching_relationships r
  where a.id = p_assignment_id and r.id = a.relationship_id
    and a.status in ('assigned', 'in_progress')
    and (r.athlete_id = auth.uid() or (r.coach_id = auth.uid() and r.status = 'active'))
  returning a.enrollment_id into v_enroll;
  if not found then raise exception 'Assignment not found or already closed'; end if;

  if v_enroll is not null then
    update user_program_enrollment set completed_at = now(), is_active = false where id = v_enroll;
  end if;
end;
$$;
revoke execute on function public.complete_assignment(uuid) from public, anon;
grant  execute on function public.complete_assignment(uuid) to authenticated;

-- ---------------------------------------------------------------- (b)
-- Private fields: birthday, height_cm, weight_kg, gender.
-- Other users can no longer SELECT them; owner and permitted Captain use RPCs.
-- NOTE: the app must select explicit columns from profiles (select('*') now errors).
revoke select on public.profiles from anon, authenticated;
grant  select (id, username, display_name, avatar_url, bio, role, created_at, updated_at, deleted_at)
  on public.profiles to authenticated;

create or replace function public.get_my_private_profile()
returns table(birthday date, height_cm numeric, weight_kg numeric, gender gender_type)
language sql stable security definer set search_path = public, pg_temp as $$
  select birthday, height_cm, weight_kg, gender from profiles where id = auth.uid();
$$;

-- Captain sees body info only with an active relationship + share_body_metrics
create or replace function public.get_athlete_body_profile(p_athlete uuid)
returns table(age_years int, height_cm numeric, weight_kg numeric, gender gender_type)
language sql stable security definer set search_path = public, pg_temp as $$
  select extract(year from age(birthday))::int, height_cm, weight_kg, gender
  from profiles where id = p_athlete and public.coach_can_view(p_athlete, 'body');
$$;

revoke execute on function public.get_my_private_profile()          from public, anon;
revoke execute on function public.get_athlete_body_profile(uuid)    from public, anon;
grant  execute on function public.get_my_private_profile()          to authenticated;
grant  execute on function public.get_athlete_body_profile(uuid)    to authenticated;

commit;
