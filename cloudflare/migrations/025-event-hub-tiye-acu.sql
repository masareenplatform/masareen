-- Persistent event hubs, contributor roles, interactive booths, verified activity
-- and the MRC incentive loop for TIYE, hosts, exhibitors, students and visitors.
ALTER TABLE events ADD COLUMN program_id INTEGER;
ALTER TABLE events ADD COLUMN event_type TEXT NOT NULL DEFAULT 'EVENT';
ALTER TABLE events ADD COLUMN source_url TEXT;
ALTER TABLE events ADD COLUMN activity_verified_at TEXT;
ALTER TABLE events ADD COLUMN activity_verified_by INTEGER;

CREATE TABLE IF NOT EXISTS event_participants (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id          INTEGER NOT NULL,
  user_id           INTEGER NOT NULL,
  role              TEXT NOT NULL,
  role_title        TEXT,
  status            TEXT NOT NULL DEFAULT 'INVITED',
  contribution      TEXT,
  evidence_json     TEXT,
  verification_note TEXT,
  verified_by       INTEGER,
  verified_at       TEXT,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  UNIQUE (event_id, user_id, role)
);
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON event_participants(event_id, role);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON event_participants(user_id, status);

CREATE TABLE IF NOT EXISTS event_media (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id      INTEGER NOT NULL,
  created_by    INTEGER,
  type          TEXT NOT NULL DEFAULT 'IMAGE',
  title         TEXT,
  description   TEXT,
  url           TEXT NOT NULL,
  thumbnail_url TEXT,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_event_media_event ON event_media(event_id, created_at);

CREATE TABLE IF NOT EXISTS event_booths (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id        INTEGER NOT NULL,
  user_id         INTEGER NOT NULL,
  title           TEXT NOT NULL,
  description     TEXT,
  logo_url        TEXT,
  cover_url       TEXT,
  video_url       TEXT,
  cta_type        TEXT NOT NULL DEFAULT 'QUOTE',
  cta_label       TEXT,
  trial_price_mrc REAL NOT NULL DEFAULT 0,
  products_json   TEXT,
  active          INTEGER NOT NULL DEFAULT 0,
  views           INTEGER NOT NULL DEFAULT 0,
  interactions    INTEGER NOT NULL DEFAULT 0,
  leads_count     INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_event_booths_event ON event_booths(event_id, active);
CREATE INDEX IF NOT EXISTS idx_event_booths_user ON event_booths(user_id);

CREATE TABLE IF NOT EXISTS booth_leads (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  booth_id   INTEGER NOT NULL,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER,
  name       TEXT,
  email      TEXT,
  phone      TEXT,
  message    TEXT,
  type       TEXT NOT NULL DEFAULT 'QUOTE',
  status     TEXT NOT NULL DEFAULT 'NEW',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_booth_leads_booth ON booth_leads(booth_id, created_at);
CREATE INDEX IF NOT EXISTS idx_booth_leads_event ON booth_leads(event_id, status);

CREATE TABLE IF NOT EXISTS booth_views (
  booth_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (booth_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_ratings (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  rating     INTEGER NOT NULL,
  review     TEXT,
  role       TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_ratings_event ON event_ratings(event_id, rating);

CREATE TABLE IF NOT EXISTS event_rewards (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  booth_id   INTEGER,
  kind       TEXT NOT NULL,
  amount     REAL NOT NULL,
  reference  TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (event_id, user_id, kind, reference)
);
CREATE INDEX IF NOT EXISTS idx_event_rewards_event ON event_rewards(event_id, kind);
CREATE INDEX IF NOT EXISTS idx_event_rewards_user ON event_rewards(user_id, created_at);
