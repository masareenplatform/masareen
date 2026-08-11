"""
Transactional Outbox Pattern implementation.

Problem: Publishing a Kafka event and committing to DB must be atomic.
Without this, a crash between the two operations causes either:
  - Duplicate events (event published, DB rolled back)
  - Lost events (DB committed, event never published)

Solution: Write events to an outbox table inside the same DB transaction.
A background relay process polls the outbox and publishes to Kafka,
then marks events as published.

DB Schema required (included in V001 migration):

  CREATE TABLE outbox_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type      VARCHAR(255) NOT NULL,
    aggregate_id    UUID NOT NULL,
    topic           VARCHAR(255) NOT NULL,
    payload         JSONB NOT NULL,
    published       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ
  );
  CREATE INDEX idx_outbox_unpublished ON outbox_events(published, created_at)
    WHERE published = FALSE;
"""
from __future__ import annotations
import asyncio
import json
import logging
from dataclasses import asdict
from typing import Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..events import DomainEvent
from .kafka_producer import EventPublisher

logger = logging.getLogger(__name__)


class OutboxWriter:
    """Writes domain events to the outbox table within the current transaction."""

    @staticmethod
    async def write(session: AsyncSession, event: DomainEvent, topic: str) -> None:
        await session.execute(
            text("""
                INSERT INTO outbox_events (id, event_type, aggregate_id, topic, payload)
                VALUES (:id, :event_type, :aggregate_id, :topic, :payload::jsonb)
            """),
            {
                "id": str(uuid4()),
                "event_type": event.event_type,
                "aggregate_id": event.aggregate_id,
                "topic": topic,
                "payload": json.dumps(event.to_dict()),
            }
        )

    @staticmethod
    async def write_many(session: AsyncSession, events: List[tuple[DomainEvent, str]]) -> None:
        for event, topic in events:
            await OutboxWriter.write(session, event, topic)


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
            rows = await session.execute(
                text("""
                    SELECT id, event_type, aggregate_id, topic, payload
                    FROM outbox_events
                    WHERE published = FALSE
                    ORDER BY created_at ASC
                    LIMIT :limit
                    FOR UPDATE SKIP LOCKED
                """),
                {"limit": self._batch_size}
            )
            events = rows.fetchall()
            if not events:
                return

            for row in events:
                event_id, event_type, aggregate_id, topic, payload = row
                try:
                    await self._publisher.publish_raw(
                        topic=topic,
                        payload=payload,
                        key=str(aggregate_id),
                    )
                    await session.execute(
                        text("""
                            UPDATE outbox_events
                            SET published = TRUE, published_at = NOW()
                            WHERE id = :id
                        """),
                        {"id": event_id}
                    )
                    logger.debug("Relayed %s → %s", event_type, topic)
                except Exception as exc:
                    logger.error("Failed to relay event %s: %s", event_id, exc)

            await session.commit()
