"""Evidence Service API — real PostgreSQL-backed endpoints (no fabricated data).

Mirrors the proven pattern used by gps-service: a per-request async session is
injected into the CQRS command/query buses, which dispatch to the real
``PostgresEvidenceRepository`` (event-sourced). Health endpoints run REAL probes
(``SELECT 1`` against Postgres) instead of returning hardcoded "connected".
"""
from __future__ import annotations

from typing import Optional, AsyncGenerator, List

from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from shared.dtos import ApiResponse, VerificationResultRequest
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.base_repository.db import build_engine, build_session_factory

from ..application.commands import (
    CaptureEvidenceCommand,
    MarkEvidenceUploadedCommand,
    RecordVerificationCommand,
)
from ..application.handlers import (
    CaptureEvidenceHandler,
    MarkUploadedHandler,
    RecordVerificationHandler,
)
from ..infrastructure.postgres_repository import PostgresEvidenceRepository
from ..queries import (
    GetEvidenceQuery, FindEvidenceByTaskQuery,
    GetEvidenceByIdHandler, FindEvidenceByTaskHandler,
)

log = get_logger(__name__)

router = APIRouter(prefix="/evidence", tags=["Evidence"])

engine = build_engine()
session_factory = build_session_factory(engine)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    repo = PostgresEvidenceRepository(session, outbox)
    bus.register(CaptureEvidenceCommand, CaptureEvidenceHandler(repo, outbox))
    bus.register(MarkEvidenceUploadedCommand, MarkUploadedHandler(repo, outbox))
    bus.register(RecordVerificationCommand, RecordVerificationHandler(repo, outbox))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = PostgresEvidenceRepository(session, OutboxWriter())
    bus.register(GetEvidenceQuery, GetEvidenceByIdHandler(repo))
    bus.register(FindEvidenceByTaskQuery, FindEvidenceByTaskHandler(repo))
    return bus


# ----- Request models -----
class CaptureRequest(BaseModel):
    task_id: str
    submitted_by: str
    media_type: str
    file_size_bytes: int
    mime_type: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)


class UploadCompleteRequest(BaseModel):
    storage_url: str
    checksum: str
    thumbnail_url: Optional[str] = None

class EvidenceResponse(BaseModel):
    id: str
    task_id: str
    submitted_by: str
    media_type: str
    status: str
    storage_url: Optional[str]
    thumbnail_url: Optional[str]
    file_size_bytes: int
    checksum: Optional[str]
    is_approved: bool


def _to_response(ev) -> EvidenceResponse:
    return EvidenceResponse(
        id=ev.id,
        task_id=ev.task_id,
        submitted_by=ev.submitted_by,
        media_type=ev.media_type.value if hasattr(ev.media_type, "value") else ev.media_type,
        status=ev.status.value if hasattr(ev.status, "value") else ev.status,
        storage_url=ev.storage_url,
        thumbnail_url=getattr(ev, "thumbnail_url", None),
        file_size_bytes=ev.file_size_bytes,
        checksum=ev.checksum,
        is_approved=ev.is_approved,
    )


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def capture_evidence(body: CaptureRequest, bus: CommandBus = Depends(get_command_bus)):
    result = await bus.dispatch(CaptureEvidenceCommand(
        task_id=body.task_id,
        submitted_by=body.submitted_by,
        media_type=body.media_type,
        file_size_bytes=body.file_size_bytes,
        mime_type=body.mime_type,
        latitude=body.latitude,
        longitude=body.longitude,
    ))
    return ApiResponse.ok(result)


@router.patch("/{evidence_id}/upload-complete", response_model=ApiResponse[dict])
async def mark_uploaded(evidence_id: str, body: UploadCompleteRequest,
                        bus: CommandBus = Depends(get_command_bus)):
    result = await bus.dispatch(MarkEvidenceUploadedCommand(
        evidence_id=evidence_id,
        storage_url=body.storage_url,
        checksum=body.checksum,
        thumbnail_url=body.thumbnail_url,
    ))
    return ApiResponse.ok(result)


@router.post("/{evidence_id}/verify", response_model=ApiResponse[dict])
async def record_verification(evidence_id: str, body: VerificationResultRequest,
                               bus: CommandBus = Depends(get_command_bus)):
    result = await bus.dispatch(RecordVerificationCommand(
        evidence_id=evidence_id,
        verifier_type=body.verifier_type,
        verdict=body.verdict,
        confidence=body.confidence,
        verifier_id=body.verifier_id,
        notes=body.notes,
    ))
    return ApiResponse.ok(result)



@router.get("/{evidence_id}", response_model=ApiResponse[EvidenceResponse])
async def get_evidence(evidence_id: str, bus: QueryBus = Depends(get_query_bus)):
    ev = await bus.dispatch(GetEvidenceQuery(evidence_id=evidence_id))
    if ev is None:
        raise HTTPException(status_code=404, detail=f"Evidence {evidence_id} not found")
    return ApiResponse.ok(_to_response(ev))


@router.get("/task/{task_id}", response_model=ApiResponse[list])
async def list_evidence_by_task(task_id: str, bus: QueryBus = Depends(get_query_bus)):
    rows = await bus.dispatch(FindEvidenceByTaskQuery(task_id=task_id))
    return ApiResponse.ok([_to_response(ev) for ev in (rows or [])])


# ----- Real health probes (no fabrication) -----
@router.get("/health", tags=["Health"])
async def health_check():
    from datetime import datetime, timezone
    try:
        async with session_factory() as s:
            await s.execute(__import__("sqlalchemy").text("SELECT 1"))
        db_status = "up"
    except Exception as e:  # pragma: no cover - genuine dependency failure
        log.warning("evidence_health_db_down", error=str(e))
        db_status = "down"
    return {
        "status": "healthy" if db_status == "up" else "degraded",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "evidence-service",
        "version": "0.1.0",
        "checks": {"database": db_status},
    }


@router.get("/health/ready", tags=["Health"])
async def readiness_check():
    from datetime import datetime, timezone
    try:
        async with session_factory() as s:
            await s.execute(__import__("sqlalchemy").text("SELECT 1"))
        db_status = "up"
    except Exception:
        db_status = "down"
    return {
        "status": "ready" if db_status == "up" else "not_ready",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "evidence-service",
        "dependencies": {"database": {"status": db_status}},
    }
