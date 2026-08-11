"""GPS Command Interfaces - Use cases with validation and business logic."""
from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Command


@dataclass
class CaptureGPSCommand(Command):
    """Command to capture GPS location from field work."""
    task_id: str
    submitted_by: str
    media_type: str
    file_size_bytes: int
    mime_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


@dataclass
class MarkGPSUploadedCommand(Command):
    """Command to mark GPS record as uploaded."""
    gps_id: str
    storage_url: str
    checksum: str
    thumbnail_url: Optional[str] = None


@dataclass
class SubmitGPSForReviewCommand(Command):
    """Command to submit GPS record for review."""
    gps_id: str
    submitted_by: str


@dataclass
class RecordGPSVerificationCommand(Command):
    """Command to record GPS verification results."""
    gps_id: str
    verifier_type: str
    verdict: str
    confidence: float
    verifier_id: Optional[str] = None
    notes: Optional[str] = None