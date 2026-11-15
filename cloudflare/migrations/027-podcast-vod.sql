-- Podcast shows/episodes and VOD videos as first-class, event-linked entities.
CREATE TABLE IF NOT EXISTS podcast_shows (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id            INTEGER NOT NULL,
  title               TEXT NOT NULL,
  slug                TEXT,
  description         TEXT,
  cover_url           TEXT,
  category            TEXT,
  sdg                 INTEGER,
  language            TEXT NOT NULL DEFAULT 'ar',
  status              TEXT NOT NULL DEFAULT 'ACTIVE',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_podcast_shows_owner ON podcast_shows(owner_id, created_at);

CREATE TABLE IF NOT EXISTS podcast_episodes (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  show_id             INTEGER NOT NULL,
  event_id            INTEGER,
  title               TEXT NOT NULL,
  description         TEXT,
  audio_url           TEXT,
  video_url           TEXT,
  cover_url           TEXT,
  duration_sec        INTEGER NOT NULL DEFAULT 0,
  season_number       INTEGER NOT NULL DEFAULT 1,
  episode_number      INTEGER NOT NULL DEFAULT 1,
  transcript          TEXT,
  guests_json         TEXT,
  published_at        TEXT,
  status              TEXT NOT NULL DEFAULT 'PUBLISHED',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_show ON podcast_episodes(show_id, published_at);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_event ON podcast_episodes(event_id);

CREATE TABLE IF NOT EXISTS vod_videos (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id            INTEGER NOT NULL,
  event_id            INTEGER,
  program_id          INTEGER,
  title               TEXT NOT NULL,
  description         TEXT,
  cover_url           TEXT,
  video_url           TEXT,
  hls_url             TEXT,
  duration_sec        INTEGER NOT NULL DEFAULT 0,
  category            TEXT,
  sdg                 INTEGER,
  views               INTEGER NOT NULL DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'PUBLISHED',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_vod_videos_owner ON vod_videos(owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_vod_videos_event ON vod_videos(event_id);
