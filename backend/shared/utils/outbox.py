"""
Transactional Outbox Pattern implementation.

Problem: Publishing a Kafka event and committing to DB must be atomic.
Without this, a crash between the two operations causes either:
  - Duplicate events (event published, DB rolled back)
  - Lost events (DB committed, event never published)

Solution: Write events to an outbox table inside the same DB transaction.
A background relay process polls the outbox and publishes to Kafka,
then marks events as published.

The SQLAlchemy model `OutboxMessage` is defined in `shared.base_entity`
and registered on the shared `Base.metadata`, so `create_all` in the
combined backend will create the table automatically.
"""
from __future__ import annotations
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any, List, Optional
from uuid import uuid4

from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..events import DomainEvent
from ..base_entity import OutboxMessage, OutboxStatus
from .kafka_producer import EventPublisher

logger = logging.getLogger(__name__)


class OutboxWriter:
    """Writes domain events to the outbox table within the current transaction."""

    @staticmethod
    async def write(session: AsyncSession, event: DomainEvent, topic: str) -> OutboxMessage:
        msg = OutboxMessage(
            event_type=event.event_type,
            aggregate_id=str(event.subject),
            aggregate_type=event.source,
            topic=topic,
            payload=event.model_dump(mode="json") if hasattr(event, "model_dump") else event.to_dict(),
            status=OutboxStatus.PENDING,
        )
        session.add(msg)
        await session.flush()
        return msg

    @staticmethod
    async def write_many(session: AsyncSession, events: List[tuple]) -> List[OutboxMessage]:
        msgs = []
        for event, topic in events:
            msgs.append(await OutboxWriter.write(session, event, topic))
        return msgs


class OutboxRelay:
    """
    Background process that polls the outbox table and publishes to Kafka.
    Run one instance per service as an asyncio task.
    """

    def __init__(
        self,
        session_factory,
        publisher: EventPublisher,
        poll_interval_seconds: float = 1.0,
        batch_size: int = 100,
    ) -> None:
        self._session_factory = session_factory
        self._publisher = publisher
        self._poll_interval = poll_interval_seconds
        self._batch_size = batch_size
        self._running = False

    async def start(self) -> None:
        self._running = True
        while self._running:
            try:
                await self._relay_batch()
            except Exception as exc:
                logger.exception("Outbox relay error: %s", exc)
            await asyncio.sleep(self._poll_interval)

    async def stop(self) -> None:
        self._running = False

    async def _relay_batch(self) -> None:
        async with self._session_factory() as session:
            stmt = (
                select(OutboxMessage)
                .where(OutboxMessage.status == OutboxStatus.PENDING)
                .order_by(OutboxMessage.created_at.asc())
                .limit(self._batch_size)
                .with_for_update(skip_locked=True)
            )
            result = await session.execute(stmt)
            msgs = result.scalars().all()
            if not msgs:
                return

            for msg in msgs:
                try:
                    await self._publisher.publish_raw(
                        topic=msg.topic,
                        payload=msg.payload,
                        key=msg.aggregate_id,
                    )
                    msg.status = OutboxStatus.PUBLISHED
                    msg.published_at = datetime.now(timezone.utc)
                    logger.debug("Relayed %s → %s", msg.event_type, msg.topic)
                except Exception as exc:
                    msg.status = OutboxStatus.FAILED
                    msg.error = str(exc)[:1000]
                    logger.error("Failed to relay event %s: %s", msg.id, exc)

            await session.commit()
