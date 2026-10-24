-- Social + impact layer (apply once on an existing database).
ALTER TABLE users ADD COLUMN password_hash TEXT;
ALTER TABLE users ADD COLUMN password_salt TEXT;
ALTER TABLE users ADD COLUMN handle TEXT;
ALTER TABLE users ADD COLUMN bio TEXT;
ALTER TABLE users ADD COLUMN phone TEXT;

CREATE TABLE IF NOT EXISTS testers (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  country    TEXT,
  device     TEXT,
  android_version TEXT,
  source     TEXT,
  status     TEXT NOT NULL DEFAULT 'pending',
  notes      TEXT,
  created_at TEXT NOT NULL,
  invited_at TEXT,
  ip_hash    TEXT
);
CREATE INDEX IF NOT EXISTS idx_testers_created ON testers(created_at);

CREATE TABLE IF NOT EXISTS posts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id     INTEGER NOT NULL,
  text          TEXT NOT NULL,
  kind          TEXT NOT NULL DEFAULT 'UPDATE',
  sdg           INTEGER,
  impact_value  REAL,
  impact_label  TEXT,
  confidence_score REAL,
  confidence_label TEXT,
  confidence_factors TEXT,
  media_url     TEXT,
  link_url      TEXT,
  hidden        INTEGER NOT NULL DEFAULT 0,
  like_count    INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  share_count   INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_impact ON posts(impact_value);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE TABLE IF NOT EXISTS post_comments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  text       TEXT NOT NULL,
  hidden     INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON post_comments(post_id, created_at);

CREATE TABLE IF NOT EXISTS post_impact_votes (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  stars      INTEGER NOT NULL,
  categories TEXT,
  note       TEXT,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS follows (
  follower_id INTEGER NOT NULL,
  followee_id INTEGER NOT NULL,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON follows(followee_id);

CREATE TABLE IF NOT EXISTS post_views (
  user_id  INTEGER NOT NULL,
  post_id  INTEGER NOT NULL,
  seen_at  TEXT NOT NULL,
  PRIMARY KEY (user_id, post_id)
);
