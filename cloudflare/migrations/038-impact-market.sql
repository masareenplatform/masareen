-- Entity impact market: every verified person, institution, event, programme
-- and project can be recognised and traded. The platform earns a brokerage fee.
CREATE TABLE IF NOT EXISTS entity_markets (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type    TEXT NOT NULL,
  entity_id      TEXT NOT NULL,
  symbol         TEXT NOT NULL,
  name           TEXT NOT NULL,
  owner_id       INTEGER,
  price_mrc      REAL NOT NULL DEFAULT 100,
  previous_close REAL NOT NULL DEFAULT 100,
  supply         INTEGER NOT NULL DEFAULT 100000,
  impact_score   REAL NOT NULL DEFAULT 0,
  volume_mrc     REAL NOT NULL DEFAULT 0,
  trade_count    INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  UNIQUE(entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_entity_markets_type ON entity_markets(entity_type, status);
CREATE INDEX IF NOT EXISTS idx_entity_markets_owner ON entity_markets(owner_id);

CREATE TABLE IF NOT EXISTS market_holdings (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  market_id  INTEGER NOT NULL,
  shares     INTEGER NOT NULL DEFAULT 0,
  avg_cost   REAL NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, market_id)
);
CREATE INDEX IF NOT EXISTS idx_market_holdings_user ON market_holdings(user_id);

CREATE TABLE IF NOT EXISTS market_trades (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  market_id  INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  side       TEXT NOT NULL,
  shares     INTEGER NOT NULL,
  price_mrc  REAL NOT NULL,
  gross_mrc  REAL NOT NULL,
  fee_mrc    REAL NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_market_trades_market ON market_trades(market_id, created_at);

CREATE TABLE IF NOT EXISTS market_price_history (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  market_id INTEGER NOT NULL,
  price_mrc REAL NOT NULL,
  at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_market_price_market ON market_price_history(market_id, at);
