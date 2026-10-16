-- favorites.user_id -> profiles(id), matching every other user-owned table
-- (workout_templates, workout_logs, body_metrics_log, user_settings, ...).
-- 20261016165917 pointed it at auth.users and is already applied, so this
-- is a follow-up rather than an edit. profiles.id itself references
-- auth.users on delete cascade, so deleting a user still clears favorites.
begin;

alter table public.favorites drop constraint favorites_user_id_fkey;
alter table public.favorites
  add constraint favorites_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete cascade;

commit;
