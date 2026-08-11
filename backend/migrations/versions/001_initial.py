"""Initial schema — outbox_events and evidence_drafts.

Revision ID: 001_initial
Revises: None
Create Date: 2026-07-25
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Outbox events table
    op.create_table(
        "outbox_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("event_type", sa.String(255), nullable=False),
        sa.Column("aggregate_id", sa.String(255), nullable=False),
        sa.Column("aggregate_type", sa.String(255), nullable=False),
        sa.Column("topic", sa.String(255), nullable=False),
        sa.Column("payload", sa.JSON, nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("error", sa.String(1000), nullable=True),
    )
    op.create_index("ix_outbox_status", "outbox_events", ["status"])
    op.create_index("ix_outbox_created_at", "outbox_events", ["created_at"])

    # Evidence drafts table (offline sync)
    op.create_table(
        "evidence_drafts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("post_id", sa.String(255), nullable=True),
        sa.Column("media_type", sa.String(50), nullable=False),
        sa.Column("file_path", sa.String(1000), nullable=True),
        sa.Column("local_path", sa.String(1000), nullable=True),
        sa.Column("file_size_bytes", sa.Integer, nullable=True),
        sa.Column("mime_type", sa.String(100), nullable=True),
        sa.Column("metadata_json", sa.JSON, nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("retry_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column("max_retries", sa.Integer, nullable=False, server_default="3"),
        sa.Column("error_message", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_evidence_drafts_user_id", "evidence_drafts", ["user_id"])
    op.create_index("ix_evidence_drafts_status", "evidence_drafts", ["status"])


def downgrade() -> None:
    op.drop_table("evidence_drafts")
    op.drop_table("outbox_events")
