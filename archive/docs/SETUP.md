# Connecting this backend to Supabase

## 1. What's new in this drop
```
supabase/
  migrations/
    20260801000001_extensions_and_enums.sql
    20260801000002_profiles.sql
    20260801000003_exercise_library.sql
    20260801000004_workout_tracker.sql
    20260801000005_roadmap_core.sql
    20260801000006_roadmap_workouts_logs.sql
    20260801000007_skill_progress.sql
    20260801000008_weekly_challenges.sql
    20260801000009_achievements.sql
    20260801000010_social.sql
    20260801000011_admin_audit.sql
    20260801000012_rls_policies.sql
    20260801000013_functions_triggers.sql
    20260801000014_views.sql
    20260801000015_storage_buckets.sql   <- new: turns the ARCHITECTURE.md
    20260801000016_realtime.sql          <- storage/realtime snippets into
    20260801000017_auth_trigger.sql      <- real, runnable migration files
.env.example
SETUP.md   (this file)
```
The first 14 files are your existing `schema.sql` and `rls_functions_views.sql`, split into
the numbered format the Supabase CLI expects (one migration per file, applied in filename
order). No SQL inside them changed. Files 15–17 are genuinely new — they were previously only
described as code snippets inside `ARCHITECTURE.md` and need to actually run.

## 2. Create the Supabase project
1. https://supabase.com/dashboard → New project. Pick a region close to your users, set the
   database password (save it — you'll need it for the CLI link step).
2. Once it's provisioned: **Project Settings → API** — copy the **Project URL** and the
   **anon public key**. Also grab the **service_role key** here (needed only for admin
   scripts/seeding, never ship it in the Flutter app).

## 3. Install the Supabase CLI and push the migrations
```bash
npm install -g supabase          # or: brew install supabase/tap/supabase

supabase login
supabase init                    # if this repo doesn't already have a supabase/ folder committed
supabase link --project-ref <your-project-ref>   # ref is in the dashboard URL
supabase db push                 # applies every file in supabase/migrations/ in order
```
`db push` runs each file in filename order and records what's already applied, so re-running
it later only applies new migrations — safe to commit this folder to git and run it in CI.

If you'd rather not install the CLI: open **SQL Editor** in the dashboard and paste each file's
contents in order (0001 → 0017), running each one before moving to the next.

## 4. Enable Auth providers
**Authentication → Providers** — since the ERD assumes Supabase Auth handles signup, turn on
Email, and Google/Apple if you're offering social login. Apple sign-in requires your Apple
Developer credentials configured here before it'll work in the Flutter app.

## 5. Connect Flutter
```
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon public key from step 2>
```
(see `.env.example`) — the anon key is safe to ship client-side; RLS is what actually protects
the data. Add your Flutter package:
```yaml
dependencies:
  supabase_flutter: ^2.x
```
```dart
await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
```

## 6. What you need to download yourself — the exercise library
Writing ~150–800 exercises by hand isn't worth your time; there are public-domain datasets
built exactly for this:

- **free-exercise-db** — https://github.com/yuhonas/free-exercise-db — 800+ exercises,
  public domain, JSON, includes images. Browsable version: https://yuhonas.github.io/free-exercise-db/
- **wrkout/exercises.json** — https://github.com/wrkout/exercises.json — same public-domain
  dataset, and it already ships a generated `exercises-psql.sql` insert file, which is the
  fastest path into Postgres.

Recommended flow:
1. Clone/download either repo.
2. Filter to bodyweight/calisthenics-relevant entries first (the roadmap's exercises need to
   exist before you can seed `roadmap_workout_exercises`) — filter on `equipment: "body_only"`
   in free-exercise-db.
3. Map their fields to this schema's `exercises` table (`name`, `description`, `equipment`,
   `is_hold_based` — you'll set this manually for holds like L-sit/planche since the source
   dataset doesn't have that concept, `video_url`/`image_url` from their asset URLs).
4. Import via the Supabase SQL Editor, `psql`, or a small script using the `service_role` key
   (never the anon key, since `exercises` is admin-write-only under RLS).

I can write the mapping/import script once you've pulled the dataset and confirm which subset
you want seeded first (calisthenics-only vs. the full ~800).

## 7. Order of operations from here
1. `supabase db push` (migrations 1–17)
2. Seed `roadmap_categories`, `muscle_groups` by hand (small, hand-authored — see
   `ARCHITECTURE.md` §8)
3. Import the exercise library (step 6 above)
4. Author `skills` / `skill_prerequisites` / `skill_stages` / `objectives` /
   `roadmap_workouts` + `roadmap_workout_exercises` per skill
5. Seed `achievements`
6. Point the Flutter app at the project and start building against real data
