"""
Messaging producer for Evidence domain events.
"""
from abc import ABC, abstractmethod
from shared.utils.logging import get_logger
from shared.events.bus_interface import MessageBus

log = get_logger(__name__)


class EvidenceProducer(ABC):
    """Abstract producer for Evidence domain events."""
    
    @abstractmethod
    async def send_event(self, topic: str, event: dict) -> None:
        pass


class EvidenceProducerImpl(EvidenceProducer):
    """Concrete implementation using a generic MessageBus."""
    
    def __init__(self, bus: MessageBus):
        self.bus = bus
        log.info("EvidenceProducer initialized with MessageBus")
    
    async def send_event(self, topic: str, event: dict) -> None:
        try:
            await self.bus.publish(topic, event)
            log.info(
                "Published event to bus",
                topic=topic,
                event_type=event.get("event_type"),
                aggregate_id=event.get("aggregate_id")
            )
        except Exception as e:
            log.error("Failed to publish event", error=str(e), topic=topic)
            raise
