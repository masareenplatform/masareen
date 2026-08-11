-- MASAREN Identity Schema
-- Migration V001

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email       VARCHAR(255) UNIQUE NOT NULL,
    phone       VARCHAR(50),
    full_name   VARCHAR(255) NOT NULL,
    role        VARCHAR(50) NOT NULL DEFAULT 'INDIVIDUAL',
    status      VARCHAR(50) NOT NULL DEFAULT 'PENDING_VERIFICATION',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE user_profiles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bio         TEXT,
    avatar_url  VARCHAR(500),
    location    GEOGRAPHY(POINT, 4326),
    country     VARCHAR(100),
    city        VARCHAR(100),
    languages   TEXT[],
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE skills (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255) UNIQUE NOT NULL,
    category    VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_skills (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_id    UUID NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    proficiency VARCHAR(50) DEFAULT 'BEGINNER',
    verified    BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, skill_id)
);

CREATE TABLE certificates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    title           VARCHAR(255) NOT NULL,
    issuer_org_id   UUID,
    program_id      UUID,
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    blockchain_hash VARCHAR(255),
    metadata        JSONB DEFAULT '{}'
);

-- Event Store
CREATE TABLE domain_events (
    event_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type      VARCHAR(255) NOT NULL,
    aggregate_id    UUID NOT NULL,
    aggregate_type  VARCHAR(100) NOT NULL,
    payload         JSONB NOT NULL,
    metadata        JSONB DEFAULT '{}',
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version         INTEGER NOT NULL DEFAULT 1,
    correlation_id  UUID,
    causation_id    UUID
);

CREATE INDEX idx_events_aggregate ON domain_events(aggregate_id, aggregate_type);
CREATE INDEX idx_events_type ON domain_events(event_type);
CREATE INDEX idx_events_occurred ON domain_events(occurred_at DESC);

-- Transactional Outbox Table (shared by all services via schema isolation)
CREATE TABLE outbox_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type      VARCHAR(255) NOT NULL,
    aggregate_id    UUID NOT NULL,
    topic           VARCHAR(255) NOT NULL,
    payload         JSONB NOT NULL,
    published       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ
);

CREATE INDEX idx_outbox_unpublished ON outbox_events(published, created_at)
    WHERE published = FALSE;
