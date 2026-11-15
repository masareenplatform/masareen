CREATE TABLE IF NOT EXISTS coin_wallets (
  owner_id     INTEGER PRIMARY KEY,
  balance      REAL NOT NULL DEFAULT 0,
  currency     TEXT NOT NULL DEFAULT 'MRC',
  updated_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS coin_transactions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id       INTEGER NOT NULL,
  type           TEXT NOT NULL,
  amount         REAL NOT NULL,
  balance_after  REAL NOT NULL,
  reference      TEXT,
  counterparty_id INTEGER,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_coin_tx_owner ON coin_transactions(owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_coin_tx_type ON coin_transactions(owner_id, type, created_at);

CREATE TABLE IF NOT EXISTS coin_rates (
  currency      TEXT PRIMARY KEY,
  rate_to_mrc   REAL NOT NULL,
  updated_at    TEXT NOT NULL
);
INSERT OR IGNORE INTO coin_rates (currency, rate_to_mrc, updated_at)
VALUES ('EGP', 0.1, '2026-01-01T00:00:00.000Z');

CREATE TABLE IF NOT EXISTS payments (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id          INTEGER NOT NULL,
  org_id           TEXT,
  amount_egp       REAL NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'EGP',
  method           TEXT NOT NULL DEFAULT 'card',
  status           TEXT NOT NULL DEFAULT 'PENDING',
  paymob_order_id  TEXT,
  payment_key      TEXT,
  redirect_url     TEXT,
  phone            TEXT,
  invoice_id       TEXT,
  purpose          TEXT NOT NULL DEFAULT 'topup',
  metadata_json    TEXT,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(paymob_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status, created_at);

CREATE TABLE IF NOT EXISTS pro_subscriptions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  plan         TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'ACTIVE',
  started_at   TEXT NOT NULL,
  expires_at   TEXT NOT NULL,
  payment_id   INTEGER,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pro_subs_user ON pro_subscriptions(user_id, status, expires_at);
