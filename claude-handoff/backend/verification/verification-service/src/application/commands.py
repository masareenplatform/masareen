"""Application layer commands for verification domain."""
from dataclasses import dataclass
from typing import Optional

from shared.utils.cqrs import Command


@dataclass
class StartVerificationPipelineCommand(Command):
    """Command to start the verification pipeline for an evidence."""
    evidence_id: str
    task_id: str
    submitted_by: str
    ai_confidence_threshold: float = 0.80
    fraud_risk_threshold: int = 30

    def __post_init__(self):
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
        if not self.task_id:
            raise ValueError("task_id is required")
        if not self.submitted_by:
            raise ValueError("submitted_by is required")
        if not 0.0 <= self.ai_confidence_threshold <= 1.0:
            raise ValueError("ai_confidence_threshold must be between 0.0 and 1.0")
        if not 0 <= self.fraud_risk_threshold <= 100:
            raise ValueError("fraud_risk_threshold must be between 0 and 100")


@dataclass
class RecordAIVerificationResultCommand(Command):
    """Command to record AI verification results."""
    pipeline_id: str
    evidence_id: str
    verdict: str
    confidence: float
    notes: Optional[str] = None

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
        if not self.verdict:
            raise ValueError("verdict is required")
        if not 0.0 <= self.confidence <= 1.0:
            raise ValueError("confidence must be between 0.0 and 1.0")


@dataclass
class StartFraudCheckCommand(Command):
    """Command to start fraud check process."""
    pipeline_id: str
    evidence_id: str

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")


@dataclass
class StartHumanReviewCommand(Command):
    """Command to start human review of evidence."""
    pipeline_id: str
    evidence_id: str
    reviewer_id: Optional[str] = None

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
        if not self.reviewer_id:
            raise ValueError("reviewer_id is required")


@dataclass
class RecordHumanVerdictCommand(Command):
    """Command to record human review verdict."""
    pipeline_id: str
    evidence_id: str
    verdict: str
    reviewer_id: str
    confidence: float
    notes: Optional[str] = None

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
        if not self.verdict:
            raise ValueError("verdict is required")
        if not self.reviewer_id:
            raise ValueError("reviewer_id is required")
        if not 0.0 <= self.confidence <= 1.0:
            raise ValueError("confidence must be between 0.0 and 1.0")


@dataclass
class SubmitVerificationCommand(Command):
    """Command to submit evidence for verification."""
    pipeline_id: str
    evidence_id: str
    submitted_by: str

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
        if not self.submitted_by:
            raise ValueError("submitted_by is required")


@dataclass
class RejectVerificationCommand(Command):
    """Command to reject evidence verification."""
    pipeline_id: str
    evidence_id: str
    reason: Optional[str] = None

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")


@dataclass
class SubmitForHumanReviewCommand(Command):
    """Command to submit evidence for human review."""
    pipeline_id: str
    evidence_id: str
    reason: Optional[str] = None

    def __post_init__(self):
        if not self.pipeline_id:
            raise ValueError("pipeline_id is required")
        if not self.evidence_id:
            raise ValueError("evidence_id is required")
