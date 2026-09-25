# Placement Backend

REST API for the Flutter app. PostgreSQL is the primary persistence implementation whenever `DATABASE_URL` is set. Without it, the JSON adapter is used explicitly as a development fallback. The relational schema is in `migrations/001_initial_schema.sql`.

## Run

Requires Node.js 20 or newer.

```powershell
$env:JWT_SECRET = 'use-a-long-random-secret'
node server.js
```

The API listens on `http://localhost:3000`.

## PostgreSQL

Copy `.env.example` to `.env`, set `DATABASE_URL`, and apply the schema with `psql`:

```powershell
psql $env:DATABASE_URL -f migrations/001_initial_schema.sql
```

When PostgreSQL is configured but unreachable, startup fails. The server never silently falls back to JSON in that case. Run `npm run db:migrate-json` to explicitly import existing `data.json` records; this is never run automatically.

Leave `DATABASE_URL` unset for JSON fallback mode. The server reports `json-fallback` in its startup log and health response. This mode is intended for local development only.

The schema is the source of truth for production and includes users, profiles, settings, tasks, practice, mocks, progress, achievements, and notifications.

PostgreSQL setup:

1. Create a PostgreSQL database and copy `.env.example` to `.env`.
2. Set `DATABASE_URL` and a strong `JWT_SECRET`.
3. Run `npm install`.
4. Run `npm run db:migrate`.
5. Start with `npm start`.

For an Android emulator, the Flutter client defaults to `http://10.0.2.2:3000/api`. For desktop or web, override it with:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Endpoints

- `POST /api/auth/signup` and `POST /api/auth/login`
- Versioned aliases are available under `/api/v1/...`.
- `GET /api/me` and `PATCH /api/me`
- `GET /api/tasks`, `POST /api/tasks`, `PATCH /api/tasks/:id`, `DELETE /api/tasks/:id`
- `GET` and `POST /api/practice/attempts`
- `GET` and `POST /api/mock-attempts`
- `GET /api/health`

Notification endpoints:

- `GET /api/v1/notifications`
- `GET /api/v1/notifications/unread-count`
- `POST /api/v1/notifications/:id/read`
- `POST /api/v1/notifications/read-all`

Completion events create deduplicated task, practice, and mock notifications. Disabled notification preferences suppress event creation, and every notification query is scoped to the authenticated user.

Analytics endpoints:

- `GET /api/v1/progress`
- `GET /api/v1/analytics`
- `GET /api/v1/analytics/weekly`
- `GET /api/v1/analytics/performance-history`
- `GET /api/v1/dashboard`

These endpoints use the authenticated user from the bearer token. They calculate task completion, practice accuracy, mock averages, streaks, category/topic performance, strengths, weak areas, recommendations, and daily activity from persisted records. The optional `timezoneOffset` query parameter lets the client calculate local-day activity correctly.

The same endpoints are available under `/api/v1/...`; both prefixes use the same persistence adapter.

## Practice and mock APIs

- `GET /api/v1/practice/questions?category=DSA&topic=Arrays&difficulty=Medium&limit=10`
- `POST /api/v1/practice/sessions` with `{ "category": "DSA", "answers": [{ "questionId": "...", "selectedAnswer": "B" }] }`
- `GET /api/v1/practice/history`
- `GET /api/v1/practice/performance`
- `GET /api/v1/mock-tests`
- `GET /api/v1/mock-tests/:id`
- `POST /api/v1/mock-tests/:id/start`
- `POST /api/v1/mock-tests/:id/submit`
- `GET /api/v1/mock-tests/history`

Question responses never include the server-side correct answer. Scores are calculated by the selected persistence adapter at submission time.

## Development seed

After applying migrations in PostgreSQL mode:

```powershell
npm run db:seed
```

The seed creates 100 development questions across ten categories and one published mock test. The question text has a unique index, so repeating the command does not duplicate questions.

Send the returned token as `Authorization: Bearer <token>` for protected endpoints. Passwords are stored as salted scrypt hashes; plaintext passwords are never written to disk.

Profile fields include `college`, `course`, `graduationYear`, `targetRole`, and `skillLevel`. Tasks support `description`, `priority`, `dueDate`, `estimatedMinutes`, `status`, and `completedAt` in addition to the original fields.

## Production Section

### Production Architecture
- **Client**: Flutter Web (compiled to CanvasKit/WASM) served over HTTPS.
- **API Server**: Node.js 20+ stateless service (Render, Railway, Fly.io, or AWS App Runner).
- **Database**: Managed PostgreSQL instance (Supabase, Neon, Render Postgres, AWS RDS) with TLS/SSL.

### Environment Variables
Configure the following in the host's secret management console:
- `NODE_ENV=production`
- `PORT=3000`
- `DATABASE_URL=postgresql://user:password@host:port/database?sslmode=require`
- `DATABASE_SSL=true`
- `DB_POOL_MAX=10`
- `JWT_SECRET=<32+ character random hex string>`
- `CORS_ORIGIN=https://your-frontend-domain.com`

### Production Migrations & Seeding
```bash
npm run db:migrate
npm run db:seed
```

### Health Check Monitoring
- `GET /health` or `GET /api/health`
- Returns HTTP 200 with `{ "status": "ok", "database": "ok", "mode": "postgresql" }` when operating normally.
- Returns HTTP 503 with `{ "status": "unhealthy", "database": "unavailable" }` if PostgreSQL connectivity is lost.
