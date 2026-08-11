from unittest.mock import AsyncMock, MagicMock
import pytest

from src.domain.evidence import Evidence
from src.application.commands import (
    CaptureEvidenceCommand, MarkEvidenceUploadedCommand,
    RecordVerificationCommand,
)
from src.application.handlers import (
    CaptureEvidenceHandler, MarkUploadedHandler,
    RecordVerificationHandler,
)
from shared.exceptions import NotFoundException


class TestCaptureEvidenceHandler:
    @pytest.mark.asyncio
    async def test_capture_evidence_handler(self):
        cmd = CaptureEvidenceCommand(
            task_id="task-1",
            submitted_by="user-1",
            media_type="PHOTO",
            file_size_bytes=2048,
            mime_type="image/jpeg",
            latitude=25.0,
            longitude=55.0,
        )
        mock_repo = MagicMock()
        mock_repo.save = AsyncMock(side_effect=lambda ev: ev)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()

        handler = CaptureEvidenceHandler(mock_repo, mock_outbox)
        result = await handler.handle(cmd)

        assert "evidence_id" in result
        assert isinstance(result["evidence_id"], str)
        assert result["status"] == "CAPTURED"
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestMarkUploadedHandler:
    @pytest.mark.asyncio
    async def test_mark_uploaded_handler(self):
        ev = Evidence.capture("task-1", "user-1", "PHOTO", 2048)
        ev.pull_domain_events()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=ev)
        mock_repo.find_by_checksum = AsyncMock(return_value=None)
        mock_repo.save = AsyncMock(side_effect=lambda e: e)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()

        handler = MarkUploadedHandler(mock_repo, mock_outbox)
        cmd = MarkEvidenceUploadedCommand(
            evidence_id=ev.id,
            storage_url="http://example.com/img.jpg",
            checksum="abc123",
        )
        result = await handler.handle(cmd)

        assert result["evidence_id"] == ev.id
        assert result["status"] == "PENDING"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.find_by_checksum.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_mark_uploaded_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_repo.find_by_checksum = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()

        handler = MarkUploadedHandler(mock_repo, mock_outbox)
        cmd = MarkEvidenceUploadedCommand(
            evidence_id="nonexistent",
            storage_url="http://example.com/img.jpg",
            checksum="abc123",
        )
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)


class TestRecordVerificationHandler:
    @pytest.mark.asyncio
    async def test_record_verification_handler(self):
        ev = Evidence.capture("task-1", "user-1", "PHOTO", 2048)
        ev.pull_domain_events()
        ev.mark_uploaded("http://example.com/img.jpg", "abc123")
        ev.pull_domain_events()
        ev.submit_for_review()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=ev)
        mock_repo.save = AsyncMock(side_effect=lambda e: e)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()

        handler = RecordVerificationHandler(mock_repo, mock_outbox)
        cmd = RecordVerificationCommand(
            evidence_id=ev.id,
            verifier_type="AI",
            verdict="APPROVED",
            confidence=0.95,
            verifier_id="ver-1",
            notes="Looks good",
        )
        result = await handler.handle(cmd)

        assert result["evidence_id"] == ev.id
        assert result["verdict"] == "APPROVED"
        assert result["status"] == "APPROVED"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_record_verification_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()

        handler = RecordVerificationHandler(mock_repo, mock_outbox)
        cmd = RecordVerificationCommand(
            evidence_id="nonexistent",
            verifier_type="AI",
            verdict="APPROVED",
            confidence=0.95,
        )
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)
