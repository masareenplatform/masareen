-- MASAREN Ads manager, campaigns, creatives, coin-funded delivery ledger
-- Migration V013
-- Campaigns are funded in MASAREN Coin (MRC). Delivery is accumulated per day so
-- spend never exceeds the campaign budget (the repository auto-pauses at zero).

CREATE TABLE IF NOT EXISTS ad_campaigns (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id     UUID NOT NULL,
    name         VARCHAR(200) NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    budget_coins DECIMAL(18,4) NOT NULL DEFAULT 0,
    spent_coins  DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency     VARCHAR(8) NOT NULL DEFAULT 'MRC',
    targeting    JSONB DEFAULT '{}',
    start_date   DATE,
    end_date     DATE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ad_creatives (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES ad_campaigns(id) ON DELETE CASCADE,
    title       VARCHAR(200) NOT NULL,
    body        TEXT NOT NULL,
    media_url   TEXT,
    cta_url     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ad_delivery (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES ad_campaigns(id) ON DELETE CASCADE,
    date        DATE NOT NULL DEFAULT CURRENT_DATE,
    impressions INTEGER NOT NULL DEFAULT 0,
    clicks      INTEGER NOT NULL DEFAULT 0,
    spent_coins DECIMAL(18,4) NOT NULL DEFAULT 0,
    UNIQUE (campaign_id, date)
);

CREATE INDEX IF NOT EXISTS idx_ad_campaigns_owner ON ad_campaigns(owner_id);
CREATE INDEX IF NOT EXISTS idx_ad_creatives_campaign ON ad_creatives(campaign_id);
