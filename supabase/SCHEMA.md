# Grit — SCHEMA.md

Status: after migrations 0001–0032 (+ later TRAIN additions noted inline, + Captain Hub `20261020200000`, + Gym Partner Platform `20261029120000`) · Backend: Supabase (Postgres, Auth, RLS, Storage, Realtime)
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
| 20261024200000 | `athlete_analytics_body_recovery` | body measurements, `body_goals`, private `progress_photos` + bucket, `recovery_checkins` |
| 20261028120100 | `marketplace_listings`    | provider directory listings (coach / gym / PT / doctor), admin approval |
| 20261029120000 | `gym_partner_platform`    | gyms, staff roles, branches, offers, gallery + `gym-media` bucket, coach invitations/affiliations, partnerships + AI allowance/usage, inquiries, profile views |
| 20261029140000 | `health_providers`        | doctors & physiotherapists: health profiles, credentials (verified vs provider-submitted), saved providers, `health-media` + private `health-credentials` buckets. Discovery only — no booking |

## 2. Table map by pillar

### Shared / identity
- `profiles` — one row per auth user; `role` = `user` | `admin`
- `body_metrics_log` — weight/height history, plus optional body fat % and neck/chest/waist/hips/arm/thigh/calf (cm) and a note (migration `20261024200000`; plausibility check is `NOT VALID`, so only new/changed rows are checked)
- `body_goals` — one optional bodyweight goal per user (`target_weight_kg`, `start_weight_kg`, `target_date`); owner CRUD
- `progress_photos` — private progress photos; objects live in the **private** `progress-photos` bucket at `<user_id>/<file>`; owner-only table + storage policies, **no coach access**
- `recovery_checkins` — one per user per local date (`sleep_hours`, `sleep_quality`, `soreness`, `energy`, `fatigue` on 1–5, `note`); owner-only, **no coach access**
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

### GYMS (Gym Partner Platform) — `20261029120000`
No membership, attendance, payment or financial data in this phase. A gym's public fields live on its `marketplace_listings` row (`provider_type = 'gym'`); `gyms` adds the rest.

| Table | Purpose | Written by |
|-------|---------|------------|
| `gyms` | 1:1 with a gym listing: owner, multi-branch flag, cover, facilities / equipment / services, coach code (`sha256` + last 4 + expiry), `submitted_at` | owner/manager/marketing (column guard); code via RPC only |
| `gym_staff` | (gym, user, role) — `owner` (exactly one), `manager`, `marketing`, `front_desk` | RPCs only |
| `gym_staff_invites` | single-use team codes, hashed, 7 days | RPCs only |
| `gym_branches` | name, address, area, city, phone, `opening_hours` jsonb or `open_24h`, facilities, `is_published` (needs hours), soft delete | owner/manager |
| `gym_offers` | gym-entered public offers: name, optional price (null = "ask the gym"), currency, duration, benefits, branch ids (empty = all), visible, soft delete | owner/manager/marketing |
| `gym_photos` | gallery, max 12; objects in **public** `gym-media` bucket at `<gym_id>/<file>` (8 MB, jpeg/png/webp) | owner/manager/marketing |
| `gym_coach_invitations` | `gym_invite` (by coach email) or `coach_request` (coach used the gym code); pending / accepted / declined / cancelled / expired; 14 days | RPCs only |
| `gym_coaches` | active / ended coach ↔ gym affiliation (role, branches). Never grants access to a coach's clients or data | RPCs only |
| `gym_partnerships` | one open partnership per gym; status, dates, `ai_monthly_allowance`, `ai_per_coach_cap`, `ai_features` | **Grit admins only** (gym can only *request*) |
| `ai_usage_events` | one row per AI action (gym, coach, feature, units) | `consume_ai_allowance` (service_role) only |
| `gym_inquiries` | "Ask about joining": name, phone, contact method, message, branch/offer; new / contacted / closed | visitor via RPC; staff update status via RPC |
| `gym_profile_views` | one row per viewer per gym per day | `record_gym_view` only; no client table access |

