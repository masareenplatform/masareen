"""Media service application handlers."""
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.exceptions import NotFoundException
from ..domain.media_asset import MediaAsset
from ..infrastructure.media_repository_impl import MediaRepositoryImpl
from ..events.media_events import MediaUploaded
from .commands import CreateUploadSlotCommand, UploadMediaCommand, ProcessMediaCommand, DeleteMediaCommand

log = get_logger(__name__)
T_MEDIA_UPLOADED = "masaren.verification.media_uploaded.v1"
T_MEDIA_DELETED = "masaren.verification.media_deleted.v1"


class CreateUploadSlotHandler(CommandHandler):
    def __init__(self, repo: MediaRepositoryImpl, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: CreateUploadSlotCommand) -> dict:
        asset = MediaAsset.create_upload_slot(
            owner_id=cmd.owner_id,
            mime_type=cmd.mime_type,
            file_size_bytes=cmd.file_size_bytes,
            evidence_id=cmd.evidence_id,
            original_filename=cmd.original_filename,
        )
        saved = await self._repo.save(asset)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_MEDIA_UPLOADED)
        log.info("upload_slot_created", asset_id=saved.id, owner=cmd.owner_id, mime=cmd.mime_type)
        return {"asset_id": saved.id, "status": saved.processing_status.value}


class UploadMediaHandler(CommandHandler):
    def __init__(self, repo: MediaRepositoryImpl, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: UploadMediaCommand) -> dict:
        asset = await self._repo.get_by_id(cmd.asset_id)
        if not asset:
            raise NotFoundException("MediaAsset", cmd.asset_id)
        asset.mark_uploaded(storage_key=cmd.storage_key or cmd.asset_id, checksum=cmd.checksum or "")
        saved = await self._repo.save(asset)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_MEDIA_UPLOADED)
        log.info("media_uploaded", asset_id=cmd.asset_id)
        return {"asset_id": saved.id, "status": saved.processing_status.value}


class ProcessMediaHandler(CommandHandler):
    def __init__(self, repo: MediaRepositoryImpl, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: ProcessMediaCommand) -> dict:
        asset = await self._repo.get_by_id(cmd.asset_id)
        if not asset:
            raise NotFoundException("MediaAsset", cmd.asset_id)
        asset.mark_ready(
            cdn_url=cmd.cdn_url,
            thumbnail_url=cmd.thumbnail_url,
            width=cmd.width,
            height=cmd.height,
            duration_seconds=cmd.duration_seconds,
        )
        saved = await self._repo.save(asset)
        log.info("media_processed", asset_id=cmd.asset_id, cdn_url=cmd.cdn_url)
        return {"asset_id": saved.id, "status": saved.processing_status.value}


class DeleteMediaHandler(CommandHandler):
    def __init__(self, repo: MediaRepositoryImpl, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: DeleteMediaCommand) -> dict:
        asset = await self._repo.get_by_id(cmd.asset_id)
        if not asset:
            raise NotFoundException("MediaAsset", cmd.asset_id)
        asset.mark_failed("Deleted by user request")
        await self._repo.delete(cmd.asset_id)
        log.info("media_deleted", asset_id=cmd.asset_id)
        return {"asset_id": cmd.asset_id, "status": "DELETED"}
