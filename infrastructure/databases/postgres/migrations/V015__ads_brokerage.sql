-- MASAREN Ads brokerage, platform cut on campaign funding
-- Migration V015
-- When an advertiser funds a campaign in MASAREN Coin (MRC), the platform takes a
-- configurable brokerage cut (see platform_config.platform_fee_rate). The advertiser's
-- deliverable budget is the gross minus that fee; the fee itself is recorded in
-- platform_revenue (source = 'ads') so profit is always auditable.

ALTER TABLE ad_campaigns
    ADD COLUMN IF NOT EXISTS platform_fee_coins DECIMAL(18,4) NOT NULL DEFAULT 0;
