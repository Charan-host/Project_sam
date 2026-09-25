ALTER TABLE practice_questions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS question_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General';
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS practice_questions_question_uidx ON practice_questions(question);
CREATE UNIQUE INDEX IF NOT EXISTS mock_tests_title_uidx ON mock_tests(title);

CREATE TABLE IF NOT EXISTS practice_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  topic TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'Medium',
  question_count INTEGER NOT NULL CHECK (question_count > 0),
  score INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  time_spent_seconds INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS practice_sessions_user_idx ON practice_sessions(user_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS practice_answers (
  session_id UUID NOT NULL REFERENCES practice_sessions(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES practice_questions(id) ON DELETE RESTRICT,
  selected_answer CHAR(1),
  correct BOOLEAN NOT NULL DEFAULT false,
  time_taken_seconds INTEGER NOT NULL DEFAULT 0,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, question_id)
);

CREATE TABLE IF NOT EXISTS mock_attempt_answers (
  attempt_id UUID NOT NULL REFERENCES mock_attempts(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES practice_questions(id) ON DELETE RESTRICT,
  selected_answer CHAR(1),
  correct BOOLEAN NOT NULL DEFAULT false,
  marked_for_review BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (attempt_id, question_id)
);
