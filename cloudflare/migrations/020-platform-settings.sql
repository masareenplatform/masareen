-- Admin-editable platform settings. OTA release values live here so admins and
-- AI agents can publish a new build without redeploying the Worker.
CREATE TABLE IF NOT EXISTS platform_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TEXT NOT NULL,
  updated_by INTEGER
);
