-- MASAREEN registrations database (Cloudflare D1, free tier)
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  google_sub    TEXT UNIQUE,
  email         TEXT NOT NULL UNIQUE,
  email_verified INTEGER NOT NULL DEFAULT 0,
  name          TEXT NOT NULL DEFAULT '',
  picture       TEXT,
  -- Who the person is, and the details that depend on that role.
  role          TEXT,
  org           TEXT,
  org_type      TEXT,
  country       TEXT,
  city          TEXT,
  interest      TEXT,
  -- Student / academic details
  university    TEXT,
  university_id TEXT,
  department    TEXT,
  academic_year TEXT,
  degree_level  TEXT,
  -- Professional / journalist / organisation details
  employer      TEXT,
  job_title     TEXT,
  consent_at    TEXT,
  profile_complete INTEGER NOT NULL DEFAULT 0,
  signup_method TEXT NOT NULL DEFAULT 'google',
  locale        TEXT,
  signup_country TEXT,
  password_hash TEXT,
  password_salt TEXT,
  handle        TEXT,
  bio           TEXT,
  phone         TEXT,
  cover_url     TEXT,
  audience      TEXT,
  is_tester     INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  last_login_at TEXT,
  login_count   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_users_created ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS login_events (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id   INTEGER NOT NULL,
  email     TEXT NOT NULL,
  method    TEXT NOT NULL,
  at        TEXT NOT NULL,
  country   TEXT,
  ip_hash   TEXT,
  user_agent TEXT
);
CREATE INDEX IF NOT EXISTS idx_login_at ON login_events(at);

CREATE TABLE IF NOT EXISTS contact_messages (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT NOT NULL,
  email     TEXT NOT NULL,
  org       TEXT,
  org_type  TEXT,
  message   TEXT NOT NULL,
  user_id   INTEGER,
  created_at TEXT NOT NULL,
  ip_hash   TEXT
);
CREATE INDEX IF NOT EXISTS idx_msg_created ON contact_messages(created_at);

-- ---------- MASAREEN social + impact layer (v1) ----------
CREATE TABLE IF NOT EXISTS testers (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  country    TEXT,
  device     TEXT,
  android_version TEXT,
  source     TEXT,
  status     TEXT NOT NULL DEFAULT 'pending',
  notes      TEXT,
  created_at TEXT NOT NULL,
  invited_at TEXT,
  ip_hash    TEXT
);
CREATE INDEX IF NOT EXISTS idx_testers_created ON testers(created_at);

CREATE TABLE IF NOT EXISTS posts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id     INTEGER NOT NULL,
  text          TEXT NOT NULL,
  kind          TEXT NOT NULL DEFAULT 'UPDATE',
  sdg           INTEGER,
  impact_value  REAL,
  impact_label  TEXT,
  confidence_score REAL,
  confidence_label TEXT,
  confidence_factors TEXT,
  media_url     TEXT,
  link_url      TEXT,
  hidden        INTEGER NOT NULL DEFAULT 0,
  like_count    INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  share_count   INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_impact ON posts(impact_value);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_comments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  text       TEXT NOT NULL,
  hidden     INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON post_comments(post_id, created_at);

