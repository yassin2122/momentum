---
name: momentum-qa
description: Review a pending Momentum change for bugs, regressions, and violations of the app's architecture/product rules (RLS tiers, TRAIN/PROGRESS decoupling, coach read-only access, design-token usage). Read-only — reports findings, never edits code unless explicitly told to apply fixes.
---

# Momentum QA

Shared rules are in the root `CLAUDE.md` — read it first. **This skill is read-only.** Do
not use Edit/Write on any file under `mobile/` or `supabase/` while running it — produce a
findings report. If the user wants fixes applied, that's a separate, explicit follow-up.

## What to check

Get the diff (`git diff` against the target branch, or the files the user names), then map
every changed file against:

- **RLS tier violations**: any `.update()`/`.insert()`/`.delete()` in a repository against
  `skill_progress`, `xp_transactions`, `personal_records`, `user_streaks`, or any other
  client-read-only table — should be an RPC call instead.
- **Coach write access**: any new RLS policy that gives a coach `insert`/`update`/`delete`
  on an athlete-owned table — this must never exist.
- **Permission gating**: a new coach-read policy that checks relationship status but not
  the matching `coaching_permissions` scope (or vice versa).
- **TRAIN/PROGRESS cross-reference**: a tracker table gaining a `skill_id` column, or
  `personal_records` merging with `roadmap_personal_bests`.
- **Template-count race**: client code counting `workout_templates` before insert instead
  of letting `enforce_max_workout_templates()` raise.
- **Design-token violations**: raw `Colors.*`, inline `TextStyle(...)`, or magic-number
  spacing/radius in a widget diff.
- **`profiles` over-fetch**: a new query doing `select('*')` or otherwise pulling
  birthday/height/weight/gender without going through `get_my_private_profile()` /
  `get_athlete_body_profile()`.
- **Migration mistakes**: an edit to an already-applied migration file, or a new migration
  missing `set search_path` on a `security definer` function.
- **"Motra/MOTRA" reintroduced**: new code using that naming instead of Momentum.
- **Known pre-existing issues** (don't re-report these as new unless the diff touches them):
  see `docs/CLEANUP_AUDIT.md` and CLAUDE.md Known gaps for the current baseline (276
  `flutter analyze` issues, `flutter test` failing to load, duplicate dashboard/workout/
  roadmap implementations, exercises querying nonexistent views).

## Steps

1. Get the diff.
2. Run `cd mobile && flutter analyze` and quote the real output — call out any issue count
   above the pre-existing 276 baseline as newly introduced.
3. Walk the checklist above against each changed file.
4. Report findings by severity (bug / regression / rule violation / style), each with
   file:line and the concrete failure scenario — not just "this looks wrong."

## Completion criteria

- A findings report (possibly empty, if nothing survived review).
- `flutter analyze` actually executed, output quoted.
- Zero files edited during this skill's run.
