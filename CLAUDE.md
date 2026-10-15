# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Momentum** — a Flutter fitness app backed entirely by Supabase (Postgres + Auth + RLS + PostgREST/RPC + Realtime + Storage). There is no custom API server; the Flutter client talks to Postgres through PostgREST and `security definer` RPCs.

The product is organized into three pillars, and this vocabulary runs through the schema, the folder names, and the migration names:

- **TRAIN** — workout tracker, templates, exercise library, logs, PRs, programs
- **PROGRESS** — the skill roadmap (galaxies → planets → stages → objectives), XP, achievements, weekly challenges
- **CONNECT** — coaching ("Captain" = an athlete's active coach), consent-gated data sharing, program assignment

Naming is inconsistent across generations of the code: `AppConstants.appName` says `'Gym App'`, the pubspec package is `gym_app`, docs and the deep-link scheme say `momentum`, and the newest widgets are prefixed `Motra`. Treat all four as the same app; don't "fix" one without asking.

## Repo layout

| Path | Contents |
|---|---|
| `mobile/` | the Flutter app (Android + iOS + desktop scaffolding; no `web/`) |
| `supabase/` | `migrations/`, `SCHEMA.md` (the current backend reference), `config.toml`, CLI state in `.temp/` |
| `archive/lib.zip` | snapshot of the full `mobile/lib` tree (~170 files) — the best reference for the intended structure |
| `node_modules/`, `package.json` | only `@supabase/server`, used for ad-hoc admin scripting; unrelated to the app build |

## Read this before touching anything: the working tree is pruned

The working tree is in the middle of a restructure and **does not compile**. `flutter analyze` reports ~466 issues.

- `mobile/lib` has 9 files on disk; `HEAD` has 171. Surviving files import modules that are gone (`core/routing/app_router.dart`, `core/theme/app_theme.dart`, `core/error/exceptions.dart`, `core/models/*`), so nearly every error is a missing-file cascade, not broken logic.
- `mobile/android/app/build.gradle*` is deleted (only `src/` remains), so the Android build is also broken.
- `supabase/migrations/` has only `…26`–`…32` on disk; `01`–`25` exist in `HEAD`.
- `app_design/`, `archive/docs/` (ARCHITECTURE, DESIGN_SYSTEM, PRODUCT, SETUP, BRAND_GUIDE, MIGRATION_NOTES), `free-exercise-db/`, and `mobile/test/` are deleted on disk but present in `HEAD`.
- ~2990 deletions are staged-as-unstaged in `git status`. Nothing has been committed since.

So: before concluding a file or symbol doesn't exist, check `HEAD` and `archive/lib.zip`. Restore rather than re-author.

```bash
git show HEAD:archive/docs/ARCHITECTURE.md        # read a deleted doc
git ls-tree -r --name-only HEAD -- mobile/lib     # what the full tree looked like
git checkout HEAD -- mobile/lib/core/routing      # restore a subtree
unzip -l archive/lib.zip                          # browse the archived lib snapshot
```

Note that `archive/docs/ARCHITECTURE.md` predates migration 26 — it still documents the social layer (`posts`, `friendships`, `activities`) that migration 26 dropped. `supabase/SCHEMA.md` is the current source of truth; ARCHITECTURE.md is only reliable for RLS strategy, storage buckets, soft-delete, and performance notes.

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

# or, since supabase/.env already holds those keys:
flutter run --dart-define-from-file=../supabase/.env
```

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
- Streaks are written by `bump_streak` / `handle_workout_log_completed`, fired when `workout_logs.completed_at` is set. Never compute a streak client-side.
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
- **Navigation**: `go_router`, with a single persistent `ShellRoute` (`MotraShell`) wrapping the bottom-nav tabs so the nav bar isn't rebuilt per navigation. All paths are constants on `AppRoutes` — never a raw path string in a widget. `AppRoutes` currently lacks `achievements`, `roadmap`, and `start`, which `motra_bottom_nav.dart` references; that's part of the pruned state.
- **Supabase access**: `main.dart` exports a top-level `final supabase = Supabase.instance.client`, and repositories import it as `import '../../../main.dart' show supabase;`. Auth is the exception — `AuthRemoteDataSource` is the only place that touches `supabase_flutter`'s auth API, and it translates raw Supabase errors into the app's own `AuthException` / `NetworkException` so the repository can map them to domain `Failure`s.
- **Theme**: dark-only (`themeMode: ThemeMode.dark`; both `theme` and `darkTheme` are `AppTheme.darkTheme`). Every color comes from `AppColors` and every `TextStyle` from `AppTypography` — no widget constructs a `TextStyle` or references `Colors.white`/`Colors.black` directly. `AppTypography._style` requires an explicit line height, so no token can forget one. Timing constants live on `AppConstants` (`animFast`, `animMedium`, …).

### Deep links

OAuth and password-reset redirects use `io.momentum.app://login-callback/`, defined once as `AppConstants.authRedirectUrl` and registered in `mobile/android/app/src/main/AndroidManifest.xml` (and iOS `Info.plist`). Changing it means changing all three plus the Supabase dashboard redirect allowlist.

## Known gaps (from SCHEMA.md §7)

- Assigned-program *completion* isn't automated — only `start_assigned_program` exists.
- `profiles` is readable by every signed-in user, including birthday, height, and weight. Tighten before launch.
- No payments; `coaching_plans` prices are display-only.
- Old social values linger in the `notification_type` enum (Postgres can't drop enum values), and the emptied `post-media` storage bucket still needs deleting in the dashboard.

## Repo hygiene issue to be aware of

There is no `.gitignore` (it was removed in commit `59164a6`, "Remove gitignore and add all project files"). As a result `node_modules/`, `mobile/build/`, `supabase/.temp/`, and **`supabase/.env` — which contains the `SUPABASE_SERVICE_ROLE_KEY` — are all tracked in git**. The service-role key bypasses RLS entirely. If this repo is or becomes non-private, that key needs rotating in the Supabase dashboard and the file needs removing from history. Flag this rather than silently committing more of the same.
