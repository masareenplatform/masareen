"""Media Asset entity — manages upload slots, CDN delivery, processing."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from ..events.media_events import MediaUploaded
from shared.exceptions import ValidationException

ALLOWED_MIME_TYPES = {
    "image/jpeg", "image/png", "image/webp", "image/heic",
    "video/mp4", "video/quicktime", "video/webm",
    "audio/mpeg", "audio/wav", "audio/ogg",
    "application/pdf",
}

MAX_PHOTO_BYTES  = 20 * 1024 * 1024   # 20 MB
MAX_VIDEO_BYTES  = 500 * 1024 * 1024  # 500 MB
MAX_AUDIO_BYTES  = 50 * 1024 * 1024   # 50 MB


class ProcessingStatus(str, Enum):
    PENDING    = "PENDING"
    PROCESSING = "PROCESSING"
    READY      = "READY"
    FAILED     = "FAILED"


@dataclass
class MediaAsset(AggregateRoot):
    """Media asset aggregate root — manages upload slots, CDN delivery, processing."""
    owner_id:          str                  = ""
    evidence_id:       Optional[str]        = None
    mime_type:         str                  = ""
    file_size_bytes:   int                  = 0
    original_filename: Optional[str]        = None
    storage_key:       Optional[str]        = None
    cdn_url:           Optional[str]        = None
    thumbnail_url:     Optional[str]        = None
    processing_status: ProcessingStatus     = ProcessingStatus.PENDING
    checksum_sha256:   Optional[str]        = None
    width:             Optional[int]         = None
    height:            Optional[int]         = None
    duration_seconds:  Optional[float]      = None
    metadata:          dict                 = field(default_factory=dict)

    @classmethod
    def create_upload_slot(cls, owner_id: str, mime_type: str, file_size_bytes: int,
                           evidence_id: Optional[str]=None, original_filename: Optional[str]=None) -> "MediaAsset":
        if mime_type not in ALLOWED_MIME_TYPES:
            raise ValidationException(f"MIME type '{mime_type}' is not allowed.")
        if mime_type.startswith("image/") and file_size_bytes > MAX_PHOTO_BYTES:
            raise ValidationException(f"Photo exceeds 20MB limit.")
        if mime_type.startswith("video/") and file_size_bytes > MAX_VIDEO_BYTES:
            raise ValidationException(f"Video exceeds 500MB limit.")
        now = datetime.now(timezone.utc)
        asset = cls(id=str(uuid4()), owner_id=owner_id, mime_type=mime_type,
                    file_size_bytes=file_size_bytes, evidence_id=evidence_id,
                    original_filename=original_filename,
                    processing_status=ProcessingStatus.PENDING,
                    created_at=now, updated_at=now)
        asset.add_domain_event(MediaUploaded(
            aggregate_id=asset.id, media_asset_id=asset.id,
            media_type=mime_type, file_size_bytes=file_size_bytes))
        return asset

    def mark_uploaded(self, storage_key: str, checksum: str) -> None:
        self.storage_key      = storage_key
        self.checksum_sha256  = checksum
        self.processing_status = ProcessingStatus.PROCESSING
        self.updated_at       = datetime.now(timezone.utc)
        self.add_domain_event(MediaUploaded(
            aggregate_id=self.id, media_asset_id=self.id,
            media_type=self.mime_type, file_size_bytes=self.file_size_bytes,
            storage_key=storage_key, checksum=checksum))

    def mark_ready(self, cdn_url: str, thumbnail_url: Optional[str]=None,
                   width: Optional[int]=None, height: Optional[int]=None,
                   duration_seconds: Optional[float]=None) -> None:
        self.cdn_url           = cdn_url
        self.thumbnail_url     = thumbnail_url
        self.width, self.height = width, height
        self.duration_seconds  = duration_seconds
        self.processing_status = ProcessingStatus.READY
        self.updated_at        = datetime.now(timezone.utc)

    def mark_failed(self, reason: str) -> None:
        self.processing_status = ProcessingStatus.FAILED
        self.metadata["failure_reason"] = reason
        self.updated_at = datetime.now(timezone.utc)
