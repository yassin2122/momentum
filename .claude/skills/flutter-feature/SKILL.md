---
name: flutter-feature
description: Add or change a Momentum Flutter feature (screen, provider, repository, use case) following the clean-architecture layering, Riverpod state management, and go_router navigation actually used in mobile/lib. Use when adding a new screen, provider, repository method, use case, or route.
---

# Flutter feature

Shared rules (don't invent, verify before claiming, standard commands) are in the root
`CLAUDE.md` — read it first.

## Architecture to follow

Clean-architecture per feature. `features/exercises/` is the cleanest real example to copy:

```
features/<feature>/
  data/
    datasources/   # talks to supabase_flutter directly (e.g. exercise_remote_datasource.dart)
    models/        # *Model.fromRow(Map) — maps a PostgREST row to a domain entity
    repositories/  # implements the domain interface, catches exceptions, returns Result<T>
  domain/
    entities/
    repositories/  # abstract interface
    usecases/      # one class per operation, calls the repository
  presentation/
    providers/     # plain Riverpod Provider<T>s, chained with ref.watch
    screens/
    widgets/
```

- **Errors**: `core/error/{exceptions,failure,result}.dart` — datasource throws
  `NetworkException`/`ServerException`, repository catches and returns
  `Result.success(...)` / `Result.failure(SomeFailure(...))`. Never let a raw exception
  reach a widget.
- **Providers**: plain `Provider<T>((ref) => ...)`, chained top-down — datasource provider
  reads `supabaseClientProvider`, repository provider reads the datasource provider, usecase
  providers read the repository provider. See `exercise_providers.dart` for the exact
  pattern. Don't introduce a different state-management approach (no Bloc, no raw
  `StatefulWidget` + `setState` for anything that talks to Supabase).
- **Supabase access**: `import '../../../main.dart' show supabase;` for the top-level
  client, or `supabaseClientProvider` (`core/network/supabase_client_provider.dart`) inside
  Riverpod providers. Auth is the one exception — only `AuthRemoteDataSource` touches
  `supabase_flutter`'s auth API directly.
- **Routing**: `core/routing/app_router.dart` is the single composition root. New routes get
  a constant on `AppRoutes` (`core/constants/app_constants.dart`) — never a raw path string
  in a widget. The live shell is `StatefulShellRoute.indexedStack` + `AppShell`
  (`core/routing/app_shell.dart`), 5 tabs today. `MotraShell`/`motra_bottom_nav.dart` exists
  on disk but is **not wired** and references routes that don't exist
  (`AppRoutes.achievements/.roadmap/.start`) — don't build against it as if it's live, and
  don't add a 6th tab to `AppShell` or revive `MotraShell` without confirming with the user
  first (the actual target is a 3-tab TRAIN/PROGRESS/CONNECT nav — see CLAUDE.md Known gaps).

## Rules that are enforced in the database, not just convention

- **Never write to a client-read-only table directly.** `skill_progress`,
  `xp_transactions`, `personal_records`, `user_streaks` (and their coaching-side mirrors)
  have no client write policy. If a feature needs to change one, the answer is an existing
  RPC (`award_stage_xp`, `complete_roadmap_workout`, `record_roadmap_personal_best`, …) or a
  trigger already firing on a different insert (e.g. PRs come from inserting into
  `workout_log_sets`) — not a new repository `.update()`/`.insert()` call. If no RPC exists
  yet for what you need, that's a `supabase-security` task, not something to work around
  client-side.
- **Don't let TRAIN reference PROGRESS tables or vice versa.** Tracker tables never carry a
  `skill_id`; `personal_records` (tracker) and `roadmap_personal_bests` (roadmap) stay
  separate. Flag it rather than adding a cross-reference.
- **Don't pre-count before an insert that has a DB-side cap** (e.g. the 7-template limit via
  `enforce_max_workout_templates()`) — let the Postgres error surface and handle it, to
  avoid a race.
- **`profiles` queries must select explicit columns, never `select('*')`** — migration 32
  revoked full-row select; see CLAUDE.md Known gaps for the exact allowlist and the two RPCs
  for private fields (birthday/height/weight/gender).

## Known landmines in this codebase (don't build on top of these without fixing them first)

Per `docs/CLEANUP_AUDIT.md` — check it before extending any of these:
- `features/exercises/` queries `exercise_library_view`, `exercise_library_facets_view`, and
  a `favorites` table that don't exist in any migration. It will not return data as written.
- `features/workout/` (singular) and `features/workouts/` (plural) are duplicate feature
  folders for the same thing; only the plural one is wired into the router.
- `features/roadmap/` has two unfinished, mutually-unwired generations (a schema-correct
  `data/` layer vs. an older `presentation/pages/` layer), both missing `core/models/*.dart`
  files that were never created.
- `features/dashboard/presentation/pages/dashboard_page.dart` is an unwired duplicate of the
  live `screens/dashboard_screen.dart`; the live one pulls in a social "Community Feed"
  widget that's a leftover from the dropped social pivot.

## Steps

1. Locate the feature folder; if new, create `data/domain/presentation` matching the layout
   above.
2. Entity → repository interface + impl → use case → provider → screen/route, in that order.
3. Run `cd mobile && flutter analyze` and `flutter test`, show real output.

## Completion criteria

- `flutter analyze` run, output shown, no new issues introduced.
- `flutter test` run, output shown (note: currently fails to load entirely due to a
  pre-existing `GymApp`/`MomentumApp` mismatch — see CLAUDE.md Known gaps; don't claim a
  pass that didn't happen, report the pre-existing failure if it's not yours to fix).
- New provider follows the `Provider` + `ref.watch` chain pattern.
- No direct client write to a tier-3 table; no new TRAIN↔PROGRESS cross-reference.
