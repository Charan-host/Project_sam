const http = require('node:http');
const crypto = require('node:crypto');
const path = require('node:path');
const { createDatabase } = require('./src/config/database');
const { JsonStore } = require('./src/persistence/jsonStore');
const { PostgresStore, mapUser } = require('./src/persistence/postgresStore');

const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET || 'change-this-secret-before-deploying';
const database = createDatabase();
const store = database ? new PostgresStore(database) : new JsonStore(path.join(__dirname, 'data.json'));
const persistenceMode = database ? 'postgresql' : 'json-fallback';
const authAttempts = new Map();

function json(response, status, body) { response.writeHead(status, { 'content-type': 'application/json; charset=utf-8' }); response.end(JSON.stringify(body)); }
function createId() { return crypto.randomUUID(); }
function passwordHash(password, salt = crypto.randomBytes(16).toString('hex')) { return { salt, hash: crypto.scryptSync(password, salt, 64).toString('hex') }; }
function tokenFor(userId) { const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url'); const payload = Buffer.from(JSON.stringify({ sub: userId, exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 })).toString('base64url'); const signature = crypto.createHmac('sha256', jwtSecret).update(`${header}.${payload}`).digest('base64url'); return `${header}.${payload}.${signature}`; }
function claimsFromRequest(request) {
  try {
    const [header, payload, signature] = (request.headers.authorization || '').replace(/^Bearer\s+/i, '').split('.');
    if (!header || !payload || !signature) return null;
    const expected = crypto.createHmac('sha256', jwtSecret).update(`${header}.${payload}`).digest('base64url');
    if (signature.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) return null;
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    return claims.exp >= Math.floor(Date.now() / 1000) ? claims : null;
  } catch (_) { return null; }
}
function publicUser(user) { const mapped = mapUser(user); return mapped ? { ...mapped, notificationsEnabled: mapped.notificationsEnabled ?? true, xp: mapped.xp ?? 0 } : null; }
function readBody(request) { return new Promise((resolve, reject) => { let body = ''; request.on('data', (chunk) => { body += chunk; if (body.length > 1e6) request.destroy(); }); request.on('end', () => { try { resolve(body ? JSON.parse(body) : {}); } catch (error) { reject(error); } }); request.on('error', reject); }); }
function errorResponse(response, error) { console.error('Request failed:', error.message); return json(response, 500, { success: false, error: 'The server could not complete that request' }); }
async function notify(user, notification) { if (user.notificationsEnabled === false || user.notifications_enabled === false) return; await store.createNotification({ userId: user.id, ...notification }); }

function resolveCorsOrigin(requestOrigin) {
  const allowed = (process.env.CORS_ORIGIN || 'http://localhost:8080,http://localhost:3000')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!requestOrigin) return allowed[0] || '*';
  if (allowed.includes('*')) return '*';
  if (allowed.includes(requestOrigin)) return requestOrigin;
  return null;
}

