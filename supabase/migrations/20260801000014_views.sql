-- VIEWS
-- ============================================================================

-- roadmap map view: skill + user's progress + lock state, ready for the UI graph
create or replace view public.v_user_roadmap as
select
  s.id as skill_id, s.name, s.slug, s.roadmap_category_id, s.sort_order,
  sp.user_id, coalesce(sp.status, 'locked') as status,
  coalesce(sp.current_xp, 0) as current_xp,
  coalesce(sp.completion_percentage, 0) as completion_percentage,
  sp.unlocked_at, sp.completed_at
from public.skills s
left join public.skill_progress sp on sp.skill_id = s.id
where s.deleted_at is null and s.is_active;

-- friend leaderboard-style feed (accepted friends only, most recent activity first)
create or replace view public.v_friend_activity_feed as
select a.*, p.username, p.display_name, p.avatar_url
from public.activities a
join public.profiles p on p.id = a.user_id
where p.deleted_at is null;
-- RLS on `activities` already restricts rows to the caller's own + accepted friends'.
