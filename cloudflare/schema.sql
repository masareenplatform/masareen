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
  national_id   TEXT,
  cover_url     TEXT,
  audience      TEXT,
  is_tester     INTEGER NOT NULL DEFAULT 0,
  suspended     INTEGER NOT NULL DEFAULT 0,
  suspension_reason TEXT,
  created_at    TEXT NOT NULL,
  last_login_at TEXT,
  last_active_at TEXT,
  login_count   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_users_created ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS rate_limits (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  key        TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rate_limits_key ON rate_limits(key, created_at);

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
  isa_score     REAL,
  impact_domains_json TEXT,
  impact_metrics_json TEXT,
  geo_adjusted  INTEGER NOT NULL DEFAULT 0,
  actor_factor  REAL,
  consistency_factor REAL,
  location_claim TEXT,
  boosted_until TEXT,
  boost_weight REAL NOT NULL DEFAULT 0,
  paid_mrc REAL NOT NULL DEFAULT 0,
  capture_source TEXT NOT NULL DEFAULT 'UNKNOWN',
  capture_trust REAL NOT NULL DEFAULT 0,
  deepfake_score REAL NOT NULL DEFAULT 0,
  deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED',
  deepfake_signals_json TEXT,
  confidence_score REAL,
  confidence_label TEXT,
  confidence_factors TEXT,
  media_url     TEXT,
  link_url      TEXT,
  media_json    TEXT,
  files_json    TEXT,
  media_type    TEXT,
  video_hls_url TEXT,
  video_poster_url TEXT,
  video_duration_seconds INTEGER,
  latitude      REAL,
  longitude     REAL,
  source        TEXT NOT NULL DEFAULT 'USER',
  updated_at    TEXT,
  edited_at     TEXT,
  hidden        INTEGER NOT NULL DEFAULT 0,
  transcript    TEXT,
  embedding_json TEXT,
  embedding_status TEXT DEFAULT 'none',
  moderation_status TEXT DEFAULT 'APPROVED',
  structured_json TEXT,
  like_count    INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  share_count   INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);
