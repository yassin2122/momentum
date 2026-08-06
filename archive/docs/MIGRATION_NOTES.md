# Momentum Mobile — Data Layer Rewrite: Migration Notes

## What this drop actually is
Everything in this app except auth (`auth_repository.dart`,
`supabase_client.dart`) was **local mock/seed data** — `SeedRoadmapContentRepository`,
`dashboard_providers.dart`, `roadmap_providers.dart` all returned hardcoded
lists, nothing queried Supabase. This drop replaces that mock layer with
real Supabase-backed models, repositories, and providers matching the
actual deployed schema (23 migrations, verified against a live Postgres
instance). The Connect pillar (friends/feed) is removed per your decision
to defer it — the Postgres tables (`posts`, `friendships`, `activities`,
etc.) still exist and are untouched, just unused by the client for now.

## Files in this drop — copy these into your project, overwriting the originals
```
lib/core/models/roadmap.dart          (NEW — replaces galaxy_planet.dart + planet_progress.dart)
lib/core/models/exercise.dart         (REWRITTEN — real normalized schema)
lib/core/models/workout.dart          (NEW — replaces workout_template.dart + training_log.dart)
lib/core/models/achievement.dart      (REWRITTEN — real category enum + uuid join key)
lib/core/models/app_user.dart         (REWRITTEN — matches `profiles` table)
lib/features/roadmap/data/roadmap_repository.dart          (NEW)
lib/features/roadmap/data/achievements_repository.dart     (NEW)
lib/features/workout/data/workout_repository.dart          (NEW)
lib/features/roadmap/application/roadmap_providers.dart    (REWRITTEN — now async)
lib/features/roadmap/application/achievements_providers.dart (REWRITTEN — now async)
lib/features/dashboard/application/dashboard_providers.dart  (REWRITTEN — now async)
lib/core/router/app_router.dart       (REWRITTEN — friends route removed)
lib/shared/widgets/motra_bottom_nav.dart (REWRITTEN — Friends tab swapped for Achievements)
```

## Delete these — superseded, no longer referenced by anything above
```
lib/core/models/galaxy_planet.dart
lib/core/models/planet_progress.dart
lib/core/models/training_log.dart
lib/core/models/friend.dart
lib/core/models/challenge.dart
lib/core/models/activity_feed_item.dart
lib/features/roadmap/data/roadmap_content_repository.dart   (the seed data)
lib/features/friends/                                        (entire folder)
```
`lib/features/auth/presentation/widgets/social_buttons.dart` is UNRELATED
(Google/Apple sign-in buttons) — keep it, that's not the Connect pillar.

## New dependency needed
The new models use `freezed`/`json_serializable` for the `fromJson`
boilerplate (matches Supabase's `List<Map<String, dynamic>>` row shape
cleanly). If your `pubspec.yaml` doesn't already have these:
```yaml
dependencies:
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
```
Then generate the `.freezed.dart`/`.g.dart` files:
```bash
dart run build_runner build --delete-conflicting-outputs
```
If you'd rather not add codegen, tell me and I'll rewrite the models as
plain classes with hand-written `fromJson` — more boilerplate, zero new
dependencies.

## UI pages — DONE, now using AsyncValue.when()
All five pages are rewritten and included in this drop:
`galaxy_page.dart`, `planet_page.dart`, `roadmap_page.dart`,
`achievements_page.dart`, `dashboard_page.dart`. Also included:
`planet_logic.dart` (rewired onto real `Skill`/`SkillStage`/`SkillStatus`
models — certification is now just `SkillProgress.status`, no longer
computed client-side from completed nodes) and `discipline_logic.dart`
(same formula, now takes `WorkoutLog` instead of the mock `TrainingLog`).

**I could not run `flutter analyze` or `dart compile` in this environment**
— no Flutter SDK here, so these are hand-verified against the real model
field names and provider signatures, not compiler-verified. Run
`flutter analyze` yourself as the first step after copying these in;
paste me any errors and I'll fix them the same way I fixed the SQL issues
earlier (verify against something real, don't just reassure).

Notable behavior changes, not just mechanical ones:
- **`planet_page.dart`** objective checkboxes are now **read-only**,
  reflecting real `user_objective_progress` rows. Tapping doesn't toggle
  anything — that needs a `complete_objective` RPC that doesn't exist yet
  (same gap flagged several times). The checkbox UI is there; the write
  path isn't.
- **`planet_page.dart`**'s elite-challenge section now queries real
  `skill_prerequisites` rows (`required_status = 'legendary'`) instead of
  a separate mock `EliteChallenge` list.
- **`dashboard_page.dart`**'s "Today's Workout" card is now a generic
  "Start a workout" CTA — the old hardcoded "Pull Day" mock had no real
  replacement (no server-side "active template" concept exists), so I
  didn't invent one.
- **`dashboard_page.dart`**'s Friend Activity section is **removed
  entirely** — Connect is deferred.
- **`galaxy_page.dart`**'s route still takes a slug in the URL, but the
  new providers key off `categoryId`/`skillId` (uuids) — pages resolve
  slug → id by scanning the fetched list. Fine at this data size; would
  need a dedicated `by-slug` query if the catalog grows large.

## What's still genuinely missing (not a UI problem — no backend exists yet)
- `complete_objective()` RPC — objectives can be read but not marked
  complete from the client yet.
- `unlock_skill()` / `complete_skill_stage()` RPCs — the certification
  state machine, flagged as an open item several times now; this is the
  actual blocker for `planet_page.dart`'s "mark objective done" button
  doing anything meaningful.
- Search RPCs (`search_exercises`, `search_skills`) — `WorkoutRepository.searchExercises()`
  does a plain `ilike` for now, which works but doesn't use the trigram
  index as efficiently as a dedicated RPC would at scale.
