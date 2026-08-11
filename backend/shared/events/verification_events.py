"""Verification domain event contracts."""
from dataclasses import dataclass, field
from typing import Optional, List
from . import DomainEvent


@dataclass
class LocationReached(DomainEvent):
    event_type: str = "LocationReached"
    aggregate_type: str = "GPSRecord"
    user_id: str = ""
    task_id: str = ""
    latitude: float = 0.0
    longitude: float = 0.0
    accuracy_meters: float = 0.0


@dataclass
class EvidenceCaptured(DomainEvent):
    event_type: str = "EvidenceCaptured"
    aggregate_type: str = "Evidence"
    task_id: str = ""
    user_id: str = ""
    media_type: str = ""  # photo, video, document, audio
    file_size_bytes: int = 0


@dataclass
class EvidenceUploaded(DomainEvent):
    event_type: str = "EvidenceUploaded"
    aggregate_type: str = "Evidence"
    storage_url: str = ""
    checksum: str = ""


@dataclass
class EvidenceVerified(DomainEvent):
    event_type: str = "EvidenceVerified"
    aggregate_type: str = "Evidence"
    verifier_type: str = ""  # AI, HUMAN, HYBRID
    confidence_score: float = 0.0
    verdict: str = ""  # APPROVED, REJECTED, NEEDS_REVIEW


@dataclass
class ImpactAssetCreated(DomainEvent):
    event_type: str = "ImpactAssetCreated"
    aggregate_type: str = "ImpactAsset"
    user_id: str = ""
    task_id: str = ""
    asset_type: str = ""
    sdg_tags: Optional[List[str]] = field(default_factory=list)

    def __post_init__(self):
        if self.sdg_tags is None:
            self.sdg_tags = []


@dataclass
class PipelineCreated(DomainEvent):
    event_type: str = "PipelineCreated"
    aggregate_type: str = "VerificationPipeline"
    task_id: str = ""
    submitted_by: str = ""
    evidence_items: list = field(default_factory=list)


