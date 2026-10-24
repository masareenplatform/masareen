"""Evidence aggregate, manages the lifecycle of field evidence."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.events.verification_events import EvidenceCaptured, EvidenceUploaded, EvidenceVerified, ImpactAssetCreated
from shared.exceptions import ValidationException, ConflictException


class EvidenceStatus(str, Enum):
    CAPTURED    = "CAPTURED"
    UPLOADING   = "UPLOADING"
    UPLOADED    = "UPLOADED"
    PENDING     = "PENDING"
    IN_REVIEW   = "IN_REVIEW"
    APPROVED    = "APPROVED"
    REJECTED    = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"


class MediaType(str, Enum):
    PHOTO     = "PHOTO"
    VIDEO     = "VIDEO"
    AUDIO     = "AUDIO"
    DOCUMENT  = "DOCUMENT"
    GPS_TRACK = "GPS_TRACK"


@dataclass
class VerificationRecord:
    verifier_type:    str       # AI | HUMAN | HYBRID
    verifier_id:      Optional[str]
    verdict:          str
    confidence:       float
    notes:            Optional[str]
    verified_at:      datetime


@dataclass
class Evidence(AggregateRoot):
    task_id:         str                       = ""
    submitted_by:    str                       = ""
    media_type:      MediaType                 = MediaType.PHOTO
    status:          EvidenceStatus            = EvidenceStatus.CAPTURED
    storage_url:     Optional[str]             = None
    thumbnail_url:   Optional[str]             = None
    file_size_bytes: int                       = 0
    checksum:        Optional[str]             = None
    mime_type:       Optional[str]             = None
    latitude:        Optional[float]           = None
    longitude:       Optional[float]           = None
    captured_at:     Optional[datetime]        = None
    uploaded_at:     Optional[datetime]        = None
    verifications:   List[VerificationRecord]  = field(default_factory=list)
    metadata:        dict                      = field(default_factory=dict)

    @classmethod
    def capture(cls, task_id: str, submitted_by: str, media_type: str,
                file_size_bytes: int, mime_type: Optional[str] = None,
                latitude: Optional[float] = None, longitude: Optional[float] = None) -> "Evidence":
        if not task_id: raise ValidationException("task_id is required.")
        if not submitted_by: raise ValidationException("submitted_by is required.")
        now = datetime.now(timezone.utc)
        ev = cls(id=str(uuid4()), task_id=task_id, submitted_by=submitted_by,
                 media_type=MediaType(media_type), status=EvidenceStatus.CAPTURED,
                 file_size_bytes=file_size_bytes, mime_type=mime_type,
                 latitude=latitude, longitude=longitude,
                 captured_at=now, created_at=now, updated_at=now)
        ev.add_domain_event(EvidenceCaptured(
            aggregate_id=ev.id, task_id=task_id, user_id=submitted_by,
            media_type=media_type, file_size_bytes=file_size_bytes))
        return ev

    def mark_uploaded(self, storage_url: str, checksum: str, thumbnail_url: Optional[str] = None) -> None:
        if not storage_url: raise ValidationException("storage_url is required.")
        self.storage_url   = storage_url
        self.checksum      = checksum
        self.thumbnail_url = thumbnail_url
        self.status        = EvidenceStatus.UPLOADED
        self.uploaded_at   = datetime.now(timezone.utc)
        self.updated_at    = self.uploaded_at
        self.add_domain_event(EvidenceUploaded(
            aggregate_id=self.id, storage_url=storage_url, checksum=checksum))

    def submit_for_review(self) -> None:
        if self.status != EvidenceStatus.UPLOADED:
            raise ConflictException("Evidence must be UPLOADED before submission for review.")
        self.status = EvidenceStatus.PENDING
        self.updated_at = datetime.now(timezone.utc)

    def start_review(self) -> None:
        self.status = EvidenceStatus.IN_REVIEW
        self.updated_at = datetime.now(timezone.utc)

    def record_verification(self, verifier_type: str, verdict: str, confidence: float,
                            verifier_id: Optional[str] = None, notes: Optional[str] = None) -> None:
        record = VerificationRecord(verifier_type=verifier_type, verifier_id=verifier_id,
            verdict=verdict, confidence=confidence, notes=notes,
            verified_at=datetime.now(timezone.utc))
        self.verifications.append(record)

        if verdict == "APPROVED":
            self.status = EvidenceStatus.APPROVED
        elif verdict == "REJECTED":
            self.status = EvidenceStatus.REJECTED
        elif verdict == "NEEDS_REVISION":
            self.status = EvidenceStatus.NEEDS_REVISION
        self.updated_at = datetime.now(timezone.utc)

        self.add_domain_event(EvidenceVerified(
            aggregate_id=self.id, verifier_type=verifier_type,
            confidence_score=confidence, verdict=verdict))

    @property
    def is_approved(self) -> bool:
        return self.status == EvidenceStatus.APPROVED

    @property
    def latest_verdict(self) -> Optional[str]:
        if not self.verifications: return None
        return self.verifications[-1].verdict
