"""Media upload command - initiates the media upload process."""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from shared.utils.cqrs import Command
from shared.exceptions import ValidationException


@dataclass
class CreateUploadSlotCommand(Command):
    """Command to create an upload slot for media."""
    owner_id: str = ""
    mime_type: str = ""
    file_size_bytes: int = 0
    evidence_id: Optional[str] = None
    original_filename: Optional[str] = None


@dataclass
class UploadMediaCommand(Command):
    """Command to upload media file and initiate processing."""
    asset_id: str = ""
    storage_key: Optional[str] = None
    checksum: Optional[str] = None


@dataclass
class ProcessMediaCommand(Command):
    """Command to process uploaded media (generate thumbnail, etc)."""
    asset_id: str = ""
    cdn_url: str = ""
    checksum: str = ""
    thumbnail_url: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration_seconds: Optional[float] = None


@dataclass
class DeleteMediaCommand(Command):
    """Command to delete media asset and all associated files."""
    asset_id: str = ""
