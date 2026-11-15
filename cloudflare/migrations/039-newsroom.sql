-- Verified, data-driven newsroom with funded articles and outlet revenue.
CREATE TABLE IF NOT EXISTS news_articles (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id        INTEGER NOT NULL,
  outlet_id        INTEGER NOT NULL,
  title            TEXT NOT NULL,
  slug             TEXT,
  summary          TEXT,
  body             TEXT NOT NULL,
  cover_url        TEXT,
  status           TEXT NOT NULL DEFAULT 'DRAFT',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  verified_by      INTEGER,
  verified_at      TEXT,
  data_snapshot_json TEXT,
  funding_goal_mrc REAL NOT NULL DEFAULT 0,
  funding_raised_mrc REAL NOT NULL DEFAULT 0,
  mrc_earned       REAL NOT NULL DEFAULT 0,
  views            INTEGER NOT NULL DEFAULT 0,
  rating_avg       REAL NOT NULL DEFAULT 0,
  rating_count     INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_news_status ON news_articles(status, created_at);
CREATE INDEX IF NOT EXISTS idx_news_outlet ON news_articles(outlet_id, created_at);

CREATE TABLE IF NOT EXISTS news_funding (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  amount_mrc REAL NOT NULL,
  fee_mrc    REAL NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_news_funding_article ON news_funding(article_id, created_at);

CREATE TABLE IF NOT EXISTS news_ratings (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  stars      INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(article_id, user_id)
);
