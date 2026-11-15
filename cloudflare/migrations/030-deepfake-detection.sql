-- Free local deepfake / AI-generated content detection integrated with verification.
ALTER TABLE posts ADD COLUMN deepfake_score REAL NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED';
ALTER TABLE posts ADD COLUMN deepfake_signals_json TEXT;

ALTER TABLE evidence ADD COLUMN description TEXT;
ALTER TABLE evidence ADD COLUMN location_label TEXT;
ALTER TABLE evidence ADD COLUMN media_json TEXT;
ALTER TABLE evidence ADD COLUMN files_json TEXT;
ALTER TABLE evidence ADD COLUMN source_name TEXT;
ALTER TABLE evidence ADD COLUMN witnesses_json TEXT;
ALTER TABLE evidence ADD COLUMN metadata_json TEXT;
ALTER TABLE evidence ADD COLUMN deepfake_score REAL NOT NULL DEFAULT 0;
ALTER TABLE evidence ADD COLUMN deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED';
ALTER TABLE evidence ADD COLUMN deepfake_signals_json TEXT;

ALTER TABLE submissions ADD COLUMN deepfake_score REAL NOT NULL DEFAULT 0;
ALTER TABLE submissions ADD COLUMN deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED';
ALTER TABLE submissions ADD COLUMN deepfake_signals_json TEXT;

ALTER TABLE event_participants ADD COLUMN deepfake_score REAL NOT NULL DEFAULT 0;
ALTER TABLE event_participants ADD COLUMN deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED';
ALTER TABLE event_participants ADD COLUMN deepfake_signals_json TEXT;

ALTER TABLE verification_pipelines ADD COLUMN deepfake_score REAL NOT NULL DEFAULT 0;
ALTER TABLE verification_pipelines ADD COLUMN deepfake_verdict TEXT NOT NULL DEFAULT 'UNSCANNED';

CREATE INDEX IF NOT EXISTS idx_posts_deepfake ON posts(deepfake_verdict, deepfake_score);
CREATE INDEX IF NOT EXISTS idx_evidence_deepfake ON evidence(deepfake_verdict, deepfake_score);

ALTER TABLE evidence ADD COLUMN target_type TEXT NOT NULL DEFAULT 'GENERAL';
ALTER TABLE evidence ADD COLUMN target_id TEXT;
ALTER TABLE evidence ADD COLUMN claim TEXT;
ALTER TABLE evidence ADD COLUMN fields_json TEXT;
ALTER TABLE submissions ADD COLUMN target_type TEXT NOT NULL DEFAULT 'GENERAL';
ALTER TABLE submissions ADD COLUMN target_id TEXT;
