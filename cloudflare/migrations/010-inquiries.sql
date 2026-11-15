CREATE TABLE IF NOT EXISTS inquiries (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  org_id       INTEGER NOT NULL,
  department   TEXT,
  type         TEXT NOT NULL DEFAULT 'general',
  subject      TEXT NOT NULL,
  message      TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'OPEN',
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inquiries_user ON inquiries(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_inquiries_org ON inquiries(org_id, status, created_at);
