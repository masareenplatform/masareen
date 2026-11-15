-- Admin popup announcements and rich course lesson attachments.
CREATE TABLE IF NOT EXISTS announcements (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  image_url      TEXT,
  link_url       TEXT,
  cta_label      TEXT,
  audience       TEXT NOT NULL DEFAULT 'ALL',
  audience_value TEXT,
  active_from    TEXT NOT NULL,
  active_until   TEXT,
  created_by     INTEGER,
  created_at     TEXT NOT NULL,
  notified       INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_announcements_active
  ON announcements(active_from, active_until);

CREATE TABLE IF NOT EXISTS announcement_dismissals (
  announcement_id INTEGER NOT NULL,
  user_id         INTEGER NOT NULL,
  dismissed_at    TEXT NOT NULL,
  PRIMARY KEY (announcement_id, user_id)
);

ALTER TABLE course_lessons ADD COLUMN media_json TEXT;
ALTER TABLE course_lessons ADD COLUMN files_json TEXT;
ALTER TABLE course_lessons ADD COLUMN links_json TEXT;
