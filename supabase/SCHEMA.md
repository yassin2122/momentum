# Grit — SCHEMA.md

Status: after migrations 0001–0032 (+ later TRAIN additions noted inline, + Captain Hub `20261020200000`) · Backend: Supabase (Postgres, Auth, RLS, Storage, Realtime)
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
| 31      | `security_hardening`      | function EXECUTE grants, pinned search_path          |
| 32      | `assignment_completion_profile_privacy` | `complete_assignment`, private profile columns |
| 20261020200000 | `captain_hub_invitations` | invites, Captain Hub RPCs, listing toggle, suspension + capacity fixes |

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
- Settings: `user_settings` (`preferred_unit` kg | lb) — migration `20261016000001`

Workout logging (migration `20261016000001_train_workout_logging`):
- `exercises.tracking_type` (`weight_reps` | `bodyweight_reps` | `weighted_bodyweight` | `assisted_bodyweight` | `duration`), `bw_factor`, `is_custom`. Library rows get `tracking_type` derived on insert when not supplied. Custom exercises are visible only to their creator and are created only via `create_custom_exercise`.
- `workout_logs` + `status` (`in_progress` | `completed` | `discarded`), `edited_at` (set by trigger on any change to a completed log or its children), `bodyweight_snapshot_kg`. `completed_at` is the end time.
- `workout_log_exercises` + `replaced_from_exercise_id`. `order_index` is 0-based.
- `workout_log_sets` + `set_type` (`warmup` | `working` | `drop`), `entered_weight` / `entered_unit` (exactly as typed), `added_kg`, `assist_kg`, `rpe`. `weight_kg` is canonical kg; `set_number` is 1-based.
- PRs: `check_and_update_personal_record` counts only completed **working** sets — heaviest weight + Epley e1RM (≤ 10 reps) for `weight_reps`, heaviest added weight for `weighted_bodyweight`, most reps for `bodyweight_reps` / `assisted_bodyweight`, longest hold for `duration`. Fires on insert only.

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
| `coach_profiles`         | coach bio, specialties, certs, capacity, `status` (pending/approved/suspended), `is_listed` (shown in directory) | coach (admin approves) |
| `coaching_plans`         | coach plan options, display-only price               | coach |
| `coaching_relationships` | athlete ↔ coach; pending/active/ended/declined; one open Captain per athlete; `source` (`directory` / `invite`), `invitation_id` | RPCs only |
| `coaching_invitations`   | single-use invite codes from a Captain; only `sha256(code)` + last 4 chars stored; expires in 1–30 days | RPCs only (Captain reads own) |
| `coaching_permissions`   | athlete consent: workouts, prs, skill progress, body metrics | RPC create, athlete update |
| `coaching_goals`         | goals set by the Captain                             | coach |
| `coaching_feedback`      | append-only messages on workouts/skills              | either party |
| `coaching_private_notes` | coach-only notes, never readable by athlete          | coach |
| `program_assignments`    | coach assigns own program to athlete                 | RPCs only |

## 3. Removed (migration 26)
`posts`, `post_likes`, `post_comments`, `activities`, `activity_comments`, `friendships`, `blocks`, `user_challenges`, `user_challenge_participants`, view `v_friend_activity_feed`, functions `are_friends`, `is_blocked`, `get_global_xp_leaderboard`, `get_friends_xp_leaderboard`, post like/comment handlers, enums `friend_request_status` and `activity_type`.
Leftovers: old social values stay inside `notification_type` (Postgres cannot drop enum values). Delete the empty `post-media` bucket in the dashboard.

## 4. Access model (Connect)
- Captain reads athlete data only when the relationship is `active` AND the matching permission is on AND the Captain is `approved` (suspension cuts access immediately — `20261020200000`).
- Scopes → tables:
  - `workouts`: `workout_logs`, `workout_log_exercises`, `workout_log_sets`, `user_streaks`
  - `prs`: `personal_records`, `personal_record_history`, `roadmap_personal_bests`
  - `progress`: `skill_progress`, `user_skill_stage_progress`, `user_objective_progress`, `xp_transactions`, `user_achievements`, `roadmap_workout_logs`, `roadmap_workout_log_exercises`
  - `body`: `body_metrics_log`
- Coaches have **no write policy** on any athlete log. History stays trustworthy.
- Ending a relationship removes access immediately.
- Coach programs are `is_official = false`, visible only to the coach and assigned athletes.

## 5. Helper functions
`is_admin()`, `is_coach()`, `in_relationship(rel)`, `is_active_coach_of(rel)`, `coach_can_view(athlete, scope)`, `can_view_program(program)`. `is_active_coach_of` and `coach_can_view` require an approved Captain. `invite_code_hash(code)` is internal (no client EXECUTE).

## 6. RPCs
| RPC | Caller | Effect |
|-----|--------|--------|
| `get_coach_directory(specialty, limit)` | any user | approved, listed coaches + athlete count |
| `get_coach_card(coach)`                 | any user | one approved coach's public card (listed or not), incl. bio/approach/certifications |
| `choose_captain(coach, plan, share_*)`  | athlete | creates pending relationship + permissions |
| `respond_to_coaching_request(rel, accept)` | coach | pending → active / declined; accept re-checks `max_athletes` and needs an approved Captain |
| `create_coaching_invitation(note, valid_days)` | approved coach | returns the plain code once (`XXXXX-XXXXX`); max 20 open |
| `revoke_coaching_invitation(invitation)` | coach | closes an open invite |
| `preview_coaching_invitation(code)`     | athlete | who sent the code (public card fields); same error for invalid/expired/used |
| `accept_coaching_invitation(code, share_*)` | athlete | creates an **active** relationship (or completes a pending request to the same coach); checks capacity; consumes the code |
| `get_captain_hub()`                     | coach | jsonb: profile, pending requests, active clients (+ workout stats only if shared), open invites, invites used. Null if no Captain profile |
| `get_client_workouts(athlete, limit)`   | athlete / coach | completed-workout summaries; coach needs `coach_can_view(athlete,'workouts')` |
| `end_coaching(rel)`                     | either  | closes relationship |
| `assign_program(rel, program, start, notes)` | coach | creates assignment |
| `start_assigned_program(assignment)`    | athlete | creates enrollment, status in_progress |
| `complete_assignment(assignment)`       | athlete / active coach | marks completed, closes the enrollment |
| `finish_workout(p_workout jsonb)`       | athlete | Train: one transaction — log, exercises, completed sets, bodyweight snapshot, template additions, completion. Idempotent on the client-generated id |
| `create_custom_exercise(name, tracking_type, equipment, bw_factor)` | user | Train: custom exercise, unique name per user (case-insensitive) |
| `create_template_from_workout(log, name)` | user | Train: "Save as template" from a completed log |
| `get_last_exercise_performance(exercise)` | user | Train: sets from the caller's last completed session of an exercise |
| `complete_roadmap_workout(...)`         | athlete | Progress: logs roadmap workout, awards XP |
| `record_roadmap_personal_best(...)`     | athlete | Progress: roadmap PR upsert |

## 7. Known gaps
- ~~Assigned program completion~~ — resolved in 32 (`complete_assignment`).
- ~~Private profile fields~~ — resolved in 32 (column allowlist + `get_my_private_profile` / `get_athlete_body_profile`).
- Approving / suspending a Captain: edit `coach_profiles.status` in the Supabase dashboard (allowed since `20261020200000`; app users still need `is_admin()`).
- No program builder for Captains yet, so `assign_program` has no UI.
- No payments; plan prices are display only.
- Certification (Complete/Master/Legendary) lives in skill structure, not a dedicated table.
