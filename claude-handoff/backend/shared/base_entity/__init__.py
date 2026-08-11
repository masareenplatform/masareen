"""Aggregate root and entity base classes."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Any, Optional
from ..events import DomainEvent

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
    """Persistence model for the transactional outbox."""
    id: str
    aggregate_id: Optional[str]
    event_type: str
    payload: Any
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    published: bool = False
    published_at: Optional[datetime] = None
