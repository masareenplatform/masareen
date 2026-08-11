-- V009: Paid-tier gating for impact reports (handoff gap S-002 6.4)
-- Real billing integration: a report is marked paid only after a real payment
-- intent is created in the payment-service local ledger.

ALTER TABLE impact_reports ADD COLUMN IF NOT EXISTS is_paid BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE impact_reports ADD COLUMN IF NOT EXISTS paid_payment_id UUID;
ALTER TABLE impact_reports ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
