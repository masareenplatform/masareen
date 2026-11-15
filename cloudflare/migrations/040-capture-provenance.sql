-- Capture provenance: camera-captured media carries more trust than gallery
-- uploads; GPS can strengthen or weaken the signal.
ALTER TABLE posts ADD COLUMN capture_source TEXT NOT NULL DEFAULT 'UNKNOWN';
ALTER TABLE posts ADD COLUMN capture_trust REAL NOT NULL DEFAULT 0;
ALTER TABLE evidence ADD COLUMN capture_source TEXT NOT NULL DEFAULT 'UNKNOWN';
ALTER TABLE evidence ADD COLUMN capture_trust REAL NOT NULL DEFAULT 0;
