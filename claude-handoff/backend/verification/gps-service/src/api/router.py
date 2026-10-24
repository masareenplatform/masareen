"""GPS Service API endpoints, uses CQRS command/query bus with proper DI."""
from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, AsyncGenerator
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.base_repository.db import build_engine, build_session_factory
from sqlalchemy.ext.asyncio import AsyncSession
from ..application.commands import CaptureGPSCommand, MarkGPSUploadedCommand, SubmitGPSForReviewCommand, RecordGPSVerificationCommand
from ..application.handlers import CaptureGPSHandler, MarkGPSUploadedHandler, SubmitGPSForReviewHandler, RecordGPSVerificationHandler, GetGPSHandler, GetGPSByTaskHandler
from ..infrastructure.postgres_repository import PostgresGPSRepository
from ..queries import GetGPSQuery, GetGPSByTaskQuery

log = get_logger(__name__)
router = APIRouter(prefix="/gps", tags=["GPS"])

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
    repo = PostgresGPSRepository(session, outbox)
    bus.register(CaptureGPSCommand, CaptureGPSHandler(repo, outbox, session))
    bus.register(MarkGPSUploadedCommand, MarkGPSUploadedHandler(repo, outbox, session))
    bus.register(SubmitGPSForReviewCommand, SubmitGPSForReviewHandler(repo, outbox, session))
    bus.register(RecordGPSVerificationCommand, RecordGPSVerificationHandler(repo, outbox, session))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = PostgresGPSRepository(session, OutboxWriter())
    bus.register(GetGPSQuery, GetGPSHandler(repo))
    bus.register(GetGPSByTaskQuery, GetGPSByTaskHandler(repo))
    return bus


class CaptureGPSRequest(BaseModel):
    task_id: str
    submitted_by: str
    media_type: str = "GPS_TRACK"
    file_size_bytes: int = 0
    mime_type: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)


class MarkUploadedRequest(BaseModel):
    gps_id: str
    storage_url: str
    checksum: str
    thumbnail_url: Optional[str] = None


class SubmitForReviewRequest(BaseModel):
    gps_id: str
    submitted_by: str


class RecordVerificationRequest(BaseModel):
    gps_id: str
    verifier_type: str = "AI"
    verdict: str = "APPROVED"
    confidence: float = Field(default=1.0, ge=0, le=1)
    notes: Optional[str] = None


@router.post("/capture", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def capture_gps(body: CaptureGPSRequest, bus: CommandBus = Depends(get_command_bus)):
    log.info("gps_capture_requested", task_id=body.task_id, submitted_by=body.submitted_by)
    cmd = CaptureGPSCommand(
        task_id=body.task_id,
        submitted_by=body.submitted_by,
        media_type=body.media_type,
        file_size_bytes=body.file_size_bytes,
        mime_type=body.mime_type,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)


@router.post("/uploaded", response_model=ApiResponse[dict])
async def mark_uploaded(body: MarkUploadedRequest, bus: CommandBus = Depends(get_command_bus)):
    log.info("gps_mark_uploaded", gps_id=body.gps_id)
    cmd = MarkGPSUploadedCommand(
        gps_id=body.gps_id,
        storage_url=body.storage_url,
        checksum=body.checksum,
        thumbnail_url=body.thumbnail_url,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)


@router.post("/submit-review", response_model=ApiResponse[dict])
async def submit_for_review(body: SubmitForReviewRequest, bus: CommandBus = Depends(get_command_bus)):
    log.info("gps_submit_review", gps_id=body.gps_id)
    cmd = SubmitGPSForReviewCommand(gps_id=body.gps_id, submitted_by=body.submitted_by)
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)


@router.post("/verify", response_model=ApiResponse[dict])
async def record_gps_verification(body: RecordVerificationRequest, bus: CommandBus = Depends(get_command_bus)):
    log.info("gps_verification_requested", gps_id=body.gps_id, verdict=body.verdict)
    cmd = RecordGPSVerificationCommand(
        gps_id=body.gps_id,
        verifier_type=body.verifier_type,
        verdict=body.verdict,
        confidence=body.confidence,
        notes=body.notes,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)


@router.get("/{gps_id}", response_model=ApiResponse[dict])
async def get_gps_record(gps_id: str, bus: QueryBus = Depends(get_query_bus)):
    log.info("get_gps_record", gps_id=gps_id)
    query = GetGPSQuery(gps_id=gps_id)
    result = await bus.dispatch(query)
    if not result:
        raise HTTPException(status_code=404, detail="GPS record not found")
    return ApiResponse.ok(result)


@router.get("/task/{task_id}", response_model=ApiResponse[list])
async def list_gps_by_task(task_id: str, bus: QueryBus = Depends(get_query_bus)):
    log.info("list_gps_by_task", task_id=task_id)
    query = GetGPSByTaskQuery(task_id=task_id)
    results = await bus.dispatch(query)
    return ApiResponse.ok(results)
