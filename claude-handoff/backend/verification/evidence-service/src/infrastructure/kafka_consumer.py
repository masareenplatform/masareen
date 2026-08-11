"""
Messaging consumer for Evidence domain events.
"""
import asyncio
from abc import ABC, abstractmethod
from typing import Callable, Awaitable
from shared.utils.logging import get_logger
from shared.events.bus_interface import MessageBus

log = get_logger(__name__)


class EvidenceConsumer(ABC):
    """Abstract consumer for Evidence domain events."""
    
    @abstractmethod
    async def start_consuming(self, topic: str, handler: Callable[[Any], Awaitable[None]]) -> None:
        pass
    
    @abstractmethod
    async def stop_consuming(self) -> None:
        pass


class EvidenceConsumerImpl(EvidenceConsumer):
    """Concrete implementation using a generic MessageBus."""
    
    def __init__(self, bus: MessageBus):
        self.bus = bus
        self.subscriptions: list[str] = []
        log.info("EvidenceConsumer initialized with MessageBus")
    
    async def start_consuming(self, topic: str, handler: Callable[[Any], Awaitable[None]]) -> None:
        """Subscribe to a topic via the MessageBus."""
        await self.bus.subscribe(topic, handler)
        self.subscriptions.append(topic)
        log.info(f"EvidenceConsumer subscribed to topic: {topic}")
    
    async def stop_consuming(self) -> None:
        """Stop all subscriptions."""
        # The bus handles the actual disconnection, but we track our topics
        self.subscriptions.clear()
        log.info("Stopped EvidenceConsumer subscriptions")