Listing state (`gym_listing_state`): `draft` → (publish) → `pending_review` → (admin approves listing) → `published`; owner can unpublish (`marketplace_listings.is_published = false`). Changing name/contact on an approved listing sends it back to review (existing listing guard). `suspended` = admin.

Access: public reads (listing, published branches, visible offers, photos, active coaches) only when `gym_is_public(gym)`. Staff read everything for their gym; writes follow `gym_has_role(gym, …)`. Coaches see their own invitations/affiliations. The coach-code hash and staff-code hash are hidden by column grants.

### HEALTH (doctors & physiotherapists) — `20261029140000`
Discovery and contact only: no appointments, slots, payments, consultations, medical records or AI. A provider's public card is their `doctor` / `physical_therapist` `marketplace_listings` row (name, `headline` = professional title, `description` = bio, `specialties`, `logo_url` = photo, contacts, location).

| Table | Purpose | Written by |
|-------|---------|------------|
| `health_profiles` | 1:1 with a health listing: experience, languages, services, `service_modes` (clinic / home), clinic name, general availability note, optional consultation fee, external `booking_url` (https), `show_phone` / `show_whatsapp` consent, `phone_verified_at`, `submitted_at` | owner (review fields: RPC / admin only) |
| `health_credentials` | licence / degree / certification / membership; `status` submitted (no document, shown "provider-submitted") → pending (document uploaded) → verified / rejected (**admin only**). Editing a verified one drops it back. Documents in the **private** `health-credentials` bucket | owner; status by admin |
| `saved_providers` | a user's saved providers (private) | user |

Access: other users can no longer read health listings straight from `marketplace_listings`; they go through `get_health_directory` / `get_health_provider`, which return phone/WhatsApp only when the provider switched them on and never return credential documents. Visible = listing approved + `is_published` + submitted. Changing name or contact on an approved profile sends it back to review (existing listing guard); changing the phone clears `phone_verified_at`.

## 3. Removed (migration 26)
`posts`, `post_likes`, `post_comments`, `activities`, `activity_comments`, `friendships`, `blocks`, `user_challenges`, `user_challenge_participants`, view `v_friend_activity_feed`, functions `are_friends`, `is_blocked`, `get_global_xp_leaderboard`, `get_friends_xp_leaderboard`, post like/comment handlers, enums `friend_request_status` and `activity_type`.
Leftovers: old social values stay inside `notification_type` (Postgres cannot drop enum values). Delete the empty `post-media` bucket in the dashboard.

