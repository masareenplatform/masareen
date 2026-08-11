"""Media file entity - stores raw media metadata and references for processing.

Attributes:
- file_path: Original storage location
- encoding_profile: Video/audio codec configuration
- duration: Media length in seconds
- frame_rate: Video frames per second
- bit_rate: Data rate in bits per second
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from shared.base_entity import Entity
from shared.exceptions import ValidationException


@dataclass
class MediaFile(Entity):
    media_asset_id: str = ""
    original_path: Optional[str] = None
    file_path: Optional[str] = None
    encoding_profile: Optional[str] = None
    duration_seconds: Optional[float] = None
    frame_rate: Optional[float] = None
    bit_rate: Optional[int] = None
    created_at: datetime = field(default_factory=lambda: datetime.now())

    def validate(self) -> None:
        if not self.media_asset_id:
            raise ValidationException("media_asset_id is required.")

    def update_processing_info(self, encoding_profile: str, duration_seconds: float,
                               frame_rate: Optional[float] = None,
                               bit_rate: Optional[int] = None) -> None:
        if not encoding_profile:
            raise ValidationException("encoding_profile is required.")
        self.encoding_profile = encoding_profile
        self.duration_seconds = duration_seconds
        self.frame_rate = frame_rate
        self.bit_rate = bit_rate
