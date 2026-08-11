"""Submission service health checks."""
from typing import List
from shared.utils.health import HealthCheck, HealthStatus
from shared.utils.logging import get_logger
from shared.base_repository.db import build_engine, build_session_factory
from sqlalchemy import text

log = get_logger(__name__)


class SubmissionHealthCheck(HealthCheck):
    """Health check for submission service."""

    async def perform(self) -> HealthStatus:
        try:
            engine = build_engine()
            session_factory = build_session_factory(engine)
            async with session_factory() as session:
                await session.execute(text("SELECT 1"))
            return HealthStatus(
                name="submission_service",
                status="healthy",
                details={"database": "connected", "kafka": "configured", "outbox": "available"}
            )
        except Exception as e:
            log.error("health_check_failed", error=str(e))
            return HealthStatus(
                name="submission_service",
                status="unhealthy",
                details={"error": str(e)}
            )

    def get_dependencies(self) -> List[HealthCheck]:
        return []


__all__ = ["SubmissionHealthCheck"]