CREATE TABLE IF NOT EXISTS post_impact_votes (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  stars      INTEGER NOT NULL,
  categories TEXT,
  note       TEXT,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS follows (
  follower_id INTEGER NOT NULL,
  followee_id INTEGER NOT NULL,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON follows(followee_id);

CREATE TABLE IF NOT EXISTS post_views (
  user_id  INTEGER NOT NULL,
  post_id  INTEGER NOT NULL,
  seen_at  TEXT NOT NULL,
  PRIMARY KEY (user_id, post_id)
);

-- ---------- Courses, events and notifications (v1 app features) ----------
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

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id             INTEGER PRIMARY KEY,
  headline            TEXT,
  summary             TEXT,
  mission             TEXT,
  beat                TEXT,
  expertise           TEXT NOT NULL DEFAULT '[]',
  specializations     TEXT NOT NULL DEFAULT '[]',
  skills              TEXT NOT NULL DEFAULT '[]',
  languages           TEXT NOT NULL DEFAULT '[]',
  education           TEXT NOT NULL DEFAULT '[]',
  experience          TEXT NOT NULL DEFAULT '[]',
  certificates        TEXT NOT NULL DEFAULT '[]',
  awards              TEXT NOT NULL DEFAULT '[]',
  publications        TEXT NOT NULL DEFAULT '[]',
  memberships         TEXT NOT NULL DEFAULT '[]',
  employment_status   TEXT,
  availability        TEXT,
  website             TEXT,
  social_links        TEXT NOT NULL DEFAULT '{}',
  coverage_regions    TEXT NOT NULL DEFAULT '[]',
  coverage_hours      REAL NOT NULL DEFAULT 0,
  visibility          TEXT NOT NULL DEFAULT 'PUBLIC',
  completeness        INTEGER NOT NULL DEFAULT 0,
  updated_at          TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS organizations (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id            INTEGER,
  name                TEXT NOT NULL,
  slug                TEXT,
  type                TEXT NOT NULL DEFAULT 'NGO',
  description         TEXT,
  logo_url            TEXT,
  cover_url           TEXT,
  website             TEXT,
  country             TEXT,
  city                TEXT,
  verified            INTEGER NOT NULL DEFAULT 0,
  verification_level  TEXT NOT NULL DEFAULT 'UNVERIFIED',
  pms_score           REAL NOT NULL DEFAULT 0,
  oii_score           REAL NOT NULL DEFAULT 0,
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_organizations_name ON organizations(name);
CREATE INDEX IF NOT EXISTS idx_organizations_owner ON organizations(owner_id);

CREATE TABLE IF NOT EXISTS organization_members (
  organization_id INTEGER NOT NULL,
  user_id         INTEGER NOT NULL,
  role            TEXT NOT NULL DEFAULT 'MEMBER',
  title           TEXT,
  start_date      TEXT,
  end_date        TEXT,
  created_at      TEXT NOT NULL,
  PRIMARY KEY (organization_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_org_members_user ON organization_members(user_id);

CREATE TABLE IF NOT EXISTS profile_achievements (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  title       TEXT NOT NULL,
  detail      TEXT,
  kind        TEXT NOT NULL DEFAULT 'AWARD',
  earned_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_profile_achievements_user ON profile_achievements(user_id, earned_at);

CREATE TABLE IF NOT EXISTS profile_recommendations (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  author_id   INTEGER NOT NULL,
  relation    TEXT,
  text        TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'PUBLISHED',
  created_at  TEXT NOT NULL,
  UNIQUE (user_id, author_id)
);
CREATE INDEX IF NOT EXISTS idx_profile_recommendations_user ON profile_recommendations(user_id);

CREATE TABLE IF NOT EXISTS profile_endorsements (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  endorser_id INTEGER NOT NULL,
  skill       TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  UNIQUE (user_id, endorser_id, skill)
);
CREATE INDEX IF NOT EXISTS idx_profile_endorsements_user ON profile_endorsements(user_id);

CREATE TABLE IF NOT EXISTS profile_analytics (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id           INTEGER NOT NULL,
  bucket            TEXT NOT NULL,
  impact_score      REAL NOT NULL DEFAULT 0,
  reach             REAL NOT NULL DEFAULT 0,
  engagement        REAL NOT NULL DEFAULT 0,
  verified_reports  INTEGER NOT NULL DEFAULT 0,
  evidence          INTEGER NOT NULL DEFAULT 0,
  trust_score       REAL NOT NULL DEFAULT 0,
  knowledge         REAL NOT NULL DEFAULT 0,
  influence         REAL NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL,
  UNIQUE (user_id, bucket)
);

CREATE TABLE IF NOT EXISTS pms_scores (
  user_id                 INTEGER PRIMARY KEY,
  reliability             REAL NOT NULL DEFAULT 0,
  execution_quality       REAL NOT NULL DEFAULT 0,
  leadership              REAL NOT NULL DEFAULT 0,
  documentation_quality   REAL NOT NULL DEFAULT 0,
  verification_confidence REAL NOT NULL DEFAULT 0,
  learning_velocity       REAL NOT NULL DEFAULT 0,
  technical_skills        REAL NOT NULL DEFAULT 0,
  innovation              REAL NOT NULL DEFAULT 0,
  consistency             REAL NOT NULL DEFAULT 0,
  community_impact        REAL NOT NULL DEFAULT 0,
  total                   REAL NOT NULL DEFAULT 0,
  tier                    TEXT NOT NULL DEFAULT 'BRONZE',
  updated_at              TEXT NOT NULL
);
