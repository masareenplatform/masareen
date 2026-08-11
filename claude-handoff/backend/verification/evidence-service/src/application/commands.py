"""Evidence Application Commands - Use cases with validation and business logic."""
from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Command


@dataclass
class CaptureEvidenceCommand(Command):
    """Command to capture new evidence from field work."""
    task_id: str
    submitted_by: str
    media_type: str
    file_size_bytes: int
    mime_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@dataclass
class MarkEvidenceUploadedCommand(Command):
    """Command to mark evidence as uploaded."""
    evidence_id: str
    storage_url: str
    checksum: str
    thumbnail_url: Optional[str] = None


@dataclass
class SubmitEvidenceForReviewCommand(Command):
    """Command to submit evidence for review."""
    evidence_id: str
    submitted_by: str


@dataclass
class RecordVerificationCommand(Command):
    """Command to record verification results."""
    evidence_id: str
    verifier_type: str
    verdict: str
    confidence: float
    verifier_id: Optional[str] = None
    notes: Optional[str] = None
