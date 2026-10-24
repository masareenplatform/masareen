-- App features: tester flag, cover photo, courses, events, notifications.
ALTER TABLE users ADD COLUMN cover_url TEXT;
ALTER TABLE users ADD COLUMN audience TEXT;
ALTER TABLE users ADD COLUMN is_tester INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS courses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id   INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  provider    TEXT,
  level       TEXT NOT NULL DEFAULT 'Beginner',
  sdg         INTEGER,
  lessons     INTEGER NOT NULL DEFAULT 0,
  duration_min INTEGER NOT NULL DEFAULT 0,
  thumbnail   TEXT,
  status      TEXT NOT NULL DEFAULT 'PUBLISHED',
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_courses_created ON courses(created_at);

CREATE TABLE IF NOT EXISTS course_enrollments (
  course_id  INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (course_id, user_id)
);

CREATE TABLE IF NOT EXISTS events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id   INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  starts_at   TEXT NOT NULL,
  ends_at     TEXT,
  location    TEXT,
  is_online   INTEGER NOT NULL DEFAULT 0,
  link_url    TEXT,
  sdg         INTEGER,
  capacity    INTEGER,
  status      TEXT NOT NULL DEFAULT 'PUBLISHED',
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_starts ON events(starts_at);

CREATE TABLE IF NOT EXISTS event_attendees (
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS notifications (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT,
  actor_id   INTEGER,
  post_id    INTEGER,
  read       INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);
