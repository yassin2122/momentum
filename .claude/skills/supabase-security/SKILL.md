---
name: supabase-security
description: Write or review Supabase migrations, RLS policies, and security-definer RPCs for Momentum — especially coach-to-athlete (Connect) data access. Use for any schema change, new RPC, or RLS policy edit under supabase/migrations/.
---

# Supabase security

Shared rules (don't invent, verify before claiming, never weaken RLS, migrations are
append-only) are in the root `CLAUDE.md` — read it first. This is the highest-risk skill in
the set: get explicit user confirmation before anything that touches the linked remote
project.

## Reference

`supabase/SCHEMA.md` is the source of truth for the table map, RLS tiers, helper functions
(`is_admin()`, `is_coach()`, `coach_can_view(athlete, scope)`, `can_view_program(program)`),
and the full RPC list. Read it before writing a new policy or RPC — don't re-derive table
names or re-invent a helper that already exists.

## Migration mechanics

- New file only: `supabase migration new <name>` → `supabase/migrations/YYYYMMDDHHMMSS_
  <snake_name>.sql`. Never edit a migration that's already in the directory.
- Wrap every migration in `begin; ... commit;` (every real migration in this repo does).
- A `security definer` function always has `set search_path = public` (newer ones add
  `pg_temp` too, e.g. migration 32) — a definer function without a pinned search path is a
  privilege-escalation hole. Every new one must have it.
- Policy naming follows `<role>_<verb>_<table>`, e.g. `coach_read_workout_logs`,
  `programs_coach_write` — match this, don't invent a different convention.
- Reuse existing helper predicates (`coach_can_view`, `is_coach`, `is_admin`,
  `can_view_program`) inside new policies instead of re-writing the same `exists(...)`
  subquery inline.

## Hard rules (enforced, not optional)

- **Coaches never get INSERT/UPDATE/DELETE on any athlete table.** Every coach-facing
  policy is `for select`. If a task implies a coach needs to "fix" or "edit" athlete data,
  stop and flag it — that's a product decision, not a migration to write.
- Access requires **both** `coaching_relationships.status = 'active'` **and** the matching
  `coaching_permissions` scope (`workouts`/`prs`/`progress`/`body`) — never gate on
  relationship status alone, and never gate on permission alone.
- Ending a relationship (`end_coaching`) must cut access immediately — don't introduce a
  caching layer or materialized view that could serve stale access.
- `profiles` only grants a safe column allowlist to `anon`/`authenticated` (migration 32) —
  any new query or view touching `profiles` must respect that, not re-expose
  birthday/height/weight/gender via a join.
- Relationship lifecycle (`choose_captain`, `respond_to_coaching_request`, `end_coaching`,
  `assign_program`, `start_assigned_program`, `complete_assignment`) is RPC-only. Don't add
  a direct insert/update policy on `coaching_relationships` or `program_assignments` as a
  shortcut.

## Verifying a new or changed policy

Don't rely on reading the SQL and reasoning about it — actually impersonate a non-owner,
non-coach user against the local database and show the query being denied:

```sql
-- after `supabase db reset`, connect with the Supabase CLI's local db (or psql)
set role authenticated;
set request.jwt.claims = '{"sub":"<some-other-users-uuid>","role":"authenticated"}';

-- should return 0 rows for a table/row this user has no access to:
select * from public.workout_logs where user_id = '<owner-uuid>';

-- for a coach-access policy, re-run with a coach's uuid in request.jwt.claims and confirm
-- it returns rows only when an active relationship + matching permission exist, and 0 rows
-- once you flip coaching_relationships.status to 'ended' or the permission to false;

reset role;
```

Show the actual query results (row counts), not just "I checked the policy logic."

## Steps

1. Read `supabase/SCHEMA.md` for the relevant tier/scope.
2. `supabase migration new <name>`, write the migration following the mechanics above.
3. `supabase db reset` locally, show real output.
4. Run the impersonation test above for the new/changed policy, show real output.
5. Stop and get explicit confirmation before `supabase db push`.

## Completion criteria

- `git status` shows only an added migration file — no edits to any existing one.
- `supabase db reset` executed locally and its output shown.
- The SQL impersonation test executed and its result (denied/allowed as expected) shown.
- Every new `security definer` function has `set search_path`.
- No coach write policy introduced on any athlete-owned table.
- `supabase db push` not run without the user's explicit go-ahead in this conversation.
