from unittest.mock import AsyncMock, MagicMock
import pytest

from src.domain.submission import SubmissionBundle, EvidenceItem
from src.application.commands import (
    CreateSubmissionCommand, ValidateSubmissionCommand,
    SubmitSubmissionCommand, RejectSubmissionCommand, CreatePipelineCommand,
)
from src.application.handlers import (
    CreateSubmissionHandler, ValidateSubmissionHandler,
    SubmitSubmissionHandler, RejectSubmissionHandler, CreatePipelineHandler,
)
from shared.exceptions import NotFoundException


class TestCreateSubmissionHandler:
    @pytest.mark.asyncio
    async def test_create_submission_handler(self):
        cmd = CreateSubmissionCommand(
            task_id="task-1",
            submitted_by="user-1",
            evidence_items=[{
                "evidence_id": "ev-1",
                "media_type": "image/jpeg",
                "file_size_bytes": 1000,
                "checksum": "abc123",
                "storage_url": "http://example.com/img.jpg",
                "latitude": 25.0,
                "longitude": 55.0,
            }],
            gps_locations=[{
                "latitude": 25.0,
                "longitude": 55.0,
                "accuracy_meters": 10.0,
                "provider": "GPS",
            }],
        )
        mock_repo = MagicMock()
        mock_repo.save = AsyncMock(side_effect=lambda bundle: bundle)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = CreateSubmissionHandler(mock_repo, mock_outbox, mock_session)
        result = await handler.handle(cmd)

        assert "submission_id" in result
        assert isinstance(result["submission_id"], str)
        assert result["status"] == "DRAFT"
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestValidateSubmissionHandler:
    @pytest.mark.asyncio
    async def test_validate_submission_handler(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.pull_domain_events()  # discard setup events

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=bundle)
        mock_repo.save = AsyncMock(side_effect=lambda b: b)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = ValidateSubmissionHandler(mock_repo, mock_outbox, mock_session)
        cmd = ValidateSubmissionCommand(submission_id=bundle.id)
        result = await handler.handle(cmd)

        assert result["submission_id"] == bundle.id
        assert result["status"] == "VALIDATED"
        assert result["approval_score"] is not None
        assert result["approval_score"] > 0
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_not_called()


class TestSubmitSubmissionHandler:
    @pytest.mark.asyncio
    async def test_submit_submission_handler(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.pull_domain_events()  # discard setup events
        bundle.validate_bundle()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=bundle)
        mock_repo.save = AsyncMock(side_effect=lambda b: b)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = SubmitSubmissionHandler(mock_repo, mock_outbox, mock_session)
        cmd = SubmitSubmissionCommand(submission_id=bundle.id)
        result = await handler.handle(cmd)

        assert result["submission_id"] == bundle.id
        assert result["status"] == "SUBMITTED"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestRejectSubmissionHandler:
    @pytest.mark.asyncio
    async def test_reject_submission_handler(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.pull_domain_events()  # discard setup events

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=bundle)
        mock_repo.save = AsyncMock(side_effect=lambda b: b)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = RejectSubmissionHandler(mock_repo, mock_outbox, mock_session)
        cmd = RejectSubmissionCommand(submission_id=bundle.id, rejection_reason="Bad evidence")
        result = await handler.handle(cmd)

        assert result["submission_id"] == bundle.id
        assert result["status"] == "REJECTED"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestCreatePipelineHandler:
    @pytest.mark.asyncio
    async def test_create_pipeline_handler(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.pull_domain_events()  # discard setup events
        bundle.validate_bundle()
        bundle.pull_domain_events()  # discard validate events
        bundle.submit()
        bundle.pull_domain_events()  # discard submit events

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=bundle)
        mock_repo.save = AsyncMock(side_effect=lambda b: b)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = CreatePipelineHandler(mock_repo, mock_outbox, mock_session)
        cmd = CreatePipelineCommand(submission_id=bundle.id)
        result = await handler.handle(cmd)

        assert result["submission_id"] == bundle.id
        assert result["status"] == "PENDING_VERIFICATION"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestHandlerNotFound:
    @pytest.mark.asyncio
    async def test_handler_raises_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = ValidateSubmissionHandler(mock_repo, mock_outbox, mock_session)
        cmd = ValidateSubmissionCommand(submission_id="nonexistent")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)
