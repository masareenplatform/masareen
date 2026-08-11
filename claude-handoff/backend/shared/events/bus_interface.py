"""Messaging bus abstraction for polyglot event-driven architecture."""
from abc import ABC, abstractmethod
from typing import Any, Callable, Awaitable

class MessageBus(ABC):
    """Abstract interface for a message bus (Kafka, NATS, RabbitMQ, etc.)."""

    @abstractmethod
    async def publish(self, topic: str, payload: Any) -> None:
        """Publish a message to a specific topic/subject."""
        pass

    @abstractmethod
    async def subscribe(self, topic: str, handler: Callable[[Any], Awaitable[None]]) -> None:
        """Subscribe to a topic and execute the handler on every message."""
        pass

    @abstractmethod
    async def connect(self) -> None:
        """Establish connection to the broker."""
        pass

    @abstractmethod
    async def disconnect(self) -> None:
        """Close the connection to the broker."""
        pass
