"""Execution domain event contracts."""
from dataclasses import dataclass
from typing import Optional
from . import DomainEvent


@dataclass
class OrganizationCreated(DomainEvent):
    event_type: str = "OrganizationCreated"
    aggregate_type: str = "Organization"
    name: str = ""
    org_type: str = ""
    country: str = ""


@dataclass
class ProgramCreated(DomainEvent):
    event_type: str = "ProgramCreated"
    aggregate_type: str = "Program"
    title: str = ""
    organization_id: str = ""
    sdg_goals: list = None

    def __post_init__(self):
        if self.sdg_goals is None:
            self.sdg_goals = []


@dataclass
class TaskAssigned(DomainEvent):
    event_type: str = "TaskAssigned"
    aggregate_type: str = "Task"
    program_id: str = ""
    assignee_id: str = ""
    due_date: Optional[str] = None


@dataclass
class TaskStarted(DomainEvent):
    event_type: str = "TaskStarted"
    aggregate_type: str = "Task"
    assignee_id: str = ""


@dataclass
class TaskCompleted(DomainEvent):
    event_type: str = "TaskCompleted"
    aggregate_type: str = "Task"
    assignee_id: str = ""
    completion_evidence_ids: list = None

    def __post_init__(self):
        if self.completion_evidence_ids is None:
            self.completion_evidence_ids = []
