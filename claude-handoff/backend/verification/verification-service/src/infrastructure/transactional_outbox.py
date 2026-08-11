"""Transactional outbox for event publishing."""
from abc import ABC, abstractmethod
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from uuid import uuid4
from shared.utils.logging import get_logger
from shared.base_entity import OutboxEntry

log = get_logger(__name__)

class OutboxWriter(ABC):
    """Abstract outbox writer interface."""
    @abstractmethod
    async def write(self, session, aggregate_id: Optional[str], event: Any, event_type: str) -> None:
        pass

    @abstractmethod
    async def get_pending_events(self, session, limit: int = 100) -> List[OutboxEntry]:
        pass

    @abstractmethod
    async def mark_as_published(self, session, event_id: str) -> None:
        pass

class TransactionalOutbox(OutboxWriter):
    """Real PostgreSQL-backed Transactional outbox."""

    async def write(self, session, aggregate_id: Optional[str], event: Any, event_type: str) -> None:
        from .postgres_repositories import PostgresOutboxRepository
        repo = PostgresOutboxRepository(session)
        
        event_id = str(uuid4())
        payload = event.__dict__ if hasattr(event, '__dict__') else event
        
        entry = OutboxEntry(
            id=event_id,
            aggregate_id=aggregate_id,
            event_type=event_type,
            payload=payload,
            created_at=datetime.now(timezone.utc),
            published=False
        )
        
        await repo.save(entry)
        log.info(f"Event {event_type} persisted to outbox (ID: {event_id})")

    async def get_pending_events(self, session, limit: int = 100) -> List[OutboxEntry]:
        from .postgres_repositories import PostgresOutboxRepository
        repo = PostgresOutboxRepository(session)
        return await repo.get_pending(limit)

    async def mark_as_published(self, session, event_id: str) -> None:
        from .postgres_repositories import PostgresOutboxRepository
        repo = PostgresOutboxRepository(session)
        await repo.mark_published(event_id)
        log.info(f"Event {event_id} marked as published in DB")

