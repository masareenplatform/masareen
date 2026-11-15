-- ---------- Security hardening: rate limiting, session types and cleanups (v1.4) ----------
CREATE TABLE IF NOT EXISTS rate_limits (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  key        TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rate_limits_key ON rate_limits(key, created_at);
