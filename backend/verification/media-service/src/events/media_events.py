"""Media domain events - updated with new events."""
from dataclasses import dataclass, field
from typing import Optional, List
from shared.events.verification_events import DomainEvent


@dataclass
class MediaUploaded(DomainEvent):
    """Event published when media file is successfully uploaded and stored."""
    event_type: str = "MediaUploaded"
    aggregate_type: str = "MediaAsset"
    aggregate_id: str = ""
    media_asset_id: str = ""
    submission_id: str = ""
    media_type: str = ""
    file_size_bytes: int = 0
    storage_key: str = ""
    checksum: Optional[str] = None
    thumbnail_url: Optional[str] = None
    metadata: dict = field(default_factory=dict)


@dataclass
class MediaValidated(DomainEvent):
    """Event published when media file has passed validation checks."""
    event_type: str = "MediaValidated"
    aggregate_type: str = "MediaAsset"
    aggregate_id: str = ""
    media_asset_id: str = ""
    validation_status: str = ""
    validation_notes: Optional[str] = None
    metadata: dict = field(default_factory=dict)


@dataclass
class ThumbnailGenerated(DomainEvent):
    """Event published when thumbnail is successfully generated."""
    event_type: str = "ThumbnailGenerated"
    aggregate_type: str = "MediaAsset"
    aggregate_id: str = ""
    media_asset_id: str = ""
    thumbnail_url: str = ""
    size: str = ""
    file_size_bytes: int = 0
    metadata: dict = field(default_factory=dict)


@dataclass
class MediaDeleted(DomainEvent):
    """Event published when media asset is deleted."""
    event_type: str = "MediaDeleted"
    aggregate_type: str = "MediaAsset"
    aggregate_id: str = ""
    media_asset_id: str = ""
    deletion_reason: str = ""
    metadata: dict = field(default_factory=dict)
