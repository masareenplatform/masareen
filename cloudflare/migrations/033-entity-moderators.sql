-- Scoped entity moderators. A moderator has explicit permissions on one entity
-- and never inherits platform-admin rights.
CREATE TABLE IF NOT EXISTS entity_moderators (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type    TEXT NOT NULL,
  entity_id      TEXT NOT NULL,
  user_id        INTEGER NOT NULL,
  permissions_json TEXT NOT NULL DEFAULT '[]',
  assigned_by    INTEGER NOT NULL,
  created_at     TEXT NOT NULL,
  UNIQUE(entity_type, entity_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_entity_moderators_entity
  ON entity_moderators(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_entity_moderators_user
  ON entity_moderators(user_id);
