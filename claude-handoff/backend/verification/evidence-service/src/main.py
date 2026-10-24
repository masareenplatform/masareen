"""Evidence Service, application entrypoint.

Wires the REAL PostgreSQL-backed API (``src.api``) instead of the previous
fabricated in-memory implementation. All evidence records are persisted via the
event-sourced ``PostgresEvidenceRepository``; health probes run real DB checks.
"""

from __future__ import annotations

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

from shared.utils.app_factory import create_app
from shared.utils.logging import get_logger

from .api import router

log = get_logger(__name__)

app = create_app(
    "evidence-service",
    "0.1.0",
    "Evidence capture, upload, lifecycle, and verification recording."
)

app.include_router(router)


@app.on_event("startup")
async def startup_event():
    log.info("Evidence Service starting up")
    log.info("Evidence Service started successfully")


@app.on_event("shutdown")
async def shutdown_event():
    log.info("Evidence Service shutting down")
    log.info("Evidence Service shut down successfully")


__all__ = ["app"]
