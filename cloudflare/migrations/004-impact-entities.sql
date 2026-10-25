-- Impact delivery entities: programs, projects, tasks, opportunities,
-- evidence, verified claims, pipelines and story packs.

CREATE TABLE IF NOT EXISTS programs (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id           INTEGER NOT NULL,
  title               TEXT NOT NULL,
  description         TEXT,
  category            TEXT,
  organization        TEXT,
  sdg                 INTEGER,
  status              TEXT NOT NULL DEFAULT 'ACTIVE',
  budget              REAL NOT NULL DEFAULT 0,
  currency            TEXT NOT NULL DEFAULT 'EGP',
  country             TEXT,
  governorate         TEXT,
  start_date          TEXT,
  end_date            TEXT,
  target_beneficiaries INTEGER NOT NULL DEFAULT 0,
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_programs_created ON programs(created_at);

CREATE TABLE IF NOT EXISTS program_members (
  program_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  role       TEXT NOT NULL DEFAULT 'MEMBER',
  created_at TEXT NOT NULL,
  PRIMARY KEY (program_id, user_id)
);

CREATE TABLE IF NOT EXISTS projects (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id  INTEGER,
  author_id   INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  category    TEXT NOT NULL DEFAULT 'Community',
  sdg         INTEGER,
  cover       TEXT,
  goal        REAL NOT NULL DEFAULT 0,
  raised      REAL NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_projects_created ON projects(created_at);

CREATE TABLE IF NOT EXISTS project_members (
  project_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  role       TEXT NOT NULL DEFAULT 'MEMBER',
  created_at TEXT NOT NULL,
  PRIMARY KEY (project_id, user_id)
);

CREATE TABLE IF NOT EXISTS tasks (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id        INTEGER,
  project_id        INTEGER,
  assignee_id       INTEGER,
  title             TEXT NOT NULL,
  description       TEXT,
  status            TEXT NOT NULL DEFAULT 'OPEN',
  due_at            TEXT,
  location          TEXT,
  evidence_required INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_program ON tasks(program_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id);

CREATE TABLE IF NOT EXISTS opportunities (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id   INTEGER NOT NULL,
  title       TEXT NOT NULL,
  description TEXT,
  type        TEXT NOT NULL DEFAULT 'VOLUNTEER',
  skills      TEXT NOT NULL DEFAULT '[]',
  sdg         INTEGER,
  location    TEXT,
  is_remote   INTEGER NOT NULL DEFAULT 0,
  deadline    TEXT,
  min_pms     REAL,
  status      TEXT NOT NULL DEFAULT 'OPEN',
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_opportunities_created ON opportunities(created_at);

CREATE TABLE IF NOT EXISTS opportunity_applications (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  opportunity_id INTEGER NOT NULL,
  user_id        INTEGER NOT NULL,
  note           TEXT,
  status         TEXT NOT NULL DEFAULT 'SUBMITTED',
  created_at     TEXT NOT NULL,
  UNIQUE (opportunity_id, user_id)
);

CREATE TABLE IF NOT EXISTS evidence (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id      INTEGER NOT NULL,
  submission_id INTEGER,
  title         TEXT NOT NULL,
  kind          TEXT NOT NULL DEFAULT 'DOCUMENT',
  url           TEXT,
  sha256        TEXT,
  latitude      REAL,
  longitude     REAL,
  captured_at   TEXT,
  status        TEXT NOT NULL DEFAULT 'PENDING',
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_evidence_owner ON evidence(owner_id);

CREATE TABLE IF NOT EXISTS submissions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id    INTEGER NOT NULL,
  title       TEXT NOT NULL,
  claim       TEXT,
  program_id  INTEGER,
  task_id     INTEGER,
  evidence_id INTEGER,
  status      TEXT NOT NULL DEFAULT 'SUBMITTED',
  confidence  REAL NOT NULL DEFAULT 0,
  reviewer_id INTEGER,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_submissions_owner ON submissions(owner_id);

CREATE TABLE IF NOT EXISTS verification_pipelines (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id INTEGER NOT NULL,
  status        TEXT NOT NULL DEFAULT 'AI_REVIEW',
  stage         INTEGER NOT NULL DEFAULT 0,
  confidence    REAL NOT NULL DEFAULT 0,
  steps         TEXT NOT NULL DEFAULT '[]',
  updated_at    TEXT NOT NULL,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pipelines_submission ON verification_pipelines(submission_id);

CREATE TABLE IF NOT EXISTS story_packs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id INTEGER,
  author_id     INTEGER NOT NULL,
  title         TEXT NOT NULL,
  summary       TEXT,
  status        TEXT NOT NULL DEFAULT 'READY',
  created_at    TEXT NOT NULL
);
