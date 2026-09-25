const { Pool } = require('pg');

function createDatabase() {
  if (!process.env.DATABASE_URL) return null;
  const isProduction = process.env.NODE_ENV === 'production';
  const requireSsl = process.env.DATABASE_SSL === 'true' || isProduction || /sslmode=require/i.test(process.env.DATABASE_URL);
  const ssl = requireSsl ? { rejectUnauthorized: false } : undefined;
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: Number(process.env.DB_POOL_MAX || 10),
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
    ssl,
  });
  return {
    pool,
    async check() { await pool.query('SELECT 1'); },
    async close() { await pool.end(); },
  };
}

module.exports = { createDatabase };

