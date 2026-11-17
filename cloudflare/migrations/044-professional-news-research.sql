-- Professional newsroom, universal reactions, automatic rankings and research review.
ALTER TABLE content_reactions ADD COLUMN reaction TEXT NOT NULL DEFAULT 'like';

ALTER TABLE news_articles ADD COLUMN source_name TEXT;
ALTER TABLE news_articles ADD COLUMN source_url TEXT;
ALTER TABLE news_articles ADD COLUMN image_url TEXT;
ALTER TABLE news_articles ADD COLUMN video_url TEXT;
ALTER TABLE news_articles ADD COLUMN published_at TEXT;
ALTER TABLE news_articles ADD COLUMN journalist_id INTEGER;
ALTER TABLE news_articles ADD COLUMN impact_score REAL NOT NULL DEFAULT 0;
ALTER TABLE news_articles ADD COLUMN impact_domain TEXT;
ALTER TABLE news_articles ADD COLUMN auto_generated INTEGER NOT NULL DEFAULT 0;
ALTER TABLE news_articles ADD COLUMN verification_note TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_news_source_url
  ON news_articles(source_url) WHERE source_url IS NOT NULL;

CREATE TABLE IF NOT EXISTS journalists (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT NOT NULL,
  slug                TEXT,
  outlet_id           INTEGER,
  outlet_name         TEXT,
  title               TEXT,
  bio                 TEXT,
  avatar_url          TEXT,
  specialties_json    TEXT NOT NULL DEFAULT '[]',
  verified            INTEGER NOT NULL DEFAULT 0,
  verification_source TEXT,
  articles_count      INTEGER NOT NULL DEFAULT 0,
  impact_score        REAL NOT NULL DEFAULT 0,
  claimed_by          INTEGER,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  UNIQUE (name, outlet_id)
);
CREATE INDEX IF NOT EXISTS idx_journalists_outlet ON journalists(outlet_id, name);

CREATE TABLE IF NOT EXISTS news_article_media (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  type       TEXT NOT NULL DEFAULT 'PHOTO',
  url        TEXT NOT NULL,
  caption    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_news_media_article ON news_article_media(article_id, id);

CREATE TABLE IF NOT EXISTS news_verifications (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id    INTEGER NOT NULL,
  reviewer_id   INTEGER NOT NULL,
  verdict        TEXT NOT NULL,
  notes         TEXT,
  confidence    REAL NOT NULL DEFAULT 0,
  impact_points REAL NOT NULL DEFAULT 0,
  reward_mrc    REAL NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  UNIQUE (article_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_news_verifications_article ON news_verifications(article_id, created_at);

CREATE TABLE IF NOT EXISTS feed_sources (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  slug           TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  homepage       TEXT NOT NULL,
  rss_url        TEXT NOT NULL UNIQUE,
  logo_url       TEXT,
  active         INTEGER NOT NULL DEFAULT 1,
  last_synced_at TEXT,
  last_error     TEXT,
  created_at     TEXT NOT NULL
);

INSERT OR IGNORE INTO feed_sources
  (slug, name, homepage, rss_url, active, created_at) VALUES
  ('dailynewsegypt', 'Daily News Egypt', 'https://dailynewsegypt.com',
   'https://dailynewsegypt.com/feed/', 1, datetime('now')),
  ('egyptindependent', 'Egypt Independent', 'https://www.egyptindependent.com',
   'https://www.egyptindependent.com/feed/', 1, datetime('now')),
  ('enterprise', 'Enterprise', 'https://enterprise.news',
   'https://enterprise.news/feed/', 1, datetime('now')),
  ('youm7', 'Youm7', 'https://www.youm7.com',
   'https://www.youm7.com/rss/SectionRss?SectionID=65', 0, datetime('now')),
  ('almasryalyoum', 'Al-Masry Al-Youm', 'https://www.almasryalyoum.com',
   'https://www.almasryalyoum.com/rss/rssfeed', 1, datetime('now'));

ALTER TABLE opportunities ADD COLUMN auto_generated INTEGER NOT NULL DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN source_type TEXT;
ALTER TABLE opportunities ADD COLUMN source_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_opportunities_source
  ON opportunities(source_type, source_id)
  WHERE source_type IS NOT NULL AND source_id IS NOT NULL;

ALTER TABLE research_stages ADD COLUMN abstract TEXT;
ALTER TABLE research_stages ADD COLUMN keywords_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE research_stages ADD COLUMN authors_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE research_stages ADD COLUMN methodology TEXT;
ALTER TABLE research_stages ADD COLUMN expected_impact TEXT;
ALTER TABLE research_stages ADD COLUMN funding_goal_mrc REAL NOT NULL DEFAULT 0;
ALTER TABLE research_stages ADD COLUMN funding_raised_mrc REAL NOT NULL DEFAULT 0;
ALTER TABLE research_stages ADD COLUMN peer_review_status TEXT NOT NULL DEFAULT 'OPEN';
ALTER TABLE research_stages ADD COLUMN open_for_review INTEGER NOT NULL DEFAULT 1;
ALTER TABLE research_stages ADD COLUMN published_at TEXT;
ALTER TABLE research_stages ADD COLUMN doi TEXT;
ALTER TABLE research_stages ADD COLUMN impact_score REAL NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS research_reviews (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id      INTEGER NOT NULL,
  reviewer_id   INTEGER NOT NULL,
  verdict       TEXT NOT NULL,
  comments      TEXT,
  score         REAL NOT NULL DEFAULT 0,
  reward_mrc    REAL NOT NULL DEFAULT 0,
  impact_points REAL NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  UNIQUE (stage_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_research_reviews_stage ON research_reviews(stage_id, created_at);

CREATE TABLE IF NOT EXISTS research_funding (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  amount_mrc REAL NOT NULL,
  fee_mrc    REAL NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS research_authors (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id     INTEGER NOT NULL,
  user_id      INTEGER,
  name         TEXT NOT NULL,
  role_title   TEXT,
  affiliation  TEXT,
  author_order INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_research_authors_stage ON research_authors(stage_id, author_order);

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  scope         TEXT NOT NULL,
  period        TEXT NOT NULL,
  metric        TEXT NOT NULL,
  rankings_json TEXT NOT NULL,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_leaderboard_snapshots_scope
  ON leaderboard_snapshots(scope, period, created_at);
