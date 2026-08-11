from dataclasses import dataclass, field
from typing import Optional, List
from shared.utils.cqrs import Command


@dataclass
class CreateSubmissionCommand(Command):
    task_id: str
    submitted_by: str
    evidence_items: List[dict]
    gps_locations: Optional[List[dict]] = field(default_factory=list)


@dataclass
class ValidateSubmissionCommand(Command):
    submission_id: str


@dataclass
class SubmitSubmissionCommand(Command):
    submission_id: str


@dataclass
class RejectSubmissionCommand(Command):
    submission_id: str
    rejection_reason: str


@dataclass
class CreatePipelineCommand(Command):
    submission_id: str
