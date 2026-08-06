/**
 * sync_exercise_db.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Imports free-exercise-db exercises into your Supabase exercise_library tables:
 *   • muscle_groups   → upserts all unique muscles
 *   • exercises       → upserts each exercise (slug = exercise id from JSON)
 *   • exercise_muscle_groups → links primary + secondary muscles
 *
 * The script is IDEMPOTENT — safe to run multiple times.
 * It uses ON CONFLICT DO NOTHING / DO UPDATE so existing records are preserved.
 *
 * Prerequisites:
 *   npm install @supabase/supabase-js dotenv
 *
 * Usage (from project root):
 *   node supabase/scripts/sync_exercise_db.js [--dry-run] [--limit=100]
 *
 * Flags:
 *   --dry-run    Parse & map data but don't write to Supabase
 *   --limit=N    Only import first N exercises (useful for testing)
 * ─────────────────────────────────────────────────────────────────────────────
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const fs   = require('fs');
const path = require('path');

// ── Args ──────────────────────────────────────────────────────────────────────
const args    = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const limitArg = args.find(a => a.startsWith('--limit='));
const LIMIT   = limitArg ? parseInt(limitArg.split('=')[1], 10) : Infinity;

// ── Supabase client ───────────────────────────────────────────────────────────
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = process.env.SUPABASE_URL;
const SERVICE_KEY   = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!DRY_RUN && (!SUPABASE_URL || !SERVICE_KEY)) {
  console.error(`
❌  Missing environment variables.
    Make sure supabase/.env contains:
      SUPABASE_URL=https://<ref>.supabase.co
      SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
`);
  process.exit(1);
}

const supabase = !DRY_RUN
  ? createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false },
    })
  : null;

// ── Paths ─────────────────────────────────────────────────────────────────────
const ROOT          = path.resolve(__dirname, '../../free-exercise-db');
const EXERCISES_DIR = path.join(ROOT, 'exercises');
const DIST_JSON     = path.join(ROOT, 'dist', 'exercises.json');

// ── Level → difficulty_level mapping (1–5 scale) ──────────────────────────────
const LEVEL_MAP = {
  beginner:     1,
  intermediate: 3,
  expert:       5,
};

// ── Equipment normalisation (free-exercise-db → your schema text) ─────────────
// Your exercises.equipment column is free-text, so we pass through as-is.
// Normalise null → null.
function normaliseEquipment(eq) {
  if (!eq || eq === 'body only') return null;
  return eq;
}

// ── Slug helper ───────────────────────────────────────────────────────────────
function toSlug(id) {
  // The exercise id from the JSON (e.g. "3_4_Sit-Up") becomes the slug.
  // Convert to lowercase, replace _ and spaces with -, strip unsafe chars.
  return id
    .toLowerCase()
    .replace(/[_\s]+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

// ── Load exercises ────────────────────────────────────────────────────────────
let rawExercises = [];

const files = fs.existsSync(EXERCISES_DIR)
  ? fs.readdirSync(EXERCISES_DIR).filter(f => f.endsWith('.json'))
  : [];

if (files.length > 0) {
  for (const file of files) {
    try {
      const ex = JSON.parse(fs.readFileSync(path.join(EXERCISES_DIR, file), 'utf8'));
      rawExercises.push(ex);
    } catch (_) { /* skip bad files */ }
  }
} else if (fs.existsSync(DIST_JSON)) {
  rawExercises = JSON.parse(fs.readFileSync(DIST_JSON, 'utf8'));
} else {
  console.error('❌  free-exercise-db not found. Expected at: ' + ROOT);
  process.exit(1);
}

// Apply limit
if (LIMIT < Infinity) {
  rawExercises = rawExercises.slice(0, LIMIT);
}

console.log(`
╔══════════════════════════════════════════════════════════════════════╗
║         MOMENTUM — Exercise DB Sync                                  ║
╚══════════════════════════════════════════════════════════════════════╝
  Mode      : ${DRY_RUN ? '🔍 DRY RUN (no writes)' : '🚀 LIVE'}
  Source    : ${files.length > 0 ? EXERCISES_DIR : DIST_JSON}
  Exercises : ${rawExercises.length}
  Supabase  : ${SUPABASE_URL || '(not needed in dry-run)'}
`);

// ── Collect all unique muscles ────────────────────────────────────────────────
const allMuscles = new Set();
for (const ex of rawExercises) {
  (ex.primaryMuscles   || []).forEach(m => allMuscles.add(m));
  (ex.secondaryMuscles || []).forEach(m => allMuscles.add(m));
}
const muscleList = [...allMuscles].sort();

console.log(`🦾  Unique muscles found: ${muscleList.length}`);
console.log(`    ${muscleList.join(', ')}\n`);

// ── Map exercises → DB rows ───────────────────────────────────────────────────
const exerciseRows = rawExercises.map(ex => ({
  name:             ex.name,
  slug:             toSlug(ex.id || ex.name),
  description:      (ex.instructions || []).join('\n\n') || null,
  equipment:        normaliseEquipment(ex.equipment),
  is_hold_based:    false,
  difficulty_level: LEVEL_MAP[ex.level] ?? null,
  category:         ex.category  || null,
  // Previously missing — now stored:
  force:            ex.force     || null,   // push / pull / static
  mechanic:         ex.mechanic  || null,   // compound / isolation
  level:            ex.level     || null,   // original string: beginner / intermediate / expert
  images:           (ex.images && ex.images.length > 0) ? ex.images : null, // text[]
}));

