"""Media queries for retrieving media assets."""
from dataclasses import dataclass, field
from typing import Optional
from shared.base_entity import Entity


@dataclass
class GetMedia:
    """Query to retrieve a media asset by ID."""
    media_asset_id: str = ""

    def validate(self) -> None:
        if not self.media_asset_id:
            raise ValueError("media_asset_id is required.")


@dataclass
class GetSubmissionMedia:
    """Query to retrieve all media assets for a submission."""
    submission_id: str = ""

    def validate(self) -> None:
        if not self.submission_id:
            raise ValueError("submission_id is required.")
