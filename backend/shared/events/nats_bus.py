"""NATS implementation of the MessageBus."""
from .bus_interface import MessageBus
from nats.aio.client import Client as NATS
import json
from typing import Any, Callable, Awaitable
from shared.utils.logging import get_logger

log = get_logger(__name__)

class NatsMessageBus(MessageBus):
    def __init__(self, servers: str):
        self.servers = servers
        self.nc: NATS | None = None
        self.js = None # JetStream context

    async def connect(self) -> None:
        self.nc = NATS()
        await self.nc.connect(servers=self.servers)
        self.js = self.nc.jetstream()
        log.info(f"Connected to NATS at {self.servers}")

    async def disconnect(self) -> None:
        if self.nc:
            await self.nc.close()
        log.info("Disconnected from NATS")

    async def publish(self, topic: str, payload: Any) -> None:
        if not self.nc:
            raise RuntimeError("NATS client not connected. Call connect() first.")
        
        data = json.dumps(payload).encode('utf-8')
        # Use JetStream for persistent messaging (equivalent to Kafka)
        await self.js.publish(topic, data)
        log.debug(f"Published to NATS subject {topic}: {payload}")

    async def subscribe(self, topic: str, handler: Callable[[Any], Awaitable[None]]) -> None:
        if not self.nc:
            raise RuntimeError("NATS client not connected. Call connect() first.")

        async def wrapped_handler(msg):
            try:
                payload = json.loads(msg.data.decode('utf-8'))
                await handler(payload)
                await msg.ack()
            except Exception as e:
                log.error(f"Error in NATS handler for {topic}: {e}")

        # Use JetStream pull/push subscription
        await self.js.subscribe(topic, cb=wrapped_handler)
        log.info(f"Subscribed to NATS subject {topic}")
