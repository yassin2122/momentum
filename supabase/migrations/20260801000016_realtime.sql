-- Enable Realtime on tables the UI should update live
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.skill_progress;
alter publication supabase_realtime add table public.post_comments;
alter publication supabase_realtime add table public.post_likes;