if (DRY_RUN) {
  console.log('📋  Sample mapped rows (first 3):');
  console.log(JSON.stringify(exerciseRows.slice(0, 3), null, 2));
  console.log('\n✅  Dry run complete — no data written.\n');
  process.exit(0);
}

// ── LIVE SYNC ─────────────────────────────────────────────────────────────────
async function main() {
  let successCount = 0;
  let errorCount   = 0;

  // ── Step 1: Upsert muscle_groups ──────────────────────────────────────────
  console.log('──────────────────────────────────────────────────────────────────');
  console.log('Step 1/3 — Upserting muscle_groups…');

  const { error: mgErr } = await supabase
    .from('muscle_groups')
    .upsert(
      muscleList.map(name => ({ name })),
      { onConflict: 'name', ignoreDuplicates: true }
    );

  if (mgErr) {
    console.error('❌  muscle_groups upsert failed:', mgErr.message);
    process.exit(1);
  }
  console.log(`✅  ${muscleList.length} muscle groups synced.\n`);

  // Fetch muscle_group id map
  const { data: mgRows, error: mgFetchErr } = await supabase
    .from('muscle_groups')
    .select('id, name');
  if (mgFetchErr) {
    console.error('❌  Could not fetch muscle_groups:', mgFetchErr.message);
    process.exit(1);
  }
  const muscleIdMap = Object.fromEntries(mgRows.map(r => [r.name, r.id]));

  // ── Step 2: Upsert exercises (batched) ────────────────────────────────────
  console.log('──────────────────────────────────────────────────────────────────');
  console.log('Step 2/3 — Upserting exercises…');

  const BATCH = 100;
  const insertedSlugs = [];

  for (let i = 0; i < exerciseRows.length; i += BATCH) {
    const batch = exerciseRows.slice(i, i + BATCH);
    const { data, error } = await supabase
      .from('exercises')
      .upsert(batch, { onConflict: 'slug' })
      .select('id, slug');

    if (error) {
      console.error(`❌  Batch ${i}–${i + BATCH} failed:`, error.message);
      errorCount += batch.length;
    } else {
      successCount += data.length;
      insertedSlugs.push(...data);
      process.stdout.write(`   ${successCount}/${exerciseRows.length} exercises…\r`);
    }
  }

  console.log(`\n✅  ${successCount} exercises upserted${errorCount > 0 ? `, ${errorCount} errors` : ''}.\n`);

  // Build slug → id map
  const slugIdMap = Object.fromEntries(insertedSlugs.map(r => [r.slug, r.id]));

  // ── Step 3: Upsert exercise_muscle_groups ─────────────────────────────────
  console.log('──────────────────────────────────────────────────────────────────');
  console.log('Step 3/3 — Linking exercise ↔ muscle_groups…');

  const muscleLinks = [];
  for (const ex of rawExercises) {
    const slug = toSlug(ex.id || ex.name);
    const exId = slugIdMap[slug];
    if (!exId) continue;

    const seen = new Set();

    // Primary muscles — is_primary = true
    for (const m of (ex.primaryMuscles || [])) {
      const mgId = muscleIdMap[m];
      if (mgId && !seen.has(mgId)) {
        seen.add(mgId);
        muscleLinks.push({ exercise_id: exId, muscle_group_id: mgId, is_primary: true });
      }
    }

    // Secondary muscles — is_primary = false
    // Skip if already added as primary (primary wins)
    for (const m of (ex.secondaryMuscles || [])) {
      const mgId = muscleIdMap[m];
      if (mgId && !seen.has(mgId)) {
        seen.add(mgId);
        muscleLinks.push({ exercise_id: exId, muscle_group_id: mgId, is_primary: false });
      }
    }
  }

  // Upsert in batches
  for (let i = 0; i < muscleLinks.length; i += BATCH) {
    const batch = muscleLinks.slice(i, i + BATCH);
    const { error } = await supabase
      .from('exercise_muscle_groups')
      .upsert(batch, { onConflict: 'exercise_id,muscle_group_id', ignoreDuplicates: true });
    if (error) {
      console.error(`❌  Muscle link batch ${i}–${i + BATCH} failed:`, error.message);
    }
  }
  console.log(`✅  ${muscleLinks.length} exercise↔muscle links synced.\n`);

  // ── Final summary ─────────────────────────────────────────────────────────
  console.log('╔══════════════════════════════════════════════════════════════════╗');
  console.log('║  ✅  SYNC COMPLETE                                               ║');
  console.log('╠══════════════════════════════════════════════════════════════════╣');
  console.log(`║  Exercises upserted   : ${String(successCount).padEnd(42)}║`);
  console.log(`║  Muscle groups synced : ${String(muscleList.length).padEnd(42)}║`);
  console.log(`║  Muscle links synced  : ${String(muscleLinks.length).padEnd(42)}║`);
  if (errorCount > 0) {
    console.log(`║  ⚠️  Errors            : ${String(errorCount).padEnd(42)}║`);
  }
  console.log('╚══════════════════════════════════════════════════════════════════╝\n');
}

main().catch(err => {
  console.error('\n❌  Unexpected error:', err);
  process.exit(1);
});
