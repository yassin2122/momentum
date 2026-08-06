require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const { createClient } = require('@supabase/supabase-js');

const s = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
);

async function main() {
  console.log('🔗  Connecting to:', process.env.SUPABASE_URL);

  const tables = ['exercises', 'muscle_groups', 'exercise_muscle_groups', 'profiles'];
  for (const table of tables) {
    const { count, error } = await s.from(table).select('*', { count: 'exact', head: true });
    if (error) {
      console.log(`  ❌  ${table.padEnd(28)} ERROR: ${error.message}`);
    } else {
      console.log(`  ✅  ${table.padEnd(28)} rows: ${count}`);
    }
  }
}

main().catch(console.error);
