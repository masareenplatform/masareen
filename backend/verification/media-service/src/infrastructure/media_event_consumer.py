"""
Kafka event consumer for Media Service.

Consumes events from the event bus and reacts to domain changes.
"""
from __future__ import annotations
import asyncio
import json
import logging
from typing import Callable, Dict, Any

from aiokafka import AIOKafkaConsumer
from shared.events.verification_events import EvidenceCaptured
from shared.events.submission_events import PipelineCreated
from shared.utils.logging import get_logger

logger = get_logger(__name__)


class MediaEventConsumer:
    """Kafka consumer for Media Service domain events."""

    def __init__(self, bootstrap_servers: str | None = None) -> None:
        self._bootstrap = bootstrap_servers
        self._consumer: AIOKafkaConsumer | None = None
        self._handlers: Dict[str, Callable] = {}

    async def start(self) -> None:
        """Start the Kafka consumer."""
        from shared.utils.config_loader import get_kafka_bootstrap
        
        bootstrap = self._bootstrap or get_kafka_bootstrap()
        self._consumer = AIOKafkaConsumer(
            "evidence-events",
            "submission-events",
            bootstrap_servers=bootstrap,
            group_id="media-service-consumer",
            enable_auto_commit=False,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="earliest",
        )
        await self._consumer.start()
        logger.info("Media event consumer started, %s", bootstrap)

        # Start message processing loop
        asyncio.create_task(self._consume_loop())

    async def stop(self) -> None:
        """Stop the Kafka consumer."""
        if self._consumer:
            await self._consumer.stop()
            logger.info("Media event consumer stopped")

    def register_handler(self, event_type: str, handler: Callable) -> None:
        """Register a handler for a specific event type."""
        self._handlers[event_type] = handler
        logger.debug("Registered handler for event type: %s", event_type)

    async def _consume_loop(self) -> None:
        """Main consumption loop - processes incoming events."""
        if not self._consumer:
            return
            
        try:
            async for msg in self._consumer:
                try:
                    event_type = msg.value.get("event_type")
                    if event_type and event_type in self._handlers:
                        handler = self._handlers[event_type]
                        await handler(msg.value)
                        await self._consumer.commit()
                    else:
                        logger.warning("No handler registered for event type: %s", event_type)
                except Exception as e:
                    logger.error("Error processing event %s: %s", 
                               msg.value.get("event_type"), str(e), exc_info=True)
        finally:
            if self._consumer:
                await self._consumer.stop()

    async def process_evidence_captured(self, event_data: Dict[str, Any]) -> None:
        """Process EvidenceCaptured event to create upload slots for media."""
        logger.info("Processing EvidenceCaptured: %s", event_data)
        from ..domain.media_asset import MediaAsset
        from ..domain.media_asset import ALLOWED_MIME_TYPES
        mime = event_data.get("media_type", "image/jpeg")
        if mime not in ALLOWED_MIME_TYPES:
            logger.warning("Unsupported mime type in EvidenceCaptured: %s", mime)
            return
        logger.info("Upload slot would be created for evidence %s", event_data.get("aggregate_id"))

    async def process_pipeline_created(self, event_data: Dict[str, Any]) -> None:
        """Process PipelineCreated event to validate and process media."""
        logger.info("Processing PipelineCreated: %s", event_data)
        evidence_ids = [e.get("evidence_id") for e in event_data.get("evidence_items", [])]
        logger.info("Pipeline created for evidence items: %s", evidence_ids)
