/**
 * audit_exercise_db.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Scans every exercise JSON in free-exercise-db/exercises/ and reports:
 *   • Schema violations (missing required fields, bad enum values)
 *   • Duplicate IDs / duplicate names
 *   • Empty or suspiciously short instructions
 *   • Missing images references
 *   • Exercises with no primary muscle
 *   • Equipment / category / level mismatches vs schema
 *
 * Usage (from project root):
 *   node supabase/scripts/audit_exercise_db.js
 *
 * No dependencies — pure Node.js (fs/path only).
 * ─────────────────────────────────────────────────────────────────────────────
 */

const fs   = require('fs');
const path = require('path');

// ── Paths ────────────────────────────────────────────────────────────────────
const ROOT          = path.resolve(__dirname, '../../free-exercise-db');
const EXERCISES_DIR = path.join(ROOT, 'exercises');
const DIST_JSON     = path.join(ROOT, 'dist', 'exercises.json');

// ── Allowed enum values (from schema.json) ───────────────────────────────────
const ALLOWED = {
  force:     new Set([null, 'static', 'pull', 'push']),
  level:     new Set(['beginner', 'intermediate', 'expert']),
  mechanic:  new Set([null, 'isolation', 'compound']),
  equipment: new Set([
    null, 'medicine ball', 'dumbbell', 'body only', 'bands',
    'kettlebells', 'foam roll', 'cable', 'machine', 'barbell',
    'exercise ball', 'e-z curl bar', 'other'
  ]),
  muscles: new Set([
    'abdominals','abductors','adductors','biceps','calves','chest',
    'forearms','glutes','hamstrings','lats','lower back','middle back',
    'neck','quadriceps','shoulders','traps','triceps'
  ]),
  category: new Set([
    'powerlifting','strength','stretching','cardio',
    'olympic weightlifting','strongman','plyometrics'
  ]),
};

const REQUIRED_FIELDS = ['id','name','level','mechanic','equipment',
                         'primaryMuscles','secondaryMuscles','instructions',
                         'category','images'];

// ── Helpers ──────────────────────────────────────────────────────────────────
const issues = [];
function warn(id, msg) {
  issues.push({ id, msg });
}

// ── Load exercises ────────────────────────────────────────────────────────────
let exercises = [];

const files = fs.existsSync(EXERCISES_DIR)
  ? fs.readdirSync(EXERCISES_DIR).filter(f => f.endsWith('.json'))
  : [];

if (files.length > 0) {
  console.log(`\n📂  Loading ${files.length} individual exercise JSON files…\n`);
  for (const file of files) {
    try {
      const raw = fs.readFileSync(path.join(EXERCISES_DIR, file), 'utf8');
      const ex  = JSON.parse(raw);
      exercises.push({ _file: file, ...ex });
    } catch (e) {
      warn(file, `JSON parse error: ${e.message}`);
    }
  }
} else if (fs.existsSync(DIST_JSON)) {
  console.log(`\n📦  Loading from dist/exercises.json…\n`);
  const raw = fs.readFileSync(DIST_JSON, 'utf8');
  exercises = JSON.parse(raw).map(ex => ({ _file: 'dist/exercises.json', ...ex }));
} else {
  console.error('❌  No exercises found. Make sure free-exercise-db is in the right place.');
  process.exit(1);
}

// ── Tracking sets ─────────────────────────────────────────────────────────────
const seenIds   = new Map();
const seenNames = new Map();

let totalChecked = 0;

