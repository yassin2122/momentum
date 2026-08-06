-- Fix: v_user_roadmap and v_friend_activity_feed were created without
-- security_invoker, so they ran as the view owner and silently bypassed
-- RLS on skill_progress / activities for every querying user. This makes
-- both views re-check permissions as the querying user, restoring the
-- RLS enforcement that was always intended.

alter view public.v_user_roadmap set (security_invoker = true);
alter view public.v_friend_activity_feed set (security_invoker = true);
