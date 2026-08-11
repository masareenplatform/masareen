-- Collaborations: companies/startups hosting services on MASAREN infrastructure.
CREATE TABLE IF NOT EXISTS collaborations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name        TEXT NOT NULL,
    contact_email       TEXT NOT NULL,
    website             TEXT,
    service_name        TEXT NOT NULL,
    service_description TEXT NOT NULL,
    desired_tier        TEXT NOT NULL DEFAULT 'SANDBOX',
    expected_load       TEXT,
    message             TEXT,
    status              TEXT NOT NULL DEFAULT 'SUBMITTED'
                          CHECK (status IN ('SUBMITTED','APPROVED','REJECTED','PROVISIONED')),
    reviewer_id         TEXT,
    review_notes        TEXT,
    reviewed_at         TIMESTAMPTZ,
    provisioned_by      TEXT,
    endpoint            TEXT,
    provisioned_at      TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_collaborations_status ON collaborations (status);
CREATE INDEX IF NOT EXISTS ix_collaborations_created ON collaborations (created_at DESC);
