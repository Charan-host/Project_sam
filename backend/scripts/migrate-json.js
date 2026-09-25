const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createDatabase } = require('../src/config/database');

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required for db:migrate-json');
  const database = createDatabase();
  const file = path.join(__dirname, '..', 'data.json');
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const client = await database.pool.connect();
  let counts = { users: 0, tasks: 0, practiceAttempts: 0, mockAttempts: 0 };
  try {
    await client.query('BEGIN');
    for (const user of data.users || []) {
      await client.query('INSERT INTO users (id,email,password_hash,password_salt) VALUES ($1,$2,$3,$4) ON CONFLICT (id) DO NOTHING', [user.id, user.email, user.hash, user.salt]);
      await client.query('INSERT INTO profiles (user_id,full_name,college,course,roll_number,graduation_year,target_role,skill_level,cgpa,degree) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT (user_id) DO NOTHING', [user.id, user.name, user.college || '', user.course || user.degree || '', user.rollNumber || '', user.graduationYear || null, user.targetRole || '', user.skillLevel || 'Beginner', user.cgpa || null, user.degree || '']);
      await client.query('INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [user.id]);
      await client.query('INSERT INTO user_progress (user_id,xp) VALUES ($1,$2) ON CONFLICT DO NOTHING', [user.id, user.xp || 0]); counts.users += 1;
    }
    for (const task of data.tasks || []) { await client.query('INSERT INTO tasks (id,user_id,title,description,category,priority,due_date,estimated_minutes,status,xp,created_at,completed_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) ON CONFLICT (id) DO NOTHING', [task.id, task.userId, task.title, task.description || '', task.category || 'General', task.priority || 'Medium', task.dueDate || null, task.estimatedMinutes || null, task.status || (task.completed ? 'Completed' : 'Pending'), task.xp || 15, task.createdAt || new Date(), task.completedAt || null]); counts.tasks += 1; }
    for (const attempt of data.practiceAttempts || []) { await client.query('INSERT INTO practice_attempts (id,user_id,topic,score,total,completed_at) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (id) DO NOTHING', [attempt.id || crypto.randomUUID(), attempt.userId, attempt.topic || 'General', attempt.score || 0, attempt.total || 0, attempt.completedAt || new Date()]); counts.practiceAttempts += 1; }
    for (const attempt of data.mockAttempts || []) { await client.query('INSERT INTO mock_attempts (id,user_id,title,score,total,completed_at) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (id) DO NOTHING', [attempt.id || crypto.randomUUID(), attempt.userId, attempt.title || 'Mock Test', attempt.score || 0, attempt.total || 0, attempt.completedAt || new Date()]); counts.mockAttempts += 1; }
    await client.query('COMMIT'); console.log(`Migrated users=${counts.users}, tasks=${counts.tasks}, practiceAttempts=${counts.practiceAttempts}, mockAttempts=${counts.mockAttempts}`);
  } catch (error) { await client.query('ROLLBACK'); throw error; } finally { client.release(); await database.close(); }
}
main().catch((error) => { console.error(`JSON migration failed: ${error.message}`); process.exit(1); });