## 4. Access model (Connect)
- Captain reads athlete data only when the relationship is `active` AND the matching permission is on AND the Captain is `approved` (suspension cuts access immediately — `20261020200000`).
- Scopes → tables:
  - `workouts`: `workout_logs`, `workout_log_exercises`, `workout_log_sets`, `user_streaks`
  - `prs`: `personal_records`, `personal_record_history`, `roadmap_personal_bests`
  - `progress`: `skill_progress`, `user_skill_stage_progress`, `user_objective_progress`, `xp_transactions`, `user_achievements`, `roadmap_workout_logs`, `roadmap_workout_log_exercises`
  - `body`: `body_metrics_log`, `body_goals` (never `progress_photos` or `recovery_checkins`)
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
| `create_gym(name, city, phone, email, multi_branch)` | signed-in user | Gyms: creates listing (pending) + gym (draft) and makes the caller owner |
| `get_my_gyms()` | user | Gyms: gyms the caller is staff at, with role |
| `set_gym_published(gym, publish)` | owner/manager | Gyms: publish (checks description ≥ 20 chars, cover, a published branch with hours) or unpublish; returns listing state |
| `gym_listing_state(gym)` | staff | Gyms: draft / pending_review / published / unpublished / suspended |
| `get_gym_directory(search, city, facility, limit)` | any user | Gyms: published gyms, partner badge, lowest visible offer price |
| `get_gym_public_coaches(gym)` | any user | Gyms: active coaches of a public gym (public card fields only) |
| `record_gym_view(gym)` | any user | Gyms: counts one view per viewer per day |
| `submit_gym_inquiry(gym, name, phone, method, message, branch, offer)` | signed-in user | Gyms: inquiry; 3 per gym and 15 total per day |
| `set_gym_inquiry_status(inquiry, status)` | owner/manager/front_desk | Gyms: new / contacted / closed |
| `get_gym_admin_overview(gym)` | staff | Gyms: jsonb counts — listing, setup checklist, views (30 days + 14-day series), inquiries (if role allows), coaches, partnership + AI used this month |
| `get_gym_coaches_admin(gym)` | owner/manager | Gyms: affiliations (+ AI used this month), invitations (90 days), code hint/expiry |
| `invite_gym_coach(gym, email, role, branches, message)` | owner/manager | Gyms: invites an approved Grit coach by account email |
| `rotate_gym_coach_code(gym)` | owner/manager | Gyms: new 7-day coach code `XXXX-XXXX`, returned once |
| `request_gym_affiliation(code)` | approved coach | Gyms: coach asks to join with the gym code (gym approves) |
| `respond_gym_invitation(invitation, accept)` | coach (gym invite) / owner·manager (coach request) | Gyms: accept creates the affiliation |
| `cancel_gym_invitation(invitation)` | sender | Gyms: cancels a pending invitation/request |
| `end_gym_affiliation(affiliation)` | coach or owner/manager | Gyms: ends it; the coach keeps their clients and data |
| `get_my_gym_affiliations()` | coach | Gyms: active affiliations + open invitations |
| `get_my_ai_entitlement()` | coach | Gyms: AI allowance through an active partnership (features, pool, per-coach cap, used, reset date) |
| `consume_ai_allowance(coach, feature, units)` | **service_role only** | Gyms: checks partnership/feature/allowance/cap and records usage. For a future AI Edge Function |
| `request_gym_partnership(gym)` | owner/manager | Gyms: opens a `pending_review` partnership for Grit to review |
| `create_gym_staff_invite(gym, role)` | owner | Gyms: single-use 7-day team code, returned once |
| `accept_gym_staff_invite(code)` | user | Gyms: joins the team with that role |
| `set_gym_staff_role(gym, user, role)` / `remove_gym_staff(gym, user)` | owner | Gyms: never the owner seat |
| `get_gym_staff(gym)` | staff | Gyms: team list with names and roles |
| `create_health_profile(kind, name, specialty, city, phone)` | signed-in (non-guest) user | Health: private draft listing + profile; one per type per user |
| `submit_health_profile(listing)` | owner | Health: checks title, bio (40+), specialty and one public contact; sends to review |
| `set_health_profile_visible(listing, visible)` | owner | Health: hide / show a submitted profile |
| `get_health_directory(search, kind, specialty, mode, verified_only, city, limit)` | any user | Health: listed providers, `license_verified`, `is_saved` |
| `get_health_provider(listing)` | any user (owner: preview) | Health: public profile; consented contacts only; credentials without documents |
| `get_my_saved_providers()` | user | Health: saved providers still listed |

## 7. Known gaps
- ~~Assigned program completion~~ — resolved in 32 (`complete_assignment`).
- ~~Private profile fields~~ — resolved in 32 (column allowlist + `get_my_private_profile` / `get_athlete_body_profile`).
- Approving / suspending a Captain: edit `coach_profiles.status` in the Supabase dashboard (allowed since `20261020200000`; app users still need `is_admin()`).
- No program builder for Captains yet, so `assign_program` has no UI.
- No payments; plan prices are display only.
- Certification (Complete/Master/Legendary) lives in skill structure, not a dedicated table.
- Gyms: **no AI service is connected yet.** Allowances and usage tracking are in place; an AI Edge Function (holding the model key server-side) must call `consume_ai_allowance` before each action. The app shows every AI feature as "Not connected yet".
- Gyms: partnerships and AI allowances are set by Grit admins in the Supabase dashboard (`gym_partnerships`); listing approval is `marketplace_listings.status`.
- Health: approving profiles (`marketplace_listings.status`), verifying credentials (`health_credentials.status = 'verified'`) and phones (`health_profiles.phone_verified_at`) are done by Grit admins in the Supabase dashboard; there's no admin UI yet.
- Gyms: invitations and inquiries are in-app only (no email/push yet). `invite_gym_coach` reveals whether an email belongs to an approved coach, to a gym owner/manager.
