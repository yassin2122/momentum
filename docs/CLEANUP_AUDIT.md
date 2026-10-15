# Cleanup Audit — Phase 1

Read-only. Nothing in `mobile/` or `supabase/` was changed to produce this; the only new files are this document and `docs/PRODUCT.md` (see Finding 0). Branch: `cleanup/revival`, based on `main` @ `59164a6`.

## Finding 0 — `docs/PRODUCT.md` doesn't exist, and the only candidate text contradicts your brief

`docs/PRODUCT.md` is not on disk and not in git at that path. The only document with that name anywhere in history is `archive/docs/PRODUCT.md` (deleted from the working tree, recovered from `HEAD` and placed at `docs/PRODUCT.md` so I had something to read). It describes **Connect as a social feed**: Friends, Activity Feed, Challenges, Leaderboards, Community likes/comments — the opposite of your brief ("Connect = online coaching, NOT a social feed").

The schema confirms your brief is the current, correct direction, not the old doc:
- Migrations 1–25 build the social layer described in that `PRODUCT.md` (`posts`, `friendships`, `activities`, `user_challenges`, leaderboard RPCs — see migration `21_momentum_connect_additions.sql`).
- Migration `26_remove_social.sql` deletes all of it.
- Migrations `27`–`32` build a *different* Connect: coach/athlete relationships, permission-gated read access, program assignment — matching your brief exactly.

So: **this document is stale by one full pivot** and should not be used as source of truth in its current form. I used your inline brief + `supabase/SCHEMA.md` as the real spec for this audit. Recommend rewriting `docs/PRODUCT.md` from scratch (or heavily editing it) before Phase 2, so there's a single written spec that matches the schema instead of contradicting it. I did not rewrite it myself — that's a product-content call, not a cleanup call.

---

## 1. Repo map

| Path | What it is | Verdict |
|---|---|---|
| `mobile/` | the Flutter app | KEEP (see §2–6) |
| `supabase/` | migrations + `SCHEMA.md`, CLI-linked | KEEP |
| `docs/` | just created this phase (`PRODUCT.md` recovered, `CLEANUP_AUDIT.md` this file) | KEEP |
| `archive/docs/*.md` | ARCHITECTURE, BRAND_GUIDE, DESIGN_SYSTEM, MIGRATION_NOTES, PRODUCT, SETUP | MIXED — see §1a |
| `archive/lib.zip` | a 170-file snapshot of `mobile/lib` from Aug 12–16 | REMOVE candidate — see §1a |
| `app_design/*.png` | 5 UI mockups: dashboard, friends, login, register, splash | MIXED — `friends screen.png` is a dropped feature; the other 4 are still-relevant screens |
| `free-exercise-db/` | full vendored clone of the public exercise dataset repo (104 MB: `.github/`, `Makefile`, `dist/`, `site/`, per-exercise JSON+images) | REMOVE candidate — see §1a |
| `node_modules/`, `package.json`, `package-lock.json` | one declared dependency, `@supabase/server`, with **zero** references anywhere in the repo outside `node_modules` itself | REMOVE candidate — see §1a |
| `.idea/` | JetBrains IDE project settings | leave alone (editor-local, harmless) |

### 1a. Detail on the mixed/remove items

