-- Grit v1.1 patch — enum extensions (own migration: PG forbids using a
-- newly added enum value inside the same transaction it was added in)

alter type achievement_category add value if not exists 'master';

alter type objective_target_type add value if not exists 'sessions';
alter type objective_target_type add value if not exists 'checkbox';

alter type pr_metric_type add value if not exists 'estimated_1rm';

alter type notification_type add value if not exists 'nudge';
alter type notification_type add value if not exists 'friend_challenge';

alter type activity_type add value if not exists 'streak_milestone';
alter type activity_type add value if not exists 'program_completed';
