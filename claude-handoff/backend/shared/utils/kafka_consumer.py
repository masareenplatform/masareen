"""
Base Kafka event consumer.
Each service extends this to subscribe to relevant topics.
"""
from __future__ import annotations
import asyncio
import json
import logging
from abc import ABC, abstractmethod
from typing import Any, Callable, Dict, List

from aiokafka import AIOKafkaConsumer

from .config_loader import get_kafka_bootstrap

logger = logging.getLogger(__name__)


class EventConsumer(ABC):
    """
    Base class for Kafka consumers.
    Subclass this in each service and implement handle_event().
    """

    def __init__(
        self,
        topics: List[str],
        group_id: str,
        bootstrap_servers: str | None = None,
    ) -> None:
        self._topics = topics
        self._group_id = group_id
        self._bootstrap = bootstrap_servers or get_kafka_bootstrap()
        self._consumer: AIOKafkaConsumer | None = None
        self._running = False

    async def start(self) -> None:
        self._consumer = AIOKafkaConsumer(
            *self._topics,
            bootstrap_servers=self._bootstrap,
            group_id=self._group_id,
            auto_offset_reset="earliest",
            enable_auto_commit=False,
            value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        )
        await self._consumer.start()
        self._running = True
        logger.info("Consumer started, group=%s topics=%s", self._group_id, self._topics)

    async def stop(self) -> None:
        self._running = False
        if self._consumer:
            await self._consumer.stop()

    async def consume(self) -> None:
        """Main consume loop. Run as a background task."""
        if not self._consumer:
            raise RuntimeError("Consumer not started.")
        async for msg in self._consumer:
            try:
                await self.handle_event(
                    event_type=msg.value.get("event_type", ""),
                    payload=msg.value,
                    topic=msg.topic,
                    partition=msg.partition,
                    offset=msg.offset,
                )
                await self._consumer.commit()
            except Exception as exc:
                logger.exception("Error handling event %s: %s", msg.value.get("event_type"), exc)
                # Do NOT commit, will retry on restart (at-least-once delivery)

    @abstractmethod
    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None: ...
