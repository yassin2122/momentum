-- Connect (coaching) — notification types. Own file: new enum values
-- cannot be used in the same transaction that adds them.
alter type notification_type add value if not exists 'coach_request';
alter type notification_type add value if not exists 'coach_accepted';
alter type notification_type add value if not exists 'coach_declined';
alter type notification_type add value if not exists 'coach_feedback';
alter type notification_type add value if not exists 'program_assigned';
