# Connect: spec vs. what already exists

Compares the Phase 2 Connect spec (captains / coaching_relationships /
coaching_permissions / `is_active_captain_of`) against the Connect schema
already applied to the linked project (migrations 27–32). Checked against the
live database on 2026-10-16 (policies read from `pg_policies`, not only from
the migration files; they match).

**Conclusion:** the spec is already implemented, mostly under different names.
No duplicate tables were created. Remaining gaps are listed in §4; none are
fixed yet except one advisor index (§5).

In the database the Captain is called `coach` (`coach_profiles`, `coach_id`,
`coach_can_view`). "Captain" is the in-app term. That's a naming difference only.

## 1. Object mapping

### captains → `coach_profiles`

| Spec field | Existing | Notes |
|---|---|---|
| user_id | `id` (PK, → `profiles.id`) | one coach profile per user |
| display_name | `profiles.display_name` | kept on profiles, not duplicated |
| photo_url | `profiles.avatar_url` | kept on profiles |
| bio | `bio` | |
| specialties text[] | `specialties text[]` | |
| training_focus | `headline`, `approach` | closest match; no single `training_focus` column |
| years_experience | `experience_years` | |
| certifications text[] | `certifications text[]` | |
| is_accepting_athletes | `accepting_athletes` | plus `max_athletes` (capacity) |
| created_at / updated_at | same | |
| — | `status` (pending / approved / suspended) | admin approval; only an admin can change it (`guard_coach_status`) |

Access: spec says "readable by all authenticated users". Existing is **stricter**:
other users see only `approved` coaches (owner and admin see their own/all).
Directory listing goes through `get_coach_directory()`. Editable only by the
owner (and admin); the owner can't change their own `status`.

### coaching_relationships → `coaching_relationships`

| Spec | Existing |
|---|---|
| id, athlete_id | same |
| captain_id | `coach_id` (→ `coach_profiles.id`) |
| status pending/active/ended/declined | `coaching_status` enum, same four values |
| requested_at, started_at, ended_at | same |
| — | `plan_id` (display-only pricing), `ended_by` |
| athlete creates the request | `choose_captain(coach, plan, share flags…)`, athlete-only |
| Captain accepts / declines | `respond_to_coaching_request(rel, accept)`, coach-only, pending only |
| either side can end | `end_coaching(rel)`, athlete or coach, pending or active |
| one active per athlete | unique partial index `uq_one_open_captain (athlete_id) where status in ('pending','active')`, which is **stricter**: one *open* (pending or active) relationship per athlete |

No insert/update/delete policies exist on the table: every state change goes through
the three RPCs.

### coaching_permissions → `coaching_permissions`

| Spec flag | Existing flag | Scope in `coach_can_view` | Tables it unlocks |
|---|---|---|---|
| can_view_workouts | `share_workouts` (default true) | `'workouts'` | workout_logs, workout_log_exercises, workout_log_sets, user_streaks |
| can_view_prs | `share_prs` (default true) | `'prs'` | personal_records, personal_record_history, roadmap_personal_bests |
| can_view_skill_progress | `share_skill_progress` (default true) | `'progress'` | skill_progress, user_skill_stage_progress, user_objective_progress, xp_transactions, user_achievements, roadmap_workout_logs, roadmap_workout_log_exercises |
| can_view_goals | none | none | see §4, G1 |
| can_view_analytics | none (decision: analytics fall under `share_workouts`) | `'workouts'` | see §4, G7 |
| — | `share_body_metrics` (default **false**) | `'body'` | body_metrics_log, `get_athlete_body_profile()` |

One row per relationship (`relationship_id` is the PK), created by `choose_captain`
with the flags the athlete picks at request time.

### is_active_captain_of(athlete, scope) → `coach_can_view(athlete, scope)`

Same contract: true only when the caller is the coach of an `active` relationship
with that athlete **and** the scope's `share_*` flag is on. Used by every
`coach_read_*` policy. (`is_active_coach_of(relationship_id)` is a different
helper: relationship-level, used for coach-authored goals/notes/assignments.)

## 2. Rule verification (static: live policy definitions + RPC bodies)

| # | Rule | Result | Evidence |
|---|---|---|---|
| R1 | Captain reads athlete data only when relationship is active AND the matching share flag is on | **PASS for rows; FAIL for one column** (G11), plus G2 | All 15 `coach_read_*` select policies use `coach_can_view(user_id, scope)`, which requires `status = 'active'` and the scope flag. No other non-owner select policy exists on any athlete table. |
| R2 | Captain has no insert/update/delete on athlete workout history, sets, PRs | **PASS** | The only write policies on those tables are owner-scoped (`user_id = auth.uid()`). PRs and streaks have no client write policy at all. SECURITY DEFINER functions that write them (`upsert_personal_record`, `check_and_update_personal_record`) aren't executable by `authenticated`. `finish_workout` is security invoker and always writes as the caller. |
| R3 | Ending removes access immediately | **PASS** | `coach_can_view` reads `status` on every query; `end_coaching` sets `status = 'ended'`. No cached grant or token. Relationship-scoped content stays readable after end (G3). |
| R4 | Only one active relationship per athlete | **PASS** (stricter) | `uq_one_open_captain` exists live: one pending-or-active row per athlete, enforced by the database, race-free. |
| R5 | Athlete controls share flags; Captain can't change them | **PASS** (minor note, G5) | Only update policy on `coaching_permissions` is `coaching_perm_athlete_update` (athlete of the relationship). No insert/delete policies; rows are created only by `choose_captain`, as the athlete. Captain has select only. |

