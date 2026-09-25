const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { seedQuestions } = require('./questionSeed');

function id() { return crypto.randomUUID(); }
function now() { return new Date().toISOString(); }
function starterTasks(userId) {
  return [
    ['Solve 10 Profit & Loss Aptitude questions', 'Aptitude', 15],
    ['Practice 2 Hard Tree Traversal coding problems', 'Coding & DSA', 25],
    ['Revise Operating System Deadlocks & Semaphores', 'Tech Core', 20],
  ].map(([title, category, xp]) => ({ id: id(), userId, title, description: '', category, priority: 'Medium', dueDate: null, estimatedMinutes: null, status: 'Pending', xp, completed: false, createdAt: now(), completedAt: null }));
}
function publicQuestion(question) {
  const { correctAnswer, ...safeQuestion } = question;
  return safeQuestion;
}
function localDate(value, offsetMinutes = 0) {
  return new Date(new Date(value).getTime() - offsetMinutes * 60000).toISOString().slice(0, 10);
}
function emptyCategory(name) { return { category: name, attempted: false, attempts: 0, questions: 0, correct: 0, accuracy: 0 }; }

class JsonStore {
  constructor(dataPath) { this.dataPath = dataPath; }
  read() {
    if (!fs.existsSync(this.dataPath)) fs.writeFileSync(this.dataPath, JSON.stringify({ users: [], tasks: [], mockAttempts: [], practiceAttempts: [] }, null, 2));
    const data = JSON.parse(fs.readFileSync(this.dataPath, 'utf8'));
    data.users ||= []; data.tasks ||= []; data.practiceAttempts ||= []; data.mockAttempts ||= []; data.notifications ||= [];
    data.practiceQuestions ||= seedQuestions().map((question) => ({ id: id(), ...question }));
    data.practiceSessions ||= [];
    data.mockTests ||= [{ id: 'local-campus-mock', title: 'Campus Technical Mock', description: 'DSA, programming, and core CS practice.', durationMinutes: 30, questionCount: 10, difficulty: 'Medium', category: 'DSA', questionIds: data.practiceQuestions.filter((question) => question.category === 'DSA').slice(0, 10).map((question) => question.id) }];
    return data;
  }
  write(data) { const temporaryPath = `${this.dataPath}.tmp`; fs.writeFileSync(temporaryPath, JSON.stringify(data, null, 2)); fs.renameSync(temporaryPath, this.dataPath); }
  async health() { return 'ok'; }
  async close() {}
  async findUserByEmail(email) { return this.read().users.find((user) => user.email === email) || null; }
  async findUserById(userId) { return this.read().users.find((user) => user.id === userId) || null; }
  async createUser(user) { const data = this.read(); data.users.push(user); data.tasks.push(...starterTasks(user.id)); this.write(data); return user; }
  async updateUser(userId, values) { const data = this.read(); const user = data.users.find((item) => item.id === userId); if (!user) return null; Object.assign(user, values); this.write(data); return user; }
  async createNotification(notification) { const data = this.read(); const duplicate = notification.relatedEntityId && data.notifications.some((item) => item.userId === notification.userId && item.type === notification.type && item.relatedEntityId === notification.relatedEntityId); if (duplicate) return null; const saved = { id: id(), ...notification, isRead: false, createdAt: now(), readAt: null }; data.notifications.push(saved); this.write(data); return saved; }
  async listNotifications(userId) { return this.read().notifications.filter((item) => item.userId === userId).sort((a, b) => b.createdAt.localeCompare(a.createdAt)); }
  async unreadNotificationCount(userId) { return (await this.listNotifications(userId)).filter((item) => !item.isRead).length; }
  async markNotificationRead(userId, notificationId) { const data = this.read(); const item = data.notifications.find((notification) => notification.id === notificationId && notification.userId === userId); if (!item) return null; item.isRead = true; item.readAt = now(); this.write(data); return item; }
  async markAllNotificationsRead(userId) { const data = this.read(); let count = 0; for (const item of data.notifications.filter((notification) => notification.userId === userId && !notification.isRead)) { item.isRead = true; item.readAt = now(); count += 1; } this.write(data); return count; }
  async listTasks(userId) { return this.read().tasks.filter((task) => task.userId === userId); }
  async createTask(task) { const data = this.read(); data.tasks.push(task); this.write(data); return task; }
  async updateTask(userId, taskId, values) { const data = this.read(); const task = data.tasks.find((item) => item.id === taskId && item.userId === userId); if (!task) return null; Object.assign(task, values); this.write(data); return task; }
  async deleteTask(userId, taskId) { const data = this.read(); const before = data.tasks.length; data.tasks = data.tasks.filter((task) => !(task.id === taskId && task.userId === userId)); this.write(data); return before !== data.tasks.length; }
  async createPracticeAttempt(attempt) { const data = this.read(); data.practiceAttempts.push(attempt); this.write(data); return attempt; }
  async listPracticeAttempts(userId) { return this.read().practiceAttempts.filter((attempt) => attempt.userId === userId); }
  async createMockAttempt(attempt) { const data = this.read(); data.mockAttempts.push(attempt); this.write(data); return attempt; }
  async listMockAttempts(userId) { return this.read().mockAttempts.filter((attempt) => attempt.userId === userId); }
  async listQuestions(filters) {
    const data = this.read();
    return data.practiceQuestions.filter((question) => (!filters.category || question.category === filters.category) && (!filters.topic || question.topic === filters.topic) && (!filters.difficulty || question.difficulty === filters.difficulty)).slice(0, filters.limit).map(publicQuestion);
  }
  async getQuestion(questionId) { return this.read().practiceQuestions.find((question) => question.id === questionId) || null; }
  async createPracticeSession(session, answers) { const data = this.read(); const result = { ...session, id: session.id || id(), completedAt: now(), score: 0, total: answers.length }; result.answers = answers.map((answer) => { const question = data.practiceQuestions.find((item) => item.id === answer.questionId); if (!question) throw new Error('Invalid practice question'); return { ...answer, correct: question.correctAnswer === answer.selectedAnswer }; }); result.score = result.answers.filter((answer) => answer.correct).length; data.practiceSessions.push(result); data.practiceAttempts.push({ id: result.id, userId: result.userId, topic: result.topic, score: result.score, total: result.total, timeSpentSeconds: result.timeSpentSeconds, completedAt: result.completedAt }); this.write(data); return result; }
  async listPracticeHistory(userId) { return this.read().practiceSessions.filter((session) => session.userId === userId).sort((a, b) => b.completedAt.localeCompare(a.completedAt)); }
  async listMockTests() { return this.read().mockTests; }
  async getMockTest(testId) { return this.read().mockTests.find((test) => test.id === testId) || null; }
  async getMockQuestions(testId) { const data = this.read(); const test = data.mockTests.find((item) => item.id === testId); return test ? test.questionIds.map((questionId) => data.practiceQuestions.find((question) => question.id === questionId)).filter(Boolean).map(publicQuestion) : []; }
  async createMockResult(result, answers) { const data = this.read(); const test = data.mockTests.find((item) => item.id === result.mockTestId); const questions = (test?.questionIds || []).map((questionId) => data.practiceQuestions.find((question) => question.id === questionId)).filter(Boolean); const scored = answers.map((answer) => ({ ...answer, correct: questions.find((question) => question.id === answer.questionId)?.correctAnswer === answer.selectedAnswer })); const saved = { ...result, id: result.id || id(), score: scored.filter((answer) => answer.correct).length, total: questions.length, completedAt: now(), answers: scored }; data.mockAttempts.push(saved); this.write(data); return saved; }
  async analytics(userId, offsetMinutes = 0) {
    const data = this.read();
    const tasks = data.tasks.filter((task) => task.userId === userId);
    const sessions = data.practiceSessions.filter((session) => session.userId === userId);
    const mocks = data.mockAttempts.filter((attempt) => attempt.userId === userId);
    const today = localDate(new Date(), offsetMinutes);
    const categoryNames = ['DSA', 'Programming', 'OOP', 'DBMS', 'Operating Systems', 'Computer Networks', 'Aptitude', 'Python', 'Java', 'SQL', 'Machine Learning'];
    const categories = categoryNames.map(emptyCategory);
    const topicMap = new Map();
    for (const session of sessions) {
      const category = categories.find((item) => item.category === session.category);
      if (category) { category.attempted = true; category.attempts += 1; category.questions += session.total; category.correct += session.score; }
      for (const answer of session.answers || []) {
        const question = data.practiceQuestions.find((item) => item.id === answer.questionId);
        if (!question) continue;
        const topic = topicMap.get(question.topic) || { topic: question.topic, attempts: 0, correct: 0, accuracy: 0 };
        topic.attempts += 1; topic.correct += answer.correct ? 1 : 0; topic.accuracy = Math.round(topic.correct / topic.attempts * 100); topicMap.set(question.topic, topic);
      }
    }
    for (const item of categories) item.accuracy = item.questions ? Math.round(item.correct / item.questions * 100) : 0;
    const activeDates = new Set();
    for (const task of tasks.filter((item) => item.completed && item.completedAt)) activeDates.add(localDate(task.completedAt, offsetMinutes));
    for (const session of sessions) activeDates.add(localDate(session.completedAt, offsetMinutes));
    for (const mock of mocks) activeDates.add(localDate(mock.completedAt, offsetMinutes));
    let streak = 0; const cursor = new Date(`${today}T00:00:00Z`);
    while (activeDates.has(cursor.toISOString().slice(0, 10))) { streak += 1; cursor.setUTCDate(cursor.getUTCDate() - 1); }
    const tasksCompleted = tasks.filter((task) => task.completed).length;
    const tasksPending = tasks.filter((task) => !task.completed).length;
    const tasksOverdue = tasks.filter((task) => !task.completed && task.dueDate && task.dueDate < today).length;
    const practiceQuestions = sessions.reduce((sum, item) => sum + item.total, 0);
    const practiceCorrect = sessions.reduce((sum, item) => sum + item.score, 0);
    const overall = practiceQuestions + mocks.reduce((sum, item) => sum + item.total, 0) + tasks.length;
    const completedUnits = practiceCorrect + mocks.reduce((sum, item) => sum + item.score, 0) + tasksCompleted;
    const strengths = categories.filter((item) => item.attempted && item.questions >= 5 && item.accuracy >= 75).map((item) => item.category);
    const weakAreas = categories.filter((item) => item.attempted && item.questions >= 5 && item.accuracy < 60).map((item) => item.category);
    const recommendations = [];
    if (tasksOverdue) recommendations.push({ title: 'Complete overdue tasks', description: `${tasksOverdue} task${tasksOverdue === 1 ? '' : 's'} need attention.`, category: 'Tasks', priority: 'High', action: 'View Tasks' });
    if (weakAreas.length) recommendations.push({ title: `Practice ${weakAreas[0]}`, description: 'Your recent accuracy needs more practice.', category: weakAreas[0], priority: 'High', action: 'Start Practice' });
    if (!sessions.some((item) => localDate(item.completedAt, offsetMinutes) >= localDate(Date.now() - 3 * 86400000, offsetMinutes))) recommendations.push({ title: 'Start a practice session', description: 'Keep your preparation momentum moving.', category: 'Practice', priority: 'Medium', action: 'Start Practice' });
    if (!mocks.some((item) => localDate(item.completedAt, offsetMinutes) >= localDate(Date.now() - 7 * 86400000, offsetMinutes))) recommendations.push({ title: 'Take a mock test', description: 'Measure your readiness with a timed simulation.', category: 'Mocks', priority: 'Medium', action: 'View Mock Tests' });
    const history = new Map();
    const historyDay = (date) => { const key = localDate(date, offsetMinutes); const item = history.get(key) || { date: key, practiceAccuracy: null, mockScore: null, tasksCompleted: 0 }; history.set(key, item); return item; };
    for (const task of tasks.filter((item) => item.completedAt)) historyDay(task.completedAt).tasksCompleted += task.completed ? 1 : 0;
    for (const session of sessions) { const item = historyDay(session.completedAt); item.practiceAccuracy = session.total ? Math.round(session.score / session.total * 100) : 0; }
    for (const mock of mocks) { const item = historyDay(mock.completedAt); item.mockScore = mock.total ? Math.round(mock.score / mock.total * 100) : 0; }
    const performanceHistory = [...history.values()].sort((a, b) => a.date.localeCompare(b.date));
    return { progress: { overallProgress: overall ? Math.round(completedUnits / overall * 100) : 0, tasksCompleted, tasksPending, tasksOverdue, practiceAttempts: sessions.length, practiceQuestionsAttempted: practiceQuestions, practiceCorrect, practiceAccuracy: practiceQuestions ? Math.round(practiceCorrect / practiceQuestions * 100) : 0, mockTestsCompleted: mocks.length, averageMockScore: mocks.length ? Math.round(mocks.reduce((sum, item) => sum + (item.total ? item.score / item.total * 100 : 0), 0) / mocks.length) : 0, currentStreak: streak }, analytics: { overall: { progress: overall ? Math.round(completedUnits / overall * 100) : 0, questionsAttempted: practiceQuestions, accuracy: practiceQuestions ? Math.round(practiceCorrect / practiceQuestions * 100) : 0 }, practice: { attempts: sessions.length, accuracy: practiceQuestions ? Math.round(practiceCorrect / practiceQuestions * 100) : 0, averageScore: sessions.length ? Math.round(sessions.reduce((sum, item) => sum + (item.total ? item.score / item.total * 100 : 0), 0) / sessions.length) : 0 }, mock: { completed: mocks.length, averageScore: mocks.length ? Math.round(mocks.reduce((sum, item) => sum + (item.total ? item.score / item.total * 100 : 0), 0) / mocks.length) : 0 }, tasks: { completed: tasksCompleted, pending: tasksPending, overdue: tasksOverdue }, categories, topics: [...topicMap.values()], strengths, weakAreas, daily: { tasksCompleted: tasks.filter((item) => item.completedAt && localDate(item.completedAt, offsetMinutes) === today).length, practiceQuestions: sessions.filter((item) => localDate(item.completedAt, offsetMinutes) === today).reduce((sum, item) => sum + item.total, 0), practiceSessions: sessions.filter((item) => localDate(item.completedAt, offsetMinutes) === today).length, mockTests: mocks.filter((item) => localDate(item.completedAt, offsetMinutes) === today).length }, recommendations, performanceHistory } };
  }
}

module.exports = { JsonStore };
