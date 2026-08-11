"""GPS Event Publisher."""
import json
from abc import ABC, abstractmethod
from shared.utils.logging import get_logger

log = get_logger(__name__)


class GPSEventPublisher(ABC):
    @abstractmethod
    async def publish(self, event_type: str, aggregate_id: str, event_data: dict, topic: str) -> None:
        pass


class GPSEventPublisherImpl(GPSEventPublisher):
    def __init__(self, bootstrap_servers: str):
        self.bootstrap_servers = bootstrap_servers
        log.info("GPS event publisher initialized", servers=bootstrap_servers)

    async def publish(self, event_type: str, aggregate_id: str, event_data: dict, topic: str) -> None:
        try:
            log.info(
                "Publishing GPS event",
                event_type=event_type,
                aggregate_id=aggregate_id,
                topic=topic,
                event_data=event_data
            )
        except Exception as e:
            log.error("Failed to publish GPS event", error=str(e), event_type=event_type)
            raise