CREATE INDEX IF NOT EXISTS idx_posts_hidden_created ON posts(hidden, created_at);
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_impact ON posts(impact_value);
CREATE INDEX IF NOT EXISTS idx_posts_isa ON posts(isa_score);
CREATE INDEX IF NOT EXISTS idx_posts_deepfake ON posts(deepfake_verdict, deepfake_score);
CREATE INDEX IF NOT EXISTS idx_posts_moderation_created ON posts(moderation_status, created_at);

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
  parent_id  INTEGER,
  text       TEXT NOT NULL,
  like_count INTEGER NOT NULL DEFAULT 0,
  hidden     INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON post_comments(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON post_comments(parent_id, created_at);

CREATE TABLE IF NOT EXISTS post_comment_likes (
  comment_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (comment_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_bookmarks (
  user_id    INTEGER NOT NULL,
  post_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, post_id)
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_post ON post_bookmarks(post_id);

CREATE TABLE IF NOT EXISTS conversations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  user_a          INTEGER NOT NULL,
  user_b          INTEGER NOT NULL,
  last_message_at TEXT,
  created_at      TEXT NOT NULL,
  UNIQUE (user_a, user_b)
);
CREATE INDEX IF NOT EXISTS idx_conversations_a ON conversations(user_a, last_message_at);
CREATE INDEX IF NOT EXISTS idx_conversations_b ON conversations(user_b, last_message_at);

CREATE TABLE IF NOT EXISTS messages (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  sender_id       INTEGER NOT NULL,
  body            TEXT NOT NULL,
  read_at         TEXT,
  created_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(conversation_id, read_at);

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id INTEGER NOT NULL,
  blocked_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON user_blocks(blocked_id);

CREATE TABLE IF NOT EXISTS reports (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  reporter_id INTEGER NOT NULL,
  target_type TEXT NOT NULL,
  target_id   INTEGER NOT NULL,
  reason      TEXT NOT NULL,
  details     TEXT,
  status      TEXT NOT NULL DEFAULT 'OPEN',
  resolved_at TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status, created_at);

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
CREATE INDEX IF NOT EXISTS idx_post_views_seen ON post_views(user_id, seen_at);

CREATE TABLE IF NOT EXISTS gps_records (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  accuracy    REAL,
  altitude    REAL,
  speed       REAL,
  heading     REAL,
  captured_at TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gps_user ON gps_records(user_id, created_at);

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
  verification_status TEXT NOT NULL DEFAULT 'APPROVED',
  rejection_reason TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER,
  creation_fee_mrc REAL NOT NULL DEFAULT 0,
  is_free INTEGER NOT NULL DEFAULT 1,
  price_mrc REAL NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_courses_created ON courses(created_at);

CREATE TABLE IF NOT EXISTS course_enrollments (
  course_id  INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (course_id, user_id)
);

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
  media_json  TEXT,
  files_json  TEXT,
  links_json  TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_course_lessons ON course_lessons(course_id, position, id);

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
  cover_url   TEXT,
  sdg         INTEGER,
  capacity    INTEGER,
  funding_goal REAL NOT NULL DEFAULT 0,
  funding_raised REAL NOT NULL DEFAULT 0,
  program_id  INTEGER,
  event_type  TEXT NOT NULL DEFAULT 'EVENT',
  source_url  TEXT,
  activity_verified_at TEXT,
  activity_verified_by INTEGER,
  status      TEXT NOT NULL DEFAULT 'PUBLISHED',
  verification_status TEXT NOT NULL DEFAULT 'APPROVED',
  rejection_reason TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER,
  creation_fee_mrc REAL NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_starts ON events(starts_at);

CREATE TABLE IF NOT EXISTS event_attendees (
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_participants (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id          INTEGER NOT NULL,
  user_id           INTEGER NOT NULL,
  role              TEXT NOT NULL,
  role_title        TEXT,
  status            TEXT NOT NULL DEFAULT 'INVITED',
  contribution      TEXT,
  evidence_json     TEXT,
  verification_note TEXT,
  verified_by       INTEGER,
  verified_at       TEXT,
  deepfake_score    REAL NOT NULL DEFAULT 0,
  deepfake_verdict  TEXT NOT NULL DEFAULT 'UNSCANNED',
  deepfake_signals_json TEXT,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  UNIQUE (event_id, user_id, role)
);
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON event_participants(event_id, role);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON event_participants(user_id, status);

CREATE TABLE IF NOT EXISTS event_media (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id      INTEGER NOT NULL,
  created_by    INTEGER,
  type          TEXT NOT NULL DEFAULT 'IMAGE',
  title         TEXT,
  description   TEXT,
  url           TEXT NOT NULL,
  thumbnail_url TEXT,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_event_media_event ON event_media(event_id, created_at);

CREATE TABLE IF NOT EXISTS podcast_shows (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id            INTEGER NOT NULL,
  title               TEXT NOT NULL,
  slug                TEXT,
  description         TEXT,
  cover_url           TEXT,
  category            TEXT,
  sdg                 INTEGER,
  language            TEXT NOT NULL DEFAULT 'ar',
  status              TEXT NOT NULL DEFAULT 'ACTIVE',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_podcast_shows_owner ON podcast_shows(owner_id, created_at);

CREATE TABLE IF NOT EXISTS podcast_episodes (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  show_id             INTEGER NOT NULL,
  event_id            INTEGER,
  title               TEXT NOT NULL,
  description         TEXT,
  audio_url           TEXT,
  video_url           TEXT,
  cover_url           TEXT,
  duration_sec        INTEGER NOT NULL DEFAULT 0,
  season_number       INTEGER NOT NULL DEFAULT 1,
  episode_number      INTEGER NOT NULL DEFAULT 1,
  transcript          TEXT,
  guests_json         TEXT,
  published_at        TEXT,
  status              TEXT NOT NULL DEFAULT 'PUBLISHED',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_show ON podcast_episodes(show_id, published_at);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_event ON podcast_episodes(event_id);

CREATE TABLE IF NOT EXISTS vod_videos (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id            INTEGER NOT NULL,
  event_id            INTEGER,
  program_id          INTEGER,
  title               TEXT NOT NULL,
  description         TEXT,
  cover_url           TEXT,
  video_url           TEXT,
  hls_url             TEXT,
  duration_sec        INTEGER NOT NULL DEFAULT 0,
  category            TEXT,
  sdg                 INTEGER,
  views               INTEGER NOT NULL DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'PUBLISHED',
  verification_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_vod_videos_owner ON vod_videos(owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_vod_videos_event ON vod_videos(event_id);

CREATE TABLE IF NOT EXISTS event_booths (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id        INTEGER NOT NULL,
  user_id         INTEGER NOT NULL,
  title           TEXT NOT NULL,
  description     TEXT,
  logo_url        TEXT,
  cover_url       TEXT,
  video_url       TEXT,
  cta_type        TEXT NOT NULL DEFAULT 'QUOTE',
  cta_label       TEXT,
  trial_price_mrc REAL NOT NULL DEFAULT 0,
  products_json   TEXT,
  tour_json       TEXT,
  ar_model_url    TEXT,
  active          INTEGER NOT NULL DEFAULT 0,
  views           INTEGER NOT NULL DEFAULT 0,
  interactions    INTEGER NOT NULL DEFAULT 0,
  leads_count     INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_event_booths_event ON event_booths(event_id, active);
CREATE INDEX IF NOT EXISTS idx_event_booths_user ON event_booths(user_id);

CREATE TABLE IF NOT EXISTS booth_leads (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  booth_id   INTEGER NOT NULL,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER,
  name       TEXT,
  email      TEXT,
  phone      TEXT,
  message    TEXT,
  type       TEXT NOT NULL DEFAULT 'QUOTE',
  status     TEXT NOT NULL DEFAULT 'NEW',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_booth_leads_booth ON booth_leads(booth_id, created_at);
CREATE INDEX IF NOT EXISTS idx_booth_leads_event ON booth_leads(event_id, status);

CREATE TABLE IF NOT EXISTS booth_views (
  booth_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (booth_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_ratings (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  rating     INTEGER NOT NULL,
  review     TEXT,
  role       TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_ratings_event ON event_ratings(event_id, rating);

CREATE TABLE IF NOT EXISTS event_rewards (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  booth_id   INTEGER,
  kind       TEXT NOT NULL,
  amount     REAL NOT NULL,
  reference  TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (event_id, user_id, kind, reference)
);
CREATE INDEX IF NOT EXISTS idx_event_rewards_event ON event_rewards(event_id, kind);
CREATE INDEX IF NOT EXISTS idx_event_rewards_user ON event_rewards(user_id, created_at);

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
CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(active_from, active_until);
CREATE TABLE IF NOT EXISTS announcement_dismissals (
  announcement_id INTEGER NOT NULL,
  user_id         INTEGER NOT NULL,
  dismissed_at    TEXT NOT NULL,
  PRIMARY KEY (announcement_id, user_id)
);

CREATE TABLE IF NOT EXISTS platform_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TEXT NOT NULL,
  updated_by INTEGER
);

CREATE TABLE IF NOT EXISTS feedback (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  role       TEXT,
  type       TEXT NOT NULL DEFAULT 'idea',
  message    TEXT NOT NULL,
  rating     INTEGER,
  status     TEXT NOT NULL DEFAULT 'OPEN',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status, created_at);

CREATE TABLE IF NOT EXISTS recognition_awards (
  user_id    INTEGER NOT NULL,
  milestone  INTEGER NOT NULL,
  post_id    INTEGER,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, milestone)
);
CREATE INDEX IF NOT EXISTS idx_recognition_awards_created
  ON recognition_awards(created_at);

CREATE TABLE IF NOT EXISTS analytics_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER,
  event_type  TEXT NOT NULL,
  target_type TEXT,
  target_id   TEXT,
  post_id     INTEGER,
  value       REAL,
  duration_ms INTEGER,
  metadata_json TEXT,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON analytics_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type ON analytics_events(event_type, created_at);
CREATE TABLE IF NOT EXISTS admin_audit (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id   INTEGER NOT NULL,
  action     TEXT NOT NULL,
  target_type TEXT,
  target_id  TEXT,
  details    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit(created_at);

CREATE TABLE IF NOT EXISTS notifications (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT,
  actor_id   INTEGER,
  post_id    INTEGER,
  link       TEXT,
  entity_type TEXT,
  entity_id  TEXT,
  read       INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);

CREATE TABLE IF NOT EXISTS auth_tokens (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  kind       TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  used_at    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user ON auth_tokens(user_id, kind, created_at);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id            INTEGER PRIMARY KEY,
  push_enabled       INTEGER NOT NULL DEFAULT 1,
  email_enabled      INTEGER NOT NULL DEFAULT 1,
  opportunity_alerts INTEGER NOT NULL DEFAULT 1,
  social_alerts      INTEGER NOT NULL DEFAULT 1,
  message_alerts     INTEGER NOT NULL DEFAULT 1,
  digest_frequency   TEXT NOT NULL DEFAULT 'instant',
  quiet_start        INTEGER,
  quiet_end          INTEGER,
  profile_visibility TEXT NOT NULL DEFAULT 'public',
  message_privacy    TEXT NOT NULL DEFAULT 'everyone',
  show_email         INTEGER NOT NULL DEFAULT 0,
  updated_at         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS device_tokens (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  token        TEXT NOT NULL,
  platform     TEXT NOT NULL,
  created_at   TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  UNIQUE (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

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
CREATE TABLE IF NOT EXISTS notification_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  kind       TEXT NOT NULL,
  ref_id     TEXT NOT NULL DEFAULT '',
  channel    TEXT NOT NULL DEFAULT 'in_app',
  created_at TEXT NOT NULL,
  UNIQUE (user_id, kind, ref_id, channel)
);
CREATE INDEX IF NOT EXISTS idx_notification_log_user ON notification_log(user_id, kind, created_at);

-- Impact delivery entities: programs, projects, tasks, opportunities,
-- evidence, verified claims, pipelines and story packs.

CREATE TABLE IF NOT EXISTS programs (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id           INTEGER NOT NULL,
  title               TEXT NOT NULL,
  description         TEXT,
  category            TEXT,
  organization        TEXT,
  cover_url           TEXT,
  sdg                 INTEGER,
  status              TEXT NOT NULL DEFAULT 'ACTIVE',
  budget              REAL NOT NULL DEFAULT 0,
  currency            TEXT NOT NULL DEFAULT 'EGP',
  country             TEXT,
  governorate         TEXT,
  start_date          TEXT,
  end_date            TEXT,
  target_beneficiaries INTEGER NOT NULL DEFAULT 0,
  verification_status TEXT NOT NULL DEFAULT 'APPROVED',
  rejection_reason TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER,
  creation_fee_mrc REAL NOT NULL DEFAULT 0,
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
  project_type TEXT NOT NULL DEFAULT 'COMMUNITY',
  institution_id INTEGER,
  academic_year TEXT,
  student_names TEXT,
  supervisor  TEXT,
  status      TEXT NOT NULL DEFAULT 'ACTIVE',
  verification_status TEXT NOT NULL DEFAULT 'APPROVED',
  rejection_reason TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER,
  creation_fee_mrc REAL NOT NULL DEFAULT 0,
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
  author_id         INTEGER,
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
  cover_url   TEXT,
  status      TEXT NOT NULL DEFAULT 'OPEN',
  verification_status TEXT NOT NULL DEFAULT 'APPROVED',
  rejection_reason TEXT,
  reviewed_at TEXT,
  reviewed_by INTEGER,
  creation_fee_mrc REAL NOT NULL DEFAULT 0,
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
  task_id       INTEGER,
  title         TEXT NOT NULL,
  description   TEXT,
  kind          TEXT NOT NULL DEFAULT 'DOCUMENT',
  url           TEXT,
  sha256        TEXT,
  location_label TEXT,
  media_json    TEXT,
  files_json    TEXT,
  source_name   TEXT,
  witnesses_json TEXT,
  metadata_json TEXT,
  target_type   TEXT NOT NULL DEFAULT 'GENERAL',
  target_id     TEXT,
  claim         TEXT,
  fields_json   TEXT,
  latitude      REAL,
  longitude     REAL,
  captured_at   TEXT,
  capture_source TEXT NOT NULL DEFAULT 'UNKNOWN',
  capture_trust REAL NOT NULL DEFAULT 0,
  deepfake_score REAL NOT NULL DEFAULT 0,
  deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED',
  deepfake_signals_json TEXT,
  status        TEXT NOT NULL DEFAULT 'PENDING',
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_evidence_owner ON evidence(owner_id);
CREATE INDEX IF NOT EXISTS idx_evidence_deepfake ON evidence(deepfake_verdict, deepfake_score);

CREATE TABLE IF NOT EXISTS submissions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id    INTEGER NOT NULL,
  title       TEXT NOT NULL,
  claim       TEXT,
  target_type TEXT NOT NULL DEFAULT 'GENERAL',
  target_id   TEXT,
  program_id  INTEGER,
  task_id     INTEGER,
  evidence_id INTEGER,
  status      TEXT NOT NULL DEFAULT 'SUBMITTED',
  confidence  REAL NOT NULL DEFAULT 0,
  deepfake_score REAL NOT NULL DEFAULT 0,
  deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED',
  deepfake_signals_json TEXT,
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
  deepfake_score REAL NOT NULL DEFAULT 0,
  deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED',
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
  metadata_json       TEXT,
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

-- ---------- Sports, institutions and HLS video (v6) ----------
CREATE TABLE IF NOT EXISTS sports_teams (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  external_source TEXT NOT NULL DEFAULT 'THESPORTSDB',
  external_id     TEXT,
  name            TEXT NOT NULL,
  short_name      TEXT,
  sport           TEXT,
  league          TEXT,
  country         TEXT,
  badge_url       TEXT,
  banner_url      TEXT,
  stadium         TEXT,
  founded         TEXT,
  metadata_json   TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  UNIQUE (external_source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_sports_teams_name ON sports_teams(name);
CREATE INDEX IF NOT EXISTS idx_sports_teams_league ON sports_teams(league);

CREATE TABLE IF NOT EXISTS sports_profiles (
  user_id            INTEGER PRIMARY KEY,
  sport              TEXT NOT NULL DEFAULT 'FOOTBALL',
  discipline         TEXT,
  position           TEXT,
  secondary_position TEXT,
  club               TEXT,
  team_id            INTEGER,
  nationality        TEXT,
  birth_date         TEXT,
  height_cm          REAL,
  weight_kg          REAL,
  preferred_foot     TEXT,
  jersey_number      INTEGER,
  market_value       TEXT,
  photo_url          TEXT,
  external_source    TEXT,
  external_id        TEXT,
  bio                TEXT,
  metrics_json       TEXT,
  verified           INTEGER NOT NULL DEFAULT 0,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_sport ON sports_profiles(sport);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_club ON sports_profiles(club);
CREATE INDEX IF NOT EXISTS idx_sports_profiles_external ON sports_profiles(external_source, external_id);

CREATE TABLE IF NOT EXISTS sports_metrics (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id          INTEGER NOT NULL,
  sport            TEXT,
  season           TEXT,
  competition      TEXT,
  team             TEXT,
  appearances      INTEGER NOT NULL DEFAULT 0,
  starts           INTEGER NOT NULL DEFAULT 0,
  minutes          INTEGER NOT NULL DEFAULT 0,
  goals            INTEGER NOT NULL DEFAULT 0,
  assists          INTEGER NOT NULL DEFAULT 0,
  rating           REAL,
  yellow_cards     INTEGER NOT NULL DEFAULT 0,
  red_cards        INTEGER NOT NULL DEFAULT 0,
  clean_sheets     INTEGER NOT NULL DEFAULT 0,
  saves            INTEGER NOT NULL DEFAULT 0,
  passes_accuracy  REAL,
  distance_km      REAL,
  sprint_count     INTEGER,
  payload_json     TEXT,
  source           TEXT NOT NULL DEFAULT 'MANUAL',
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (user_id, season, competition, team)
);
CREATE INDEX IF NOT EXISTS idx_sports_metrics_user ON sports_metrics(user_id, season);
CREATE INDEX IF NOT EXISTS idx_sports_metrics_competition ON sports_metrics(competition, season);

CREATE TABLE IF NOT EXISTS sports_roster (
  org_id         INTEGER NOT NULL,
  athlete_id     INTEGER NOT NULL,
  position       TEXT,
  jersey_number  INTEGER,
  season         TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at     TEXT NOT NULL,
  PRIMARY KEY (org_id, athlete_id, season)
);
CREATE INDEX IF NOT EXISTS idx_sports_roster_athlete ON sports_roster(athlete_id);

CREATE TABLE IF NOT EXISTS sports_events (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  org_id         INTEGER NOT NULL,
  opponent_name  TEXT NOT NULL,
  opponent_logo  TEXT,
  competition    TEXT,
  starts_at      TEXT NOT NULL,
  venue          TEXT,
  home_away      TEXT NOT NULL DEFAULT 'HOME',
  status         TEXT NOT NULL DEFAULT 'SCHEDULED',
  home_score     INTEGER,
  away_score     INTEGER,
  payload_json   TEXT,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sports_events_org ON sports_events(org_id, starts_at);

CREATE TABLE IF NOT EXISTS institution_profiles (
  user_id            INTEGER PRIMARY KEY,
  institution_type   TEXT NOT NULL DEFAULT 'GOVERNMENT',
  jurisdiction       TEXT,
  services_json      TEXT,
  departments_json   TEXT,
  metrics_json       TEXT,
  transparency_score REAL NOT NULL DEFAULT 0,
  updated_at         TEXT NOT NULL
);

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

CREATE TABLE IF NOT EXISTS video_jobs (
  id            TEXT PRIMARY KEY,
  user_id       INTEGER NOT NULL,
  post_id       INTEGER,
  status        TEXT NOT NULL DEFAULT 'queued',
  original_url  TEXT NOT NULL,
  hls_url       TEXT,
  poster_url    TEXT,
  duration_seconds INTEGER,
  error         TEXT,
  attempts      INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_video_jobs_status ON video_jobs(status, created_at);
CREATE INDEX IF NOT EXISTS idx_video_jobs_post ON video_jobs(post_id);

CREATE TABLE IF NOT EXISTS coin_wallets (
  owner_id     INTEGER PRIMARY KEY,
  balance      REAL NOT NULL DEFAULT 0,
  currency     TEXT NOT NULL DEFAULT 'MRC',
  updated_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS coin_transactions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id       INTEGER NOT NULL,
  type           TEXT NOT NULL,
  amount         REAL NOT NULL,
  balance_after  REAL NOT NULL,
  reference      TEXT,
  counterparty_id INTEGER,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_coin_tx_owner ON coin_transactions(owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_coin_tx_type ON coin_transactions(owner_id, type, created_at);

CREATE TABLE IF NOT EXISTS daily_claims (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id   INTEGER NOT NULL,
  claim_date TEXT NOT NULL,
  amount     REAL NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (owner_id, claim_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_claims_owner ON daily_claims(owner_id, claim_date);

CREATE TABLE IF NOT EXISTS coin_rates (
  currency      TEXT PRIMARY KEY,
  rate_to_mrc   REAL NOT NULL,
  updated_at    TEXT NOT NULL
);
INSERT OR IGNORE INTO coin_rates (currency, rate_to_mrc, updated_at)
VALUES ('EGP', 0.1, '2026-01-01T00:00:00.000Z');

CREATE TABLE IF NOT EXISTS payments (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id          INTEGER NOT NULL,
  org_id           TEXT,
  amount_egp       REAL NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'EGP',
  method           TEXT NOT NULL DEFAULT 'card',
  status           TEXT NOT NULL DEFAULT 'PENDING',
  paymob_order_id  TEXT,
  payment_key      TEXT,
  redirect_url     TEXT,
  phone            TEXT,
  invoice_id       TEXT,
  purpose          TEXT NOT NULL DEFAULT 'topup',
  metadata_json    TEXT,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(paymob_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status, created_at);

CREATE TABLE IF NOT EXISTS pro_subscriptions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  plan         TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'ACTIVE',
  started_at   TEXT NOT NULL,
  expires_at   TEXT NOT NULL,
  payment_id   INTEGER,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pro_subs_user ON pro_subscriptions(user_id, status, expires_at);

CREATE TABLE IF NOT EXISTS inquiries (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  org_id       INTEGER NOT NULL,
  department   TEXT,
  type         TEXT NOT NULL DEFAULT 'general',
  subject      TEXT NOT NULL,
  message      TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'OPEN',
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inquiries_user ON inquiries(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_inquiries_org ON inquiries(org_id, status, created_at);

-- ---------- Ads manager (v1.1) ----------
CREATE TABLE IF NOT EXISTS ad_campaigns (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER NOT NULL,
  name           TEXT NOT NULL,
  objective      TEXT NOT NULL DEFAULT 'awareness',
  placement      TEXT NOT NULL DEFAULT 'feed',
  status         TEXT NOT NULL DEFAULT 'DRAFT',
  budget_coins   REAL NOT NULL DEFAULT 0,
  funded_coins   REAL NOT NULL DEFAULT 0,
  spent_coins    REAL NOT NULL DEFAULT 0,
  currency       TEXT NOT NULL DEFAULT 'MRC',
  start_at       TEXT,
  end_at         TEXT,
  targeting_json TEXT NOT NULL DEFAULT '{}',
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_user ON ad_campaigns(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_status ON ad_campaigns(status, placement, start_at, end_at);

CREATE TABLE IF NOT EXISTS ad_creatives (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id INTEGER NOT NULL,
  title       TEXT NOT NULL,
  body        TEXT,
  media_url   TEXT,
  media_type  TEXT NOT NULL DEFAULT 'image',
  cta_label   TEXT,
  cta_url     TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_creatives_campaign ON ad_creatives(campaign_id, sort_order);

CREATE TABLE IF NOT EXISTS ad_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id  INTEGER NOT NULL,
  creative_id  INTEGER,
  user_id      INTEGER NOT NULL,
  type         TEXT NOT NULL,
  cost_coins   REAL NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ad_events_campaign ON ad_events(campaign_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_events_user ON ad_events(user_id, campaign_id, type, created_at);
CREATE INDEX IF NOT EXISTS idx_ad_events_type ON ad_events(type, created_at);

CREATE TABLE IF NOT EXISTS entity_markets (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type    TEXT NOT NULL,
  entity_id      TEXT NOT NULL,
  symbol         TEXT NOT NULL,
  name           TEXT NOT NULL,
  owner_id       INTEGER,
  price_mrc      REAL NOT NULL DEFAULT 100,
  previous_close REAL NOT NULL DEFAULT 100,
  supply         INTEGER NOT NULL DEFAULT 100000,
  impact_score   REAL NOT NULL DEFAULT 0,
  volume_mrc     REAL NOT NULL DEFAULT 0,
  trade_count    INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  UNIQUE(entity_type, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_entity_markets_type ON entity_markets(entity_type, status);
CREATE TABLE IF NOT EXISTS market_holdings (
  id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, market_id INTEGER NOT NULL,
  shares INTEGER NOT NULL DEFAULT 0, avg_cost REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
  UNIQUE(user_id, market_id)
);
CREATE TABLE IF NOT EXISTS market_trades (
  id INTEGER PRIMARY KEY AUTOINCREMENT, market_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
  side TEXT NOT NULL, shares INTEGER NOT NULL, price_mrc REAL NOT NULL, gross_mrc REAL NOT NULL,
  fee_mrc REAL NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS market_price_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT, market_id INTEGER NOT NULL, price_mrc REAL NOT NULL, at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS news_articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT, author_id INTEGER NOT NULL, outlet_id INTEGER NOT NULL,
  title TEXT NOT NULL, slug TEXT, summary TEXT, body TEXT NOT NULL, cover_url TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT', verification_status TEXT NOT NULL DEFAULT 'PENDING',
  verified_by INTEGER, verified_at TEXT, data_snapshot_json TEXT,
  funding_goal_mrc REAL NOT NULL DEFAULT 0, funding_raised_mrc REAL NOT NULL DEFAULT 0,
  mrc_earned REAL NOT NULL DEFAULT 0, views INTEGER NOT NULL DEFAULT 0,
  rating_avg REAL NOT NULL DEFAULT 0, rating_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS news_funding (
  id INTEGER PRIMARY KEY AUTOINCREMENT, article_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
  amount_mrc REAL NOT NULL, fee_mrc REAL NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS news_ratings (
  id INTEGER PRIMARY KEY AUTOINCREMENT, article_id INTEGER NOT NULL, user_id INTEGER NOT NULL,
  stars INTEGER NOT NULL, created_at TEXT NOT NULL, UNIQUE(article_id, user_id)
);
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
-- Real vs demo accounts, share aggregation, invoices, manual MRC payments and call rooms.
ALTER TABLE users ADD COLUMN is_demo INTEGER NOT NULL DEFAULT 0;
UPDATE users SET is_demo=1 WHERE signup_method='seed';

CREATE TABLE IF NOT EXISTS post_shares (
  post_id    INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_post_shares_user ON post_shares(user_id, created_at);

CREATE TABLE IF NOT EXISTS invoices (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  number         TEXT UNIQUE,
  user_id        INTEGER NOT NULL,
  kind           TEXT NOT NULL,
  description    TEXT,
  amount_mrc     REAL NOT NULL DEFAULT 0,
  amount_egp     REAL NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'ISSUED',
  reference_type TEXT,
  reference_id   TEXT,
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_invoices_user ON invoices(user_id, created_at);

CREATE TABLE IF NOT EXISTS wallet_payment_requests (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  kind        TEXT NOT NULL,
  amount_mrc  REAL NOT NULL,
  amount_egp  REAL NOT NULL,
  method      TEXT NOT NULL DEFAULT 'MANUAL',
  account_ref TEXT,
  status      TEXT NOT NULL DEFAULT 'PENDING',
  admin_note  TEXT,
  invoice_id  INTEGER,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_wallet_requests_user ON wallet_payment_requests(user_id, created_at);

CREATE TABLE IF NOT EXISTS call_rooms (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  code             TEXT NOT NULL UNIQUE,
  host_id          INTEGER NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  scheduled_at     TEXT,
  started_at       TEXT,
  ended_at         TEXT,
  status           TEXT NOT NULL DEFAULT 'SCHEDULED',
  entity_type      TEXT,
  entity_id        INTEGER,
  reward_mrc       REAL NOT NULL DEFAULT 0,
  max_participants INTEGER NOT NULL DEFAULT 2,
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_call_rooms_host ON call_rooms(host_id, scheduled_at);

CREATE TABLE IF NOT EXISTS call_participants (
  room_id     INTEGER NOT NULL,
  user_id     INTEGER NOT NULL,
  role        TEXT NOT NULL DEFAULT 'GUEST',
  joined_at   TEXT NOT NULL,
  left_at     TEXT,
  reward_paid INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS call_signals (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id     INTEGER NOT NULL,
  from_user   INTEGER NOT NULL,
  to_user     INTEGER NOT NULL,
  type        TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_call_signals_target ON call_signals(room_id, to_user, id);

CREATE TABLE IF NOT EXISTS pulse_surveys (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  slug          TEXT NOT NULL UNIQUE,
  trigger       TEXT NOT NULL DEFAULT 'home',
  title         TEXT NOT NULL,
  question      TEXT NOT NULL,
  options_json  TEXT NOT NULL,
  reward_mrc    REAL NOT NULL DEFAULT 5,
  active        INTEGER NOT NULL DEFAULT 1,
  priority      INTEGER NOT NULL DEFAULT 0,
  cooldown_days INTEGER NOT NULL DEFAULT 7,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_pulse_surveys_active ON pulse_surveys(active, priority, id);

CREATE TABLE IF NOT EXISTS pulse_survey_responses (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  survey_id   INTEGER NOT NULL,
  user_id     INTEGER NOT NULL,
  answer      TEXT NOT NULL,
  reward_mrc  REAL NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  UNIQUE (survey_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_pulse_responses_user ON pulse_survey_responses(user_id, created_at);

INSERT OR IGNORE INTO pulse_surveys
  (slug, trigger, title, question, options_json, reward_mrc, active, priority, cooldown_days, created_at)
VALUES
  ('impact_intent', 'home', 'Your next move',
   'What would make MASAREEN most useful for you this week?',
   '["Discover verified impact","Find opportunities","Follow entities and people","Share my own work"]',
   5, 1, 30, 7, datetime('now')),
  ('event_interest', 'events', 'Shape the next gathering',
   'Which kind of MASAREEN event should we prioritize next?',
   '["Field impact visits","Career and opportunity fairs","Policy and government dialogues","Media and newsroom sessions"]',
   5, 1, 20, 14, datetime('now')),
  ('feed_quality', 'feed', 'Make the feed better',
   'What should the MASAREEN feed show more of?',
   '["Verified field evidence","Opportunities and grants","Entity updates","Learning and courses"]',
   3, 1, 10, 14, datetime('now'));

-- Professional newsroom, universal reactions, automatic rankings and research review.
ALTER TABLE content_reactions ADD COLUMN reaction TEXT NOT NULL DEFAULT 'like';

ALTER TABLE news_articles ADD COLUMN source_name TEXT;
ALTER TABLE news_articles ADD COLUMN source_url TEXT;
ALTER TABLE news_articles ADD COLUMN image_url TEXT;
ALTER TABLE news_articles ADD COLUMN video_url TEXT;
ALTER TABLE news_articles ADD COLUMN published_at TEXT;
ALTER TABLE news_articles ADD COLUMN journalist_id INTEGER;
ALTER TABLE news_articles ADD COLUMN impact_score REAL NOT NULL DEFAULT 0;
ALTER TABLE news_articles ADD COLUMN impact_domain TEXT;
ALTER TABLE news_articles ADD COLUMN auto_generated INTEGER NOT NULL DEFAULT 0;
ALTER TABLE news_articles ADD COLUMN verification_note TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_news_source_url
  ON news_articles(source_url) WHERE source_url IS NOT NULL;

CREATE TABLE IF NOT EXISTS journalists (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  name                TEXT NOT NULL,
  slug                TEXT,
  outlet_id           INTEGER,
  outlet_name         TEXT,
  title               TEXT,
  bio                 TEXT,
  avatar_url          TEXT,
  specialties_json    TEXT NOT NULL DEFAULT '[]',
  verified            INTEGER NOT NULL DEFAULT 0,
  verification_source TEXT,
  articles_count      INTEGER NOT NULL DEFAULT 0,
  impact_score        REAL NOT NULL DEFAULT 0,
  claimed_by          INTEGER,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  UNIQUE (name, outlet_id)
);
CREATE INDEX IF NOT EXISTS idx_journalists_outlet ON journalists(outlet_id, name);

CREATE TABLE IF NOT EXISTS news_article_media (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  type       TEXT NOT NULL DEFAULT 'PHOTO',
  url        TEXT NOT NULL,
  caption    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_news_media_article ON news_article_media(article_id, id);

CREATE TABLE IF NOT EXISTS news_verifications (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  article_id    INTEGER NOT NULL,
  reviewer_id   INTEGER NOT NULL,
  verdict        TEXT NOT NULL,
  notes         TEXT,
  confidence    REAL NOT NULL DEFAULT 0,
  impact_points REAL NOT NULL DEFAULT 0,
  reward_mrc    REAL NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  UNIQUE (article_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_news_verifications_article ON news_verifications(article_id, created_at);

CREATE TABLE IF NOT EXISTS feed_sources (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  slug           TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  homepage       TEXT NOT NULL,
  rss_url        TEXT NOT NULL UNIQUE,
  logo_url       TEXT,
  active         INTEGER NOT NULL DEFAULT 1,
  last_synced_at TEXT,
  last_error     TEXT,
  created_at     TEXT NOT NULL
);

INSERT OR IGNORE INTO feed_sources
  (slug, name, homepage, rss_url, active, created_at) VALUES
  ('dailynewsegypt', 'Daily News Egypt', 'https://dailynewsegypt.com',
   'https://dailynewsegypt.com/feed/', 1, datetime('now')),
  ('egyptindependent', 'Egypt Independent', 'https://www.egyptindependent.com',
   'https://www.egyptindependent.com/feed/', 1, datetime('now')),
  ('enterprise', 'Enterprise', 'https://enterprise.news',
   'https://enterprise.news/feed/', 1, datetime('now')),
  ('youm7', 'Youm7', 'https://www.youm7.com',
   'https://www.youm7.com/rss/SectionRss?SectionID=65', 0, datetime('now')),
  ('almasryalyoum', 'Al-Masry Al-Youm', 'https://www.almasryalyoum.com',
   'https://www.almasryalyoum.com/rss/rssfeed', 1, datetime('now'));

ALTER TABLE opportunities ADD COLUMN auto_generated INTEGER NOT NULL DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN source_type TEXT;
ALTER TABLE opportunities ADD COLUMN source_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_opportunities_source
  ON opportunities(source_type, source_id)
  WHERE source_type IS NOT NULL AND source_id IS NOT NULL;

ALTER TABLE research_stages ADD COLUMN abstract TEXT;
ALTER TABLE research_stages ADD COLUMN keywords_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE research_stages ADD COLUMN authors_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE research_stages ADD COLUMN methodology TEXT;
ALTER TABLE research_stages ADD COLUMN expected_impact TEXT;
ALTER TABLE research_stages ADD COLUMN funding_goal_mrc REAL NOT NULL DEFAULT 0;
ALTER TABLE research_stages ADD COLUMN funding_raised_mrc REAL NOT NULL DEFAULT 0;
ALTER TABLE research_stages ADD COLUMN peer_review_status TEXT NOT NULL DEFAULT 'OPEN';
ALTER TABLE research_stages ADD COLUMN open_for_review INTEGER NOT NULL DEFAULT 1;
ALTER TABLE research_stages ADD COLUMN published_at TEXT;
ALTER TABLE research_stages ADD COLUMN doi TEXT;
ALTER TABLE research_stages ADD COLUMN impact_score REAL NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS research_reviews (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id      INTEGER NOT NULL,
  reviewer_id   INTEGER NOT NULL,
  verdict       TEXT NOT NULL,
  comments      TEXT,
  score         REAL NOT NULL DEFAULT 0,
  reward_mrc    REAL NOT NULL DEFAULT 0,
  impact_points REAL NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  UNIQUE (stage_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_research_reviews_stage ON research_reviews(stage_id, created_at);

CREATE TABLE IF NOT EXISTS research_funding (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id   INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  amount_mrc REAL NOT NULL,
  fee_mrc    REAL NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS research_authors (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id     INTEGER NOT NULL,
  user_id      INTEGER,
  name         TEXT NOT NULL,
  role_title   TEXT,
  affiliation  TEXT,
  author_order INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_research_authors_stage ON research_authors(stage_id, author_order);

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  scope         TEXT NOT NULL,
  period        TEXT NOT NULL,
  metric        TEXT NOT NULL,
  rankings_json TEXT NOT NULL,
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_leaderboard_snapshots_scope
  ON leaderboard_snapshots(scope, period, created_at);
-- Platform-level roles assigned by existing admins.
ALTER TABLE users ADD COLUMN platform_role TEXT;
CREATE INDEX IF NOT EXISTS idx_users_platform_role ON users(platform_role);

-- Entity-specific impact frameworks and weights.
CREATE TABLE IF NOT EXISTS impact_frameworks (
  entity_type    TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  description    TEXT,
  indicators_json TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

INSERT OR REPLACE INTO impact_frameworks
  (entity_type,title,description,indicators_json,updated_at) VALUES
  ('NEWS','News impact','Accuracy, verification and public value.',
   '[{"key":"verification","label":"Verification","weight":0.35,"source":"news_verifications","unit":"verified reviews"},{"key":"reach","label":"Reach","weight":0.20,"source":"views","unit":"views"},{"key":"engagement","label":"Engagement","weight":0.25,"source":"content_reactions/content_comments","unit":"reactions + comments"},{"key":"quality","label":"Quality","weight":0.20,"source":"news_ratings","unit":"reader ratings"}]',datetime('now')),
  ('JOURNALIST','Journalist impact','Verified reporting and trusted reach.',
   '[{"key":"verified_stories","label":"Verified stories","weight":0.35,"source":"news_articles.verification_status","unit":"stories"},{"key":"impact","label":"Story impact","weight":0.30,"source":"news_articles.impact_score","unit":"points"},{"key":"output","label":"Output","weight":0.20,"source":"news_articles","unit":"published stories"},{"key":"trust","label":"Trust","weight":0.15,"source":"verification verdicts","unit":"verified share"}]',datetime('now')),
  ('RESEARCH','Research impact','Evidence, review and uptake.',
   '[{"key":"peer_review","label":"Peer review","weight":0.35,"source":"research_reviews","unit":"review points"},{"key":"funding","label":"Funding","weight":0.25,"source":"research_funding","unit":"MRC"},{"key":"engagement","label":"Engagement","weight":0.20,"source":"content reactions/comments","unit":"signals"},{"key":"publication","label":"Publication","weight":0.20,"source":"peer_review_status","unit":"accepted stages"}]',datetime('now')),
  ('AGRICULTURE','Agricultural impact','Adoption, resilience and resource use.',
   '[{"key":"yield","label":"Yield change","weight":0.25,"source":"field evidence","unit":"%"},{"key":"water","label":"Water saved","weight":0.20,"source":"field evidence","unit":"m3"},{"key":"adoption","label":"Adoption","weight":0.20,"source":"projects/training","unit":"farmers"},{"key":"training","label":"Training","weight":0.15,"source":"courses/rooms","unit":"trained people"},{"key":"resilience","label":"Resilience","weight":0.20,"source":"verified evidence","unit":"score"}]',datetime('now')),
  ('TRAINING','Training impact','Completion, application and reach.',
   '[{"key":"completion","label":"Completion","weight":0.30,"source":"track/course progress","unit":"% completed"},{"key":"assessment","label":"Assessment","weight":0.25,"source":"assessment score","unit":"score"},{"key":"application","label":"Applied evidence","weight":0.25,"source":"evidence","unit":"verified application"},{"key":"reach","label":"Reach","weight":0.20,"source":"participants","unit":"people"}]',datetime('now')),
  ('STUDENT','Student impact','Learning, evidence and contribution.',
   '[{"key":"skills","label":"Skills","weight":0.25,"source":"pathways/courses","unit":"completion"},{"key":"evidence","label":"Evidence","weight":0.30,"source":"verified evidence","unit":"items"},{"key":"participation","label":"Participation","weight":0.20,"source":"events/projects","unit":"activities"},{"key":"opportunity","label":"Opportunity readiness","weight":0.25,"source":"applications/passport","unit":"progress"}]',datetime('now')),
  ('ORGANIZATION','Organisation impact','Delivery, transparency and ecosystem value.',
   '[{"key":"projects","label":"Verified projects","weight":0.25,"source":"projects","unit":"projects"},{"key":"beneficiaries","label":"Beneficiaries","weight":0.20,"source":"project/event metrics","unit":"people"},{"key":"evidence","label":"Evidence coverage","weight":0.20,"source":"evidence","unit":"verified items"},{"key":"funding","label":"Funding","weight":0.15,"source":"funding","unit":"MRC"},{"key":"transparency","label":"Transparency","weight":0.20,"source":"reports/profile","unit":"score"}]',datetime('now')),
  ('EVENT','Event impact','Convening, evidence and outcomes.',
   '[{"key":"attendance","label":"Attendance","weight":0.25,"source":"event attendance","unit":"people"},{"key":"evidence","label":"Evidence","weight":0.25,"source":"event evidence","unit":"verified items"},{"key":"funding","label":"Funding","weight":0.20,"source":"event funding","unit":"MRC"},{"key":"rating","label":"Experience","weight":0.15,"source":"event ratings","unit":"stars"},{"key":"follow_on","label":"Follow-on action","weight":0.15,"source":"opportunities/content","unit":"outcomes"}]',datetime('now'));