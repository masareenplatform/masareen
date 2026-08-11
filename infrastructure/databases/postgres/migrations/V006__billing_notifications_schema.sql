-- MASAREN Billing & Notifications Schema
-- Migration V006
-- Real persistence for billing (invoices/line items), payments (local ledger),
-- subscriptions, and notifications. No fabricated ids or payment intents.

CREATE TABLE IF NOT EXISTS invoices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    currency        VARCHAR(8) NOT NULL DEFAULT 'USD',
    subtotal        DECIMAL(14,2) NOT NULL DEFAULT 0,
    tax_rate        DECIMAL(5,4) NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(14,2) NOT NULL DEFAULT 0,
    total           DECIMAL(14,2) NOT NULL DEFAULT 0,
    due_date        DATE,
    paid_at         TIMESTAMPTZ,
    period_start    DATE,
    period_end      DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS invoice_line_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id      UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description     VARCHAR(500) NOT NULL,
    quantity        DECIMAL(14,4) NOT NULL,
    unit_price      DECIMAL(14,4) NOT NULL,
    total           DECIMAL(14,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id      UUID REFERENCES invoices(id) ON DELETE SET NULL,
    organization_id UUID NOT NULL,
    amount_usd      DECIMAL(14,2) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'CAPTURED',
    payment_method_id VARCHAR(255),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS subscriptions (
    organization_id UUID PRIMARY KEY,
    plan            VARCHAR(20) NOT NULL DEFAULT 'FREE',
    billing_email   VARCHAR(255),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL,
    channel         VARCHAR(20) NOT NULL,
    title           VARCHAR(500) NOT NULL,
    body            TEXT NOT NULL,
    data            JSONB DEFAULT '{}',
    status          VARCHAR(20) NOT NULL DEFAULT 'QUEUED',
    read            BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at         TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id         UUID PRIMARY KEY,
    push            BOOLEAN NOT NULL DEFAULT TRUE,
    email           BOOLEAN NOT NULL DEFAULT TRUE,
    sms             BOOLEAN NOT NULL DEFAULT FALSE,
    in_app          BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_org ON invoices(organization_id);
CREATE INDEX IF NOT EXISTS idx_payments_org ON payments(organization_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
