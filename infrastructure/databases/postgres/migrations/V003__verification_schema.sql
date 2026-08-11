-- MASAREN Verification Schema
-- Migration V003

CREATE TABLE evidence (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id         UUID NOT NULL REFERENCES tasks(id),
    submitted_by    UUID NOT NULL REFERENCES users(id),
    media_type      VARCHAR(50) NOT NULL,
    storage_url     VARCHAR(1000),
    file_size_bytes BIGINT,
    checksum        VARCHAR(255),
    status          VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    uploaded_at     TIMESTAMPTZ,
    location        GEOGRAPHY(POINT, 4326),
    metadata        JSONB DEFAULT '{}'
);

CREATE TABLE verifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    evidence_id     UUID NOT NULL REFERENCES evidence(id),
    verifier_type   VARCHAR(50) NOT NULL,
    verifier_id     UUID,
    verdict         VARCHAR(50) NOT NULL,
    confidence      DECIMAL(4,3),
    notes           TEXT,
    verified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE gps_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    task_id         UUID REFERENCES tasks(id),
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    accuracy_meters DECIMAL(8,2),
    altitude        DECIMAL(8,2),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE impact_assets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    task_id         UUID REFERENCES tasks(id),
    asset_type      VARCHAR(100) NOT NULL,
    title           VARCHAR(500),
    description     TEXT,
    sdg_tags        INTEGER[],
    evidence_ids    UUID[],
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    blockchain_hash VARCHAR(255)
);

CREATE INDEX idx_evidence_task ON evidence(task_id);
CREATE INDEX idx_gps_user_time ON gps_records(user_id, recorded_at DESC);
CREATE INDEX idx_gps_location ON gps_records USING GIST(location);

-- Verification pipelines
CREATE TABLE verification_pipelines (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    evidence_id         UUID NOT NULL REFERENCES evidence(id),
    task_id             UUID NOT NULL REFERENCES tasks(id),
    submitted_by        UUID NOT NULL REFERENCES users(id),
    status              VARCHAR(50) NOT NULL DEFAULT 'QUEUED',
    stages              JSONB NOT NULL DEFAULT '[]',
    fraud_risk_score    INTEGER DEFAULT 0,
    final_verdict       VARCHAR(50),
    assigned_reviewer   UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pipelines_evidence ON verification_pipelines(evidence_id);
CREATE INDEX idx_pipelines_status   ON verification_pipelines(status);
CREATE INDEX idx_pipelines_reviewer ON verification_pipelines(assigned_reviewer) WHERE assigned_reviewer IS NOT NULL;

-- Media assets
CREATE TABLE media_assets (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id            UUID NOT NULL REFERENCES users(id),
    evidence_id         UUID REFERENCES evidence(id),
    mime_type           VARCHAR(100) NOT NULL,
    file_size_bytes     BIGINT NOT NULL,
    original_filename   VARCHAR(500),
    storage_key         VARCHAR(1000),
    cdn_url             VARCHAR(1000),
    thumbnail_url       VARCHAR(1000),
    processing_status   VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    checksum_sha256     VARCHAR(64),
    width               INTEGER,
    height              INTEGER,
    duration_seconds    DECIMAL(8,2),
    metadata            JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_media_owner    ON media_assets(owner_id);
CREATE INDEX idx_media_evidence ON media_assets(evidence_id);
CREATE INDEX idx_media_checksum ON media_assets(checksum_sha256);
