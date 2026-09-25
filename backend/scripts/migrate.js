const fs = require('node:fs');
const path = require('node:path');
const { createDatabase } = require('../src/config/database');

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required for db:migrate');
  const database = createDatabase();
  const migrationDirectory = path.join(__dirname, '..', 'migrations');
  const sql = fs.readdirSync(migrationDirectory).filter((file) => file.endsWith('.sql')).sort().map((file) => fs.readFileSync(path.join(migrationDirectory, file), 'utf8')).join('\n');
  try { await database.pool.query(sql); console.log('Database migration applied successfully.'); }
  finally { await database.close(); }
}
main().catch((error) => { console.error(`Migration failed: ${error.message}`); process.exit(1); });
