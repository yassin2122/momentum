-- Seed profiles.display_name from the name entered on the Register screen.
-- The client passes it as auth signUp metadata (raw_user_meta_data.display_name);
-- until now handle_new_user ignored it, so display_name stayed null.
-- Body is otherwise unchanged from migration 17. The search_path pin from
-- migration 31 is restated because CREATE OR REPLACE resets SET clauses.
begin;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    'user_' || substr(new.id::text, 1, 8),
    -- client-supplied: trim, cap length, treat blank as absent
    nullif(left(btrim(new.raw_user_meta_data ->> 'display_name'), 80), '')
  );
  perform public.initialize_user_skill_progress(new.id);
  return new;
end;
$$;

-- Trigger-only function: keep it uncallable from the API (as in migration 31).
revoke execute on function public.handle_new_user() from public, anon, authenticated;

commit;
