"""Audit service command and query handlers."""
from uuid import uuid4
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from sqlalchemy.ext.asyncio import AsyncSession
from shared.exceptions import NotFoundException
from ..domain.audit_record import AuditRecord, AuditEventType
from ..domain.audit_repository import AuditRepository
from ..domain.review_queue import ReviewQueueItem, ReviewStatus
from ..domain.review_repository import ReviewQueueRepository
from .commands import (
    RecordAuditEventCommand, ExportAuditTrailCommand,
    RouteToReviewCommand, ResolveReviewCommand
)
from .queries import GetAuditTrailQuery, GetPendingReviewsQuery

log = get_logger(__name__)
T_AUDIT_RECORDED = "masaren.verification.audit_recorded.v1"


class RecordAuditEventHandler(CommandHandler):
    def __init__(self, repo: AuditRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: RecordAuditEventCommand) -> dict:
        try:
            event_type = AuditEventType(cmd.event_type)
        except ValueError:
            event_type = AuditEventType.SUBMISSION_CREATED

        record = AuditRecord.record(
            event_type=event_type,
            aggregate_type=cmd.aggregate_type,
            aggregate_id=cmd.aggregate_id,
            actor_id=cmd.actor_id,
            action=cmd.action,
            details=cmd.details,
            source_service=cmd.source_service,
        )
        saved = await self._repo.save(record)
        log.info("audit_event_recorded", event_type=cmd.event_type, aggregate_id=cmd.aggregate_id)
        return {"record_id": saved.id, "event_type": cmd.event_type, "created_at": saved.created_at.isoformat()}


class ExportAuditTrailHandler(CommandHandler):
    def __init__(self, repo: AuditRepository, outbox: OutboxWriter, session: AsyncSession):
        self._repo = repo
        self._outbox = outbox
        self._session = session

    async def handle(self, cmd: ExportAuditTrailCommand) -> dict:
        records = await self._repo.list_by_aggregate(cmd.aggregate_id)
        return {
            "aggregate_id": cmd.aggregate_id,
            "total_events": len(records),
            "events": [r.to_dict() for r in records],
        }


class RouteToReviewHandler(CommandHandler):
    def __init__(self, repo: ReviewQueueRepository):
        self._repo = repo

    async def handle(self, cmd: RouteToReviewCommand) -> dict:
        item = ReviewQueueItem(
            id=str(uuid4()),
            entity_id=cmd.entity_id,
            entity_type=cmd.entity_type,
            confidence_score=cmd.confidence_score,
            status=ReviewStatus.PENDING,
        )
        saved = await self._repo.add_item(item)
        log.info("routed_to_review", entity_id=cmd.entity_id, entity_type=cmd.entity_type)
        return {
            "review_id": saved.id,
            "entity_id": saved.entity_id,
            "entity_type": saved.entity_type,
            "status": saved.status.value,
        }


class ResolveReviewHandler(CommandHandler):
    def __init__(self, repo: ReviewQueueRepository):
        self._repo = repo

    async def handle(self, cmd: ResolveReviewCommand) -> dict:
        item = await self._repo.get_by_id(cmd.review_id)
        if not item:
            raise NotFoundException(f"Review {cmd.review_id} not found")

        try:
            verdict = ReviewStatus(cmd.verdict)
        except ValueError:
            raise NotFoundException(f"Invalid verdict: {cmd.verdict}")

        item.resolve(admin_id=cmd.admin_id, verdict=verdict, comments=cmd.comments)
        saved = await self._repo.save(item)
        log.info("review_resolved", review_id=cmd.review_id, verdict=cmd.verdict)
        return {
            "review_id": saved.id,
            "status": saved.status.value,
            "resolved_at": saved.resolved_at.isoformat() if saved.resolved_at else None,
        }


class GetAuditTrailHandler(QueryHandler):
    def __init__(self, repo: AuditRepository):
        self._repo = repo

    async def handle(self, query: GetAuditTrailQuery):
        records = await self._repo.list_by_aggregate(query.aggregate_id)
        return records


class GetPendingReviewsHandler(QueryHandler):
    def __init__(self, repo: ReviewQueueRepository):
        self._repo = repo

    async def handle(self, query: GetPendingReviewsQuery):
        return await self._repo.get_pending(limit=query.limit, offset=query.offset)
