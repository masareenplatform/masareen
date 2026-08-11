"""Verification Pipeline domain model."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional, Dict, Any
from uuid import uuid4

from shared.base_entity import AggregateRoot
from shared.events.verification_events import PipelineCreated
from shared.exceptions import ValidationException, ConflictException


class PipelineStatus(str, Enum):
    QUEUED = "QUEUED"
    PROCESSING = "PROCESSING"
    AI_REVIEW = "AI_REVIEW"
    FRAUD_CHECK = "FRAUD_CHECK"
    HUMAN_REVIEW = "HUMAN_REVIEW"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"

    @classmethod
    def is_completed(cls, status: PipelineStatus) -> bool:
        return status in (cls.APPROVED, cls.REJECTED, cls.NEEDS_REVISION)

    @classmethod
    def requires_human_review(cls, status: PipelineStatus) -> bool:
        return status in (cls.HUMAN_REVIEW, cls.NEEDS_REVISION)


@dataclass
class PipelineStageResult:
    stage: str
    verdict: str
    confidence: float
    notes: Optional[str] = None
    completed_at: Optional[datetime] = None

    @classmethod
    def ai_review(cls, verdict: str, confidence: float, notes: Optional[str] = None) -> "PipelineStageResult":
        return cls(
            stage="AI_REVIEW",
            verdict=verdict,
            confidence=confidence,
            notes=notes,
            completed_at=datetime.now(timezone.utc)
        )

    @classmethod
    def fraud_check(cls, verdict: str, confidence: float, notes: Optional[str] = None) -> "PipelineStageResult":
        return cls(
            stage="FRAUD_CHECK",
            verdict=verdict,
            confidence=confidence,
            notes=notes,
            completed_at=datetime.now(timezone.utc)
        )

    @classmethod
    def human_review(cls, verdict: str, confidence: float, notes: Optional[str] = None) -> "PipelineStageResult":
        return cls(
            stage="HUMAN_REVIEW",
            verdict=verdict,
            confidence=confidence,
            notes=notes,
            completed_at=datetime.now(timezone.utc)
        )


@dataclass
class VerificationPipeline(AggregateRoot):
    pipeline_id: str = ""
    evidence_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    status: PipelineStatus = PipelineStatus.QUEUED
    stages: List[PipelineStageResult] = field(default_factory=list)
    fraud_risk_score: int = 0
    fraud_risk_details: Optional[str] = None
    final_verdict: Optional[str] = None
    assigned_reviewer: Optional[str] = None
    ai_confidence_threshold: float = 0.80
    fraud_risk_threshold: int = 30
    ai_confidence_score: float = 0.0
    human_verdict: Optional[str] = None

    @classmethod
    def create(cls, evidence_id: str, task_id: str, submitted_by: str,
               ai_confidence_threshold: float = 0.80,
               fraud_risk_threshold: int = 30) -> "VerificationPipeline":
        if not evidence_id:
            raise ValidationException("evidence_id is required")
        if not task_id:
            raise ValidationException("task_id is required")
        if not submitted_by:
            raise ValidationException("submitted_by is required")

        now = datetime.now(timezone.utc)
        pipeline = cls(
            id=str(uuid4()),
            pipeline_id=str(uuid4()),
            evidence_id=evidence_id,
            task_id=task_id,
            submitted_by=submitted_by,
            status=PipelineStatus.QUEUED,
            ai_confidence_threshold=ai_confidence_threshold,
            fraud_risk_threshold=fraud_risk_threshold,
            created_at=now,
            updated_at=now
        )

        pipeline.add_domain_event(PipelineCreated(
            aggregate_id=pipeline.id,
            task_id=task_id,
            submitted_by=submitted_by,
            evidence_items=[{"evidence_id": evidence_id}]
        ))
        return pipeline

    def start_processing(self) -> None:
        if self.status != PipelineStatus.QUEUED:
            raise ConflictException("Pipeline must be in QUEUED state to start processing")
        self.status = PipelineStatus.PROCESSING
        self.updated_at = datetime.now(timezone.utc)

    def start_ai_review(self) -> None:
        if self.status != PipelineStatus.PROCESSING:
            raise ConflictException("Pipeline must be in PROCESSING state to start AI review")
        self.status = PipelineStatus.AI_REVIEW
        self.updated_at = datetime.now(timezone.utc)

    def record_ai_result(self, verdict: str, confidence: float, notes: Optional[str] = None) -> None:
        if self.status != PipelineStatus.AI_REVIEW:
            raise ConflictException("Pipeline must be in AI_REVIEW state to record AI result")

        if confidence < 0.0 or confidence > 1.0:
            raise ValidationException("confidence must be between 0.0 and 1.0")

        self.ai_confidence_score = confidence
        self.stages.append(
            PipelineStageResult.ai_review(verdict, confidence, notes)
        )

        if self.should_proceed_to_fraud_check(confidence, verdict):
            self.status = PipelineStatus.FRAUD_CHECK
        else:
            self.status = PipelineStatus.HUMAN_REVIEW

        self.updated_at = datetime.now(timezone.utc)

    def should_proceed_to_fraud_check(self, confidence: float, verdict: str) -> bool:
        if verdict == "REJECTED":
            return False
        if confidence >= self.ai_confidence_threshold:
            return False
        return True

    def start_fraud_check(self) -> None:
        """Transition AI_REVIEW -> FRAUD_CHECK before recording a fraud result."""
        if self.status != PipelineStatus.FRAUD_CHECK:
            if self.status != PipelineStatus.AI_REVIEW:
                raise ConflictException("Pipeline must be in AI_REVIEW state to start fraud check")
            self.status = PipelineStatus.FRAUD_CHECK
            self.updated_at = datetime.now(timezone.utc)

    def record_fraud_result(self, risk_score: int, verdict: str, notes: Optional[str] = None) -> None:
        if self.status != PipelineStatus.FRAUD_CHECK:
            raise ConflictException("Pipeline must be in FRAUD_CHECK state to record fraud result")
        
        if risk_score < 0 or risk_score > 100:
            raise ValidationException("risk_score must be between 0 and 100")
        
        self.fraud_risk_score = risk_score
        self.fraud_risk_details = notes
        self.stages.append(
            PipelineStageResult.fraud_check(verdict, 1.0 - risk_score / 100.0, notes)
        )
        
        # Move logic from handler to domain
        risk_factors = []
        # This logic is conceptually handled by the AI/Fraud agent, but the domain manages the state
        if self.should_route_to_human_review(risk_score, verdict):
            self.status = PipelineStatus.HUMAN_REVIEW
            self.assign_reviewer("auto-assigned-reviewer")
        else:
            self.finalize_pipeline(verdict)
        
        self.updated_at = datetime.now(timezone.utc)


    def should_route_to_human_review(self, risk_score: int, verdict: str) -> bool:
        if verdict == "REJECTED":
            return False
        if risk_score > self.fraud_risk_threshold:
            return True
        return False

    def assign_reviewer(self, reviewer_id: str) -> None:
        self.assigned_reviewer = reviewer_id
        self.updated_at = datetime.now(timezone.utc)

    def record_human_verdict(self, verdict: str, reviewer_id: str, confidence: float,
                             notes: Optional[str] = None) -> None:
        if self.status != PipelineStatus.HUMAN_REVIEW:
            raise ConflictException("Pipeline must be in HUMAN_REVIEW state to record human verdict")

        if not self.assigned_reviewer or self.assigned_reviewer != reviewer_id:
            raise ValidationException("Reviewer must be assigned and must match")

        self.stages.append(
            PipelineStageResult.human_review(verdict, confidence, notes)
        )

        if verdict == "APPROVED":
            self.finalize_pipeline("APPROVED")
        elif verdict == "REJECTED":
            self.finalize_pipeline("REJECTED")
        else:
            self.finalize_pipeline("NEEDS_REVISION")

        self.human_verdict = verdict
        self.updated_at = datetime.now(timezone.utc)

    def finalize_pipeline(self, final_verdict: str) -> None:
        self.final_verdict = final_verdict
        status_map = {
            "APPROVED": PipelineStatus.APPROVED,
            "REJECTED": PipelineStatus.REJECTED,
            "NEEDS_REVISION": PipelineStatus.NEEDS_REVISION,
        }
        self.status = status_map.get(final_verdict, PipelineStatus.HUMAN_REVIEW)
        self.updated_at = datetime.now(timezone.utc)

    def can_transition_to(self, new_status: PipelineStatus) -> bool:
        valid_transitions = {
            PipelineStatus.QUEUED: [PipelineStatus.PROCESSING],
            PipelineStatus.PROCESSING: [PipelineStatus.AI_REVIEW],
            PipelineStatus.AI_REVIEW: [PipelineStatus.FRAUD_CHECK, PipelineStatus.HUMAN_REVIEW],
            PipelineStatus.FRAUD_CHECK: [PipelineStatus.HUMAN_REVIEW],
            PipelineStatus.HUMAN_REVIEW: [PipelineStatus.APPROVED, PipelineStatus.REJECTED, PipelineStatus.NEEDS_REVISION],
            PipelineStatus.APPROVED: [],
            PipelineStatus.REJECTED: [],
            PipelineStatus.NEEDS_REVISION: [],
        }

        return new_status in valid_transitions.get(self.status, [])

    @property
    def is_complete(self) -> bool:
        return PipelineStatus.is_completed(self.status)

    @property
    def requires_human_review(self) -> bool:
        return PipelineStatus.requires_human_review(self.status)
