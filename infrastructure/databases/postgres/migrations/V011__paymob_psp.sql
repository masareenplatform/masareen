-- MASAREN Payments ledger extension for multi-PSP (Paymob / Vodafone Cash)
-- Migration V011
-- Adds currency + PSP provider + stable external reference so a single ledger row
-- can represent a Stripe, Paymob (card/wallet) or Vodafone Cash transaction without
-- conflating the PSP intent id with the local payment_method_id.

ALTER TABLE payments ADD COLUMN IF NOT EXISTS currency VARCHAR(8) NOT NULL DEFAULT 'USD';
ALTER TABLE payments ADD COLUMN IF NOT EXISTS psp_provider VARCHAR(32);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS external_ref VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_payments_external_ref ON payments(external_ref);
CREATE INDEX IF NOT EXISTS idx_payments_psp_provider ON payments(psp_provider);
