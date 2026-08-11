"""Redis-backed token store for refresh tokens, password reset tokens, etc."""
from __future__ import annotations
from typing import Optional
import redis.asyncio as aioredis


class RedisTokenStore:
    def __init__(self, redis_url: str) -> None:
        self._redis = aioredis.from_url(redis_url, decode_responses=True)

    async def set(self, key: str, value: str, ttl_seconds: int = 3600) -> None:
        await self._redis.setex(key, ttl_seconds, value)

    async def get(self, key: str) -> Optional[str]:
        return await self._redis.get(key)

    async def delete(self, key: str) -> None:
        await self._redis.delete(key)

    async def ping(self) -> bool:
        try:
            return await self._redis.ping()
        except Exception:
            return False