These verdicts come from reading the definitions, **not** from running the tests.
`docs/connect_rls_tests.sql` exercises all five rules; it hasn't been run yet
(needs a local stack or a branch).

## 3. Goals

There is **no athlete-owned goals table.** The only goals table is
`coaching_goals`: relationship-scoped, **created and updated only by the
Captain** (`coaching_goals_coach_insert` / `_coach_update`), readable by both
sides. A `share_goals` flag would mean hiding from the Captain the goals the
Captain wrote, so it doesn't fit. **`share_goals` was not added**; decision
needed (G1).

## 4. Gaps and risks

| ID | Severity | Gap |
|---|---|---|
| G1 | decision | **`share_goals`**: no athlete-owned goals table exists (§3). Either drop the idea, or define what athlete goals are first (a new table would be a feature, not a permission). |
| G11 | medium | **Body weight leaks through `share_workouts`.** `20261016000001_train_workout_logging.sql` added `workout_logs.bodyweight_snapshot_kg`. `coach_read_workout_logs` exposes the whole row under `share_workouts`, so a Captain reads the athlete's body weight even with `share_body_metrics` off. Fix options: column-level grant + an RPC, or move the snapshot out of `workout_logs` into a body-scoped read path. |
| G2 | medium | **Suspended coach keeps access.** `coach_can_view` checks the relationship, not `coach_profiles.status`. If an admin suspends a coach, they still read every active athlete's data until each relationship is ended. Fix: also require `status = 'approved'` in `coach_can_view` / `is_active_coach_of` (small migration, `create or replace function`). |
| G3 | low / product | **Relationship content after it ends.** `coaching_goals`, `coaching_feedback`, `program_assignments` select via `in_relationship()` (any status), and `coaching_private_notes` stays readable by its author. A former Captain still reads goals/feedback/notes from that relationship. None of it is athlete log data, but confirm it's intended. |
| G4 | medium | **Capacity can be exceeded.** `choose_captain` counts active athletes then inserts, with no lock (two concurrent requests can both pass), and `respond_to_coaching_request` doesn't re-check `max_athletes` on accept, so accepting several pending requests can exceed it. |
| G5 | low | `coaching_perm_athlete_update` has no `WITH CHECK` (USING is reused) and doesn't check status: the athlete can still edit flags on ended/declined relationships. Harmless today (those grant nothing). |
| G6 | low / functional | **Custom exercise names hidden from the Captain.** `exercises` RLS shows custom exercises only to their creator, so a Captain reading an athlete's log sees the `exercise_id` but can't read that exercise's name. Needs a `coach_can_view(created_by, 'workouts')` read path on custom exercises. |
| G7 | low | **Analytics under `share_workouts`.** Client-computed stats from logs are covered. But `user_aggregate_records` (server-side aggregates) has no coach policy, so a Captain can't read it even with `share_workouts` on. Add a `coach_read_*` policy if the Captain UI needs it. |
| G8 | info | Coach **writes one athlete-owned row**: `complete_assignment` (coach, active relationship) sets `user_program_enrollment.completed_at/is_active`. Not workout history, and documented in CLAUDE.md, but it is the one exception to "coaches don't write athlete rows". |
| G9 | info | `notify_coaching_event` notifies on request/accept/decline but not when a relationship is **ended**. |
| G10 | info | Spec defaults "all true". Existing: body metrics default **off**, and flags are chosen at request time (`choose_captain` args), not at accept time. |

## 5. Advisors (2026-10-16)

**Security**
- `authenticated_security_definer_function_executable` (WARN ×18): every
  client RPC and RLS helper (`choose_captain`, `coach_can_view`, `is_admin`, …).
  Intentional: these are the RPC-only write paths and policy helpers, each scoped
  to `auth.uid()`. Not changed.
- `auth_leaked_password_protection` (WARN): dashboard setting (Auth → Passwords),
  not a migration.

**Performance**
- `unindexed_foreign_keys` (INFO ×1): `coaching_relationships.ended_by`.
  **Fixed** in `20261016171751_coaching_relationships_ended_by_index.sql`.
- `auth_rls_initplan` (WARN ×39): policies calling `auth.uid()` per row instead of
  `(select auth.uid())`, on Connect tables and on most older tracker/progress tables.
  Mechanical fix, but it recreates 39 policies across ~30 tables. **Not done.**
- `multiple_permissive_policies` (WARN ×240): owner-select + coach-select (and
  public-select + admin-write) on the same table/action. Mostly inherent to the
  Connect design; merging policies is a larger refactor. **Not done.**
- `unused_index` (INFO ×78): the project has almost no traffic yet (2 users, 0
  workout logs), so "unused" carries no signal. Not changed.
