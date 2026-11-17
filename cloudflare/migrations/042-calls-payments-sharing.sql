-- Real vs demo accounts, share aggregation, invoices, manual MRC payments and call rooms.
ALTER TABLE users ADD COLUMN is_demo INTEGER NOT NULL DEFAULT 0;
UPDATE users SET is_demo=1 WHERE signup_method='seed';

CREATE TABLE IF NOT EXISTS post_shares (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_post_shares_user ON post_shares(user_id, created_at);

CREATE TABLE IF NOT EXISTS invoices (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  number         TEXT UNIQUE,
  user_id        INTEGER NOT NULL,
  kind           TEXT NOT NULL,
  description    TEXT,
  amount_mrc     REAL NOT NULL DEFAULT 0,
  amount_egp     REAL NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'ISSUED',
  reference_type TEXT,
  reference_id   TEXT,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invoices_user ON invoices(user_id, created_at);

CREATE TABLE IF NOT EXISTS wallet_payment_requests (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  kind        TEXT NOT NULL,
  amount_mrc  REAL NOT NULL,
  amount_egp  REAL NOT NULL,
  method      TEXT NOT NULL DEFAULT 'MANUAL',
  account_ref TEXT,
  status      TEXT NOT NULL DEFAULT 'PENDING',
  admin_note  TEXT,
  invoice_id  INTEGER,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_wallet_requests_user ON wallet_payment_requests(user_id, created_at);

CREATE TABLE IF NOT EXISTS call_rooms (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  code             TEXT NOT NULL UNIQUE,
  host_id          INTEGER NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  scheduled_at     TEXT,
  started_at       TEXT,
  ended_at         TEXT,
  status           TEXT NOT NULL DEFAULT 'SCHEDULED',
  entity_type      TEXT,
  entity_id        INTEGER,
  reward_mrc       REAL NOT NULL DEFAULT 0,
  max_participants INTEGER NOT NULL DEFAULT 2,
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_call_rooms_host ON call_rooms(host_id, scheduled_at);

CREATE TABLE IF NOT EXISTS call_participants (
  room_id     INTEGER NOT NULL,
  user_id     INTEGER NOT NULL,
  role        TEXT NOT NULL DEFAULT 'GUEST',
  joined_at   TEXT NOT NULL,
  left_at     TEXT,
  reward_paid INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS call_signals (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id     INTEGER NOT NULL,
  from_user   INTEGER NOT NULL,
  to_user     INTEGER NOT NULL,
  type        TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_call_signals_target ON call_signals(room_id, to_user, id);
