-- One recognition post per member per achieved impact milestone.
CREATE TABLE IF NOT EXISTS recognition_awards (
  user_id    INTEGER NOT NULL,
  milestone  INTEGER NOT NULL,
  post_id    INTEGER,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, milestone)
);
CREATE INDEX IF NOT EXISTS idx_recognition_awards_created
  ON recognition_awards(created_at);
