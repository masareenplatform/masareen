"""GPS application handlers, both command and query handlers."""
from typing import Optional, List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.gps_record import GPSRecord
from ..domain.gps_repository import GPSRepository
from ..infrastructure.postgres_repository import PostgresGPSRepository
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.exceptions import NotFoundException
from .commands import CaptureGPSCommand, MarkGPSUploadedCommand, SubmitGPSForReviewCommand, RecordGPSVerificationCommand
from ..queries import GetGPSQuery, GetGPSByTaskQuery, GetGPSByUserQuery, GetGPSHistoryQuery

log = get_logger(__name__)
T_GPS_CAPTURED = "masaren.verification.gps_captured.v1"
T_GPS_UPLOADED = "masaren.verification.gps_uploaded.v1"
T_GPS_VERIFIED = "masaren.verification.gps_verified.v1"


class CaptureGPSHandler(CommandHandler):
    def __init__(self, repo: GPSRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: CaptureGPSCommand) -> dict:
        record = GPSRecord.capture(
            task_id=cmd.task_id,
            submitted_by=cmd.submitted_by,
            media_type=cmd.media_type,
            file_size_bytes=cmd.file_size_bytes,
            mime_type=cmd.mime_type,
            latitude=cmd.latitude,
            longitude=cmd.longitude,
        )
        saved = await self._repo.save(record)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_GPS_CAPTURED)
        log.info("gps_captured", gps_id=saved.id, task_id=saved.task_id)
        return {"gps_id": saved.id, "task_id": saved.task_id, "submitted_by": saved.submitted_by,
                "status": saved.status.value, "latitude": saved.latitude, "longitude": saved.longitude}


class MarkGPSUploadedHandler(CommandHandler):
    def __init__(self, repo: GPSRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: MarkGPSUploadedCommand) -> dict:
        record = await self._repo.get_by_id(cmd.gps_id)
        if not record:
            raise NotFoundException("GPSRecord", cmd.gps_id)
        record.mark_uploaded(storage_url=cmd.storage_url, checksum=cmd.checksum, thumbnail_url=cmd.thumbnail_url)
        saved = await self._repo.save(record)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_GPS_UPLOADED)
        log.info("gps_uploaded", gps_id=cmd.gps_id)
        return {"gps_id": saved.id, "status": saved.status.value}


class SubmitGPSForReviewHandler(CommandHandler):
    def __init__(self, repo: GPSRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: SubmitGPSForReviewCommand) -> dict:
        record = await self._repo.get_by_id(cmd.gps_id)
        if not record:
            raise NotFoundException("GPSRecord", cmd.gps_id)
        record.submit_for_review()
        saved = await self._repo.save(record)
        log.info("gps_submitted_for_review", gps_id=cmd.gps_id)
        return {"gps_id": saved.id, "status": saved.status.value}


class RecordGPSVerificationHandler(CommandHandler):
    def __init__(self, repo: GPSRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: RecordGPSVerificationCommand) -> dict:
        record = await self._repo.get_by_id(cmd.gps_id)
        if not record:
            raise NotFoundException("GPSRecord", cmd.gps_id)
        record.record_verification(
            verifier_type=cmd.verifier_type,
            verdict=cmd.verdict,
            confidence=cmd.confidence,
            verifier_id=cmd.verifier_id,
            notes=cmd.notes,
        )
        saved = await self._repo.save(record)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_GPS_VERIFIED)
        log.info("gps_verified", gps_id=cmd.gps_id, verdict=cmd.verdict)
        return {"gps_id": saved.id, "status": saved.status.value, "verdict": cmd.verdict}


class GetGPSHandler(QueryHandler):
    def __init__(self, repository: GPSRepository):
        self.repository = repository

    async def handle(self, query: GetGPSQuery) -> Optional[Dict[str, Any]]:
        gps_record = await self.repository.get_by_id(query.gps_id)
        if not gps_record:
            return None
        return {"id": gps_record.id, "task_id": gps_record.task_id, "status": gps_record.status.value}


class GetGPSByTaskHandler(QueryHandler):
    def __init__(self, repository: GPSRepository):
        self.repository = repository

    async def handle(self, query: GetGPSByTaskQuery) -> List[Dict[str, Any]]:
        gps_records = await self.repository.find_by_task_id(query.task_id)
        return [{"id": r.id, "task_id": r.task_id, "status": r.status.value} for r in gps_records]


class GetGPSByUserHandler(QueryHandler):
    def __init__(self, repository: GPSRepository):
        self.repository = repository

    async def handle(self, query: GetGPSByUserQuery) -> List[Dict[str, Any]]:
        gps_records = await self.repository.find_by_user_id(query.user_id)
        return [{"id": r.id, "task_id": r.task_id, "status": r.status.value} for r in gps_records]


class GetGPSHistoryHandler(QueryHandler):
    def __init__(self, repository: GPSRepository):
        self.repository = repository

    async def handle(self, query: GetGPSHistoryQuery) -> List[Dict[str, Any]]:
        if query.task_id:
            gps_records = await self.repository.find_by_task_id(query.task_id)
            return [{"id": r.id, "task_id": r.task_id, "status": r.status.value} for r in gps_records]
        elif query.user_id:
            gps_records = await self.repository.find_by_user_id(query.user_id)
            return [{"id": r.id, "task_id": r.task_id, "status": r.status.value} for r in gps_records]
        else:
            return []