-- Engagement for VOD and podcasts (comments and reactions).
CREATE TABLE IF NOT EXISTS content_comments (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  target_type   TEXT NOT NULL,
  target_id     INTEGER NOT NULL,
  author_id     INTEGER NOT NULL,
  text          TEXT NOT NULL,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_content_comments_target ON content_comments(target_type, target_id, created_at);

CREATE TABLE IF NOT EXISTS content_reactions (
  target_type   TEXT NOT NULL,
  target_id     INTEGER NOT NULL,
  user_id       INTEGER NOT NULL,
  created_at    TEXT NOT NULL,
  PRIMARY KEY (target_type, target_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_content_reactions_target ON content_reactions(target_type, target_id);
