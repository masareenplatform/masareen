"""GPS Domain Events."""
from dataclasses import dataclass, field
from typing import Optional
from shared.events import DomainEvent


@dataclass
class GPSCaptured(DomainEvent):
    event_type: str = "GPSCaptured"
    aggregate_type: str = "GPSRecord"
    gps_id: str = ""
    task_id: str = ""
    user_id: str = ""
    media_type: str = ""
    file_size_bytes: int = 0


@dataclass
class GPSUploaded(DomainEvent):
    event_type: str = "GPSUploaded"
    aggregate_type: str = "GPSRecord"
    gps_id: str = ""
    storage_url: str = ""
    checksum: str = ""


@dataclass
class GPSVerified(DomainEvent):
    event_type: str = "GPSVerified"
    aggregate_type: str = "GPSRecord"
    gps_id: str = ""
    verifier_type: str = ""
    confidence_score: float = 0.0
    verdict: str = ""


@dataclass
class LocationConflicted(DomainEvent):
    event_type: str = "LocationConflicted"
    aggregate_type: str = "GPSRecord"
    gps_id: str = ""
    conflict_count: int = 0
    coordinate: str = ""  # lat,lon format


@dataclass
class GPSRecordRejected(DomainEvent):
    event_type: str = "GPSRecordRejected"
    aggregate_type: str = "GPSRecord"
    gps_id: str = ""
    rejection_reason: str = ""