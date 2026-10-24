-- MASAREN Coin (MRC), in-app token wallet, immutable ledger, EGP exchange
-- Migration V012
-- A single authoritative coin per owner, an append-only transaction ledger so any
-- balance is reconstructable, and admin-managed fiat (EGP) exchange rates. All
-- balance changes are transactional; no fabricated balances.

CREATE TABLE IF NOT EXISTS wallets (
    owner_id    UUID PRIMARY KEY,
    balance     DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency    VARCHAR(8) NOT NULL DEFAULT 'MRC',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coin_transactions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id      UUID NOT NULL,
    counterparty_id UUID,
    type          VARCHAR(20) NOT NULL,   -- EARN, SPEND, TRANSFER_OUT, TRANSFER_IN, DEPOSIT, WITHDRAW
    amount        DECIMAL(18,4) NOT NULL,
    balance_after DECIMAL(18,4) NOT NULL,
    reference     VARCHAR(255),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coin_exchange_rates (
    currency     VARCHAR(8) PRIMARY KEY,   -- e.g. EGP
    rate_to_mrc  DECIMAL(18,6) NOT NULL,   -- 1 unit of currency = rate_to_mrc MRC
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed a sensible default: 1 EGP = 10 MRC (overridable via the admin rate endpoint).
INSERT INTO coin_exchange_rates (currency, rate_to_mrc)
VALUES ('EGP', 10.0)
ON CONFLICT (currency) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_coin_tx_owner ON coin_transactions(owner_id);
CREATE INDEX IF NOT EXISTS idx_coin_tx_created ON coin_transactions(created_at DESC);
