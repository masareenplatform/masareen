"""Kafka implementation of the MessageBus."""
from .bus_interface import MessageBus
from aiokafka import AIOKafkaProducer, AIOKafkaConsumer
import json
import asyncio
from typing import Any, Callable, Awaitable
from shared.utils.logging import get_logger

log = get_logger(__name__)

class KafkaMessageBus(MessageBus):
    def __init__(self, bootstrap_servers: str):
        self.bootstrap_servers = bootstrap_servers
        self.producer: AIOKafkaProducer | None = None
        self.consumers: list[AIOKafkaConsumer] = []

    async def connect(self) -> None:
        self.producer = AIOKafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
        await self.producer.start()
        log.info(f"Connected to Kafka at {self.bootstrap_servers}")

    async def disconnect(self) -> None:
        if self.producer:
            await self.producer.stop()
        for consumer in self.consumers:
            await consumer.stop()
        log.info("Disconnected from Kafka")

    async def publish(self, topic: str, payload: Any) -> None:
        if not self.producer:
            raise RuntimeError("Kafka producer not connected. Call connect() first.")
        await self.producer.send_and_wait(topic, payload)
        log.debug(f"Published to Kafka topic {topic}: {payload}")

    async def subscribe(self, topic: str, handler: Callable[[Any], Awaitable[None]]) -> None:
        consumer = AIOKafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            group_id=f"masaren-{topic}"
        )
        await consumer.start()
        self.consumers.append(consumer)
        
        async def listen():
            try:
                async for msg in consumer:
                    await handler(msg.value)
            except Exception as e:
                log.error(f"Error in Kafka consumer for {topic}: {e}")
            finally:
                await consumer.stop()

        asyncio.create_task(listen())
        log.info(f"Subscribed to Kafka topic {topic}")
