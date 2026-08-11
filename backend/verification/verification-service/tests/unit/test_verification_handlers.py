import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from src.application.handlers import (
    StartVerificationPipelineHandler,
    RecordAIVerificationHandler,
    StartFraudCheckHandler,
    RecordHumanVerdictHandler,
    SubmitVerificationHandler,
)
from src.application.commands import (
    StartVerificationPipelineCommand,
    RecordAIVerificationResultCommand,
    StartFraudCheckCommand,
    RecordHumanVerdictCommand,
    SubmitVerificationCommand,
)
from src.domain.evidence_record import EvidenceRecord, EvidenceStatus
from src.domain.verification_pipeline import VerificationPipeline, PipelineStatus
from shared.exceptions import NotFoundException, ConflictException


@pytest.mark.asyncio
async def test_start_verification_pipeline_handler():
    evidence = EvidenceRecord(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
        status=EvidenceStatus.UPLOADED,
        media_type="PHOTO",
        file_size_bytes=1024,
    )
    evidence_repo = MagicMock()
    evidence_repo.get_by_id = AsyncMock(return_value=evidence)

    pipeline_repo = MagicMock()
    pipeline_repo.save = AsyncMock(side_effect=lambda p: p)

    outbox = MagicMock()
    outbox.write = AsyncMock()

    mock_session = MagicMock()

    handler = StartVerificationPipelineHandler(evidence_repo, pipeline_repo, outbox)

    cmd = StartVerificationPipelineCommand(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
    )

    result = await handler.handle(cmd)

    assert "pipeline_id" in result
    assert result["status"] == "QUEUED"
    evidence_repo.get_by_id.assert_awaited_once_with("ev-1")
    pipeline_repo.save.assert_awaited_once()
    outbox.write.assert_awaited()


@pytest.mark.asyncio
async def test_record_ai_verification_handler():
    evidence = EvidenceRecord(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
        status=EvidenceStatus.UPLOADED,
        media_type="PHOTO",
        file_size_bytes=1024,
    )
    evidence_repo = MagicMock()
    evidence_repo.get_by_id = AsyncMock(return_value=evidence)
    evidence_repo.save = AsyncMock(side_effect=lambda e: e)

    pipeline_repo = MagicMock()

    outbox = MagicMock()
    outbox.write = AsyncMock()

    mock_session = MagicMock()

    handler = RecordAIVerificationHandler(evidence_repo, pipeline_repo, outbox)

    cmd = RecordAIVerificationResultCommand(
        pipeline_id="pipe-1",
        evidence_id="ev-1",
        verdict="APPROVED",
        confidence=0.95,
    )

    result = await handler.handle(cmd)

    assert result["evidence_id"] == "ev-1"
    assert result["verdict"] == "APPROVED"
    evidence_repo.get_by_id.assert_awaited_once_with("ev-1")
    evidence_repo.save.assert_awaited_once()


@pytest.mark.asyncio
async def test_start_fraud_check_handler():
    pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
    pipeline.start_processing()
    pipeline.start_ai_review()

    pipeline_repo = MagicMock()
    pipeline_repo.get_by_id = AsyncMock(return_value=pipeline)
    pipeline_repo.save = AsyncMock(side_effect=lambda p: p)

    evidence = EvidenceRecord(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
        status=EvidenceStatus.UPLOADED,
        media_type="PHOTO",
        file_size_bytes=1024,
    )
    evidence_repo = MagicMock()
    evidence_repo.get_by_id = AsyncMock(return_value=evidence)

    mock_session = MagicMock()

    handler = StartFraudCheckHandler(pipeline_repo, evidence_repo)
    handler.outbox = MagicMock()

    cmd = StartFraudCheckCommand(
        pipeline_id=pipeline.pipeline_id,
        evidence_id="ev-1",
    )

    result = await handler.handle(cmd)

    assert "status" in result
    assert "risk_score" in result
    pipeline_repo.get_by_id.assert_awaited_once_with(pipeline.pipeline_id)
    evidence_repo.get_by_id.assert_awaited_once_with("ev-1")
    pipeline_repo.save.assert_awaited_once()


@pytest.mark.asyncio
async def test_record_human_verdict_handler():
    evidence = EvidenceRecord(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
        status=EvidenceStatus.UNDER_REVIEW,
        media_type="PHOTO",
        file_size_bytes=1024,
    )
    evidence_repo = MagicMock()
    evidence_repo.get_by_id = AsyncMock(return_value=evidence)
    evidence_repo.save = AsyncMock(side_effect=lambda e: e)

    pipeline = MagicMock()
    pipeline_repo = MagicMock()
    pipeline_repo.get_by_id = AsyncMock(return_value=pipeline)

    outbox = MagicMock()
    outbox.write = AsyncMock()

    mock_session = MagicMock()

    handler = RecordHumanVerdictHandler(evidence_repo, pipeline_repo, outbox)

    cmd = RecordHumanVerdictCommand(
        pipeline_id="pipe-1",
        evidence_id="ev-1",
        verdict="APPROVED",
        reviewer_id="reviewer-1",
        confidence=0.95,
    )

    result = await handler.handle(cmd)

    assert result["evidence_id"] == "ev-1"
    assert result["final_verdict"] == "APPROVED"
    assert result["status"] == "APPROVED"
    evidence_repo.get_by_id.assert_awaited_once_with("ev-1")
    pipeline_repo.get_by_id.assert_awaited_once_with("pipe-1")
    evidence_repo.save.assert_awaited_once()
    outbox.write.assert_awaited()


@pytest.mark.asyncio
async def test_submit_verification_handler():
    evidence = EvidenceRecord(
        evidence_id="ev-1",
        task_id="task-1",
        submitted_by="user-1",
        status=EvidenceStatus.UPLOADED,
        media_type="PHOTO",
        file_size_bytes=1024,
    )
    evidence_repo = MagicMock()
    evidence_repo.get_by_id = AsyncMock(return_value=evidence)
    evidence_repo.save = AsyncMock(side_effect=lambda e: e)

    mock_session = MagicMock()

    handler = SubmitVerificationHandler(evidence_repo)

    cmd = SubmitVerificationCommand(
        pipeline_id="pipe-1",
        evidence_id="ev-1",
        submitted_by="user-1",
    )

    result = await handler.handle(cmd)

    assert result["evidence_id"] == "ev-1"
    assert result["status"] == "UNDER_REVIEW"
    evidence_repo.get_by_id.assert_awaited_once_with("ev-1")
    evidence_repo.save.assert_awaited_once()
