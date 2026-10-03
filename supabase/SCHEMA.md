# Momentum — SCHEMA.md

Status: after migrations 0001–0030 · Backend: Supabase (Postgres, Auth, RLS, Storage, Realtime)
Rule: never edit an applied migration. Add a new one.

## 1. Migration order

| #       | File                      | Purpose                                              |
|---------|---------------------------|------------------------------------------------------|
| 01–17   | base                      | enums, profiles, exercises, tracker, roadmap, progress, challenges, achievements, RLS, functions, views, storage, realtime, auth trigger |
| 18–25   | patches                   | enum extensions, progress fixes, train additions (programs, streaks), view/index fixes |
| 26      | `remove_social`           | drops legacy social layer, rewrites 5 functions that fed it |
| 27      | `connect_enums`           | coaching notification types                          |
| 28      | `connect_core`            | coaching tables, helper functions, RLS               |
| 29      | `connect_data_access`     | permission-gated coach read access, coach programs   |
| 30      | `connect_rpcs`            | RPCs, notification triggers, realtime                |

## 2. Table map by pillar

### Shared / identity
- `profiles` — one row per auth user; `role` = `user` | `admin`
- `body_metrics_log` — weight/height history
- `notifications` — generic in-app notifications (reused by Connect)
- `content_audit_log` — admin content change log

### TRAIN
- Library: `exercises`, `muscle_groups`, `exercise_muscle_groups`
- Templates: `workout_templates`, `workout_template_exercises`
- Logging: `workout_logs` → `workout_log_exercises` → `workout_log_sets`
- Records: `personal_records`, `personal_record_history`
- Programs: `programs`, `program_days`, `program_day_exercises`, `user_program_enrollment`
- Analytics foundations: `user_streaks`, `user_aggregate_records`

### PROGRESS
- Structure: `roadmap_categories` (galaxies) → `skills` (planets) → `skill_stages` → `objectives`; `skill_prerequisites`
- Roadmap workouts: `roadmap_workouts`, `roadmap_workout_exercises`
- User state: `skill_progress`, `user_skill_stage_progress`, `user_objective_progress`
- Roadmap logs: `roadmap_workout_logs`, `roadmap_workout_log_exercises`, `roadmap_personal_bests`
- XP: `xp_transactions` (visual feedback only; objectives unlock skills)
- Achievements: `achievements`, `user_achievements`
- Weekly (admin-authored): `weekly_challenges`, `user_weekly_challenge_progress`

### CONNECT (coaching) — new
| Table                    | Purpose                                              | Written by |
|--------------------------|------------------------------------------------------|------------|
| `coach_profiles`         | coach bio, specialties, certs, capacity, `status` (pending/approved/suspended) | coach (admin approves) |
| `coaching_plans`         | coach plan options, display-only price               | coach |
| `coaching_relationships` | athlete ↔ coach; pending/active/ended/declined; one open Captain per athlete | RPCs only |
| `coaching_permissions`   | athlete consent: workouts, prs, skill progress, body metrics | RPC create, athlete update |
| `coaching_goals`         | goals set by the Captain                             | coach |
| `coaching_feedback`      | append-only messages on workouts/skills              | either party |
| `coaching_private_notes` | coach-only notes, never readable by athlete          | coach |
| `program_assignments`    | coach assigns own program to athlete                 | RPCs only |

## 3. Removed (migration 26)
`posts`, `post_likes`, `post_comments`, `activities`, `activity_comments`, `friendships`, `blocks`, `user_challenges`, `user_challenge_participants`, view `v_friend_activity_feed`, functions `are_friends`, `is_blocked`, `get_global_xp_leaderboard`, `get_friends_xp_leaderboard`, post like/comment handlers, enums `friend_request_status` and `activity_type`.
Leftovers: old social values stay inside `notification_type` (Postgres cannot drop enum values). Delete the empty `post-media` bucket in the dashboard.

## 4. Access model (Connect)
- Captain reads athlete data only when the relationship is `active` AND the matching permission is on.
- Scopes → tables:
  - `workouts`: `workout_logs`, `workout_log_exercises`, `workout_log_sets`, `user_streaks`
  - `prs`: `personal_records`, `personal_record_history`, `roadmap_personal_bests`
  - `progress`: `skill_progress`, `user_skill_stage_progress`, `user_objective_progress`, `xp_transactions`, `user_achievements`, `roadmap_workout_logs`, `roadmap_workout_log_exercises`
  - `body`: `body_metrics_log`
- Coaches have **no write policy** on any athlete log. History stays trustworthy.
- Ending a relationship removes access immediately.
- Coach programs are `is_official = false`, visible only to the coach and assigned athletes.

## 5. Helper functions
`is_admin()`, `is_coach()`, `in_relationship(rel)`, `is_active_coach_of(rel)`, `coach_can_view(athlete, scope)`, `can_view_program(program)`

## 6. RPCs
| RPC | Caller | Effect |
|-----|--------|--------|
| `get_coach_directory(specialty, limit)` | any user | approved coaches + athlete count |
| `choose_captain(coach, plan, share_*)`  | athlete | creates pending relationship + permissions |
| `respond_to_coaching_request(rel, accept)` | coach | pending → active / declined |
| `end_coaching(rel)`                     | either  | closes relationship |
| `assign_program(rel, program, start, notes)` | coach | creates assignment |
| `start_assigned_program(assignment)`    | athlete | creates enrollment, status in_progress |
| `complete_roadmap_workout(...)`         | athlete | Progress: logs roadmap workout, awards XP |
| `record_roadmap_personal_best(...)`     | athlete | Progress: roadmap PR upsert |

## 7. Known gaps
- Assigned program completion is not automated (only start).
- `profiles` is readable by all signed-in users (includes birthday, height, weight). Tighten before launch.
- No payments; plan prices are display only.
- Certification (Complete/Master/Legendary) lives in skill structure, not a dedicated table.