// ── Per-exercise validation ───────────────────────────────────────────────────
for (const ex of exercises) {
  totalChecked++;
  const id = ex.id || ex._file;

  // 1. Required fields
  for (const field of REQUIRED_FIELDS) {
    if (!(field in ex)) {
      warn(id, `Missing required field: "${field}"`);
    }
  }

  // 2. Duplicate IDs
  if (ex.id) {
    if (seenIds.has(ex.id)) {
      warn(id, `Duplicate ID — also in ${seenIds.get(ex.id)}`);
    } else {
      seenIds.set(ex.id, ex._file);
    }
  }

  // 3. Duplicate names (case-insensitive)
  if (ex.name) {
    const normName = ex.name.trim().toLowerCase();
    if (seenNames.has(normName)) {
      warn(id, `Duplicate name "${ex.name}" — also in ${seenNames.get(normName)}`);
    } else {
      seenNames.set(normName, ex._file);
    }
  }

  // 4. Enum checks
  if ('force' in ex    && !ALLOWED.force.has(ex.force))
    warn(id, `Invalid force value: "${ex.force}"`);
  if ('level' in ex    && !ALLOWED.level.has(ex.level))
    warn(id, `Invalid level value: "${ex.level}"`);
  if ('mechanic' in ex && !ALLOWED.mechanic.has(ex.mechanic))
    warn(id, `Invalid mechanic value: "${ex.mechanic}"`);
  if ('equipment' in ex && !ALLOWED.equipment.has(ex.equipment))
    warn(id, `Invalid equipment value: "${ex.equipment}"`);
  if ('category' in ex && !ALLOWED.category.has(ex.category))
    warn(id, `Invalid category value: "${ex.category}"`);

  // 5. Muscle checks
  if (Array.isArray(ex.primaryMuscles)) {
    if (ex.primaryMuscles.length === 0)
      warn(id, `primaryMuscles is empty — no primary muscle defined`);
    for (const m of ex.primaryMuscles)
      if (!ALLOWED.muscles.has(m)) warn(id, `Unknown primary muscle: "${m}"`);
  }
  if (Array.isArray(ex.secondaryMuscles)) {
    for (const m of ex.secondaryMuscles)
      if (!ALLOWED.muscles.has(m)) warn(id, `Unknown secondary muscle: "${m}"`);
  }

  // 6. Instructions quality
  if (Array.isArray(ex.instructions)) {
    if (ex.instructions.length === 0) {
      warn(id, `instructions array is empty`);
    } else {
      ex.instructions.forEach((step, i) => {
        if (typeof step !== 'string' || step.trim().length < 10)
          warn(id, `instruction[${i}] is suspiciously short: "${step}"`);
      });
    }
  }

  // 7. Images (existence on disk)
  if (Array.isArray(ex.images)) {
    if (ex.images.length === 0) {
      warn(id, `images array is empty`);
    }
    for (const imgPath of ex.images) {
      const absImg = path.join(EXERCISES_DIR, imgPath);
      if (!fs.existsSync(absImg))
        warn(id, `Image file not found: "${imgPath}"`);
    }
  }

  // 8. Filename ↔ id consistency
  if (ex.id && ex._file !== 'dist/exercises.json') {
    const expectedFile = `${ex.id}.json`;
    if (ex._file !== expectedFile)
      warn(id, `Filename "${ex._file}" doesn't match id "${ex.id}" (expected ${expectedFile})`);
  }

  // 9. Non-empty name
  if (!ex.name || typeof ex.name !== 'string' || ex.name.trim() === '')
    warn(id, `name is missing or empty`);
}

// ── Summary Report ────────────────────────────────────────────────────────────
console.log('═'.repeat(72));
console.log('  FREE-EXERCISE-DB AUDIT REPORT');
console.log('═'.repeat(72));
console.log(`  Total exercises checked : ${totalChecked}`);
console.log(`  Total issues found      : ${issues.length}`);
console.log('─'.repeat(72));

if (issues.length === 0) {
  console.log('\n✅  No issues found — database looks clean!\n');
} else {
  // Group issues by category prefix
  const byType = {};
  for (const { id, msg } of issues) {
    const type = msg.split(':')[0].trim();
    if (!byType[type]) byType[type] = [];
    byType[type].push({ id, msg });
  }

  for (const [type, items] of Object.entries(byType)) {
    console.log(`\n⚠️  ${type} (${items.length} occurrence${items.length > 1 ? 's' : ''})`);
    console.log('─'.repeat(72));
    for (const { id, msg } of items.slice(0, 20)) {
      console.log(`   [${id}]`);
      console.log(`     → ${msg}`);
    }
    if (items.length > 20) {
      console.log(`   … and ${items.length - 20} more (see report file)`);
    }
  }

  // Write JSON report next to this script
  const reportPath = path.join(__dirname, 'audit_report.json');
  fs.writeFileSync(reportPath, JSON.stringify({
    generated: new Date().toISOString(),
    totalExercises: totalChecked,
    totalIssues: issues.length,
    issues,
  }, null, 2));
  console.log(`\n📄  Full report → ${reportPath}`);
}

console.log('\n' + '═'.repeat(72));

// Exit with error code if critical issues exist
const criticalIssues = issues.filter(i =>
  i.msg.includes('parse error') ||
  i.msg.includes('Duplicate ID') ||
  i.msg.includes('Missing required field')
);
if (criticalIssues.length > 0) {
  console.log(`\n🚨  ${criticalIssues.length} CRITICAL issue(s) — fix before running sync!\n`);
  process.exit(1);
}
