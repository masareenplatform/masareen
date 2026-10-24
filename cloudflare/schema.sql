-- MASAREEN registrations database (Cloudflare D1, free tier)
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  google_sub    TEXT UNIQUE,
  email         TEXT NOT NULL UNIQUE,
  email_verified INTEGER NOT NULL DEFAULT 0,
  name          TEXT NOT NULL DEFAULT '',
  picture       TEXT,
  -- Who the person is, and the details that depend on that role.
  role          TEXT,
  org           TEXT,
  org_type      TEXT,
  country       TEXT,
  city          TEXT,
  interest      TEXT,
  -- Student / academic details
  university    TEXT,
  university_id TEXT,
  department    TEXT,
  academic_year TEXT,
  degree_level  TEXT,
  -- Professional / journalist / organisation details
  employer      TEXT,
  job_title     TEXT,
  consent_at    TEXT,
  profile_complete INTEGER NOT NULL DEFAULT 0,
  signup_method TEXT NOT NULL DEFAULT 'google',
  locale        TEXT,
  signup_country TEXT,
  password_hash TEXT,
  password_salt TEXT,
  handle        TEXT,
  bio           TEXT,
  phone         TEXT,
  created_at    TEXT NOT NULL,
  last_login_at TEXT,
  login_count   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_users_created ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS login_events (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id   INTEGER NOT NULL,
  email     TEXT NOT NULL,
  method    TEXT NOT NULL,
  at        TEXT NOT NULL,
  country   TEXT,
  ip_hash   TEXT,
  user_agent TEXT
);
CREATE INDEX IF NOT EXISTS idx_login_at ON login_events(at);

CREATE TABLE IF NOT EXISTS contact_messages (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT NOT NULL,
  email     TEXT NOT NULL,
  org       TEXT,
  org_type  TEXT,
  message   TEXT NOT NULL,
  user_id   INTEGER,
  created_at TEXT NOT NULL,
  ip_hash   TEXT
);
CREATE INDEX IF NOT EXISTS idx_msg_created ON contact_messages(created_at);

-- ---------- MASAREEN social + impact layer (v1) ----------
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
