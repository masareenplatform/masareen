-- ---------- Live presence, GPS capture and feed indexes (v1.2) ----------
ALTER TABLE users ADD COLUMN last_active_at TEXT;
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at);

CREATE INDEX IF NOT EXISTS idx_post_views_seen ON post_views(user_id, seen_at);
CREATE INDEX IF NOT EXISTS idx_posts_hidden_created ON posts(hidden, created_at);

CREATE TABLE IF NOT EXISTS gps_records (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  accuracy    REAL,
  altitude    REAL,
  speed       REAL,
  heading     REAL,
  captured_at TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gps_user ON gps_records(user_id, created_at);
