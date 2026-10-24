"""Submission bundle aggregate root, orchestrates evidence submission and pipeline creation."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.events.submission_events import SubmissionCreated, SubmissionSubmitted, PipelineCreated, BundleRejected
from shared.exceptions import ValidationException, ConflictException


class BundleStatus(str, Enum):
    DRAFT = "DRAFT"
    VALIDATED = "VALIDATED"
    SUBMITTED = "SUBMITTED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    COMPLETED = "COMPLETED"
    REJECTED = "REJECTED"


@dataclass
class EvidenceItem:
    evidence_id: str
    media_type: str
    file_size_bytes: int
    checksum: str
    storage_url: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@dataclass
class GpsLocation:
    latitude: float
    longitude: float
    accuracy_meters: float = 0.0
    provider: str = "GPS"

    @property
    def is_valid_for_task(self) -> bool:
        return not (self.latitude == 0.0 and self.longitude == 0.0)

    @property
    def is_low_accuracy(self) -> bool:
        return self.accuracy_meters > 100


@dataclass
class SubmissionBundle(AggregateRoot):
    task_id: str = ""
    submitted_by: str = ""
    status: BundleStatus = BundleStatus.DRAFT
    evidence_items: List[EvidenceItem] = field(default_factory=list)
    gps_locations: List[GpsLocation] = field(default_factory=list)
    approval_score: Optional[float] = None
    rejection_reason: Optional[str] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    submitted_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    @classmethod
    def create(cls, task_id: str, submitted_by: str, evidence_items: List[EvidenceItem],
               gps_locations: Optional[List[GpsLocation]] = None) -> "SubmissionBundle":
        if not task_id: raise ValidationException("task_id is required.")
        if not submitted_by: raise ValidationException("submitted_by is required.")
        if not evidence_items: raise ValidationException("at least one evidence item is required.")

        now = datetime.now(timezone.utc)
        bundle = cls(
            id=str(uuid4()),
            task_id=task_id,
            submitted_by=submitted_by,
            evidence_items=evidence_items,
            gps_locations=gps_locations or [],
            created_at=now,
            submitted_at=now
        )
        bundle.add_domain_event(SubmissionCreated(
            aggregate_id=bundle.id,
            task_id=task_id,
            submitted_by=submitted_by,
            evidence_count=len(evidence_items)
        ))
        return bundle

    def validate_bundle(self) -> None:
        if self.status != BundleStatus.DRAFT:
            raise ConflictException("Can only validate bundles in DRAFT status.")
        self.validate_evidence()
        self.validate_gis_completeness()
        self.calculate_approval_score()
        self.status = BundleStatus.VALIDATED
        self.updated_at = datetime.now(timezone.utc)

    def validate_evidence(self) -> None:
        for item in self.evidence_items:
            if not item.evidence_id: raise ValidationException("Evidence ID is required.")
            if not item.checksum: raise ValidationException("Checksum is required.")
            if not item.storage_url: raise ValidationException("Storage URL is required.")

    def validate_gis_completeness(self) -> None:
        for location in self.gps_locations:
            if not (-90 <= location.latitude <= 90):
                raise ValidationException(f"Invalid latitude: {location.latitude}")
            if not (-180 <= location.longitude <= 180):
                raise ValidationException(f"Invalid longitude: {location.longitude}")

    def calculate_approval_score(self) -> None:
        if not self.gps_locations:
            self.approval_score = 0.5
            return

        total_score = 0.0
        for location in self.gps_locations:
            location_score = 1.0
            if location.accuracy_meters > 100:
                location_score *= 0.7
            if not location.is_valid_for_task:
                location_score *= 0.5
            total_score += location_score

        self.approval_score = total_score / len(self.gps_locations)

    def submit(self) -> None:
        if self.status != BundleStatus.VALIDATED:
            raise ConflictException("Can only submit validated bundles.")
        self.status = BundleStatus.SUBMITTED
        self.submitted_at = datetime.now(timezone.utc)
        self.updated_at = self.submitted_at
        self.add_domain_event(SubmissionSubmitted(
            aggregate_id=self.id,
            task_id=self.task_id,
            submitted_by=self.submitted_by,
            approval_score=self.approval_score,
            evidence_count=len(self.evidence_items)
        ))

    def create_verification_pipeline(self) -> None:
        if self.status != BundleStatus.SUBMITTED:
            raise ConflictException("Can only create pipeline for submitted bundles.")
        self.status = BundleStatus.PENDING_VERIFICATION
        self.updated_at = datetime.now(timezone.utc)
        self.add_domain_event(PipelineCreated(
            aggregate_id=self.id,
            task_id=self.task_id,
            submitted_by=self.submitted_by,
            evidence_items=[{
                "evidence_id": item.evidence_id,
                "media_type": item.media_type,
                "file_size_bytes": item.file_size_bytes,
                "checksum": item.checksum
            } for item in self.evidence_items]
        ))

    def reject(self, reason: str) -> None:
        if self.status == BundleStatus.REJECTED:
            return
        self.status = BundleStatus.REJECTED
        self.rejection_reason = reason
        self.updated_at = datetime.now(timezone.utc)
        self.add_domain_event(BundleRejected(
            aggregate_id=self.id,
            task_id=self.task_id,
            submitted_by=self.submitted_by,
            rejection_reason=reason
        ))

    @property
    def is_submit_eligible(self) -> bool:
        return self.status == BundleStatus.VALIDATED

    @property
    def can_create_pipeline(self) -> bool:
        return self.status == BundleStatus.SUBMITTED
