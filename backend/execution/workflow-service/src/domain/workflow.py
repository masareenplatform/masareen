"""
Workflow aggregate, orchestrates multi-step task sequences.
A workflow defines a template of steps; each step maps to a task.
The workflow engine advances steps as tasks complete.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException, ConflictException


class WorkflowStatus(str, Enum):
    DRAFT      = "DRAFT"
    ACTIVE     = "ACTIVE"
    PAUSED     = "PAUSED"
    COMPLETED  = "COMPLETED"
    CANCELLED  = "CANCELLED"


class StepStatus(str, Enum):
    WAITING    = "WAITING"
    ACTIVE     = "ACTIVE"
    COMPLETED  = "COMPLETED"
    SKIPPED    = "SKIPPED"
    FAILED     = "FAILED"


@dataclass
class WorkflowStep:
    id:           str
    name:         str
    order:        int
    status:       StepStatus        = StepStatus.WAITING
    task_id:      Optional[str]     = None
    depends_on:   List[str]         = field(default_factory=list)  # step IDs
    completed_at: Optional[datetime]= None
    metadata:     Dict              = field(default_factory=dict)

    def can_start(self, completed_step_ids: List[str]) -> bool:
        return all(dep in completed_step_ids for dep in self.depends_on)

    def complete(self, task_id: Optional[str] = None) -> None:
        self.status       = StepStatus.COMPLETED
        self.task_id      = task_id
        self.completed_at = datetime.now(timezone.utc)


@dataclass
class WorkflowTemplate:
    id:          str
    name:        str
    description: Optional[str]
    steps:       List[WorkflowStep] = field(default_factory=list)
    program_id:  Optional[str]      = None
    created_by:  str                = ""
    created_at:  datetime           = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class WorkflowInstance(AggregateRoot):
    """
    A running instance of a WorkflowTemplate for a specific program/participant.
    """
    template_id:    str                    = ""
    program_id:     str                    = ""
    assignee_id:    str                    = ""
    status:         WorkflowStatus         = WorkflowStatus.DRAFT
    steps:          List[WorkflowStep]     = field(default_factory=list)
    current_step:   int                    = 0
    completed_steps: List[str]             = field(default_factory=list)
    metadata:       Dict                   = field(default_factory=dict)

    @classmethod
    def instantiate(cls, template: WorkflowTemplate, program_id: str, assignee_id: str) -> "WorkflowInstance":
        ordered = sorted(template.steps, key=lambda x: x.order)
        # Instance steps get fresh ids; remap each template step's dependencies
        # to the corresponding new instance-step id so `depends_on` stays valid.
        id_map = {s.id: str(uuid4()) for s in ordered}
        steps = [
            WorkflowStep(
                id=id_map[s.id], name=s.name, order=s.order,
                depends_on=[id_map[d] for d in s.depends_on if d in id_map],
                metadata=s.meta,
            )
            for s in ordered
        ]
        now = datetime.now(timezone.utc)
        return cls(
            id=str(uuid4()), template_id=template.id,
            program_id=program_id, assignee_id=assignee_id,
            status=WorkflowStatus.DRAFT, steps=steps,
            created_at=now, updated_at=now,
        )

    def start(self) -> None:
        if self.status != WorkflowStatus.DRAFT:
            raise ConflictException("Workflow already started.")
        self.status = WorkflowStatus.ACTIVE
        self.updated_at = datetime.now(timezone.utc)
        self._activate_ready_steps()

    def advance_step(self, step_id: str, task_id: Optional[str] = None) -> Optional[WorkflowStep]:
        """Mark a step complete and activate next eligible steps."""
        step = self._get_step(step_id)
        if not step:
            raise ValidationException(f"Step {step_id} not found in workflow.")
        if step.status != StepStatus.ACTIVE:
            raise ConflictException(f"Step {step.name} is not ACTIVE (current: {step.status.value}).")
        step.complete(task_id)
        self.completed_steps.append(step_id)
        self.updated_at = datetime.now(timezone.utc)
        self._activate_ready_steps()
        if self._all_steps_done():
            self.status = WorkflowStatus.COMPLETED
        return step

    def pause(self) -> None:
        if self.status != WorkflowStatus.ACTIVE:
            raise ConflictException("Only ACTIVE workflows can be paused.")
        self.status = WorkflowStatus.PAUSED
        self.updated_at = datetime.now(timezone.utc)

    def resume(self) -> None:
        if self.status != WorkflowStatus.PAUSED:
            raise ConflictException("Only PAUSED workflows can be resumed.")
        self.status = WorkflowStatus.ACTIVE
        self.updated_at = datetime.now(timezone.utc)

    def cancel(self) -> None:
        self.status = WorkflowStatus.CANCELLED
        self.updated_at = datetime.now(timezone.utc)

    def _get_step(self, step_id: str) -> Optional[WorkflowStep]:
        return next((s for s in self.steps if s.id == step_id), None)

    def _activate_ready_steps(self) -> None:
        for step in self.steps:
            if step.status == StepStatus.WAITING and step.can_start(self.completed_steps):
                step.status = StepStatus.ACTIVE

    def _all_steps_done(self) -> bool:
        return all(s.status in (StepStatus.COMPLETED, StepStatus.SKIPPED) for s in self.steps)

    @property
    def progress_percent(self) -> float:
        if not self.steps:
            return 0.0
        done = sum(1 for s in self.steps if s.status in (StepStatus.COMPLETED, StepStatus.SKIPPED))
        return round(done / len(self.steps) * 100, 1)
