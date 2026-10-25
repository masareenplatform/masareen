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
