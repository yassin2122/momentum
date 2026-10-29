-- ============================================================================
-- Auth security hardening
--   1. profiles.role can only be changed by an admin (server-side, not UI).
--   2. Users who enrolled 2FA must present an aal2 token on EVERY API call
--      (tables + RPCs via PostgREST pre-request; storage via RLS).
--   3. Per-account lockout after repeated failed password / 2FA attempts
--      (Supabase Auth hooks — enable them in config.toml / dashboard).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Admin role can't be self-assigned
-- ---------------------------------------------------------------------------
-- Only end-user API calls (anon/authenticated JWT) are restricted; the
-- signup trigger, migrations, dashboard and service-role scripts are not.
create or replace function public.guard_profile_role()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if coalesce(auth.role(), '') not in ('anon', 'authenticated') or public.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.role := 'user';
  elsif new.role is distinct from old.role then
    raise exception 'Only an admin can change account roles'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_guard_role on public.profiles;
create trigger trg_profiles_guard_role
  before insert or update of role on public.profiles
  for each row execute function public.guard_profile_role();

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert
  with check (id = auth.uid() and role = 'user');

-- ---------------------------------------------------------------------------
-- 2. Enforce 2FA server-side
-- ---------------------------------------------------------------------------
-- True when the caller either has no verified 2FA factor, or already
-- proved it in this session (JWT aal = aal2).
create or replace function public.mfa_satisfied()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is null
      or coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      or not exists (
        select 1 from auth.mfa_factors f
        where f.user_id = auth.uid() and f.status = 'verified'
      );
$$;
revoke execute on function public.mfa_satisfied() from public;
grant  execute on function public.mfa_satisfied() to anon, authenticated, service_role;

-- Runs before every PostgREST request (tables, views and RPCs, including
-- security-definer ones that bypass RLS).
create or replace function public.enforce_mfa()
returns void language plpgsql stable set search_path = public, pg_temp as $$
begin
  if not public.mfa_satisfied() then
    raise exception 'Two-factor verification required'
      using errcode = '42501', hint = 'mfa_required';
  end if;
end;
$$;
revoke execute on function public.enforce_mfa() from public;
grant  execute on function public.enforce_mfa() to anon, authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'public.enforce_mfa';
notify pgrst, 'reload config';

-- Storage doesn't go through PostgREST, so gate it with a restrictive policy.
drop policy if exists "storage_require_mfa" on storage.objects;
create policy "storage_require_mfa" on storage.objects
  as restrictive for all to authenticated
  using ((select public.mfa_satisfied()))
  with check ((select public.mfa_satisfied()));

-- ---------------------------------------------------------------------------
-- 3. Account lockout (password + 2FA brute force)
-- ---------------------------------------------------------------------------
-- Private schema: not exposed by the API; only the Auth server touches it.
create schema if not exists auth_security;
revoke all on schema auth_security from public, anon, authenticated;
grant usage on schema auth_security to supabase_auth_admin;

create table if not exists auth_security.failed_attempts (
  user_id         uuid not null references auth.users(id) on delete cascade,
  kind            text not null check (kind in ('password', 'mfa')),
  failed_count    int  not null default 0,
  window_start    timestamptz not null default now(),
  locked_until    timestamptz,
  primary key (user_id, kind)
);
revoke all on auth_security.failed_attempts from public, anon, authenticated;
grant select, insert, update, delete on auth_security.failed_attempts to supabase_auth_admin;

-- 5 failures inside 15 minutes -> locked for 15 minutes. A correct attempt
-- while unlocked clears the counter. Messages never say whether the
-- password was right, only that the account must wait.
create or replace function auth_security.register_attempt(
  p_user uuid, p_kind text, p_valid boolean
) returns jsonb language plpgsql set search_path = auth_security, pg_temp as $$
declare
  c_max_failures constant int := 5;
  c_window       constant interval := interval '15 minutes';
  c_lockout      constant interval := interval '15 minutes';
  r failed_attempts;
  v_msg text := 'Too many attempts. Please wait a few minutes and try again.';
begin
  select * into r from failed_attempts
   where user_id = p_user and kind = p_kind for update;

  if found and r.locked_until is not null and r.locked_until > now() then
    return jsonb_build_object('decision', 'reject', 'message', v_msg,
                              'should_logout_user', false);
  end if;

  if p_valid then
    delete from failed_attempts where user_id = p_user and kind = p_kind;
    return jsonb_build_object('decision', 'continue');
  end if;

  insert into failed_attempts as f (user_id, kind, failed_count, window_start)
  values (p_user, p_kind, 1, now())
  on conflict (user_id, kind) do update
     set failed_count = case when f.window_start < now() - c_window
                             then 1 else f.failed_count + 1 end,
         window_start = case when f.window_start < now() - c_window
                             then now() else f.window_start end,
         locked_until = null
  returning * into r;

  if r.failed_count >= c_max_failures then
    update failed_attempts set locked_until = now() + c_lockout
     where user_id = p_user and kind = p_kind;
    return jsonb_build_object('decision', 'reject', 'message', v_msg,
                              'should_logout_user', false);
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$;

-- Supabase Auth hook: password_verification_attempt
create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb language plpgsql set search_path = public, pg_temp as $$
begin
  return auth_security.register_attempt(
    (event ->> 'user_id')::uuid, 'password', (event ->> 'valid')::boolean);
end;
$$;

-- Supabase Auth hook: mfa_verification_attempt
create or replace function public.hook_mfa_verification_attempt(event jsonb)
returns jsonb language plpgsql set search_path = public, pg_temp as $$
begin
  return auth_security.register_attempt(
    (event ->> 'user_id')::uuid, 'mfa', (event ->> 'valid')::boolean);
end;
$$;

revoke execute on function auth_security.register_attempt(uuid, text, boolean) from public;
revoke execute on function public.hook_password_verification_attempt(jsonb) from public, anon, authenticated;
revoke execute on function public.hook_mfa_verification_attempt(jsonb)      from public, anon, authenticated;
grant  execute on function auth_security.register_attempt(uuid, text, boolean) to supabase_auth_admin;
grant  execute on function public.hook_password_verification_attempt(jsonb) to supabase_auth_admin;
grant  execute on function public.hook_mfa_verification_attempt(jsonb)      to supabase_auth_admin;
