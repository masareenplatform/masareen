-- User and tester feedback, reviewed by admins.
CREATE TABLE IF NOT EXISTS feedback (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  role       TEXT,
  type       TEXT NOT NULL DEFAULT 'idea',
  message    TEXT NOT NULL,
  rating     INTEGER,
  status     TEXT NOT NULL DEFAULT 'OPEN',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status, created_at);
