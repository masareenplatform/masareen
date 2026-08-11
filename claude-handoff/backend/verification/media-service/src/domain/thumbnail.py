"""Thumbnail entity for resized versions of media files.

Attributes:
- size: dimensions (width x height)
- file_size: storage size in bytes
- storage_key: object storage reference
"""
from typing import Optional
from dataclasses import dataclass, field
from datetime import datetime
from shared.base_entity import Entity
from shared.exceptions import ValidationException


@dataclass
class Thumbnail(Entity):
    media_asset_id: str = ""
    size: str = ""  # Format: "width x height"
    file_size_bytes: int = 0
    storage_key: Optional[str] = None
    created_at: datetime = field(default_factory=lambda: datetime.now())

    def validate(self) -> None:
        if not self.media_asset_id:
            raise ValidationException("media_asset_id is required.")
        if not self.size:
            raise ValidationException("size is required.")

    def generate(self, size: str, file_size: int, storage_key: str) -> None:
        if not size:
            raise ValidationException("size is required.")
        self.size = size
        self.file_size_bytes = file_size
        self.storage_key = storage_key
