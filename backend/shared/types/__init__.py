"""Shared domain types used across MASAREN bounded contexts.

These are lightweight value objects and type aliases — not ORM models or API schemas.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID, uuid4


# ── Identifiers ───────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class EntityId:
    """Strongly-typed identifier wrapper to avoid mixing IDs across domains."""
    value: UUID = field(default_factory=uuid4)

    def __str__(self) -> str:
        return str(self.value)

    @classmethod
    def from_str(cls, raw: str) -> "EntityId":
        return cls(value=UUID(raw))


# ── Audit metadata ────────────────────────────────────────────────────────────
@dataclass
class AuditMeta:
    created_by: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_by: str = ""
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    deleted: bool = False


# ── Domain events ─────────────────────────────────────────────────────────────
class EventPriority(str, Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class DomainEventRecord:
    """Outbox-ready domain event record."""
    id: UUID = field(default_factory=uuid4)
    event_type: str = ""
    aggregate_id: str = ""
    aggregate_type: str = ""
    topic: str = ""
    payload: Dict[str, Any] = field(default_factory=dict)
    priority: EventPriority = EventPriority.NORMAL
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


# ── Currency / money ──────────────────────────────────────────────────────────
class Currency(str, Enum):
    EGP = "EGP"
    USD = "USD"
    EUR = "EUR"
    SAR = "SAR"
    AED = "AED"


@dataclass(frozen=True)
class Money:
    amount: float
    currency: Currency = Currency.EGP

    def to_dict(self) -> dict:
        return {"amount": self.amount, "currency": self.currency.value}


# ── Geo ───────────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class GeoPoint:
    latitude: float
    longitude: float

    def to_dict(self) -> dict:
        return {"lat": self.latitude, "lng": self.longitude}


# ── Time range ────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class TimeRange:
    start: datetime
    end: Optional[datetime] = None

    def to_dict(self) -> dict:
        return {
            "start": self.start.isoformat(),
            "end": self.end.isoformat() if self.end else None,
        }


# ── Pagination ────────────────────────────────────────────────────────────────
@dataclass
class PageRequest:
    offset: int = 0
    limit: int = 20

    @property
    def page(self) -> int:
        return (self.offset // self.limit) + 1 if self.limit else 1


@dataclass
class PageResult:
    total: int
    offset: int
    limit: int

    @property
    def has_more(self) -> bool:
        return (self.offset + self.limit) < self.total
