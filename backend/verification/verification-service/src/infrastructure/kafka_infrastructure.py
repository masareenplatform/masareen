"""Event-driven infrastructure for verification service.

Delegates to shared kernel EventPublisher/EventConsumer.
"""
from shared.utils.kafka_producer import EventPublisher as SharedEventPublisher
from shared.utils.kafka_consumer import EventConsumer as SharedEventConsumer
from shared.events.verification_events import EvidenceVerified
from shared.utils.logging import get_logger

log = get_logger(__name__)


class KafkaEventPublisher(SharedEventPublisher):
    """Verification service event publisher."""

    def __init__(self, bootstrap_servers: str | None = None):
        super().__init__(bootstrap_servers)

    async def publish_event(self, event, topic: str) -> None:
        from shared.events import DomainEvent
        if isinstance(event, DomainEvent):
            await self.publish(topic, event)
        else:
            log.warning("Cannot publish non-DomainEvent", event_type=type(event).__name__)


class VerificationEventConsumer(SharedEventConsumer):
    """Verification service event consumer."""

    def __init__(self, bootstrap_servers: str | None = None):
        topics = ["masaren.verification.evidence.v1", "masaren.verification.submission.v1"]
        super().__init__(topics=topics, group_id="verification-service", bootstrap_servers=bootstrap_servers)

    async def handle_event(self, event_type: str, payload: dict, topic: str, partition: int, offset: int) -> None:
        log.info("Processing verification event", event_type=event_type, topic=topic)
