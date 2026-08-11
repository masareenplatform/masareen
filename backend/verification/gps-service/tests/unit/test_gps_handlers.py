from unittest.mock import AsyncMock, MagicMock
import pytest

from src.domain.gps_record import GPSRecord
from src.application.commands import (
    CaptureGPSCommand, MarkGPSUploadedCommand,
    SubmitGPSForReviewCommand, RecordGPSVerificationCommand,
)
from src.application.handlers import (
    CaptureGPSHandler, MarkGPSUploadedHandler,
    SubmitGPSForReviewHandler, RecordGPSVerificationHandler,
)
from shared.exceptions import NotFoundException


class TestCaptureGPSHandler:
    @pytest.mark.asyncio
    async def test_capture_gps_handler(self):
        cmd = CaptureGPSCommand(
            task_id="task-1",
            submitted_by="user-1",
            media_type="PHOTO",
            file_size_bytes=1024,
            mime_type="image/jpeg",
            latitude=25.0,
            longitude=55.0,
        )
        mock_repo = MagicMock()
        mock_repo.save = AsyncMock(side_effect=lambda r: r)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = CaptureGPSHandler(mock_repo, mock_outbox, mock_session)
        result = await handler.handle(cmd)

        assert "gps_id" in result
        assert isinstance(result["gps_id"], str)
        assert result["task_id"] == "task-1"
        assert result["submitted_by"] == "user-1"
        assert result["status"] == "CAPTURED"
        assert result["latitude"] == 25.0
        assert result["longitude"] == 55.0
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestMarkGPSUploadedHandler:
    @pytest.mark.asyncio
    async def test_mark_gps_uploaded_handler(self):
        record = GPSRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.pull_domain_events()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=record)
        mock_repo.save = AsyncMock(side_effect=lambda r: r)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = MarkGPSUploadedHandler(mock_repo, mock_outbox, mock_session)
        cmd = MarkGPSUploadedCommand(
            gps_id=record.id,
            storage_url="http://example.com/gps.gpx",
            checksum="abc123",
        )
        result = await handler.handle(cmd)

        assert result["gps_id"] == record.id
        assert result["status"] == "VALIDATING"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_not_called()

    @pytest.mark.asyncio
    async def test_mark_gps_uploaded_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = MarkGPSUploadedHandler(mock_repo, mock_outbox, mock_session)
        cmd = MarkGPSUploadedCommand(gps_id="nonexistent", storage_url="", checksum="")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)


class TestSubmitGPSForReviewHandler:
    @pytest.mark.asyncio
    async def test_submit_gps_for_review_handler(self):
        record = GPSRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.pull_domain_events()
        record.mark_uploaded("http://example.com/gps.gpx", "abc123")

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=record)
        mock_repo.save = AsyncMock(side_effect=lambda r: r)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = SubmitGPSForReviewHandler(mock_repo, mock_outbox, mock_session)
        cmd = SubmitGPSForReviewCommand(gps_id=record.id, submitted_by="user-1")
        result = await handler.handle(cmd)

        assert result["gps_id"] == record.id
        assert result["status"] == "VALIDATING"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_not_called()

    @pytest.mark.asyncio
    async def test_submit_gps_for_review_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = SubmitGPSForReviewHandler(mock_repo, mock_outbox, mock_session)
        cmd = SubmitGPSForReviewCommand(gps_id="nonexistent", submitted_by="user-1")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)


class TestRecordGPSVerificationHandler:
    @pytest.mark.asyncio
    async def test_record_gps_verification_handler(self):
        record = GPSRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.pull_domain_events()
        record.mark_uploaded("http://example.com/gps.gpx", "abc123")
        record.submit_for_review()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=record)
        mock_repo.save = AsyncMock(side_effect=lambda r: r)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = RecordGPSVerificationHandler(mock_repo, mock_outbox, mock_session)
        cmd = RecordGPSVerificationCommand(
            gps_id=record.id,
            verifier_type="AI",
            verdict="APPROVED",
            confidence=0.95,
            verifier_id="ver-1",
            notes="Good location",
        )
        result = await handler.handle(cmd)

        assert result["gps_id"] == record.id
        assert result["status"] == "VALIDATED"
        assert result["verdict"] == "APPROVED"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_not_called()

    @pytest.mark.asyncio
    async def test_record_gps_verification_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = RecordGPSVerificationHandler(mock_repo, mock_outbox, mock_session)
        cmd = RecordGPSVerificationCommand(
            gps_id="nonexistent",
            verifier_type="AI",
            verdict="APPROVED",
            confidence=0.95,
        )
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)
