from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException

# Canonical ad pricing (see SYSTEM_STATE.md): money is Decimal, never float.
COST_PER_IMPRESSION = Decimal("0.01")
COST_PER_CLICK = Decimal("0.10")


class ContentType(str, Enum):
    AD = "AD"                 # Paid visibility
    EDUCATIONAL = "EDUCATIONAL" # How to use MASAREEN
    ANNOUNCEMENT = "ANNOUNCEMENT" # Admin news


def _to_decimal(value) -> Optional[Decimal]:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


@dataclass
class PlatformPost(AggregateRoot):
    title: str = ""
    body: str = ""
    content_type: ContentType = ContentType.EDUCATIONAL
    media_url: Optional[str] = None
    target_audience: List[str] = field(default_factory=list) # "ALL", "STUDENTS", "ORGS"
    is_active: bool = True
    priority: int = 0 # Higher = more frequent in feed
    spend_limit: Optional[Decimal] = None # For ads: total budget
    current_spend: Decimal = field(default_factory=lambda: Decimal("0"))
    clicks: int = 0
    impressions: int = 0
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @classmethod
    def create(cls, title: str, body: str, content_type: str,
               media_url: Optional[str]=None, target: List[str]=None,
               budget: Optional[float]=None) -> "PlatformPost":
        if not title or not body:
            raise ValidationException("Title and body are required for platform posts.")

        return cls(
            id=str(uuid4()),
            title=title,
            body=body,
            content_type=ContentType(content_type),
            media_url=media_url,
            target_audience=target or ["ALL"],
            spend_limit=_to_decimal(budget),
            current_spend=Decimal("0"),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )

    def _charge(self, amount: Decimal) -> None:
        self.current_spend += amount
        if self.spend_limit is not None and self.current_spend >= self.spend_limit:
            self.is_active = False

    def record_impression(self) -> None:
        self.impressions += 1
        if self.content_type == ContentType.AD and self.spend_limit is not None:
            self._charge(COST_PER_IMPRESSION)

    def record_click(self) -> None:
        self.clicks += 1
        if self.content_type == ContentType.AD and self.spend_limit is not None:
            self._charge(COST_PER_CLICK)
