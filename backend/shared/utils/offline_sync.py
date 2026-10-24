"""Offline sync service, local draft queue for evidence capture.

Implements the offline evidence capture and draft-queue pattern from the
MASAREN Technical Architecture (Doc 1, §Offline-Sync):

    1. User captures photo/video/document via camera or gallery
    2. File is stored locally with metadata (not yet uploaded)
    3. A background sync worker uploads drafts when connectivity returns
    4. Server acknowledges receipt; local draft is marked synced or purged

This module provides the sync queue model and helper functions for the
combined backend to receive and process offline-submitted evidence.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, String, JSON, DateTime, Enum as SAEnum, Integer, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from ..base_repository.db import Base


# ── Sync queue status ─────────────────────────────────────────────────────────

class DraftStatus(str, Enum):
    PENDING = "pending"          # captured, waiting for connectivity
    UPLOADING = "uploading"      # background worker is uploading
    UPLOADED = "uploaded"        # server acknowledged receipt
    FAILED = "failed"            # upload failed after retries
    EXPIRED = "expired"          # too old, should be purged


# ── SQLAlchemy model, server-side evidence draft queue ───────────────────────

class EvidenceDraft(Base):
    """Server-side record of an offline-captured evidence item.

    The mobile client POSTs to /api/v1/evidence/drafts when connectivity
    is available. The server stores the metadata and processes the binary
    upload asynchronously.
    """
    __tablename__ = "evidence_drafts"
    __table_args__ = {"extend_existing": True}

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=lambda: uuid4())
    user_id = Column(String(255), nullable=False, index=True)
    post_id = Column(String(255), nullable=True, index=True)
    media_type = Column(String(50), nullable=False)          # PHOTO, VIDEO, DOCUMENT, AUDIO
    file_path = Column(String(1000), nullable=True)          # server storage path after upload
    local_path = Column(String(1000), nullable=True)         # client-side original path
    file_size_bytes = Column(Integer, nullable=True)
    mime_type = Column(String(100), nullable=True)
    metadata_json = Column(JSON, nullable=True)              # EXIF, GPS, timestamps, etc.
    status = Column(SAEnum(DraftStatus), nullable=False, default=DraftStatus.PENDING)
    retry_count = Column(Integer, nullable=False, default=0)
    max_retries = Column(Integer, nullable=False, default=3)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False,
                        server_default=__import__("sqlalchemy").text("NOW()"))
    uploaded_at = Column(DateTime(timezone=True), nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "user_id": self.user_id,
            "post_id": self.post_id,
            "media_type": self.media_type,
            "file_path": self.file_path,
            "file_size_bytes": self.file_size_bytes,
            "mime_type": self.mime_type,
            "status": self.status.value if self.status else DraftStatus.PENDING.value,
            "retry_count": self.retry_count,
            "error_message": self.error_message,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
        }


# ── Data transfer objects ─────────────────────────────────────────────────────

@dataclass
class OfflineDraftDTO:
    """Incoming offline draft from the mobile client."""
    user_id: str = ""
    post_id: Optional[str] = None
    media_type: str = "PHOTO"
    local_path: str = ""
    file_size_bytes: int = 0
    mime_type: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class SyncStatusDTO:
    """Response indicating current sync state for a user."""
    pending_count: int = 0
    uploaded_count: int = 0
    failed_count: int = 0
    last_sync_at: Optional[datetime] = None


# ── Helper functions ──────────────────────────────────────────────────────────

async def register_offline_draft(session, draft: OfflineDraftDTO) -> EvidenceDraft:
    """Register a new offline evidence draft in the server queue."""
    record = EvidenceDraft(
        user_id=draft.user_id,
        post_id=draft.post_id,
        media_type=draft.media_type,
        local_path=draft.local_path,
        file_size_bytes=draft.file_size_bytes,
        mime_type=draft.mime_type,
        metadata_json=draft.metadata,
        status=DraftStatus.PENDING,
    )
    session.add(record)
    await session.flush()
    return record


async def get_user_sync_status(session, user_id: str) -> SyncStatusDTO:
    """Return the sync queue summary for a given user."""
    from sqlalchemy import select, func

    result = await session.execute(
        select(EvidenceDraft).where(EvidenceDraft.user_id == user_id)
    )
    drafts = result.scalars().all()

    pending = sum(1 for d in drafts if d.status == DraftStatus.PENDING)
    uploaded = sum(1 for d in drafts if d.status == DraftStatus.UPLOADED)
    failed = sum(1 for d in drafts if d.status == DraftStatus.FAILED)

    last_sync = None
    for d in drafts:
        if d.uploaded_at and (last_sync is None or d.uploaded_at > last_sync):
            last_sync = d.uploaded_at

    return SyncStatusDTO(
        pending_count=pending,
        uploaded_count=uploaded,
        failed_count=failed,
        last_sync_at=last_sync,
    )


async def mark_draft_uploaded(session, draft_id: UUID) -> None:
    """Mark an evidence draft as successfully uploaded."""
    from sqlalchemy import update
    await session.execute(
        update(EvidenceDraft)
        .where(EvidenceDraft.id == draft_id)
        .values(
            status=DraftStatus.UPLOADED,
            uploaded_at=datetime.now(timezone.utc),
        )
    )


async def mark_draft_failed(session, draft_id: UUID, error: str) -> None:
    """Mark an evidence draft as failed and increment retry count."""
    from sqlalchemy import update
    await session.execute(
        update(EvidenceDraft)
        .where(EvidenceDraft.id == draft_id)
        .values(
            error_message=error,
            retry_count=EvidenceDraft.retry_count + 1,
        )
    )


async def get_pending_drafts(session, limit: int = 50) -> List[EvidenceDraft]:
    """Fetch pending drafts for background upload processing."""
    from sqlalchemy import select
    result = await session.execute(
        select(EvidenceDraft)
        .where(EvidenceDraft.status == DraftStatus.PENDING)
        .order_by(EvidenceDraft.created_at)
        .limit(limit)
    )
    return list(result.scalars().all())
