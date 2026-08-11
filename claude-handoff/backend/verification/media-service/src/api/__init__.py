from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus
from shared.utils.logging import get_logger
from ..application.commands import CreateUploadSlotCommand, UploadMediaCommand, ProcessMediaCommand, DeleteMediaCommand
from ..application.handlers import (
    CreateUploadSlotHandler, UploadMediaHandler, ProcessMediaHandler, DeleteMediaHandler,
)
from ..infrastructure.media_repository_impl import MediaRepositoryImpl
from shared.base_repository.db import build_engine, build_session_factory
from shared.utils.outbox import OutboxWriter
from sqlalchemy.ext.asyncio import AsyncSession
from typing import AsyncGenerator

log = get_logger(__name__)
router = APIRouter(prefix="/media", tags=["Media"])

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
    repo = MediaRepositoryImpl(session, outbox)
    bus.register(CreateUploadSlotCommand, CreateUploadSlotHandler(repo, outbox, session))
    bus.register(UploadMediaCommand, UploadMediaHandler(repo, outbox, session))
    bus.register(ProcessMediaCommand, ProcessMediaHandler(repo, outbox, session))
    bus.register(DeleteMediaCommand, DeleteMediaHandler(repo, outbox, session))
    return bus


class CreateUploadSlotRequest(BaseModel):
    owner_id: str
    mime_type: str
    file_size_bytes: int = Field(..., gt=0)
    evidence_id: Optional[str] = None
    original_filename: Optional[str] = None


class UploadSlotResponse(BaseModel):
    asset_id: str
    status: str
    expires_in_seconds: int


class ProcessingCallbackRequest(BaseModel):
    asset_id: str
    cdn_url: str
    checksum: str
    thumbnail_url: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration_seconds: Optional[float] = None


@router.post("/upload-slot", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[UploadSlotResponse])
async def create_upload_slot(body: CreateUploadSlotRequest, bus: CommandBus = Depends(get_command_bus)):
    cmd = CreateUploadSlotCommand(
        owner_id=body.owner_id,
        mime_type=body.mime_type,
        file_size_bytes=body.file_size_bytes,
        evidence_id=body.evidence_id,
        original_filename=body.original_filename,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(UploadSlotResponse(
        asset_id=result["asset_id"],
        status=result["status"],
        expires_in_seconds=3600,
    ))


@router.post("/processing/callback", response_model=ApiResponse[dict])
async def processing_callback(body: ProcessingCallbackRequest, bus: CommandBus = Depends(get_command_bus)):
    cmd = ProcessMediaCommand(
        asset_id=body.asset_id,
        cdn_url=body.cdn_url,
        checksum=body.checksum,
        thumbnail_url=body.thumbnail_url,
        width=body.width,
        height=body.height,
        duration_seconds=body.duration_seconds,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)


@router.get("/{asset_id}", response_model=ApiResponse[dict])
async def get_asset(asset_id: str, session: AsyncSession = Depends(get_db_session)):
    repo = MediaRepositoryImpl(session, OutboxWriter())
    asset = await repo.get_by_id(asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    return ApiResponse.ok({
        "id": asset.id,
        "owner_id": asset.owner_id,
        "mime_type": asset.mime_type,
        "file_size_bytes": asset.file_size_bytes,
        "status": asset.processing_status.value,
        "cdn_url": asset.cdn_url,
        "thumbnail_url": asset.thumbnail_url,
        "original_filename": asset.original_filename,
        "width": asset.width,
        "height": asset.height,
    })


@router.delete("/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_asset(asset_id: str, bus: CommandBus = Depends(get_command_bus)):
    cmd = DeleteMediaCommand(asset_id=asset_id)
    await bus.dispatch(cmd)
