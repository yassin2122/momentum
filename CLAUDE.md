# CLAUDE.md

Your Master Product Instruction currently lives only in the claude.ai Project. Claude Code reads CLAUDE.md automatically every session, so put a short version there:

the three pillars
the “no social” rule
the permission-based coach access rule
append-only migrations
the folder conventions
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

- UI follows design/grit/. Always use lib/core/theme/ tokens.
- Never modify business logic or Supabase code when doing UI tasks.

## What this is

**Grit** — a Flutter fitness app backed entirely by Supabase (Postgres + Auth + RLS + PostgREST/RPC + Realtime + Storage). There is no custom API server; the Flutter client talks to Postgres through PostgREST and `security definer` RPCs.

The product is organized into three pillars, and this vocabulary runs through the schema, the folder names, and the migration names:

- **TRAIN** — workout tracker, templates, exercise library, logs, PRs, programs
- **PROGRESS** — the skill roadmap (galaxies → planets → stages → objectives), XP, achievements, weekly challenges
- **CONNECT** — coaching ("Captain" = an athlete's active coach), consent-gated data sharing, program assignment

The app is named **Grit** everywhere: `AppConstants.appName` is `'Grit'`, the pubspec package is `grit`, the deep-link scheme is `io.grit.app`, and branded widgets are prefixed `Grit` (e.g. `GritApp`, `GritNavBar`). Earlier names (Momentum, Motra, Gym App / `gym_app`) are retired — don't reintroduce them. The only leftovers are intentional: the Android Kotlin `namespace` (`com.example.gym_app`, must match `MainActivity.kt`'s package), the local Supabase `project_id`, and the historical migration filenames (renaming applied migrations would break history).

## Repo layout

| Path | Contents |
|---|---|
| `mobile/` | the Flutter app (Android + iOS + desktop scaffolding; no `web/`) |
| `supabase/` | `migrations/`, `SCHEMA.md` (the current backend reference), `config.toml`, CLI state in `.temp/` |
| `archive/lib.zip` | snapshot of the full `mobile/lib` tree (~170 files) — the best reference for the intended structure |
| `node_modules/`, `package.json` | only `@supabase/server`, used for ad-hoc admin scripting; unrelated to the app build |

## Current tree state (re-verified this session, supersedes any earlier "pruned tree" note)

The restructure described in earlier revisions of this file has been restored: the working
tree now matches `HEAD` — full `mobile/lib` (93 Dart files), migrations `…01`–`…32` plus
`20260806000001` all present, `mobile/android/app/build.gradle.kts` present, and `docs/`,
`app_design/`, `archive/`, `mobile/test/` all exist on disk. **Do not treat the app as
missing files** — if something looks absent, it's more likely dead/orphaned/duplicated code
than a deleted file. Check `git log` / `archive/lib.zip` only as a last resort now.

That said, the app is **not healthy**:

- `flutter analyze` (from `mobile/`, after `flutter pub get`) reports **276 issues**
  (verified by re-running it, not just read from a doc).
- `flutter test` previously failed to load because `test/widget_test.dart` and `main.dart`
  disagreed on the root widget's name; both now use `GritApp` — re-run to confirm.

None of this is a missing-file cascade — every error traces back to a known dead,
duplicated, or orphaned file (unwired `dashboard_page.dart`, two unfinished generations of
the Progress UI missing `core/models/*.dart`, duplicate `features/workout/` vs
`features/workouts/`, the orphaned `grit_bottom_nav.dart`, and the old root-widget rename mismatch). Full
file-by-file detail: **`docs/CLEANUP_AUDIT.md`** — read that before re-deriving any of this
from scratch. None of it has been fixed as part of adding the skill system in
`.claude/skills/`; it's tracked for a later cleanup phase, not resolved.

## Commands

All Flutter commands run from `mobile/`.

```bash
flutter pub get
flutter analyze                       # add --no-pub to skip resolution
flutter test
flutter test test/widget_test.dart    # single file
flutter test --plain-name "renders"   # single test by name
```

Supabase credentials are **not** read from a bundled `.env` at runtime — `main.dart` uses `String.fromEnvironment`, so they must be injected at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>

