const { createDatabase } = require('../src/config/database');
const { seedQuestions } = require('../src/persistence/questionSeed');
const crypto = require('node:crypto');

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required for db:seed');
  const database = createDatabase();
  const client = await database.pool.connect();
  const questions = seedQuestions();
  try {
    await client.query('BEGIN');
    const ids = [];
    for (const question of questions) {
      const result = await client.query(`INSERT INTO practice_questions (id,question,option_a,option_b,option_c,option_d,correct_answer,explanation,category,topic,difficulty) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) ON CONFLICT (question) DO NOTHING RETURNING id`, [crypto.randomUUID(), question.question, ...question.options, question.correctAnswer, question.explanation, question.category, question.topic, question.difficulty]);
      if (result.rows[0]) ids.push(result.rows[0].id);
    }
    const test = await client.query(`INSERT INTO mock_tests (title,description,duration_minutes,question_count,difficulty,category,is_published) SELECT 'Campus Technical Mock','Development seed mock test',30,10,'Medium','DSA',true WHERE NOT EXISTS (SELECT 1 FROM mock_tests WHERE title = 'Campus Technical Mock') RETURNING id`);
    const testId = test.rows[0]?.id || (await client.query("SELECT id FROM mock_tests WHERE title = 'Campus Technical Mock' LIMIT 1")).rows[0].id;
    const dsaQuestions = (await client.query("SELECT id FROM practice_questions WHERE category = 'DSA' ORDER BY created_at LIMIT 10")).rows;
    for (let index = 0; index < dsaQuestions.length; index += 1) await client.query('INSERT INTO mock_questions (mock_test_id,question_id,position) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING', [testId, dsaQuestions[index].id, index + 1]);
    await client.query('UPDATE mock_tests SET question_count = (SELECT count(*) FROM mock_questions WHERE mock_test_id = $1) WHERE id = $1', [testId]);
    await client.query('COMMIT');
    console.log(`Seeded ${questions.length} practice questions and one mock test.`);
  } catch (error) { await client.query('ROLLBACK'); throw error; } finally { client.release(); await database.close(); }
}
main().catch((error) => { console.error(`Seed failed: ${error.message}`); process.exit(1); });
