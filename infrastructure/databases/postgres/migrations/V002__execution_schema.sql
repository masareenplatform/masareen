-- MASAREN Execution Schema
-- Migration V002

CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(255) UNIQUE NOT NULL,
    org_type        VARCHAR(100) NOT NULL,
    country         VARCHAR(100),
    verified        BOOLEAN DEFAULT FALSE,
    oii_score       DECIMAL(5,4) DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata        JSONB DEFAULT '{}'
);

CREATE TABLE programs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    title           VARCHAR(500) NOT NULL,
    description     TEXT,
    status          VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
    start_date      DATE,
    end_date        DATE,
    sdg_goals       INTEGER[],
    location        GEOGRAPHY(POINT, 4326),
    country         VARCHAR(100),
    max_participants INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tasks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id      UUID NOT NULL REFERENCES programs(id),
    title           VARCHAR(500) NOT NULL,
    description     TEXT,
    status          VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    assignee_id     UUID REFERENCES users(id),
    supervisor_id   UUID REFERENCES users(id),
    due_date        TIMESTAMPTZ,
    location        GEOGRAPHY(POINT, 4326),
    geofence_radius INTEGER DEFAULT 500,
    evidence_required BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_program ON tasks(program_id);
CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX idx_programs_org ON programs(organization_id);

-- Workflow Templates
CREATE TABLE workflow_templates (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    program_id  UUID REFERENCES programs(id) ON DELETE SET NULL,
    steps       JSONB NOT NULL DEFAULT '[]',
    created_by  UUID REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Workflow Instances
CREATE TABLE workflow_instances (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id     UUID NOT NULL REFERENCES workflow_templates(id),
    program_id      UUID NOT NULL REFERENCES programs(id),
    assignee_id     UUID NOT NULL REFERENCES users(id),
    status          VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
    steps           JSONB NOT NULL DEFAULT '[]',
    completed_steps TEXT[] DEFAULT '{}',
    metadata        JSONB DEFAULT '{}',
    progress        DECIMAL(5,1) DEFAULT 0.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_instances_program   ON workflow_instances(program_id);
CREATE INDEX idx_workflow_instances_assignee  ON workflow_instances(assignee_id);
CREATE INDEX idx_workflow_instances_status    ON workflow_instances(status);

-- Program enrollments
CREATE TABLE program_enrollments (
    program_id   UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    enrolled_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status       VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (program_id, user_id)
);

-- Organization memberships
CREATE TABLE organization_members (
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
    role            VARCHAR(50) NOT NULL DEFAULT 'MEMBER',
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, user_id)
);
