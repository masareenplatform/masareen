from shared.exceptions import NotFoundException, ConflictException
from shared.utils.cqrs import CommandHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.submission import SubmissionBundle
from ..domain.submission_repository import SubmissionRepository
from ..domain.submission import EvidenceItem, GpsLocation
from .commands import (
    CreateSubmissionCommand, ValidateSubmissionCommand,
    SubmitSubmissionCommand, RejectSubmissionCommand, CreatePipelineCommand,
)

log = get_logger(__name__)
T_SUBMISSION_CREATED  = "masaren.verification.submission_created.v1"
T_SUBMISSION_SUBMITTED  = "masaren.verification.submission_submitted.v1"
T_PIPELINE_CREATED    = "masaren.verification.pipeline_created.v1"
T_BUNDLE_REJECTED     = "masaren.verification.bundle_rejected.v1"


class CreateSubmissionHandler(CommandHandler):
    def __init__(self, repo: SubmissionRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: CreateSubmissionCommand) -> dict:
        evidence_items = [EvidenceItem(**item) for item in cmd.evidence_items]
        gps_locations = [GpsLocation(**loc) for loc in cmd.gps_locations]
        bundle = SubmissionBundle.create(cmd.task_id, cmd.submitted_by, evidence_items, gps_locations)
        saved = await self._repo.save(bundle)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_SUBMISSION_CREATED)
        log.info("submission_created", submission_id=saved.id, task_id=saved.task_id)
        return {"submission_id": saved.id, "status": saved.status.value}


class ValidateSubmissionHandler(CommandHandler):
    def __init__(self, repo: SubmissionRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: ValidateSubmissionCommand) -> dict:
        bundle = await self._repo.get_by_id(cmd.submission_id)
        if not bundle:
            raise NotFoundException("SubmissionBundle", cmd.submission_id)
        bundle.validate_bundle()
        saved = await self._repo.save(bundle)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_SUBMISSION_SUBMITTED)
        return {"submission_id": saved.id, "status": saved.status.value, "approval_score": saved.approval_score}


class SubmitSubmissionHandler(CommandHandler):
    def __init__(self, repo: SubmissionRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: SubmitSubmissionCommand) -> dict:
        bundle = await self._repo.get_by_id(cmd.submission_id)
        if not bundle:
            raise NotFoundException("SubmissionBundle", cmd.submission_id)
        bundle.submit()
        saved = await self._repo.save(bundle)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_PIPELINE_CREATED)
        return {"submission_id": saved.id, "status": saved.status.value}


class RejectSubmissionHandler(CommandHandler):
    def __init__(self, repo: SubmissionRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: RejectSubmissionCommand) -> dict:
        bundle = await self._repo.get_by_id(cmd.submission_id)
        if not bundle:
            raise NotFoundException("SubmissionBundle", cmd.submission_id)
        bundle.reject(cmd.rejection_reason)
        saved = await self._repo.save(bundle)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_BUNDLE_REJECTED)
        return {"submission_id": saved.id, "status": saved.status.value}


class CreatePipelineHandler(CommandHandler):
    def __init__(self, repo: SubmissionRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: CreatePipelineCommand) -> dict:
        bundle = await self._repo.get_by_id(cmd.submission_id)
        if not bundle:
            raise NotFoundException("SubmissionBundle", cmd.submission_id)
        bundle.create_verification_pipeline()
        saved = await self._repo.save(bundle)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_PIPELINE_CREATED)
        return {"submission_id": saved.id, "status": saved.status.value}
