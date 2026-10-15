---
name: performance-audit
description: Find performance problems in Momentum's Flutter widgets/providers and Supabase queries/RLS policies — unnecessary rebuilds, missing pagination, N+1 queries, unindexed foreign keys, oversized payloads. Read-only — reports findings only.
---

# Performance audit

Shared rules are in the root `CLAUDE.md` — read it first. **This skill is read-only.** Do
not use Edit/Write while running it — produce a findings report; fixes are a separate,
explicitly-authorized follow-up.

## Flutter side

- **Rebuild scope**: a `ConsumerWidget`/`ref.watch` at the top of a large widget tree
  rebuilds the whole tree on every provider change — check whether a narrower `Consumer`
  around just the data-dependent subtree would do.
- **Pagination**: the existing good pattern is in `exercise_repository_impl.dart` —
  fetch `limit + 1` rows to derive `hasMore` without a separate count query. Flag any new
  list screen that instead loads everything or re-queries a count.
- **Images**: `cached_network_image` is a declared dependency — flag raw `Image.network(...)`
  where a cached variant would avoid re-fetching on every rebuild/scroll.
- **Nav shell**: `StatefulNavigationShell` (via `AppShell`) already preserves per-tab state
  so switching tabs doesn't rebuild from scratch — flag any new screen that defeats this by
  keying itself out of the shell unnecessarily.
- **setState vs Riverpod**: flag broad `setState` calls that rebuild more than the widget
  that actually changed, where a scoped provider would do less work.

## Supabase side

- **Missing FK indexes**: migrations 24/25 (`fix_missing_fk_indexes`,
  `fix_remaining_fk_indexes`) exist specifically because earlier migrations added foreign
  keys without indexes. Check that any new FK in a new migration has a matching index.
- **N+1 queries**: a loop issuing one query per row from the client, where a single
  PostgREST embed/join (or a new view) would do it in one round trip.
- **Payload size**: `config.toml`'s `max_rows = 1000` is a hard cap — flag a query that
  could plausibly need more than that without pagination.
- **RLS policy cost**: a policy whose `using`/`with check` runs an expensive subquery per
  row (e.g. a multi-join `exists(...)`) on a large, frequently-queried table — compare
  against how `coach_can_view` is written (single indexed lookup) before flagging.

## Steps

1. Read the changed/target files (or the area the user names).
2. Check each against the lists above.
3. For a DB concern, read the actual migration + policy involved rather than guessing from
   the table name.
4. Report findings with file:line and a concrete suggested fix. Make no edits.

## Completion criteria

- A findings report with file:line and suggested fix per item (possibly empty).
- Zero files edited during this skill's run.
