-- Lightweight, rate-limited EMA surveys with fixed MRC rewards.
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
