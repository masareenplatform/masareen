"""
Submission domain event contracts - updated with new events.
"""
from dataclasses import dataclass, field
from typing import Optional, List
from . import DomainEvent


@dataclass
class SubmissionCreated(DomainEvent):
    event_type: str = "SubmissionCreated"
    aggregate_type: str = "SubmissionBundle"
    aggregate_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    evidence_count: int = 0


@dataclass
class SubmissionSubmitted(DomainEvent):
    event_type: str = "SubmissionSubmitted"
    aggregate_type: str = "SubmissionBundle"
    aggregate_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    approval_score: Optional[float] = None
    evidence_count: int = 0


@dataclass
class PipelineCreated(DomainEvent):
    event_type: str = "PipelineCreated"
    aggregate_type: str = "SubmissionBundle"
    aggregate_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    evidence_items: List[dict] = field(default_factory=list)


@dataclass
class BundleRejected(DomainEvent):
    event_type: str = "BundleRejected"
    aggregate_type: str = "SubmissionBundle"
    aggregate_id: str = ""
    task_id: str = ""
    submitted_by: str = ""
    rejection_reason: str = ""
