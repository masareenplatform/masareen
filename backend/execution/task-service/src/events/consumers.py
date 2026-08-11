"""
Task service event consumers.
Listens for EvidenceVerified → auto-advance task to VERIFIED state.
"""
from __future__ import annotations
from typing import Any, Dict
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.logging import get_logger

log = get_logger(__name__)


class TaskEventConsumer(EventConsumer):
    """
    Consumes: masaren.verification.evidence_verified.v1
    When evidence is APPROVED → auto-verify the associated task.
    """
    def __init__(self, session_factory, publisher):
        super().__init__(
            topics=["masaren.verification.evidence_verified.v1"],
            group_id="task-service-consumer",
        )
        self._session_factory = session_factory

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "EvidenceVerified":
            return
        verdict = payload.get("verdict", "")
        evidence_id = payload.get("aggregate_id") or payload.get("evidence_id")
        if not evidence_id:
            return
        if verdict == "APPROVED":
            await self._auto_verify_task(evidence_id)
        elif verdict == "REJECTED":
            log.info("evidence_rejected_received", evidence_id=evidence_id)

    async def _auto_verify_task(self, evidence_id: str) -> None:
        from ..infrastructure.task_repository_impl import SQLAlchemyTaskRepository
        from ..domain.task_repository import TaskRepository
        from ..application.commands import VerifyTaskCommand
        from ..application.handlers import VerifyTaskHandler
        from shared.utils.outbox import OutboxWriter

        async with self._session_factory() as session:
            repo: TaskRepository = SQLAlchemyTaskRepository(session)
            task = await repo.get_by_evidence_id(evidence_id)
            if not task:
                log.warning("evidence_task_not_found", evidence_id=evidence_id)
                return
            if task.status.value in ("VERIFIED", "COMPLETED"):
                log.info("task_already_verified", task_id=task.id, status=task.status.value)
                return
            handler = VerifyTaskHandler(repo)
            await handler.handle(VerifyTaskCommand(
                task_id=task.id, verified_by="system:verification-pipeline", note="Auto-verified from approved evidence",
            ))
            await session.commit()
            log.info("task_auto_verified", task_id=task.id, evidence_id=evidence_id)