async function handle(request, response) {
  const requestOrigin = request.headers.origin;
  const allowedOrigin = resolveCorsOrigin(requestOrigin);
  if (request.method === 'OPTIONS') {
    if (requestOrigin && !allowedOrigin) {
      response.writeHead(403, { 'content-type': 'application/json' });
      return response.end(JSON.stringify({ success: false, error: 'Origin not allowed by CORS' }));
    }
    response.writeHead(204, {
      'access-control-allow-origin': allowedOrigin || '*',
      'access-control-allow-headers': 'content-type, authorization',
      'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
      'vary': 'Origin',
    });
    return response.end();
  }
  if (allowedOrigin) {
    response.setHeader('access-control-allow-origin', allowedOrigin);
    response.setHeader('vary', 'Origin');
  }
  const url = new URL(request.url, `http://${request.headers.host}`);
  const versioned = url.pathname.startsWith('/api/v1');
  url.pathname = url.pathname.replace(/^\/api\/v1(?=\/|$)/, '/api');
  let body = {};
  try { if (['POST', 'PATCH'].includes(request.method)) body = await readBody(request); } catch (_) { return json(response, 400, { success: false, error: 'Request body must be valid JSON' }); }

  if (request.method === 'GET' && (url.pathname === '/api/health' || url.pathname === '/health')) {
    try { await store.health(); return json(response, 200, { success: true, status: 'ok', server: 'ok', database: persistenceMode === 'postgresql' ? 'ok' : 'json-fallback', mode: persistenceMode, versioned }); }
    catch (_) { return json(response, 503, { success: false, status: 'unhealthy', server: 'ok', database: 'unavailable', mode: persistenceMode }); }
  }
  if (request.method === 'POST' && ['/api/auth/signup', '/api/auth/login'].includes(url.pathname)) {
    const clientKey = request.socket.remoteAddress || 'unknown'; const recentAttempts = authAttempts.get(clientKey) || []; const activeAttempts = recentAttempts.filter((time) => Date.now() - time < 60000); if (activeAttempts.length >= 10) return json(response, 429, { success: false, error: 'Too many authentication attempts. Try again shortly.' }); authAttempts.set(clientKey, [...activeAttempts, Date.now()]);
    const email = String(body.email || '').trim().toLowerCase(); const password = String(body.password || ''); const name = String(body.name || '').trim();
    const signup = url.pathname.endsWith('signup'); const invalidPassword = signup ? password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password) : password.length === 0;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || (signup && !name) || invalidPassword) return json(response, 400, { success: false, error: 'Use a valid email and a password of at least 8 characters containing a letter and a number' });
    const existing = await store.findUserByEmail(email);
    let user;
    if (signup) {
      if (existing) return json(response, 409, { success: false, error: 'An account with this email already exists' });
      user = await store.createUser({ id: createId(), name, email, ...passwordHash(password), rollNumber: '', cgpa: '', degree: String(body.course || 'B.Tech CSE'), college: String(body.college || ''), course: String(body.course || 'B.Tech CSE'), graduationYear: body.graduationYear ? Number(body.graduationYear) : null, targetRole: String(body.targetRole || ''), skillLevel: String(body.skillLevel || 'Beginner'), notificationsEnabled: true, xp: 0 });
    } else {
      if (!existing || passwordHash(password, existing.password_salt || existing.salt).hash !== (existing.password_hash || existing.hash)) return json(response, 401, { success: false, error: 'Invalid email or password' });
      user = existing;
    }
    return json(response, 200, { success: true, token: tokenFor(user.id), user: publicUser(user) });
  }

  const claims = claimsFromRequest(request);
  const user = claims ? await store.findUserById(claims.sub) : null;
  if (!user) return json(response, 401, { success: false, error: 'Authentication required' });
  if (request.method === 'GET' && url.pathname === '/api/me') return json(response, 200, { success: true, user: publicUser(user) });
  if (request.method === 'PATCH' && url.pathname === '/api/me') return json(response, 200, { success: true, user: publicUser(await store.updateUser(user.id, body)) });
  if (request.method === 'GET' && url.pathname === '/api/notifications') return json(response, 200, { success: true, notifications: await store.listNotifications(user.id) });
  if (request.method === 'GET' && url.pathname === '/api/notifications/unread-count') return json(response, 200, { success: true, count: await store.unreadNotificationCount(user.id) });
  const notificationMatch = url.pathname.match(/^\/api\/notifications\/([^/]+)\/read$/);
  if (notificationMatch && request.method === 'POST') { const notification = await store.markNotificationRead(user.id, notificationMatch[1]); return notification ? json(response, 200, { success: true, notification }) : json(response, 404, { success: false, error: 'Notification not found' }); }
  if (request.method === 'POST' && url.pathname === '/api/notifications/read-all') return json(response, 200, { success: true, count: await store.markAllNotificationsRead(user.id) });
  const timezoneOffset = Number(url.searchParams.get('timezoneOffset') || 0);
  if (request.method === 'GET' && ['/api/progress', '/api/analytics', '/api/dashboard', '/api/analytics/weekly', '/api/analytics/performance-history'].includes(url.pathname)) {
    const snapshot = await store.analytics(user.id, Number.isFinite(timezoneOffset) ? timezoneOffset : 0);
    if (url.pathname === '/api/progress') return json(response, 200, { success: true, progress: snapshot.progress });
    if (url.pathname === '/api/analytics') return json(response, 200, { success: true, ...snapshot.analytics });
    if (url.pathname === '/api/analytics/weekly') return json(response, 200, { success: true, weekly: snapshot.analytics.daily });
    if (url.pathname === '/api/analytics/performance-history') return json(response, 200, { success: true, history: snapshot.analytics.performanceHistory || [] });
    return json(response, 200, { success: true, dashboard: { user: publicUser(user), ...snapshot.progress, ...snapshot.analytics } });
  }
  if (request.method === 'GET' && url.pathname === '/api/practice/questions') {
    const questions = await store.listQuestions({ category: url.searchParams.get('category') || '', topic: url.searchParams.get('topic') || '', difficulty: url.searchParams.get('difficulty') || '', limit: Number(url.searchParams.get('limit') || 10) });
    return json(response, 200, { success: true, questions });
  }
  if (request.method === 'GET' && url.pathname === '/api/practice/history') return json(response, 200, { success: true, attempts: await store.listPracticeHistory(user.id) });
  if (request.method === 'GET' && url.pathname === '/api/practice/performance') {
    const attempts = await store.listPracticeHistory(user.id); const total = attempts.reduce((sum, attempt) => sum + Number(attempt.total || 0), 0); const score = attempts.reduce((sum, attempt) => sum + Number(attempt.score || 0), 0);
    return json(response, 200, { success: true, performance: { attempts: attempts.length, questions: total, correct: score, accuracy: total ? Math.round((score / total) * 100) : 0 } });
  }
  if (request.method === 'POST' && url.pathname === '/api/practice/sessions') {
    if (!Array.isArray(body.answers) || body.answers.length === 0) return json(response, 400, { success: false, error: 'At least one answer is required' });
    if (body.answers.some((answer) => answer.selectedAnswer && !/^[ABCD]$/i.test(answer.selectedAnswer))) return json(response, 400, { success: false, error: 'Answer choices must be A, B, C, or D' });
    const result = await store.createPracticeSession({ id: createId(), userId: user.id, category: String(body.category || 'General'), topic: String(body.topic || ''), difficulty: String(body.difficulty || 'Medium'), timeSpentSeconds: Number(body.timeSpentSeconds || 0) }, body.answers.map((answer) => ({ questionId: String(answer.questionId || ''), selectedAnswer: answer.selectedAnswer ? String(answer.selectedAnswer).toUpperCase() : null, timeTakenSeconds: Number(answer.timeTakenSeconds || 0) })));
    await notify(user, { type: 'practice_completed', title: 'Practice session completed', message: `${result.score}/${result.total} in ${result.category}`, relatedEntityType: 'practice_session', relatedEntityId: result.id });
    return json(response, 201, { success: true, result });
  }
  if (request.method === 'GET' && url.pathname === '/api/mock-tests') return json(response, 200, { success: true, tests: await store.listMockTests() });
  if (request.method === 'GET' && url.pathname === '/api/mock-tests/history') return json(response, 200, { success: true, attempts: await store.listMockAttempts(user.id) });
  const mockMatch = url.pathname.match(/^\/api\/mock-tests\/([^/]+)$/);
  if (mockMatch && request.method === 'GET') {
    const test = await store.getMockTest(mockMatch[1]); if (!test) return json(response, 404, { success: false, error: 'Mock test not found' });
    return json(response, 200, { success: true, test: { ...test, questions: await store.getMockQuestions(mockMatch[1]) } });
  }
  const mockStart = url.pathname.match(/^\/api\/mock-tests\/([^/]+)\/start$/);
  if (mockStart && request.method === 'POST') {
    const test = await store.getMockTest(mockStart[1]); if (!test) return json(response, 404, { success: false, error: 'Mock test not found' });
    return json(response, 200, { success: true, test: { ...test, questions: await store.getMockQuestions(mockStart[1]) } });
  }
  const mockSubmit = url.pathname.match(/^\/api\/mock-tests\/([^/]+)\/submit$/);
  if (mockSubmit && request.method === 'POST') {
    const test = await store.getMockTest(mockSubmit[1]); if (!test || !Array.isArray(body.answers)) return json(response, 400, { success: false, error: 'Valid mock test and answers are required' });
    if (body.answers.some((answer) => answer.selectedAnswer && !/^[ABCD]$/i.test(answer.selectedAnswer))) return json(response, 400, { success: false, error: 'Answer choices must be A, B, C, or D' });
    const questions = await store.getMockQuestions(mockSubmit[1]); const allowed = new Set(questions.map((question) => question.id));
    if (body.answers.some((answer) => !allowed.has(answer.questionId))) return json(response, 400, { success: false, error: 'Answer contains an invalid question' });
    const result = await store.createMockResult({ id: createId(), userId: user.id, mockTestId: mockSubmit[1], title: test.title, timeSpentSeconds: Number(body.timeSpentSeconds || 0) }, body.answers.map((answer) => ({ questionId: answer.questionId, selectedAnswer: answer.selectedAnswer ? String(answer.selectedAnswer).toUpperCase() : null, markedForReview: Boolean(answer.markedForReview) })));
    await notify(user, { type: 'mock_completed', title: 'Mock test completed', message: `${result.score}/${result.total} in ${test.title}`, relatedEntityType: 'mock_attempt', relatedEntityId: result.id });
    return json(response, 201, { success: true, result });
  }
  if (url.pathname === '/api/tasks' && request.method === 'GET') return json(response, 200, { success: true, tasks: await store.listTasks(user.id) });
  if (url.pathname === '/api/tasks' && request.method === 'POST') {
    const title = String(body.title || '').trim(); if (!title) return json(response, 400, { success: false, error: 'Task title is required' });
    const task = await store.createTask({ id: createId(), userId: user.id, title, description: String(body.description || ''), category: String(body.category || 'General'), priority: ['Low', 'Medium', 'High'].includes(body.priority) ? body.priority : 'Medium', dueDate: body.dueDate || null, estimatedMinutes: body.estimatedMinutes ? Number(body.estimatedMinutes) : null, status: 'Pending', xp: Number(body.xp || 15), completed: false, createdAt: new Date().toISOString(), completedAt: null });
    return json(response, 201, { success: true, task });
  }
  const taskMatch = url.pathname.match(/^\/api\/tasks\/([^/]+)$/);
  if (taskMatch) {
    if (request.method === 'GET') { const task = (await store.listTasks(user.id)).find((item) => item.id === taskMatch[1]); return task ? json(response, 200, { success: true, task }) : json(response, 404, { success: false, error: 'Task not found' }); }
    if (request.method === 'PATCH') { const task = await store.updateTask(user.id, taskMatch[1], body); if (!task) return json(response, 404, { success: false, error: 'Task not found' }); if (task.completed && body.completed === true) await notify(user, { type: 'task_completed', title: 'Task completed', message: task.title, relatedEntityType: 'task', relatedEntityId: task.id }); return json(response, 200, { success: true, task }); }
    if (request.method === 'DELETE') return (await store.deleteTask(user.id, taskMatch[1])) ? json(response, 204, {}) : json(response, 404, { success: false, error: 'Task not found' });
  }
  if (request.method === 'POST' && url.pathname === '/api/practice/attempts') { const attempt = await store.createPracticeAttempt({ id: createId(), userId: user.id, topic: String(body.topic || 'General'), score: Number(body.score || 0), total: Number(body.total || 0), timeSpentSeconds: Number(body.timeSpentSeconds || 0), completedAt: new Date().toISOString() }); return json(response, 201, { success: true, attempt }); }
  if (request.method === 'GET' && url.pathname === '/api/practice/attempts') return json(response, 200, { success: true, attempts: await store.listPracticeAttempts(user.id) });
  if (request.method === 'POST' && url.pathname === '/api/mock-attempts') { const attempt = await store.createMockAttempt({ id: createId(), userId: user.id, title: String(body.title || 'Mock Test'), score: Number(body.score || 0), total: Number(body.total || 100), timeSpentSeconds: Number(body.timeSpentSeconds || 0), completedAt: new Date().toISOString() }); return json(response, 201, { success: true, attempt }); }
  if (request.method === 'GET' && url.pathname === '/api/mock-attempts') return json(response, 200, { success: true, attempts: await store.listMockAttempts(user.id) });
  return json(response, 404, { success: false, error: 'Route not found' });
}

async function start() {
  if (process.env.NODE_ENV === 'production') {
    if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'change-this-secret-before-deploying' || process.env.JWT_SECRET.length < 32) {
      console.error('CRITICAL: In production, JWT_SECRET must be configured with a random string of at least 32 characters.');
      process.exitCode = 1;
      return;
    }
  }
  if (database) {
    try {
      await database.check();
      console.log('Production PostgreSQL database connection verified.');
    } catch (error) {
      console.error('PostgreSQL is configured but unavailable. Server will not start.');
      process.exitCode = 1;
      return;
    }
  }
  const server = http.createServer((request, response) => handle(request, response).catch((error) => errorResponse(response, error)));
  server.listen(port, () => console.log(`Placement backend listening on http://localhost:${port} (${persistenceMode})`));
  const shutdown = async () => {
    console.log('Shutting down placement backend...');
    server.close();
    await store.close();
    process.exit(0);
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
}
start().catch((error) => { console.error('Backend startup failed:', error.message); process.exit(1); });

