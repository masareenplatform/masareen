import pytest
from unittest.mock import AsyncMock, MagicMock
from src.application.handlers import RecordAuditEventHandler, ExportAuditTrailHandler
from src.application.commands import RecordAuditEventCommand, ExportAuditTrailCommand
from src.domain.audit_record import AuditRecord, AuditEventType


class TestRecordAuditEventHandler:
    @pytest.mark.asyncio
    async def test_record_audit_event_handler(self):
        repo = AsyncMock(spec=[])
        repo.save = AsyncMock()
        outbox = AsyncMock()
        session = AsyncMock()

        saved_record = AuditRecord.record(
            event_type=AuditEventType.SUBMISSION_CREATED,
            aggregate_type="submission",
            aggregate_id="agg-1",
            actor_id="user-1",
            action="CREATE",
        )
        repo.save.return_value = saved_record

        handler = RecordAuditEventHandler(repo, outbox, session)
        cmd = RecordAuditEventCommand(
            event_type="SUBMISSION_CREATED",
            aggregate_type="submission",
            aggregate_id="agg-1",
            actor_id="user-1",
            action="CREATE",
            details={},
            source_service="test",
        )
        result = await handler.handle(cmd)
        repo.save.assert_awaited_once()
        assert result["event_type"] == "SUBMISSION_CREATED"
        assert result["record_id"] == "agg-1"


class TestExportAuditTrailHandler:
    @pytest.mark.asyncio
    async def test_export_audit_trail_handler(self):
        repo = AsyncMock(spec=[])
        repo.list_by_aggregate = AsyncMock()
        outbox = AsyncMock()
        session = AsyncMock()

        records = [
            AuditRecord.record(
                event_type=AuditEventType.SUBMISSION_CREATED,
                aggregate_type="submission",
                aggregate_id="agg-1",
                actor_id="user-1",
                action="CREATE",
            ),
            AuditRecord.record(
                event_type=AuditEventType.SUBMISSION_SUBMITTED,
                aggregate_type="submission",
                aggregate_id="agg-1",
                actor_id="user-1",
                action="SUBMIT",
            ),
        ]
        repo.list_by_aggregate.return_value = records

        handler = ExportAuditTrailHandler(repo, outbox, session)
        cmd = ExportAuditTrailCommand(aggregate_id="agg-1")
        result = await handler.handle(cmd)
        repo.list_by_aggregate.assert_awaited_once_with("agg-1")
        assert result["aggregate_id"] == "agg-1"
        assert result["total_events"] == 2
        assert len(result["events"]) == 2
