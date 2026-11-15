-- Entity verification + creation pricing.
-- Existing rows are grandfathered as approved. New rows created by members
-- start as PENDING and are reviewed by the platform team.
ALTER TABLE courses ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'APPROVED';
ALTER TABLE courses ADD COLUMN rejection_reason TEXT;
ALTER TABLE courses ADD COLUMN reviewed_at TEXT;
ALTER TABLE courses ADD COLUMN reviewed_by INTEGER;
ALTER TABLE courses ADD COLUMN creation_fee_mrc REAL NOT NULL DEFAULT 0;

ALTER TABLE events ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'APPROVED';
ALTER TABLE events ADD COLUMN rejection_reason TEXT;
ALTER TABLE events ADD COLUMN reviewed_at TEXT;
ALTER TABLE events ADD COLUMN reviewed_by INTEGER;
ALTER TABLE events ADD COLUMN creation_fee_mrc REAL NOT NULL DEFAULT 0;

ALTER TABLE programs ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'APPROVED';
ALTER TABLE programs ADD COLUMN rejection_reason TEXT;
ALTER TABLE programs ADD COLUMN reviewed_at TEXT;
ALTER TABLE programs ADD COLUMN reviewed_by INTEGER;
ALTER TABLE programs ADD COLUMN creation_fee_mrc REAL NOT NULL DEFAULT 0;

ALTER TABLE projects ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'APPROVED';
ALTER TABLE projects ADD COLUMN rejection_reason TEXT;
ALTER TABLE projects ADD COLUMN reviewed_at TEXT;
ALTER TABLE projects ADD COLUMN reviewed_by INTEGER;
ALTER TABLE projects ADD COLUMN creation_fee_mrc REAL NOT NULL DEFAULT 0;

ALTER TABLE opportunities ADD COLUMN verification_status TEXT NOT NULL DEFAULT 'APPROVED';
ALTER TABLE opportunities ADD COLUMN rejection_reason TEXT;
ALTER TABLE opportunities ADD COLUMN reviewed_at TEXT;
ALTER TABLE opportunities ADD COLUMN reviewed_by INTEGER;
ALTER TABLE opportunities ADD COLUMN creation_fee_mrc REAL NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_courses_verification ON courses(verification_status);
CREATE INDEX IF NOT EXISTS idx_events_verification ON events(verification_status);
CREATE INDEX IF NOT EXISTS idx_programs_verification ON programs(verification_status);
CREATE INDEX IF NOT EXISTS idx_projects_verification ON projects(verification_status);
CREATE INDEX IF NOT EXISTS idx_opportunities_verification ON opportunities(verification_status);