- **`archive/docs/ARCHITECTURE.md`, `BRAND_GUIDE.md`, `DESIGN_SYSTEM.md`, `MIGRATION_NOTES.md`, `SETUP.md`**: these predate the social→coaching pivot the same way `PRODUCT.md` does. `ARCHITECTURE.md`'s ERD and RLS-tier writeup still describe `posts`/`friendships`/`activities` as live tables. Useful for historical context (storage bucket setup, RLS-tier reasoning, soft-delete strategy are still accurate), not safe to read as current. Recommend keeping them under `archive/` (clearly out of the way) rather than deleting outright — they're small (plain markdown) and explain *why* some current patterns exist.
- **`archive/docs/PRODUCT.md`**: superseded by the new `docs/PRODUCT.md` once that gets rewritten. Once that happens, this copy is pure historical duplicate — fine to delete then.
- **`archive/lib.zip`**: a snapshot of the exact same `mobile/lib` tree that's already in `HEAD` (compare: 171 files in `HEAD` now vs. 170 in the zip, same paths, same feature folders). It adds no information `git log`/`git show` doesn't already give you, and it's a binary blob nobody can diff or grep without unzipping. REMOVE — recommend deleting once you've confirmed (as this audit did) that everything in it is reachable via git history.
- **`app_design/friends screen.png`**: mockup for the dropped Friends feature. REMOVE — matches nothing in the current brief. The other 4 mockups (dashboard/login/register/splash) still correspond to pillars/screens that exist.
- **`free-exercise-db/`**: this was the one-time import source for the exercise library (see `archive/docs/SETUP.md` §6 and the newest migration's own comment — `supabase/migrations/20260806000001_exercise_missing_fields.sql:1-2` says "Store all free-exercise-db fields that were missing"). It's already been mined into the schema (`force`, `mechanic`, `images[]`, `level` columns). Nothing in the app or migrations reads from this folder at runtime — it's a one-time ETL source, not a dependency. REMOVE from the repo (link to the upstream GitHub repo in a doc instead, if you want it as a reference) — 104 MB of someone else's dataset, images included, has no reason to live in a Flutter/Postgres app repo and is itself a separate project with its own CI/license/Makefile.
- **`node_modules/`, `package.json`, `package-lock.json`**: `@supabase/server` is referenced nowhere outside `node_modules`. No script in the repo invokes Node. This looks like a one-off `npm install` that was never used and then got swept into the "add all project files" commit. REMOVE — and this is also the single biggest repo-hygiene problem: **there is no `.gitignore`** (removed in commit `59164a6`, "Remove gitignore and add all project files"), so `node_modules/` (thousands of files), `mobile/build/`, and `supabase/.temp/` are all tracked in git, and **`supabase/.env` — containing `SUPABASE_SERVICE_ROLE_KEY` — is committed**. That key bypasses RLS entirely. Recommend: add a `.gitignore` back, remove these paths from tracking, and rotate the service-role key in the Supabase dashboard since it's already been committed. This is independent of the Flutter/schema cleanup but should happen in the same pass since it's a credential exposure, not just tidiness. I have not touched the key or git history — flagging for your explicit go-ahead given how destructive history-rewriting is.

---

## 2. Flutter (`mobile/`) — feature folders by pillar

| Folder | Pillar | Status | Why |
|---|---|---|---|
| `core/` | — | FIX | Solid foundation (theme tokens, error types, widgets, routing). `app_router.dart`/`app_shell.dart` wire a 5-tab nav (Dashboard/Workouts/Exercises/Statistics/Profile) with **no Progress or Connect tab at all** — those pillars are unreachable in the running app. |
| `features/auth/` | shared | KEEP | Clean-architecture, fully wired (router → screens → providers → usecases → repository → datasource), only one touches raw Supabase auth. No issues found. |
| `features/dashboard/` | Train/Progress mix | FIX | Two competing implementations in one folder — see §5. The wired one (`dashboard_screen.dart`) pulls in `community_feed_section.dart`, a Connect-as-social leftover — see §3. |
| `features/workout/` (singular) | Train | FIX/ORPHAN | One file, `workout_repository.dart` — correctly targets the real schema (`workout_logs`, `workout_log_sets`, etc.) but **imports two files that don't exist** (`core/models/exercise.dart`, `core/models/workout.dart`) and **is not imported by anything else in the app**. Dead-on-arrival despite being the most schema-correct workout code in the repo. |
| `features/workouts/` (plural) | Train | FIX | This is the one actually wired into the router (`workouts_screen.dart`). `data/`, `domain/` are empty `.gitkeep` stubs — no repository, no model, no use case. The screen itself has no social references (checked). |
| `features/exercises/` | Train | FIX — schema mismatch | Fully wired, clean architecture, but queries two views and one table that **do not exist in any migration** — `exercise_library_view`, `exercise_library_facets_view`, `favorites`. See §4, finding A. This is your most-used screen and it cannot work against the real database as written. |
| `features/roadmap/` | Progress | FIX/split | Two generations mixed together — see §5. The newer `data/` layer (`roadmap_repository.dart`, `achievements_repository.dart`) correctly queries current tables (`roadmap_categories`, `skills`, `skill_progress`, etc.) but, like `workout_repository.dart`, imports nonexistent `core/models/*.dart` files and is unused by anything. The older `presentation/pages/` (`galaxy_page.dart`, `planet_page.dart`, `roadmap_page.dart`, `achievements_page.dart`) import a whole missing `application/` provider layer + `core/logic/planet_logic.dart`, and aren't registered in the router either. **Net result: Progress has zero working UI and zero wired data layer.** |
| `features/statistics/` | Train | FIX | Only a bare screen exists (`statistics_screen.dart`), wired into router; `data/`/`domain/` are empty stubs. No PR/analytics data layer behind it yet (matches `PRODUCT.md`'s "Analytics" feature list, which is unbuilt). |
| `features/profile/` | shared | FIX | Only a bare screen exists, wired, no data layer. No social refs found. |
| `features/history/` | Train | UNSURE | 100% empty `.gitkeep` scaffold, no screen at all, not routed. Either an intentional placeholder for "workout history" (a named `PRODUCT.md` Train feature) or dead scaffolding — your call whether to keep the folder or let it get recreated when the feature is actually built. |
| `shared/widgets/motra_bottom_nav.dart` | — | ORPHAN | A complete, self-consistent 4-tab nav (Dashboard/Achievements/Roadmap/Profile — note: still not the 3-pillar TRAIN/PROGRESS/CONNECT shape your brief wants) with its own `MotraShell`. **Nothing imports it.** It references `AppRoutes.achievements`, `.roadmap`, `.start`, none of which exist on `AppRoutes`. This reads like an abandoned attempt to replace `app_shell.dart` that was never finished or wired in. |

No feature folder currently represents **Connect** at all — there's no `features/connect/` or `features/coaching/` directory, no screen, no repository, despite Connect being a fully-built, well-designed pillar in the Postgres schema (migrations 27–32, RLS, RPCs — see §7). This is the single largest gap between schema and app.

---

## 3. Social leftovers (Connect-as-feed residue)

Everything below conflicts with your brief ("remove all social features: FYP, photo posts, likes, comments, activity feed, friends, friend challenges, leaderboards").

**In the Flutter app:**
- `mobile/lib/features/dashboard/presentation/widgets/community_feed_section.dart` — a complete "Community Feed" widget (`CommunityPost`, `CommunityPostCard`, like/comment engagement row), imported and rendered by the currently-wired `dashboard_screen.dart:6`.
- `app_design/friends screen.png` — mockup asset for a Friends screen that was never built in Flutter (no `features/friends/` or `features/social/` folder exists), but documents the intent.

**In the database (already mostly cleaned up by migration 26, included here for completeness since your brief asks me to list every reference):**
- Tables dropped by `26_remove_social.sql`: `posts`, `post_likes`, `post_comments`, `activities`, `activity_comments`, `friendships`, `blocks`, `user_challenges`, `user_challenge_participants`.
- Functions dropped: `are_friends()`, `is_blocked()`, `get_global_xp_leaderboard()`, `get_friends_xp_leaderboard()`.
- View dropped: `v_friend_activity_feed`.
- **Leftover (can't be cleaned by a normal migration):** the `notification_type` and old `activity_type` enums still contain social-era values Postgres won't let you drop (`SCHEMA.md` §3 already documents this as a known gap). The `post-media` storage bucket is also still sitting in the Supabase dashboard, emptied but not deleted (also already flagged in `SCHEMA.md` §7). Both are pre-existing, already-known gaps, not new findings — repeating them here only because the brief asked for a complete list.
- `profiles` table has no `friend`/`social` columns — clean.

**Not social, but worth noting for scope-chasing:** `coaching_feedback` (migration 28) lets athlete and coach exchange append-only messages on workouts/skills. That's Connect-as-coaching (matches your brief), not a social feed — flagging only so it isn't mistaken for leftover social code during Phase 2.

---

## 4. Schema mismatches

**A. Exercises feature queries objects that don't exist (most severe).**
`exercise_remote_datasource.dart:44,79,98` queries `exercise_library_view`, `exercise_library_facets_view`, and (`:112`) a `favorites` table. None of the 33 migrations create any of these — the only two views in the whole schema are `v_user_roadmap` and the now-dropped `v_friend_activity_feed` (`views.sql:5,17`). The real `exercises` table (`exercise_library.sql`) has no `exercise_type` or `difficulty` column either — that's `category` (text) and `difficulty_level` (smallint 1–5), added later by migration 22, plus `force`/`mechanic` (singular)/`images[]`/`level` added by the newest migration (`20260806000001`). `exercise_model.dart`'s doc comment (`:3-22`) describes column names (`exercise_type`, `difficulty`, `mechanics` plural) that match neither generation of the real table. This screen cannot return data as written — it's not a small fix, the whole data source needs to be rebuilt against `public.exercises` + `exercise_muscle_groups` + `muscle_groups` directly (or a new view needs to be migrated in, your call).

**B. Three repositories import model files that were never created.**
`workout_repository.dart:2-3` → `core/models/exercise.dart`, `core/models/workout.dart`; `roadmap_repository.dart:2` → `core/models/roadmap.dart`; `achievements_repository.dart:2` → `core/models/achievement.dart`. `git log --all` shows `core/models/` has **never existed** in this repo's history — not deleted, never created. Unlike finding A, the *table names and columns these repositories query are correct* (`workout_logs`, `roadmap_categories`, `skills`, `skill_progress`, `achievements`, etc. all match current migrations exactly). This is pure missing-plumbing, not a schema disagreement — the fix is writing the four model files, not rethinking the queries.

**C. `AppRoutes` is missing routes that other files assume exist.**
`motra_bottom_nav.dart` and the orphaned `roadmap/presentation/pages/*` reference `AppRoutes.achievements`, `.roadmap`, `.start`, `.templates`, and methods `.galaxyFor(id)` / `.planetFor(id)` that don't exist on `AppRoutes` (`app_constants.dart:30-42` only has splash/login/register/forgotPassword/dashboard/workouts/exercises/statistics/profile). Not a database-schema mismatch, but the same "written against a future version of the app that was never finished" pattern.

**D. `test/widget_test.dart:18` references `GymApp()`** — the actual exported widget in `main.dart:31` is `MomentumApp`. One-line rename mismatch, not a deep issue, but it's why `flutter test` currently fails outright (see §6).

I did not find any surviving reference to the "galaxies/planets/planet_nodes" or flat "training_logs" naming you described from the old React port — `core/models/` (where that would have lived) was never committed, so that layer seems to have been deleted before this repo's first commit rather than left behind. The closest surviving trace is finding A (a view-based schema assumption that doesn't match the real tables) and the orphaned `application/`-layer imports in finding C's neighborhood — same symptom (code written against a schema/layer that doesn't exist), different specifics.

---

## 5. Dead code & duplicated systems

**Duplicate dashboard implementations** (`features/dashboard/presentation/`):
- `pages/dashboard_page.dart` — **not imported by the router at all** (`app_router.dart` only imports `screens/dashboard_screen.dart`). It's also independently broken: it imports `package:gym_app/lib/core/theme/app_colors.dart` (note the stray `/lib/` segment — not how Dart package imports work, so this is a guaranteed-broken import even if the target existed) plus four more missing files (`shared/widgets/progress_ring_widget.dart`, `shared/widgets/week_chain_widget.dart`, `roadmap/application/roadmap_providers.dart`, `dashboard/application/dashboard_providers.dart`). Pure dead weight — 30 of the 276 `flutter analyze` errors trace to this one unreachable file.
- `screens/dashboard_screen.dart` — the real one, wired, compiles, but pulls in the social `community_feed_section.dart` (§3).

Recommend deleting `pages/dashboard_page.dart` and its exclusive dependents outright in Phase 2 (it's unreachable and nothing links to it), keeping `screens/dashboard_screen.dart` as the base to fix in Phase 4.

**Duplicate workout feature folders**: `features/workout/` (singular, schema-correct repository, zero consumers) vs. `features/workouts/` (plural, wired screen, zero data layer). Same two systems, same job, needs merging into one — recommend keeping the plural name (matches every other feature folder's plural convention: `exercises`, `workouts`, `statistics`) and moving `workout_repository.dart`'s logic in once the missing models are written.

**Duplicate roadmap implementations**: see §2 — a schema-correct-but-unwired `data/` layer vs. an unwired, schema-era-mismatched `presentation/pages/` layer, neither connected to the other or to the router. These were very likely written at different times against different plans for the `application/` provider layer; recommend picking one direction in Phase 3 rather than trying to reconcile both.

**Orphaned nav shell**: `shared/widgets/motra_bottom_nav.dart` (`MotraShell`/`MotraBottomNav`) — unreferenced anywhere, broken `AppRoutes` references. Given your brief wants exactly a 3-tab TRAIN/PROGRESS/CONNECT nav and neither this file (4 tabs, no Connect) nor `app_shell.dart` (5 tabs, no Progress/Connect) matches that, recommend treating both as reference material for Phase 3 rather than trying to repair either in place.

**Unused pubspec dependencies** (zero imports anywhere in `lib/`, checked via grep):
- `flutter_dotenv` — nothing calls `dotenv.load()` or reads `dotenv.env`; `main.dart` gets its Supabase credentials from `--dart-define` instead (`main.dart:16-17`).
- `google_fonts` — zero usage; `AppTypography` hardcodes `fontFamily = 'SF Pro Display'` (`app_typography.dart:22`) as a plain string, not via this package.
- `intl` — zero usage.
- `cupertino_icons` — zero usage (the app uses `lucide_icons_flutter` and raw `Icons.*` throughout).
- `fl_chart` — zero usage, but this one has an explicit comment marking it intentional: `pubspec.yaml:23` says "wired now, used starting Phase 2" — **not** a cleanup candidate, flagging only so it isn't confused with the others.

Recommend removing the first four in Phase 2 unless you know of planned near-term use; keep `fl_chart` per its own comment.

**Unused repository classes** (beyond the three already covered in §4B as "missing models," these would still be dead weight even once the models exist, because nothing calls them): confirmed via grep that `workout_repository.dart`, `roadmap_repository.dart`, and `achievements_repository.dart` have exactly zero importers outside their own file. Not asking you to delete them — they're the most schema-correct code in the repo — but Phase 3/4 needs to actually wire them into providers/screens, or they'll just keep bit-rotting.

---

## 6. Bugs — `flutter pub get` / `analyze` / `test`

**`flutter pub get`**: succeeds. 4 packages bumped within existing constraints; 61 packages have newer versions outside current constraints (routine, not an error) — full list available via `flutter pub outdated` if you want it.

**`flutter analyze`**: **276 issues** (down from "doesn't run at all" before the working tree was restored this session). Every single error traces back to one of the dead/orphaned files already named above — there is no error in a live, wired, reachable file. Breakdown:

| File | Errors | Root cause |
|---|---|---|
| `features/dashboard/presentation/pages/dashboard_page.dart` | ~30 | unwired duplicate, broken package-style relative import (§5) |
| `features/roadmap/presentation/pages/{galaxy,planet,roadmap,achievements}_page.dart` | ~130 | missing `core/models/roadmap.dart`, `core/models/achievement.dart`, `core/logic/planet_logic.dart`, and a whole missing `application/` provider layer (§4B/C) |
| `features/roadmap/data/{roadmap,achievements}_repository.dart` | ~16 | missing `core/models/roadmap.dart`, `core/models/achievement.dart` (§4B) |
| `features/workout/data/workout_repository.dart` | ~16 | missing `core/models/exercise.dart`, `core/models/workout.dart` (§4B) |
| `shared/widgets/motra_bottom_nav.dart` | ~6 | missing `AppRoutes` members (§4C) |
| `test/widget_test.dart` | 2 | `GymApp` vs `MomentumApp` (§4D) |
| everywhere else | ~4 `info`-level lints | `prefer_const_constructors`, one `withOpacity`/`anonKey` deprecation each, one `unused_element` each in two of the orphan files above |

**`flutter test`**: **fails to even load** — `test/widget_test.dart:18` compile error (`GymApp` undefined, §4D). This is the project's only test file; there is currently no passing test in the repo.

---

## 7. Supabase

**Migration order**: visually audited all 33 files in filename order for forward-references (a table/column/function used before its own `create`). Found none — each migration only references objects created in itself or an earlier-numbered file. I could not run `supabase db reset --local` to verify mechanically: it requires Docker Desktop, which isn't running on this machine (`LegacyDbBootstrapError: failed to inspect service`). Recommend running `supabase db reset` yourself (or in CI) before Phase 2 as a hard confirmation — static reading is good evidence, not proof.

**RLS — Connect/coaching access (the part you specifically asked me to check carefully)**: this is well-built. `coach_can_view(athlete, scope)` (`connect_core.sql:146-160`) requires both an `active` relationship row **and** the matching `coaching_permissions` boolean (`share_workouts`/`share_prs`/`share_skill_progress`/`share_body_metrics`) before any read policy fires; `connect_data_access.sql` applies it per-scope across every relevant table (workout logs/sets, streaks, PRs, skill/stage/objective progress, XP, achievements, roadmap logs, body metrics). `coaching_private_notes` is coach-only on both read and write (`coach_id = auth.uid()`, `connect_core.sql:228-229`) — athletes can never see a coach's private notes about them, matching the schema doc's description. I did not find a write policy anywhere that lets a coach mutate athlete data — confirms `SCHEMA.md`'s "Coaches have no write policy on any athlete log" claim. No gaps found in this part.

**RLS — known gaps (already documented in `SCHEMA.md` §7, re-verified here, not new findings)**:
- `profiles_select_all` (`rls_policies.sql:83-84`) lets every signed-in user read every other user's full profile row, including birthday/height/weight. Confirmed still true as of the latest migration.
- No payment enforcement on `coaching_plans` — prices are display-only, confirmed, nothing to flag beyond what's already written down.

**New gap I did find, not previously documented**: nothing. `coaching_private_notes` initially looked unprotected in a narrow grep, but a full-file read showed the policy exists (`connect_core.sql:228`) — false alarm, included here only so you know I checked and ruled it out rather than skipped it.

---

## 8. Proposed REMOVE list (needs your explicit approval before Phase 2 touches any of it)

1. `archive/lib.zip` — fully superseded by git history.
2. `free-exercise-db/` — one-time import source, already mined into the schema, 104 MB.
3. `node_modules/`, `package.json`, `package-lock.json` — zero-usage dependency.
4. `app_design/friends screen.png` — mockup for a dropped feature.
5. `mobile/lib/features/dashboard/presentation/pages/dashboard_page.dart` (and nothing else depends on it, so no knock-on deletions needed).
6. `mobile/lib/features/dashboard/presentation/widgets/community_feed_section.dart` — once its import is removed from `dashboard_screen.dart`.
7. Unused pubspec deps: `flutter_dotenv`, `google_fonts`, `intl`, `cupertino_icons` (keep `fl_chart`).
8. `mobile/lib/shared/widgets/motra_bottom_nav.dart` — orphaned, superseded-by-plan nav shell (recommend treating as reference, not reviving).

**Needs a product decision, not just a cleanup one — not proposing removal yet:**
- `archive/docs/*.md` (ARCHITECTURE/BRAND_GUIDE/DESIGN_SYSTEM/MIGRATION_NOTES/SETUP/PRODUCT) — recommend keeping under `archive/` for historical reasoning, revisit once `docs/PRODUCT.md` is rewritten.
- `mobile/lib/features/history/` — empty scaffold; keep or delete depending on whether you want the folder to exist ahead of the feature being built.
- `supabase/.env` / service-role key exposure — flagged in §1a; needs your decision on key rotation and whether to rewrite git history, separate from the rest of this cleanup.

## Proposed new folder structure (Phase 3 target, not applied yet)

```
mobile/lib/
  core/                         # theme, router, supabase client, shared widgets, utils — unchanged
  features/
    train/
      data/        # workout_repository's logic (once models exist) + exercise data source (once rebuilt against real tables)
      domain/
      presentation/ # merged workouts_screen + exercises_screen + statistics_screen under one pillar
    progress/
      data/        # roadmap_repository.dart + achievements_repository.dart, once wired
      domain/
      presentation/ # one chosen generation of galaxy/planet/roadmap/achievements pages, rebuilt against the data layer above
    connect/
      data/        # new — coaching_relationships, coaching_permissions, coaching_feedback, program_assignments
      domain/
      presentation/ # new — find/choose a Captain, Captain's athlete view, feedback
    auth/                        # unchanged, already clean
    profile/                     # unchanged
  shared/widgets/
```
This mirrors your Phase 3 instructions exactly (`features/train/`, `features/progress/`, `features/connect/`, each with `data/domain/presentation`) and gives Connect a home for the first time.

---

Stopping here per your instructions. Waiting for approval on §8 before any deletion happens.
