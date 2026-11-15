-- Entity connections, university projects, event funding and research stages.
ALTER TABLE events ADD COLUMN funding_goal REAL NOT NULL DEFAULT 0;
ALTER TABLE events ADD COLUMN funding_raised REAL NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN project_type TEXT NOT NULL DEFAULT 'COMMUNITY';
ALTER TABLE projects ADD COLUMN institution_id INTEGER;
ALTER TABLE projects ADD COLUMN academic_year TEXT;
ALTER TABLE projects ADD COLUMN student_names TEXT;
ALTER TABLE projects ADD COLUMN supervisor TEXT;

CREATE TABLE IF NOT EXISTS entity_links (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  source_type TEXT NOT NULL,
  source_id   TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id   TEXT NOT NULL,
  relation    TEXT NOT NULL DEFAULT 'RELATED',
  created_by  INTEGER,
  created_at  TEXT NOT NULL,
  UNIQUE (source_type, source_id, target_type, target_id, relation)
);
CREATE INDEX IF NOT EXISTS idx_entity_links_source ON entity_links(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_entity_links_target ON entity_links(target_type, target_id);

CREATE TABLE IF NOT EXISTS research_stages (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  researcher_id  INTEGER NOT NULL,
  institution_id INTEGER,
  project_id     INTEGER,
  post_id        INTEGER,
  title          TEXT NOT NULL,
  stage          TEXT NOT NULL DEFAULT 'IDEA',
  summary        TEXT,
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  media_url      TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_research_stages_researcher ON research_stages(researcher_id, created_at);
CREATE INDEX IF NOT EXISTS idx_research_stages_institution ON research_stages(institution_id, created_at);
