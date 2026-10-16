-- Performance advisor (unindexed_foreign_keys): coaching_relationships.ended_by
-- references profiles(id) without a covering index, so deleting a profile
-- has to scan coaching_relationships for the ON DELETE SET NULL.
create index if not exists idx_coaching_rel_ended_by
  on public.coaching_relationships (ended_by);
