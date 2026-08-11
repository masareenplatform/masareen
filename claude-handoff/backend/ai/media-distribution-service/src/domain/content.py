"""Content distribution aggregate for Media Institutions."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional, List
from uuid import uuid4
from shared.base_entity import AggregateRoot

@dataclass
class MediaContent(AggregateRoot):
    title: str = ""
    body: str = ""
    media_url: str = ""
    media_type: str = "VIDEO" # VIDEO | AUDIO | IMAGE | ARTICLE
    institution_id: str = ""
    target_audience: List[str] = field(default_factory=list)
    reach_count: int = 0
    engagement_score: float = 0.0
    is_official: bool = True
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @classmethod
    def publish(cls, institution_id: str, title: str, body: str, media_url: str, media_type: str):
        return cls(
            id=str(uuid4()),
            institution_id=institution_id,
            title=title,
            body=body,
            media_url=media_url,
            media_type=media_type
        )
