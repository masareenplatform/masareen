import pytest
from src.domain.verification_pipeline import VerificationPipeline, PipelineStatus
from shared.events.verification_events import PipelineCreated
from shared.exceptions import ConflictException


class TestVerificationPipeline:
    def test_create_pipeline(self):
        pipeline = VerificationPipeline.create(
            evidence_id="ev-1",
            task_id="task-1",
            submitted_by="user-1",
        )
        assert pipeline.evidence_id == "ev-1"
        assert pipeline.task_id == "task-1"
        assert pipeline.submitted_by == "user-1"
        assert pipeline.status == PipelineStatus.QUEUED
        assert pipeline.pipeline_id is not None
        events = pipeline.pull_domain_events()
        assert len(events) == 1
        assert isinstance(events[0], PipelineCreated)

    def test_start_ai_review(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        pipeline.start_processing()
        pipeline.start_ai_review()
        assert pipeline.status == PipelineStatus.AI_REVIEW

    def test_start_fraud_check(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        pipeline.start_processing()
        pipeline.start_ai_review()
        pipeline.record_ai_result(verdict="APPROVED", confidence=0.50)
        assert pipeline.status == PipelineStatus.FRAUD_CHECK

    def test_start_human_review(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        pipeline.start_processing()
        pipeline.start_ai_review()
        pipeline.record_ai_result(verdict="REJECTED", confidence=0.50)
        assert pipeline.status == PipelineStatus.HUMAN_REVIEW

    def test_approve(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        pipeline.start_processing()
        pipeline.start_ai_review()
        pipeline.record_ai_result(verdict="REJECTED", confidence=0.50)
        pipeline.assign_reviewer("reviewer-1")
        pipeline.record_human_verdict(
            verdict="APPROVED",
            reviewer_id="reviewer-1",
            confidence=0.95,
        )
        assert pipeline.status == PipelineStatus.APPROVED
        assert pipeline.final_verdict == "APPROVED"

    def test_reject(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        pipeline.start_processing()
        pipeline.start_ai_review()
        pipeline.record_ai_result(verdict="REJECTED", confidence=0.50)
        pipeline.assign_reviewer("reviewer-1")
        pipeline.record_human_verdict(
            verdict="REJECTED",
            reviewer_id="reviewer-1",
            confidence=0.95,
        )
        assert pipeline.status == PipelineStatus.REJECTED
        assert pipeline.final_verdict == "REJECTED"

    def test_invalid_transition_raises(self):
        pipeline = VerificationPipeline.create("ev-1", "task-1", "user-1")
        with pytest.raises(ConflictException):
            pipeline.start_ai_review()
