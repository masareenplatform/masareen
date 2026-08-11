"""GPS Domain Aggregates and Entities."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from math import asin, cos, radians, sin, sqrt
from typing import List, NamedTuple, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.events.verification_events import LocationReached
from shared.exceptions import ConflictException, ValidationException

LOW_ACCURACY_THRESHOLD_M = 100.0
EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Haversine distance between two GPS coordinates in kilometres."""
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    return EARTH_RADIUS_KM * 2 * asin(sqrt(a))


class GeofenceResult(NamedTuple):
    inside: bool
    distance_meters: float


class GPSRecordStatus(str, Enum):
    CAPTURED = "CAPTURED"
    VALIDATING = "VALIDATING"
    VALIDATED = "VALIDATED"
    LOW_ACCURACY = "LOW_ACCURACY"
    CONFLICTED = "CONFLICTED"
    REJECTED = "REJECTED"


class MediaType(str, Enum):
    PHOTO = "PHOTO"
    VIDEO = "VIDEO"
    AUDIO = "AUDIO"
    DOCUMENT = "DOCUMENT"
    GPS_TRACK = "GPS_TRACK"


@dataclass
class VerificationRecord:
    verifier_type: str
    verifier_id: Optional[str]
    verdict: str
    confidence: float
    notes: Optional[str]
    verified_at: datetime


@dataclass
class GPSRecord(AggregateRoot):
    gps_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    media_type: MediaType = MediaType.PHOTO
    status: GPSRecordStatus = GPSRecordStatus.CAPTURED
    mime_type: Optional[str] = None
    storage_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    file_size_bytes: int = 0
    checksum: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy_meters: float = 0.0
    captured_at: Optional[datetime] = None
    uploaded_at: Optional[datetime] = None
    verifications: List[VerificationRecord] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)

    @classmethod
    def capture(cls, task_id: str, submitted_by: str, media_type: str,
                file_size_bytes: int, mime_type: Optional[str] = None,
                latitude: Optional[float] = None, longitude: Optional[float] = None,
                accuracy_meters: float = 0.0) -> "GPSRecord":
        if not task_id: raise ValidationException("task_id is required.")
        if not submitted_by: raise ValidationException("submitted_by is required.")
        if latitude is not None and not (-90 <= latitude <= 90):
            raise ValidationException("latitude must be between -90 and 90.")
        if longitude is not None and not (-180 <= longitude <= 180):
            raise ValidationException("longitude must be between -180 and 180.")
        if latitude is not None and longitude is not None and latitude == 0.0 and longitude == 0.0:
            raise ValidationException("Null Island (0, 0) is not a valid GPS location.")
        if accuracy_meters < 0:
            raise ValidationException("accuracy_meters cannot be negative.")
        now = datetime.now(timezone.utc)
        ev = cls(id=str(uuid4()), gps_id=str(uuid4()), task_id=task_id, submitted_by=submitted_by,
                 media_type=MediaType(media_type), status=GPSRecordStatus.CAPTURED,
                 file_size_bytes=file_size_bytes, mime_type=mime_type,
                 latitude=latitude, longitude=longitude, accuracy_meters=accuracy_meters,
                 captured_at=now, created_at=now, updated_at=now)
        ev.add_domain_event(LocationReached(
            aggregate_id=ev.id, task_id=task_id, user_id=submitted_by,
            latitude=latitude or 0.0, longitude=longitude or 0.0,
            accuracy_meters=accuracy_meters))
        return ev

    def mark_uploaded(self, storage_url: str, checksum: str, thumbnail_url: Optional[str] = None) -> None:
        if not storage_url: raise ValidationException("storage_url is required.")
        self.storage_url = storage_url
        self.checksum = checksum
        self.thumbnail_url = thumbnail_url
        self.status = GPSRecordStatus.VALIDATING
        self.uploaded_at = datetime.now(timezone.utc)
        self.updated_at = self.uploaded_at
        # No specific upload event for GPS — LocationReached already emitted on capture
        pass

    def submit_for_review(self) -> None:
        if self.status != GPSRecordStatus.VALIDATING:
            raise ConflictException("GPS record must be VALIDATING before submission for review.")
        self.status = GPSRecordStatus.VALIDATING
        self.updated_at = datetime.now(timezone.utc)

    def start_review(self) -> None:
        self.status = GPSRecordStatus.VALIDATED
        self.updated_at = datetime.now(timezone.utc)

    def record_verification(self, verifier_type: str, verdict: str, confidence: float,
                            verifier_id: Optional[str] = None, notes: Optional[str] = None) -> None:
        record = VerificationRecord(verifier_type=verifier_type, verifier_id=verifier_id,
                                   verdict=verdict, confidence=confidence, notes=notes,
                                   verified_at=datetime.now(timezone.utc))
        self.verifications.append(record)

        if verdict == "APPROVED":
            self.status = GPSRecordStatus.VALIDATED
        elif verdict == "REJECTED":
            self.status = GPSRecordStatus.REJECTED
        elif verdict == "NEEDS_REVISION":
            self.status = GPSRecordStatus.LOW_ACCURACY
        elif verdict == "VALIDATING":
            self.status = GPSRecordStatus.VALIDATING

        self.updated_at = datetime.now(timezone.utc)
        # Verification events are emitted by the Verification service, not GPS

    @property
    def is_approved(self) -> bool:
        return self.status == GPSRecordStatus.VALIDATED

    @property
    def is_low_accuracy(self) -> bool:
        return self.accuracy_meters > LOW_ACCURACY_THRESHOLD_M

    def check_geofence(self, center_lat: float, center_lng: float, radius_m: float) -> GeofenceResult:
        if self.latitude is None or self.longitude is None:
            return GeofenceResult(inside=False, distance_meters=0.0)
        distance_km = haversine_km(center_lat, center_lng, self.latitude, self.longitude)
        distance_m = distance_km * 1000.0
        return GeofenceResult(inside=distance_m <= radius_m, distance_meters=distance_m)