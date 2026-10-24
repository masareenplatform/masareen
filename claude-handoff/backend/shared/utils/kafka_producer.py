"""
Base Kafka event publisher.
All services use this to emit domain events to the event bus.
Events are serialised as JSON. Schema registry integration is a future concern.
"""
from __future__ import annotations
import json
import logging
from typing import Any, Dict, Optional

from aiokafka import AIOKafkaProducer

from .config_loader import get_kafka_bootstrap
from ..events import DomainEvent

logger = logging.getLogger(__name__)


class EventPublisher:
    """Async Kafka producer wrapper. One instance per service (singleton)."""

    def __init__(self, bootstrap_servers: str | None = None) -> None:
        self._bootstrap = bootstrap_servers or get_kafka_bootstrap()
        self._producer: Optional[AIOKafkaProducer] = None

    async def start(self) -> None:
        self._producer = AIOKafkaProducer(
            bootstrap_servers=self._bootstrap,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
            acks="all",
            enable_idempotence=True,
            compression_type="gzip",
        )
        await self._producer.start()
        logger.info("Kafka producer started, %s", self._bootstrap)

    async def stop(self) -> None:
        if self._producer:
            await self._producer.stop()

    async def publish(self, topic: str, event: DomainEvent, key: str | None = None) -> None:
        if not self._producer:
            raise RuntimeError("EventPublisher not started. Call await publisher.start() first.")
        payload = event.to_dict()
        await self._producer.send_and_wait(topic, value=payload, key=key or event.aggregate_id)
        logger.debug("Published %s → %s", event.event_type, topic)

    async def publish_raw(self, topic: str, payload: Dict[str, Any], key: str | None = None) -> None:
        if not self._producer:
            raise RuntimeError("EventPublisher not started.")
        await self._producer.send_and_wait(topic, value=payload, key=key)
