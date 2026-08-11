from __future__ import annotations
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Dict, Generic, List, Optional, TypeVar
from dataclasses import dataclass

T = TypeVar("T")


class EventPublisher(ABC, Generic[T]):
    """Port for event publishing in submission service."""
    
    @abstractmethod
    async def publish(self, event: T, event_type: str, aggregate_id: str) -> None:
        """Publish a domain event."""
        pass


class InMemoryEventPublisher(EventPublisher[T]):
    """In-memory implementation for event publisher."""
    
    def __init__(self):
        self._events: List[Dict[str, Any]] = []
    
    async def publish(self, event: T, event_type: str, aggregate_id: str) -> None:
        self._events.append({
            "event": event,
            "event_type": event_type,
            "aggregate_id": aggregate_id,
            "timestamp": datetime.now()
        })


@dataclass
class EventRecord:
    event_id: str
    event_type: str
    aggregate_id: str
    aggregate_type: str
    event_data: Dict[str, Any]
    occurred_at: datetime
    version: int = 1


class EventStore(ABC):
    """Event store for submission service."""
    
    @abstractmethod
    async def append(self, event_record: EventRecord) -> None:
        """Append an event record."""
        pass
    
    @abstractmethod
    async def get_by_aggregate(self, aggregate_id: str) -> List[EventRecord]:
        """Get all events for an aggregate."""
        pass


class InMemoryEventStore(EventStore):
    """In-memory event store for testing."""
    
    def __init__(self):
        self._events: Dict[str, List[EventRecord]] = {}
    
    async def append(self, event_record: EventRecord) -> None:
        if event_record.aggregate_id not in self._events:
            self._events[event_record.aggregate_id] = []
        self._events[event_record.aggregate_id].append(event_record)
    
    async def get_by_aggregate(self, aggregate_id: str) -> List[EventRecord]:
        return self._events.get(aggregate_id, [])