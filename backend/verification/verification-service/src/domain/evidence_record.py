"""Evidence Record aggregate for multi-stage verification pipeline."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4

from shared.base_entity import AggregateRoot
from shared.events.verification_events import (
    EvidenceVerified, ImpactAssetCreated,
    EvidenceCaptured,
)
from shared.exceptions import ValidationException, ConflictException


class EvidenceStatus(str, Enum):
    PENDING = "PENDING"
    CAPTURED = "CAPTURED"
    UPLOADED = "UPLOADED"
    UNDER_REVIEW = "UNDER_REVIEW"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"


class FinalVerdict(str, Enum):
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    NEEDS_REVIEW = "NEEDS_REVIEW"


@dataclass
class EvidenceRecord(AggregateRoot):
    evidence_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    status: EvidenceStatus = EvidenceStatus.PENDING
    media_type: str = ""
    file_size_bytes: int = 0
    storage_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    checksum: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    captured_at: Optional[datetime] = None
    uploaded_at: Optional[datetime] = None
    ai_confidence_score: float = 0.0
    fraud_risk_score: int = 0
    fraud_risk_details: Optional[str] = None
    verifier_type: Optional[str] = None
    verified_at: Optional[datetime] = None
    final_verdict: Optional[FinalVerdict] = None
    confidence_score: float = 0.0
    notes: Optional[str] = None
    assigned_reviewer: Optional[str] = None
    metadata: dict = field(default_factory=dict)
    # Industrial Metrics
    spatial_accuracy: float = 0.0 # 0.0 to 1.0
    temporal_consistency: float = 0.0 # 0.0 to 1.0
    metadata_integrity: float = 0.0 # 0.0 to 1.0

    @classmethod
    def capture(cls, task_id: str, submitted_by: str, media_type: str,
                file_size_bytes: int, latitude: Optional[float] = None,
                longitude: Optional[float] = None) -> "EvidenceRecord":
        if not task_id:
            raise ValidationException("task_id is required")
        if not submitted_by:
            raise ValidationException("submitted_by is required")
        now = datetime.now(timezone.utc)
        record = cls(
            id=str(uuid4()),
            evidence_id=str(uuid4()),
            task_id=task_id,
            submitted_by=submitted_by,
            status=EvidenceStatus.CAPTURED,
            media_type=media_type,
            file_size_bytes=file_size_bytes,
            latitude=latitude,
            longitude=longitude,
            captured_at=now,
            created_at=now,
            updated_at=now,
        )
        record.add_domain_event(EvidenceCaptured(
            aggregate_id=record.id, task_id=task_id, user_id=submitted_by,
            media_type=media_type, file_size_bytes=file_size_bytes,
        ))
        return record

    def mark_uploaded(self, storage_url: str, checksum: str,
                      thumbnail_url: Optional[str] = None) -> None:
        self.storage_url = storage_url
        self.checksum = checksum
        self.thumbnail_url = thumbnail_url
        self.status = EvidenceStatus.UPLOADED
        self.uploaded_at = datetime.now(timezone.utc)
        self.updated_at = self.uploaded_at

    def record_ai_result(self, verdict: str, confidence: float) -> None:
        self.ai_confidence_score = confidence
        self.updated_at = datetime.now(timezone.utc)

    def assign_reviewer(self, reviewer_id: str) -> None:
        self.assigned_reviewer = reviewer_id
        self.updated_at = datetime.now(timezone.utc)

    def start_human_review(self) -> None:
        self.status = EvidenceStatus.UNDER_REVIEW
        self.updated_at = datetime.now(timezone.utc)

    def record_human_verdict(self, verdict: str, reviewer_id: str,
                             confidence: float, notes: Optional[str] = None) -> None:
        self.final_verdict = FinalVerdict(verdict)
        self.confidence_score = confidence
        self.notes = notes
        self.verifier_type = "HUMAN"
        self.verified_at = datetime.now(timezone.utc)
        self.status = EvidenceStatus.APPROVED if verdict == "APPROVED" else EvidenceStatus.REJECTED
        self.updated_at = self.verified_at
        self.add_domain_event(EvidenceVerified(
            aggregate_id=self.id, verifier_type="HUMAN",
            confidence_score=confidence, verdict=verdict,
        ))

    def submit(self, evidence_id: str) -> None:
        self.status = EvidenceStatus.UNDER_REVIEW
        self.updated_at = datetime.now(timezone.utc)