# or, since mobile/.env already holds the matching client credentials:
cd mobile && flutter run --dart-define-from-file=.env
```

**Two different `.env` files exist — don't mix them up, it's a 404-producing trap:**
- `mobile/.env` — client credentials for the Flutter app (`SUPABASE_URL` +
  publishable `SUPABASE_ANON_KEY`) for the CLI-linked project, ref `lnpraurmeprnfzfervgj`
  ("gym" — see `supabase/.temp/linked-project.json`). This is the one to pass via
  `--dart-define-from-file`. Its own header comment ("loaded by flutter_dotenv") is
  inaccurate — nothing calls `dotenv.load()` (see below); it's meant for dart-define, not
  dotenv.
- `supabase/.env` — **server-side only** (seeding scripts, `supabase/scripts/*.js`, local
  CLI), holds `SUPABASE_SERVICE_ROLE_KEY` and a `SUPABASE_URL` that now points at the
  linked project (ref `lnpraurmeprnfzfervgj`; it used to point at a stale ref,
  `adskpshwfymknhvqjmlu`). Never pass this file to `flutter run` — it carries the
  service-role key, which bypasses RLS and must never ship in the client. (If the URL ever
  drifts to a wrong project ref again: a *.supabase.co subdomain for a nonexistent ref still
  resolves via wildcard DNS but returns an empty-body 404 on every endpoint, which `gotrue`
  surfaces as `AuthUnknownException` "Received an empty response with status code 404".)

Backend (from repo root, CLI already linked — see `supabase/.temp/project-ref`):

```bash
supabase db push      # applies migrations in filename order, skipping applied ones
supabase migration new <name>
```

`flutter_dotenv` is in `pubspec.yaml` but nothing loads it; don't add `.env` runtime loading without checking why.

## Architecture rules that matter

### Writes to progress data never go through the client

This is the single most important constraint, and it is enforced in the database, not by convention. Tables are in one of three RLS tiers (`archive/docs/ARCHITECTURE.md` §4):

1. **User-owned** (`workout_templates`, `workout_logs`, `body_metrics_log`) — full CRUD under `user_id = auth.uid()`.
2. **Global content, admin-write** (`exercises`, `skills`, `achievements`, `roadmap_workouts`) — public select, writes gated by `is_admin()`.
3. **Progress data, client-read-only** (`skill_progress`, `xp_transactions`, `personal_records`, `user_streaks`) — the client has **no write policy at all**. Every mutation goes through a `security definer` RPC or a server-side trigger.

Concretely, in the repository layer:

- XP moves only via `award_stage_xp` / `award_xp` RPCs.
- Roadmap completion goes through `complete_roadmap_workout`; roadmap PRs through `record_roadmap_personal_best`.
- PRs are written by the `check_and_update_personal_record` trigger that fires on `workout_log_sets` insert — just insert the set.
- Streaks count **app opens**, not workouts (migration `20261018120000`): the client calls `record_app_open(p_local_date)` on dashboard open/resume, which logs a `user_activity_days` row (tier 3, client-read-only) and runs `bump_streak(user, day)` — +1 per new day, survives 1–2 missed days, resets after 3 missed days in a row. The old workout-completion trigger is dropped. Never compute a streak client-side. The dashboard's discipline score comes from `get_discipline_score(p_local_date)` (50% active days + 50% completed workouts vs. templates-per-week plan, 30-day window).
- Template count is capped at 7 per user by `enforce_max_workout_templates()`. Let the Postgres error surface rather than pre-counting (avoids a race).

If you find yourself writing an `.update()` against a progress table, the answer is an RPC.

### Coaching access is consent-gated, read-only

A coach reads athlete data only when the relationship is `active` **and** the matching `coaching_permissions` scope is on, checked by `coach_can_view(athlete, scope)`. Coaches have no write policy on any athlete log — training history stays trustworthy. Scope → table mapping is in `SCHEMA.md` §4. Relationship lifecycle is RPC-only (`choose_captain`, `respond_to_coaching_request`, `end_coaching`).

### TRAIN and PROGRESS are deliberately decoupled

They share exactly two things: `profiles` and `exercises`. Tracker tables never reference `skill_id` or any roadmap table, and `personal_records` (tracker) is intentionally separate from `roadmap_personal_bests` (roadmap). Deleting either pillar leaves the other functional. Don't add a cross-reference without flagging it.

### Migrations are append-only

Never edit an applied migration — add a new one. Filenames are `YYYYMMDDHHMMSS_<snake_name>.sql` and apply in filename order.

### Client structure

Clean-architecture layering per feature, as seen in `archive/lib.zip`:

```
lib/
  core/        constants, error (exceptions/failure/result), network, routing, theme, utils, widgets
  features/<feature>/
    data/        datasources/, models/, repositories/
    domain/      entities/, repositories/, usecases/
    presentation/ providers/, screens/, widgets/
  shared/widgets/
```

- **State**: `flutter_riverpod`, `ProviderScope` at the root. Providers live in each feature's `presentation/providers/`.
- **Navigation**: `go_router`, with a single persistent shell wrapping the bottom-nav tabs so the nav bar isn't rebuilt per navigation. The shell actually wired into `app_router.dart` is `AppShell` (`core/routing/app_shell.dart`) + `FloatingNavBar`, 5 tabs: dashboard/workouts/exercises/statistics/profile. `shared/widgets/grit_bottom_nav.dart` (`GritShell`/`GritBottomNav`, 4 tabs) is a second, **unwired** shell — nothing imports it, and it references `AppRoutes.achievements`/`.roadmap`/`.start`, which don't exist on `AppRoutes`. All paths are constants on `AppRoutes` — never a raw path string in a widget. See Known gaps: neither shell matches the product's actual 3-pillar TRAIN/PROGRESS/CONNECT nav target.
- **Supabase access**: `main.dart` exports a top-level `final supabase = Supabase.instance.client`, and repositories import it as `import '../../../main.dart' show supabase;`. Auth is the exception — `AuthRemoteDataSource` is the only place that touches `supabase_flutter`'s auth API, and it translates raw Supabase errors into the app's own `AuthException` / `NetworkException` so the repository can map them to domain `Failure`s.
- **Theme**: dark-only (`themeMode: ThemeMode.dark`; both `theme` and `darkTheme` are `AppTheme.darkTheme`). Every color comes from `AppColors` and every `TextStyle` from `AppTypography` — no widget constructs a `TextStyle` or references `Colors.white`/`Colors.black` directly. `AppTypography._style` requires an explicit line height, so no token can forget one. Timing constants live on `AppConstants` (`animFast`, `animMedium`, …).

### Deep links

OAuth and password-reset redirects use `io.grit.app://login-callback/`, defined once as `AppConstants.authRedirectUrl` and registered in `mobile/android/app/src/main/AndroidManifest.xml` (and iOS `Info.plist`). Changing it means changing all three plus the Supabase dashboard redirect allowlist.

## Known gaps

`SCHEMA.md` §7 was written after migration 30 and is stale on two points — migration `32`
(`assignment_completion_profile_privacy.sql`) already resolved them:

- **Assigned-program completion**: resolved. `complete_assignment(p_assignment_id)` marks a
  `program_assignments` row completed and closes the linked `user_program_enrollment`;
  callable by the athlete, or the coach while the relationship is `active`.
- **Profile privacy**: resolved. `anon`/`authenticated` can no longer read the full
  `profiles` row — only a safe column allowlist is granted (`id, username, display_name,
  avatar_url, bio, role, created_at, updated_at, deleted_at`). Birthday/height/weight/gender
  are reachable only via `get_my_private_profile()` (owner) or `get_athlete_body_profile
  (athlete)` (Captain, gated by `coach_can_view(athlete, 'body')`). **Any query against
  `profiles` must select explicit columns — `select('*')` now errors.** No client code
  queries `profiles` directly yet (`features/profile/` has no data layer), so there's
  nothing to fix today, but this is a trap for the first person who adds one.

Still open:

- No payments; `coaching_plans` prices are display-only.
- Old social values linger in the `notification_type` enum (Postgres can't drop enum
  values); the emptied `post-media` storage bucket still needs deleting in the Supabase
  dashboard (dashboard-only, not fixable by a migration).
- The live nav (`AppShell`, 5 tabs) and the unwired `GritShell` (4 tabs, broken `AppRoutes`
  refs) both predate the product's actual target — a 3-tab **TRAIN / PROGRESS / CONNECT**
  nav. Neither is "the convention" to extend; don't add a tab to either as if it were final.
  No `features/connect/` folder exists at all yet, despite Connect being fully built in the
  schema (migrations 27–32) — it's the single largest gap between schema and app.
- **Old names retired**: the app was previously called Momentum, and before that Motra / Gym App.
  All of those were renamed to **Grit** across code, docs and platform configs. Don't
  reintroduce any of the old names.
- ~~`docs/PRODUCT.md` describes Connect as a social feed~~ — **resolved** (commit
  `c574c7c`): it now describes Connect as 1:1 coaching, matching this file and the schema.
  `archive/docs/PRODUCT.md` still has the old pre-pivot social version — that copy is
  historical only, don't read it as current.
- `docs/CLEANUP_AUDIT.md` has the full picture beyond this file: duplicate/orphaned feature
  code (`dashboard_page.dart` vs `dashboard_screen.dart`, `features/workout/` vs
  `features/workouts/`, two unfinished Progress-UI generations), the exercises feature
  querying views/tables that don't exist (`exercise_library_view`,
  `exercise_library_facets_view`, `favorites`), unused pubspec deps, and more.

## Skill system ground rules

Six skills live in `.claude/skills/` (grit-ui, flutter-feature, supabase-security,
grit-qa, performance-audit, release-check). Rules shared by all of them, so each
`SKILL.md` can stay focused on its own workflow instead of repeating this:

- **Don't invent.** Never reference a table, column, RPC, package, widget, or route that
  isn't actually in the repo. If something's unclear or inconsistent, stop and list it as an
  open question instead of guessing.
- **Never claim a check passed without actually running it.** Quote the real command output.
- **Never weaken RLS or add a client-side write to a client-read-only table**
  (`skill_progress`, `xp_transactions`, `personal_records`, `user_streaks`, or any other
  tier-3 table — see "Writes to progress data never go through the client" above). Coach
  access to athlete data stays permission-gated and read-only; never add a coach write
  policy on an athlete log.
- **Migrations are append-only.** New file only (`supabase migration new <name>`), never
  edit an applied one. Treat any RLS/RPC/migration change as high-risk: confirm with the
  user before running `supabase db push` (hits the linked remote project).
- **The live nav is not the target nav.** `AppShell` (5 tabs) is what's actually wired today;
  the product's target is a 3-tab TRAIN/PROGRESS/CONNECT nav (see Known gaps). Don't treat
  `AppShell`'s current 5 tabs, or `GritShell`'s 4, as "the convention" to extend.
- **Small, scoped diffs** over broad rewrites.
- **Standard verification commands** (run from the stated directory, show real output):
  - `cd mobile && flutter analyze` — required after any Dart change
  - `cd mobile && flutter test` — required after any logic change (currently fails to load —
    see Known gaps / `docs/CLEANUP_AUDIT.md`; don't claim it passes)
  - `supabase db reset` (repo root) — required after any new migration, before `db push`
  - `supabase db push` — only with explicit user confirmation
- **No old names** ("Momentum", "Motra", "Gym App") in new skill content, code, or docs.
  The product name is Grit.
- `grit-qa` and `performance-audit` are **read-only**: report findings, don't edit code
  unless the user explicitly authorizes fixes afterward.

## Repo hygiene issue to be aware of

There is no `.gitignore` (it was removed in commit `59164a6`, "Remove gitignore and add all project files"). As a result `node_modules/`, `mobile/build/`, `supabase/.temp/`, and **`supabase/.env` — which contains the `SUPABASE_SERVICE_ROLE_KEY` — are all tracked in git**. The service-role key bypasses RLS entirely. If this repo is or becomes non-private, that key needs rotating in the Supabase dashboard and the file needs removing from history. Flag this rather than silently committing more of the same.

`mobile/.env` is also tracked (same missing-`.gitignore` cause), but lower severity — it only
holds a `sb_publishable_...` anon key, which is meant to ship inside the client anyway.
