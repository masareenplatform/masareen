-- Follows graph (social following between users).
CREATE TABLE IF NOT EXISTS follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON follows(followee_id);
