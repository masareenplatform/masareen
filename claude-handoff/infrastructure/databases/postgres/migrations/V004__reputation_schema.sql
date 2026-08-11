-- MASAREN Reputation Schema
-- Migration V004

CREATE TABLE pms_scores (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    composite_score DECIMAL(6,4) DEFAULT 0,
    dimensions      JSONB NOT NULL DEFAULT '{}',
    version         INTEGER NOT NULL DEFAULT 0,
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE pms_dimension_weights (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dimension_key   VARCHAR(100) NOT NULL UNIQUE,
    weight          DECIMAL(5,4) NOT NULL,
    description     TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default weights
INSERT INTO pms_dimension_weights (dimension_key, weight, description) VALUES
    ('reliability', 0.15, 'Shows up consistently'),
    ('execution_quality', 0.15, 'Quality of completed work'),
    ('leadership', 0.10, 'Leads others effectively'),
    ('documentation_quality', 0.10, 'Evidence documentation quality'),
    ('verification_confidence', 0.15, 'AI/human confidence in their work'),
    ('learning_velocity', 0.08, 'Rate of skill acquisition'),
    ('technical_skills', 0.10, 'Domain-specific technical competence'),
    ('innovation', 0.07, 'Novel approaches and solutions'),
    ('consistency', 0.05, 'Regular, sustained participation'),
    ('community_impact', 0.05, 'Measurable community outcomes');

CREATE TABLE oii_scores (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    composite_index DECIMAL(6,4) DEFAULT 0,
    dimensions      JSONB NOT NULL DEFAULT '{}',
    version         INTEGER NOT NULL DEFAULT 0,
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Opportunities
CREATE TABLE opportunities (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id     UUID NOT NULL REFERENCES organizations(id),
    title               VARCHAR(500) NOT NULL,
    opp_type            VARCHAR(50) NOT NULL,
    status              VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
    description         TEXT,
    country             VARCHAR(100),
    city                VARCHAR(100),
    remote              BOOLEAN DEFAULT FALSE,
    min_pms_score       DECIMAL(5,4) DEFAULT 0,
    required_skills     TEXT[],
    required_sdgs       INTEGER[],
    compensation_usd    DECIMAL(10,2),
    deadline            DATE,
    max_applicants      INTEGER,
    applicant_count     INTEGER DEFAULT 0,
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_opp_org    ON opportunities(organization_id);
CREATE INDEX idx_opp_type   ON opportunities(opp_type);
CREATE INDEX idx_opp_status ON opportunities(status);
CREATE INDEX idx_opp_pms    ON opportunities(min_pms_score);

-- Applications
CREATE TABLE opportunity_applications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    opportunity_id  UUID NOT NULL REFERENCES opportunities(id),
    applicant_id    UUID NOT NULL REFERENCES users(id),
    status          VARCHAR(50) NOT NULL DEFAULT 'SUBMITTED',
    match_score     DECIMAL(5,3),
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (opportunity_id, applicant_id)
);

-- NOTE: The `invoices` and `invoice_line_items` tables are owned by the billing
-- domain and are defined in V006__billing_notifications_schema.sql (which also
-- carries the `updated_at` column the billing repository relies on). They were
-- previously duplicated here, which — because V004 runs first — shadowed the
-- complete V006 definition and broke `UPDATE ... SET updated_at`. Removed to keep
-- a single source of truth.

-- Impact reports
CREATE TABLE impact_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_type     VARCHAR(100) NOT NULL,
    status          VARCHAR(50) NOT NULL DEFAULT 'QUEUED',
    entity_id       UUID NOT NULL,
    entity_type     VARCHAR(50) NOT NULL,
    title           VARCHAR(500) NOT NULL,
    executive_summary TEXT,
    sections        JSONB DEFAULT '[]',
    sdg_indicators  JSONB DEFAULT '[]',
    metrics         JSONB DEFAULT '{}',
    pdf_url         VARCHAR(1000),
    period_start    DATE,
    period_end      DATE,
    requested_by    UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
