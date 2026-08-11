-- V007: Chat service schema
-- Conversational assistant persistence. No fabricated content: assistant replies
-- are stored verbatim from the configured LLM (or an honest "unavailable" note).

CREATE TABLE IF NOT EXISTS chat_conversations (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(64) NOT NULL,
    title       VARCHAR(200) NOT NULL DEFAULT 'New conversation',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id               VARCHAR(36) PRIMARY KEY,
    conversation_id  VARCHAR(36) NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    role             VARCHAR(16) NOT NULL,
    content          TEXT NOT NULL,
    context_type     VARCHAR(32),
    context_id       VARCHAR(64),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_user ON chat_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_updated ON chat_conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages(conversation_id, created_at);
