-- MASAREN platform brokerage / revenue
-- Migration V014
-- A single, tweakable brokerage rate and an append-only ledger of every fee the
-- platform collects (coin conversions, transfers, PSP payments, ads). Profit is
-- therefore always auditable and the rate can be changed by an admin at runtime.

CREATE TABLE IF NOT EXISTS platform_config (
    key          VARCHAR(32) PRIMARY KEY,
    value_numeric DECIMAL(18,6),
    value_text   VARCHAR(64),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS platform_revenue (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_service VARCHAR(32) NOT NULL,   -- coin | payment | ads | transfer
    currency       VARCHAR(8) NOT NULL,     -- MRC | EGP
    amount         DECIMAL(18,4) NOT NULL,
    reference      VARCHAR(255),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Default brokerage: 2.5% on every monetisable action.
INSERT INTO platform_config (key, value_numeric)
VALUES ('platform_fee_rate', 0.025)
ON CONFLICT (key) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_platform_revenue_created ON platform_revenue(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_revenue_source ON platform_revenue(source_service);
