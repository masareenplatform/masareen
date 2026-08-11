"""Health checks for verification service."""
from datetime import datetime, timezone
from shared.utils.health import HealthChecker
from shared.utils.logging import get_logger
from shared.base_repository.db import build_engine, build_session_factory
from sqlalchemy import text

log = get_logger(__name__)

_health_checker = HealthChecker("verification-service")


class VerificationHealthChecks:
    """Health check utilities for verification service."""

    @staticmethod
    async def health_check():
        try:
            engine = build_engine()
            session_factory = build_session_factory(engine)
            async with session_factory() as session:
                await session.execute(text("SELECT 1"))
            return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}
        except Exception as e:
            log.error("Health check failed", error=str(e))
            return {"status": "unhealthy", "error": str(e), "timestamp": datetime.now(timezone.utc).isoformat()}

    @staticmethod
    async def liveness_check():
        return {"status": "alive", "timestamp": datetime.now(timezone.utc).isoformat()}

    @staticmethod
    async def readiness_check():
        result = await VerificationHealthChecks.health_check()
        if result["status"] == "healthy":
            return {"status": "ready", "timestamp": result["timestamp"]}
        return {"status": "not_ready", "reason": "Dependencies unhealthy", "timestamp": result["timestamp"]}
