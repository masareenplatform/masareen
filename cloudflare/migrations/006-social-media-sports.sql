-- 006: media-rich posts, sports organisations/athletes, and HLS video jobs.
ALTER TABLE users ADD COLUMN national_id TEXT;

ALTER TABLE posts ADD COLUMN media_json TEXT;
ALTER TABLE posts ADD COLUMN media_type TEXT;
ALTER TABLE posts ADD COLUMN video_hls_url TEXT;
ALTER TABLE posts ADD COLUMN video_poster_url TEXT;
ALTER TABLE posts ADD COLUMN video_duration_seconds INTEGER;
ALTER TABLE posts ADD COLUMN latitude REAL;
ALTER TABLE posts ADD COLUMN longitude REAL;
ALTER TABLE posts ADD COLUMN source TEXT NOT NULL DEFAULT 'USER';
ALTER TABLE posts ADD COLUMN updated_at TEXT;

ALTER TABLE organizations ADD COLUMN metadata_json TEXT;

CREATE TABLE IF NOT EXISTS sports_teams (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  external_source TEXT NOT NULL DEFAULT 'THESPORTSDB',
  external_id     TEXT,
  name            TEXT NOT NULL,
  short_name      TEXT,
  sport           TEXT,
  league          TEXT,
  country         TEXT,
  badge_url       TEXT,
  banner_url      TEXT,
  stadium         TEXT,
  founded         TEXT,
  metadata_json   TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  UNIQUE (external_source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_sports_teams_name ON sports_teams(name);
CREATE INDEX IF NOT EXISTS idx_sports_teams_league ON sports_teams(league);

CREATE TABLE IF NOT EXISTS sports_profiles (
  user_id            INTEGER PRIMARY KEY,
  sport              TEXT NOT NULL DEFAULT 'FOOTBALL',
  discipline         TEXT,
  position           TEXT,
  secondary_position TEXT,
  club               TEXT,
  team_id            INTEGER,
  nationality        TEXT,
  birth_date         TEXT,
  height_cm          REAL,
  weight_kg          REAL,
  preferred_foot     TEXT,
  jersey_number      INTEGER,
  market_value       TEXT,
  photo_url          TEXT,
  external_source    TEXT,
  external_id        TEXT,
  bio                TEXT,
  metrics_json       TEXT,
  verified           INTEGER NOT NULL DEFAULT 0,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_sport ON sports_profiles(sport);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_club ON sports_profiles(club);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_external ON sports_profiles(external_source, external_id);

CREATE TABLE IF NOT EXISTS sports_metrics (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id          INTEGER NOT NULL,
  sport            TEXT,
  season           TEXT,
  competition      TEXT,
  team             TEXT,
  appearances      INTEGER NOT NULL DEFAULT 0,
  starts           INTEGER NOT NULL DEFAULT 0,
  minutes          INTEGER NOT NULL DEFAULT 0,
  goals            INTEGER NOT NULL DEFAULT 0,
  assists          INTEGER NOT NULL DEFAULT 0,
  rating           REAL,
  yellow_cards     INTEGER NOT NULL DEFAULT 0,
  red_cards        INTEGER NOT NULL DEFAULT 0,
  clean_sheets     INTEGER NOT NULL DEFAULT 0,
  saves            INTEGER NOT NULL DEFAULT 0,
  passes_accuracy  REAL,
  distance_km      REAL,
  sprint_count     INTEGER,
  payload_json     TEXT,
  source           TEXT NOT NULL DEFAULT 'MANUAL',
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (user_id, season, competition, team)
);
CREATE INDEX IF NOT EXISTS idx_sports_metrics_user ON sports_metrics(user_id, season);
CREATE INDEX IF NOT EXISTS idx_sports_metrics_competition ON sports_metrics(competition, season);

CREATE TABLE IF NOT EXISTS sports_roster (
  org_id         INTEGER NOT NULL,
  athlete_id     INTEGER NOT NULL,
  position       TEXT,
  jersey_number  INTEGER,
  season         TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at     TEXT NOT NULL,
  PRIMARY KEY (org_id, athlete_id, season)
);
CREATE INDEX IF NOT EXISTS idx_sports_roster_athlete ON sports_roster(athlete_id);

CREATE TABLE IF NOT EXISTS sports_events (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  org_id         INTEGER NOT NULL,
  opponent_name  TEXT NOT NULL,
  opponent_logo  TEXT,
  competition    TEXT,
  starts_at      TEXT NOT NULL,
  venue          TEXT,
  home_away      TEXT NOT NULL DEFAULT 'HOME',
  status         TEXT NOT NULL DEFAULT 'SCHEDULED',
  home_score     INTEGER,
  away_score     INTEGER,
  payload_json   TEXT,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sports_events_org ON sports_events(org_id, starts_at);

CREATE TABLE IF NOT EXISTS institution_profiles (
  user_id            INTEGER PRIMARY KEY,
  institution_type   TEXT NOT NULL DEFAULT 'GOVERNMENT',
  jurisdiction       TEXT,
  services_json      TEXT,
  departments_json   TEXT,
  metrics_json       TEXT,
  transparency_score REAL NOT NULL DEFAULT 0,
  updated_at         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS video_jobs (
  id            TEXT PRIMARY KEY,
  user_id       INTEGER NOT NULL,
  post_id       INTEGER,
  status        TEXT NOT NULL DEFAULT 'queued',
  original_url  TEXT NOT NULL,
  hls_url       TEXT,
  poster_url    TEXT,
  duration_seconds INTEGER,
  error         TEXT,
  attempts      INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_video_jobs_status ON video_jobs(status, created_at);
CREATE INDEX IF NOT EXISTS idx_video_jobs_post ON video_jobs(post_id);
