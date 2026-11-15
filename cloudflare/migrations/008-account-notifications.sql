CREATE TABLE IF NOT EXISTS auth_tokens (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  kind       TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  used_at    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user ON auth_tokens(user_id, kind, created_at);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id            INTEGER PRIMARY KEY,
  push_enabled       INTEGER NOT NULL DEFAULT 1,
  email_enabled      INTEGER NOT NULL DEFAULT 1,
  opportunity_alerts INTEGER NOT NULL DEFAULT 1,
  social_alerts      INTEGER NOT NULL DEFAULT 1,
  message_alerts     INTEGER NOT NULL DEFAULT 1,
  digest_frequency   TEXT NOT NULL DEFAULT 'instant',
  quiet_start        INTEGER,
  quiet_end          INTEGER,
  profile_visibility TEXT NOT NULL DEFAULT 'public',
  message_privacy    TEXT NOT NULL DEFAULT 'everyone',
  show_email         INTEGER NOT NULL DEFAULT 0,
  updated_at         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS device_tokens (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  token        TEXT NOT NULL,
  platform     TEXT NOT NULL,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  UNIQUE (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

CREATE TABLE IF NOT EXISTS notification_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  kind       TEXT NOT NULL,
  ref_id     TEXT NOT NULL DEFAULT '',
  channel    TEXT NOT NULL DEFAULT 'in_app',
  created_at TEXT NOT NULL,
  UNIQUE (user_id, kind, ref_id, channel)
);
CREATE INDEX IF NOT EXISTS idx_notification_log_user ON notification_log(user_id, kind, created_at);
