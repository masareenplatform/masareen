-- V008: Device push-token registration
-- Enables real push delivery at scale (handoff gap S-002 6.3). Tokens are
-- stored verbatim (opaque FCM/APNs credentials) and upserted per user+token.

CREATE TABLE IF NOT EXISTS device_tokens (
    id           VARCHAR(36) PRIMARY KEY,
    user_id      VARCHAR(64) NOT NULL,
    device_token  TEXT NOT NULL,
    platform     VARCHAR(16) NOT NULL DEFAULT 'android',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_user_tok
    ON device_tokens(user_id, device_token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user
    ON device_tokens(user_id);
