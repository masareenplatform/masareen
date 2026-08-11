from shared.exceptions import NotFoundException, ConflictException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.evidence import Evidence
from ..domain.evidence_repository import EvidenceRepository
from .commands import CaptureEvidenceCommand, MarkEvidenceUploadedCommand, SubmitEvidenceForReviewCommand, RecordVerificationCommand

log = get_logger(__name__)
T_CAPTURED  = "masaren.verification.evidence_captured.v1"
T_UPLOADED  = "masaren.verification.evidence_uploaded.v1"
T_VERIFIED  = "masaren.verification.evidence_verified.v1"

class CaptureEvidenceHandler(CommandHandler):
    def __init__(self, repo: EvidenceRepository, outbox: OutboxWriter):
        self._repo = repo
        self._outbox = outbox
    async def handle(self, cmd: CaptureEvidenceCommand) -> dict:
        ev = Evidence.capture(cmd.task_id, cmd.submitted_by, cmd.media_type,
            cmd.file_size_bytes, cmd.mime_type, cmd.latitude, cmd.longitude)
        saved = await self._repo.save(ev)
        for evt in saved.pull_domain_events():
            await self._outbox.write(None, evt, T_CAPTURED)
        log.info("evidence_captured", evidence_id=saved.id, task_id=saved.task_id)
        return {"evidence_id": saved.id, "status": saved.status.value}

class MarkUploadedHandler(CommandHandler):
    def __init__(self, repo: EvidenceRepository, outbox: OutboxWriter):
        self._repo = repo
        self._outbox = outbox
    async def handle(self, cmd: MarkEvidenceUploadedCommand) -> dict:
        # Check for duplicate checksum (fraud signal)
        existing = await self._repo.find_by_checksum(cmd.checksum)
        if existing and existing.id != cmd.evidence_id:
            log.warning("duplicate_checksum_detected", checksum=cmd.checksum,
                existing_id=existing.id, new_id=cmd.evidence_id)
        ev = await self._repo.get_by_id(cmd.evidence_id)
        if not ev: raise NotFoundException("Evidence", cmd.evidence_id)
        ev.mark_uploaded(cmd.storage_url, cmd.checksum, cmd.thumbnail_url)
        ev.submit_for_review()
        saved = await self._repo.save(ev)
        for evt in saved.pull_domain_events():
            await self._outbox.write(None, evt, T_UPLOADED)
        return {"evidence_id": saved.id, "status": saved.status.value}

class RecordVerificationHandler(CommandHandler):
    def __init__(self, repo: EvidenceRepository, outbox: OutboxWriter):
        self._repo = repo
        self._outbox = outbox
    async def handle(self, cmd: RecordVerificationCommand) -> dict:
        ev = await self._repo.get_by_id(cmd.evidence_id)
        if not ev: raise NotFoundException("Evidence", cmd.evidence_id)
        ev.record_verification(cmd.verifier_type, cmd.verdict, cmd.confidence,
            cmd.verifier_id, cmd.notes)
        saved = await self._repo.save(ev)
        for evt in saved.pull_domain_events():
            await self._outbox.write(None, evt, T_VERIFIED)
        log.info("evidence_verified", evidence_id=saved.id, verdict=cmd.verdict)
        return {"evidence_id": saved.id, "verdict": cmd.verdict, "status": saved.status.value}
