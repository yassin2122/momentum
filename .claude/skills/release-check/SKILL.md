---
name: release-check
description: Pre-release verification for Momentum — confirms the app builds/analyzes clean, tests pass, migrations are in sync, and known release blockers are addressed or explicitly accepted. Use when asked "is this ready to ship" or for a pre-release checklist.
---

# Release check

Shared rules are in the root `CLAUDE.md` — read it first. Every item below must be run for
real, with its output shown — never mark an item passed without the command output to back
it up.

## 1. Build and test

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Show the real output of each. As of this session's baseline: `flutter analyze` reports 276
pre-existing issues and `flutter test` fails to load entirely (`GymApp`/`MomentumApp`
mismatch in `test/widget_test.dart` — see CLAUDE.md Known gaps / `docs/CLEANUP_AUDIT.md`).
Report the current numbers, don't assume they still match that baseline — re-run and quote.

## 2. Migration sync

Check whether local migrations are all applied to the linked project. Do **not** run
`supabase db push` as part of this check without explicit confirmation — it mutates the
remote project. Report sync status; let the user decide whether to push.

## 3. Resolved-but-verify items

Migration 32 already resolved two items that older docs (`SCHEMA.md` §7) still list as
open — confirm they're still holding, don't re-flag them as blockers:

- **Profile privacy**: `profiles` grants only a safe column allowlist to
  `anon`/`authenticated`; birthday/height/weight/gender require
  `get_my_private_profile()` / `get_athlete_body_profile()`. Grep for any new
  `.from('profiles')` call in `mobile/lib` and confirm it selects explicit columns, not
  `select('*')` (which now errors against this policy).
- **Assigned-program completion**: `complete_assignment(assignment_id)` RPC exists and is
  callable by the athlete or the active coach.

## 4. Still-open items (report as accepted-risk or blocker — don't silently skip)

- No payment enforcement; `coaching_plans` prices are display-only.
- Stale `notification_type` enum values from the removed social layer (informational —
  Postgres can't drop enum values, not fixable here).
- `docs/PRODUCT.md` still describes Connect as a social feed, contradicting the actual
  coaching-based Connect in the schema — flag if anyone might read it as current spec.
- No `features/connect/` folder exists yet — Connect has no UI despite being fully built in
  the schema. If this is meant to ship, that's a major missing feature, not a checklist item.

## 5. Deep link config

Confirm `AppConstants.authRedirectUrl` (`io.momentum.app://login-callback/`) matches:
- `mobile/android/app/src/main/AndroidManifest.xml`
- iOS `Info.plist`
- the Supabase dashboard's redirect allowlist — **can't be checked from the repo**; call
  this out as a manual-only step, don't claim it's verified.

## 6. Secrets

Confirm `supabase/.env` (contains `SUPABASE_SERVICE_ROLE_KEY`) hasn't grown new tracked
secrets since the last check, and that it's still flagged as a pre-existing hygiene issue
(see CLAUDE.md) rather than something this check just introduced or fixed.

## Completion criteria

- Every command in §1 actually run, real output shown.
- A pass/fail/manual-only line for every item in §2–6.
- Manual-only items (dashboard allowlist, key rotation, store listings) explicitly called
  out as needing a human, not marked done.
