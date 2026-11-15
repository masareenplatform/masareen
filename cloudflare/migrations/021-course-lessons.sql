-- Structured course lessons and free/paid access.
ALTER TABLE courses ADD COLUMN is_free INTEGER NOT NULL DEFAULT 1;
ALTER TABLE courses ADD COLUMN price_mrc REAL NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS course_lessons (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  course_id   INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  content     TEXT,
  video_url   TEXT,
  duration_min INTEGER NOT NULL DEFAULT 0,
  position    INTEGER NOT NULL DEFAULT 0,
  is_preview  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_course_lessons ON course_lessons(course_id, position, id);
