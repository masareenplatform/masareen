-- MASAREN Verification Domain — Complete Extension
-- Migration V005
-- Adds tables and columns needed by verification services but missing from V003

BEGIN;

-- 1. submission_bundles
CREATE TABLE IF NOT EXISTS submission_bundles (
    id UUID PRIMARY KEY,
    task_id VARCHAR(255) NOT NULL,
    submitted_by VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
    evidence_items JSONB DEFAULT '[]',
    gps_locations JSONB DEFAULT '[]',
    approval_score DECIMAL(5,2),
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. audit_records
CREATE TABLE IF NOT EXISTS audit_records (
    id UUID PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    actor_id VARCHAR(255) DEFAULT '',
    action VARCHAR(100) NOT NULL,
    details JSONB DEFAULT '{}',
    source_service VARCHAR(100) DEFAULT '',
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_aggregate ON audit_records(aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_records(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_records(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_records(created_at DESC);

-- 3. evidence_records (separate table for the verification service)
CREATE TABLE IF NOT EXISTS evidence_records (
    id UUID PRIMARY KEY,
    evidence_id VARCHAR(255),
    task_id VARCHAR(255) NOT NULL,
    submitted_by VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'CAPTURED',
    media_type VARCHAR(100),
    file_size_bytes BIGINT DEFAULT 0,
    storage_url TEXT,
    thumbnail_url TEXT,
    checksum VARCHAR(255),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    accuracy_meters DECIMAL(10,2),
    captured_at TIMESTAMPTZ,
    uploaded_at TIMESTAMPTZ,
    ai_confidence_score DECIMAL(5,4),
    fraud_risk_score INTEGER DEFAULT 0,
    fraud_risk_details TEXT,
    verifier_type VARCHAR(50),
    verified_at TIMESTAMPTZ,
    final_verdict VARCHAR(50),
    confidence_score DECIMAL(5,4),
    notes TEXT,
    assigned_reviewer VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_evidence_records_task ON evidence_records(task_id);
CREATE INDEX IF NOT EXISTS idx_evidence_records_status ON evidence_records(status);
CREATE INDEX IF NOT EXISTS idx_evidence_records_checksum ON evidence_records(checksum);

-- 4. gps_records — add missing columns
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS gps_id VARCHAR(255);
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS media_type VARCHAR(50);
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100);
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT DEFAULT 0;
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS storage_url TEXT;
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS checksum VARCHAR(255);
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'CAPTURED';
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS verifications JSONB DEFAULT '[]';
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS submitted_by VARCHAR(255);
ALTER TABLE gps_records ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 5. verification_pipelines — add missing columns
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS pipeline_id VARCHAR(255);
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS evidence_id_new VARCHAR(255);
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS submitted_by_new VARCHAR(255);
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS ai_confidence_threshold DECIMAL(5,4) DEFAULT 0.8;
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS fraud_risk_threshold INTEGER DEFAULT 30;
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS ai_confidence_score DECIMAL(5,4);
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS human_verdict VARCHAR(50);
ALTER TABLE verification_pipelines ADD COLUMN IF NOT EXISTS fraud_risk_details TEXT;

COMMIT;
