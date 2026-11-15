-- ---------- Ads manager (v1.1) ----------
CREATE TABLE IF NOT EXISTS ad_campaigns (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER NOT NULL,
  name           TEXT NOT NULL,
  objective      TEXT NOT NULL DEFAULT 'awareness',
  placement      TEXT NOT NULL DEFAULT 'feed',
  status         TEXT NOT NULL DEFAULT 'DRAFT',
  budget_coins   REAL NOT NULL DEFAULT 0,
  funded_coins   REAL NOT NULL DEFAULT 0,
  spent_coins    REAL NOT NULL DEFAULT 0,
  currency       TEXT NOT NULL DEFAULT 'MRC',
  start_at       TEXT,
  end_at         TEXT,
  targeting_json TEXT NOT NULL DEFAULT '{}',
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_user ON ad_campaigns(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_status ON ad_campaigns(status, placement, start_at, end_at);

CREATE TABLE IF NOT EXISTS ad_creatives (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id INTEGER NOT NULL,
  title       TEXT NOT NULL,
  body        TEXT,
  media_url   TEXT,
  media_type  TEXT NOT NULL DEFAULT 'image',
  cta_label   TEXT,
  cta_url     TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_creatives_campaign ON ad_creatives(campaign_id, sort_order);

CREATE TABLE IF NOT EXISTS ad_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id  INTEGER NOT NULL,
  creative_id  INTEGER,
  user_id      INTEGER NOT NULL,
  type         TEXT NOT NULL,
  cost_coins   REAL NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_events_campaign ON ad_events(campaign_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_events_user ON ad_events(user_id, campaign_id, type, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_events_type ON ad_events(type, created_at);
