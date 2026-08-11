"""Aggregate root and entity base classes."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Any, Optional
from enum import Enum
from sqlalchemy import Column, String, JSON, DateTime, Enum as SAEnum, text
from sqlalchemy.dialects.postgresql import UUID
from ..events import DomainEvent
from ..base_repository.db import Base


class OutboxStatus(str, Enum):
    """Lifecycle states for an outbox message."""
    PENDING = "PENDING"
    PUBLISHED = "PUBLISHED"
    FAILED = "FAILED"


class OutboxMessage(Base):
    """Transactional outbox table — written in the same DB transaction as the
    aggregate change, then polled by a relay process for Kafka publication.

    This is the authoritative schema referenced by the outbox.py relay and
    the combined backend's `create_all` call.
    """
    __tablename__ = "outbox_events"
    __table_args__ = {"extend_existing": True}

    id = Column(UUID(as_uuid=True), primary_key=True, default=lambda: __import__("uuid").uuid4())
    event_type = Column(String(255), nullable=False)
    aggregate_id = Column(String(255), nullable=False)
    aggregate_type = Column(String(255), nullable=False)
    topic = Column(String(255), nullable=False)
    payload = Column(JSON, nullable=False)
    status = Column(SAEnum(OutboxStatus), nullable=False, default=OutboxStatus.PENDING)
    created_at = Column(DateTime(timezone=True), nullable=False,
                        server_default=text("NOW()"))
    published_at = Column(DateTime(timezone=True), nullable=True)
    error = Column(String(1000), nullable=True)

    def __repr__(self) -> str:
        return f"<OutboxMessage {self.event_type} status={self.status}>"


@dataclass
class AggregateRoot:
    """Base class for all DDD aggregate roots."""
    id: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    version: int = 0
    _domain_events: List[DomainEvent] = field(default_factory=list, repr=False, compare=False)

    def add_domain_event(self, event: DomainEvent) -> None:
        self._domain_events.append(event)

    def pull_domain_events(self) -> List[DomainEvent]:
        events = list(self._domain_events)
        self._domain_events.clear()
        return events


@dataclass
class OutboxEntry:
    """Dataclass variant of the outbox for services using in-memory outbox."""
    id: str = ""
    aggregate_id: Optional[str] = None
    event_type: str = ""
    payload: Any = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    published: bool = False
    published_at: Optional[datetime] = None
