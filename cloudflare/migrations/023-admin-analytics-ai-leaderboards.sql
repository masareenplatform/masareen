-- Admin notifications/deep links, analytics, AI-ready posts and leaderboards.
ALTER TABLE users ADD COLUMN suspended INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN suspension_reason TEXT;
ALTER TABLE notifications ADD COLUMN link TEXT;
ALTER TABLE notifications ADD COLUMN entity_type TEXT;
ALTER TABLE notifications ADD COLUMN entity_id TEXT;

ALTER TABLE posts ADD COLUMN transcript TEXT;
ALTER TABLE posts ADD COLUMN embedding_json TEXT;
ALTER TABLE posts ADD COLUMN embedding_status TEXT DEFAULT 'none';
ALTER TABLE posts ADD COLUMN moderation_status TEXT DEFAULT 'APPROVED';
ALTER TABLE posts ADD COLUMN structured_json TEXT;

CREATE TABLE IF NOT EXISTS analytics_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER,
  event_type  TEXT NOT NULL,
  target_type TEXT,
  target_id   TEXT,
  post_id     INTEGER,
  value       REAL,
  duration_ms INTEGER,
  metadata_json TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user
  ON analytics_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type
  ON analytics_events(event_type, created_at);

CREATE TABLE IF NOT EXISTS admin_audit (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id   INTEGER NOT NULL,
  action     TEXT NOT NULL,
  target_type TEXT,
  target_id  TEXT,
  details    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created
  ON admin_audit(created_at);
