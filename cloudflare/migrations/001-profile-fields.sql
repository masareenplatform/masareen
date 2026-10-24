-- Upgrade an existing MASAREEN D1 database with the richer profile fields.
-- Fresh installs already get these columns from schema.sql, so this file is only
-- needed when the database was created before the role-aware sign-up was added.
--
-- Apply once:
--   npx wrangler d1 execute masareen --remote --file=migrations/001-profile-fields.sql
--
-- SQLite has no "ADD COLUMN IF NOT EXISTS": re-running it reports
-- "duplicate column name", which is safe to ignore.

ALTER TABLE users ADD COLUMN role TEXT;
ALTER TABLE users ADD COLUMN city TEXT;
ALTER TABLE users ADD COLUMN university TEXT;
ALTER TABLE users ADD COLUMN university_id TEXT;
ALTER TABLE users ADD COLUMN department TEXT;
ALTER TABLE users ADD COLUMN academic_year TEXT;
ALTER TABLE users ADD COLUMN degree_level TEXT;
ALTER TABLE users ADD COLUMN employer TEXT;
ALTER TABLE users ADD COLUMN job_title TEXT;

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
