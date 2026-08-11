"""Redis client and cache utilities for the MASAREN shared kernel.

Provides a singleton async Redis client with connection pooling, session
storage, rate-limiting primitives, and cache helpers. All services import
from `shared.utils.redis` to ensure a single, consistently-configured client.
"""
from __future__ import annotations

import json
import os
from typing import Any, Optional

import redis.asyncio as redis

_REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

_client: Optional[redis.Redis] = None


def get_redis() -> redis.Redis:
    """Return the singleton async Redis client, creating it on first use."""
    global _client
    if _client is None:
        _client = redis.from_url(_REDIS_URL, decode_responses=True)
    return _client


async def close_redis() -> None:
    """Close the singleton Redis client (call on shutdown)."""
    global _client
    if _client is not None:
        await _client.close()
        _client = None


async def cache_set(key: str, value: Any, ttl: int = 300) -> bool:
    """Store a JSON-serializable value in Redis with a TTL (seconds)."""
    r = get_redis()
    return await r.setex(key, ttl, json.dumps(value, default=str))


async def cache_get(key: str) -> Optional[Any]:
    """Retrieve and JSON-decode a value from Redis, or None if missing/expired."""
    r = get_redis()
    raw = await r.get(key)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw


async def cache_delete(key: str) -> int:
    """Delete a key from Redis. Returns the number of keys removed."""
    r = get_redis()
    return await r.delete(key)


class RateLimiter:
    """Simple sliding-window rate limiter backed by Redis."""

    def __init__(self, key_prefix: str = "rl", window: int = 60, max_requests: int = 100):
        self._prefix = key_prefix
        self._window = window
        self._max = max_requests

    async def check(self, identifier: str) -> bool:
        """Return True if the request is allowed, False if rate-limited."""
        r = get_redis()
        key = f"{self._prefix}:{identifier}"
        now = int(__import__("time").time())
        pipe = r.pipeline()
        pipe.zremrangebyscore(key, 0, now - self._window)
        pipe.zcard(key)
        pipe.zadd(key, {str(now): now})
        pipe.expire(key, self._window)
        results = await pipe.execute()
        count = results[1] if len(results) > 1 else 0
        return count <= self._max


async def session_set(session_id: str, data: dict, ttl: int = 3600) -> bool:
    """Store a session dict in Redis."""
    return await cache_set(f"session:{session_id}", data, ttl)


async def session_get(session_id: str) -> Optional[dict]:
    """Retrieve a session dict from Redis."""
    return await cache_get(f"session:{session_id}")


async def session_delete(session_id: str) -> int:
    """Delete a session from Redis."""
    return await cache_delete(f"session:{session_id}")
