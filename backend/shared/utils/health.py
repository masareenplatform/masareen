"""Health check system for the MASAREN combined backend.

Provides endpoint handlers and helper functions to verify the liveness and
readiness of all backing services: PostgreSQL, Redis, and Kafka.

Usage in combined/main.py:

    from shared.utils.health import health_router
    app.include_router(health_router)

Endpoints:
    GET /health        → lightweight liveness (always 200 if process is up)
    GET /health/ready  → deep readiness (checks every backing service)
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Awaitable, Dict, Optional

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

health_router = APIRouter(tags=["health"])


# ── HealthChecker class (used by app_factory and individual services) ─────────

@dataclass
class ComponentStatus:
    name: str
    healthy: bool
    latency_ms: float = 0.0
    error: Optional[str] = None

    def to_dict(self) -> dict:
        d = {"status": "healthy" if self.healthy else "unhealthy", "latency_ms": self.latency_ms}
        if self.error:
            d["error"] = self.error
        return d


@dataclass
class HealthReport:
    service: str
    status: str
    components: list[ComponentStatus] = field(default_factory=list)
    checked_at: str = ""

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "service": self.service,
            "checked_at": self.checked_at or datetime.now(timezone.utc).isoformat(),
            "components": {c.name: c.to_dict() for c in self.components},
        }


class HealthChecker:
    """Lightweight health checker for individual services.

    Usage:
        health = HealthChecker("my-service")
        health.register("db", check_db_fn)   # async () -> bool

        # In the health endpoint:
        report = await health.run()
        return report.to_dict()
    """

    def __init__(self, service_name: str):
        self._service = service_name
        self._checks: dict[str, Callable[[], Awaitable[bool]]] = {}

    def register(self, name: str, check_fn: Callable[[], Awaitable[bool]]) -> None:
        self._checks[name] = check_fn

    async def run(self) -> HealthReport:
        components: list[ComponentStatus] = []
        all_healthy = True
        for name, fn in self._checks.items():
            start = time.monotonic()
            try:
                healthy = await fn()
            except Exception as exc:
                healthy = False
                error = str(exc)
            else:
                error = None
            latency = round((time.monotonic() - start) * 1000, 2)
            components.append(ComponentStatus(name=name, healthy=healthy, latency_ms=latency, error=error))
            if not healthy:
                all_healthy = False
        return HealthReport(
            service=self._service,
            status="healthy" if all_healthy else "degraded",
            components=components,
        )

# ── Individual service checks ─────────────────────────────────────────────────


async def _check_postgres(request: Request) -> Dict[str, Any]:
    """Ping Postgres via the existing async engine."""
    start = time.monotonic()
    try:
        engine = request.app.state.db_engine
        async with engine.connect() as conn:
            await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
        elapsed_ms = round((time.monotonic() - start) * 1000, 2)
        return {"status": "healthy", "latency_ms": elapsed_ms}
    except Exception as exc:
        elapsed_ms = round((time.monotonic() - start) * 1000, 2)
        return {"status": "unhealthy", "latency_ms": elapsed_ms, "error": str(exc)}


async def _check_redis(request: Request) -> Dict[str, Any]:
    """Ping Redis via the shared singleton client."""
    start = time.monotonic()
    try:
        from shared.utils.redis import get_redis
        r = get_redis()
        pong = await r.ping()
        elapsed_ms = round((time.monotonic() - start) * 1000, 2)
        return {"status": "healthy" if pong else "unhealthy", "latency_ms": elapsed_ms}
    except Exception as exc:
        elapsed_ms = round((time.monotonic() - start) * 1000, 1000)
        return {"status": "unhealthy", "latency_ms": elapsed_ms, "error": str(exc)}


async def _check_kafka(request: Request) -> Dict[str, Any]:
    """Check Kafka connectivity via the bus adapter if available."""
    start = time.monotonic()
    try:
        bus = getattr(request.app.state, "event_bus", None)
        if bus is None:
            return {"status": "unknown", "message": "event_bus not initialised"}
        # Prefer a lightweight metadata/probe call if the bus exposes one
        if hasattr(bus, "health"):
            healthy = await bus.health()
            elapsed_ms = round((time.monotonic() - start) * 1000, 2)
            return {"status": "healthy" if healthy else "unhealthy", "latency_ms": elapsed_ms}
        elapsed_ms = round((time.monotonic() - start) * 1000, 2)
        return {"status": "unknown", "latency_ms": elapsed_ms, "message": "no health probe available"}
    except Exception as exc:
        elapsed_ms = round((time.monotonic() - start) * 1000, 2)
        return {"status": "unhealthy", "latency_ms": elapsed_ms, "error": str(exc)}


# ── Routes ────────────────────────────────────────────────────────────────────

@health_router.get("/health")
async def liveness():
    """Liveness probe — returns 200 if the process is running."""
    return {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()}


@health_router.get("/health/ready")
async def readiness(request: Request):
    """Readiness probe — verifies all backing services are reachable.

    Returns HTTP 200 only when every service reports healthy.
    """
    postgres = await _check_postgres(request)
    redis = await _check_redis(request)
    kafka = await _check_kafka(request)

    all_healthy = (
        postgres.get("status") == "healthy"
        and redis.get("status") == "healthy"
        and kafka.get("status") in ("healthy", "unknown")  # Kafka may be optional
    )

    body: Dict[str, Any] = {
        "status": "ready" if all_healthy else "degraded",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "services": {
            "postgres": postgres,
            "redis": redis,
            "kafka": kafka,
        },
    }

    status_code = 200 if all_healthy else 503
    return JSONResponse(content=body, status_code=status_code)
