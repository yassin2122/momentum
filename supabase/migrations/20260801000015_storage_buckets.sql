-- Storage buckets: avatars, exercise-media, skill-media, post-media
insert into storage.buckets (id, name, public) values
  ('avatars', 'avatars', true),
  ('exercise-media', 'exercise-media', true),
  ('skill-media', 'skill-media', true),
  ('post-media', 'post-media', true)
on conflict (id) do nothing;

create policy "avatar_owner_write" on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar_owner_update" on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar_owner_delete" on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "exercise_media_admin_write" on storage.objects for insert
  with check (bucket_id = 'exercise-media' and public.is_admin());
create policy "exercise_media_admin_update" on storage.objects for update
  using (bucket_id = 'exercise-media' and public.is_admin());

create policy "skill_media_admin_write" on storage.objects for insert
  with check (bucket_id = 'skill-media' and public.is_admin());
create policy "skill_media_admin_update" on storage.objects for update
  using (bucket_id = 'skill-media' and public.is_admin());

create policy "post_media_owner_write" on storage.objects for insert
  with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "post_media_owner_delete" on storage.objects for delete
  using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
