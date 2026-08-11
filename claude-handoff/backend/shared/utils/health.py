"""
Standardised health check framework.
Every MASAREN service exposes GET /health with consistent response schema.
Kubernetes readiness and liveness probes depend on this.
"""
from __future__ import annotations
import asyncio
from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional
import time


class HealthStatus(str, Enum):
    HEALTHY   = "healthy"
    DEGRADED  = "degraded"
    UNHEALTHY = "unhealthy"


@dataclass
class ComponentHealth:
    name: str
    status: HealthStatus
    latency_ms: float = 0.0
    error: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class HealthReport:
    service: str
    status: HealthStatus
    timestamp: str
    version: str = "0.1.0"
    components: List[ComponentHealth] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "service": self.service,
            "status": self.status,
            "timestamp": self.timestamp,
            "version": self.version,
            "components": [
                {
                    "name": c.name,
                    "status": c.status,
                    "latency_ms": round(c.latency_ms, 2),
                    "error": c.error,
                    "metadata": c.metadata,
                }
                for c in self.components
            ],
        }


class HealthChecker:
    """Register component checks and run them all on demand."""

    def __init__(self, service_name: str) -> None:
        self.service_name = service_name
        self._checks: Dict[str, Callable] = {}

    def register(self, name: str, check_fn: Callable) -> None:
        """Register an async function that returns True if healthy."""
        self._checks[name] = check_fn

    async def run(self) -> HealthReport:
        results: List[ComponentHealth] = []
        tasks = {name: fn() for name, fn in self._checks.items()}

        for name, coro in tasks.items():
            start = time.monotonic()
            try:
                ok = await asyncio.wait_for(coro, timeout=5.0)
                latency = (time.monotonic() - start) * 1000
                results.append(ComponentHealth(
                    name=name,
                    status=HealthStatus.HEALTHY if ok else HealthStatus.UNHEALTHY,
                    latency_ms=latency,
                ))
            except Exception as exc:
                latency = (time.monotonic() - start) * 1000
                results.append(ComponentHealth(
                    name=name,
                    status=HealthStatus.UNHEALTHY,
                    latency_ms=latency,
                    error=str(exc),
                ))

        overall = HealthStatus.HEALTHY
        if any(c.status == HealthStatus.UNHEALTHY for c in results):
            overall = HealthStatus.UNHEALTHY
        elif any(c.status == HealthStatus.DEGRADED for c in results):
            overall = HealthStatus.DEGRADED

        return HealthReport(
            service=self.service_name,
            status=overall,
            timestamp=datetime.now(timezone.utc).isoformat(),
            components=results,
        )
