"""
Task aggregate root with full FSM state machine.
Valid transitions:
  PENDING → ASSIGNED → IN_PROGRESS → SUBMITTED → VERIFIED → COMPLETED
  Any state → CANCELLED
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4

from shared.base_entity import AggregateRoot
from shared.events.execution_events import TaskAssigned, TaskStarted, TaskCompleted
from shared.exceptions import ValidationException, ConflictException


class TaskStatus(str, Enum):
    PENDING     = "PENDING"
    ASSIGNED    = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    SUBMITTED   = "SUBMITTED"
    VERIFIED    = "VERIFIED"
    COMPLETED   = "COMPLETED"
    CANCELLED   = "CANCELLED"


class TaskPriority(str, Enum):
    LOW    = "LOW"
    MEDIUM = "MEDIUM"
    HIGH   = "HIGH"
    URGENT = "URGENT"


# Valid FSM transitions
VALID_TRANSITIONS: dict[TaskStatus, list[TaskStatus]] = {
    TaskStatus.PENDING:     [TaskStatus.ASSIGNED,    TaskStatus.CANCELLED],
    TaskStatus.ASSIGNED:    [TaskStatus.IN_PROGRESS, TaskStatus.CANCELLED],
    TaskStatus.IN_PROGRESS: [TaskStatus.SUBMITTED,   TaskStatus.CANCELLED],
    TaskStatus.SUBMITTED:   [TaskStatus.VERIFIED,    TaskStatus.IN_PROGRESS, TaskStatus.CANCELLED],
    TaskStatus.VERIFIED:    [TaskStatus.COMPLETED,   TaskStatus.CANCELLED],
    TaskStatus.COMPLETED:   [],
    TaskStatus.CANCELLED:   [],
}


@dataclass
class TaskGeofence:
    latitude:  float
    longitude: float
    radius_meters: int = 500


@dataclass
class TaskStatusHistoryEntry:
    from_status: str
    to_status:   str
    changed_by:  str
    changed_at:  datetime
    note:        Optional[str] = None


@dataclass
class Task(AggregateRoot):
    program_id:        str                        = ""
    title:             str                        = ""
    description:       Optional[str]              = None
    status:            TaskStatus                 = TaskStatus.PENDING
    priority:          TaskPriority               = TaskPriority.MEDIUM
    assignee_id:       Optional[str]              = None
    supervisor_id:     Optional[str]              = None
    due_date:          Optional[datetime]         = None
    geofence:          Optional[TaskGeofence]     = None
    evidence_required: bool                       = True
    evidence_ids:      List[str]                  = field(default_factory=list)
    status_history:    List[TaskStatusHistoryEntry] = field(default_factory=list)
    tags:              List[str]                  = field(default_factory=list)
    estimated_hours:   Optional[float]            = None
    actual_hours:      Optional[float]            = None
    created_by:        str                        = ""

    # ── Factory ───────────────────────────────────────────────────────────
    @classmethod
    def create(
        cls,
        program_id: str,
        title: str,
        created_by: str,
        description: Optional[str] = None,
        priority: str = "MEDIUM",
        due_date: Optional[datetime] = None,
        geofence: Optional[TaskGeofence] = None,
        evidence_required: bool = True,
        estimated_hours: Optional[float] = None,
        supervisor_id: Optional[str] = None,
        geofence_lat: Optional[float] = None,
        geofence_lon: Optional[float] = None,
        geofence_radius: int = 500,
    ) -> "Task":
        if not title or len(title.strip()) < 3:
            raise ValidationException("Task title must be at least 3 characters.")
        if not program_id:
            raise ValidationException("program_id is required.")
        # Convenience: build a geofence from raw coordinates when an object
        # was not supplied directly (used by the API/command layer).
        if geofence is None and geofence_lat is not None and geofence_lon is not None:
            geofence = TaskGeofence(latitude=geofence_lat, longitude=geofence_lon,
                                    radius_meters=geofence_radius)
        now = datetime.now(timezone.utc)
        return cls(
            id=str(uuid4()), program_id=program_id, title=title.strip(),
            description=description, status=TaskStatus.PENDING,
            priority=TaskPriority(priority), due_date=due_date,
            geofence=geofence, evidence_required=evidence_required,
            estimated_hours=estimated_hours, supervisor_id=supervisor_id,
            created_by=created_by, created_at=now, updated_at=now,
        )

    # ── FSM transition guard ──────────────────────────────────────────────
    def _transition(self, to: TaskStatus, changed_by: str, note: Optional[str] = None) -> None:
        allowed = VALID_TRANSITIONS.get(self.status, [])
        if to not in allowed:
            raise ConflictException(
                f"Cannot transition task from {self.status.value} to {to.value}. "
                f"Allowed: {[s.value for s in allowed]}"
            )
        self.status_history.append(TaskStatusHistoryEntry(
            from_status=self.status.value, to_status=to.value,
            changed_by=changed_by, changed_at=datetime.now(timezone.utc), note=note,
        ))
        self.status = to
        self.updated_at = datetime.now(timezone.utc)

    # ── State transitions ─────────────────────────────────────────────────
    def assign(self, assignee_id: str, assigned_by: str, due_date: Optional[datetime] = None) -> None:
        self._transition(TaskStatus.ASSIGNED, assigned_by)
        self.assignee_id = assignee_id
        if due_date:
            self.due_date = due_date
        self.add_domain_event(TaskAssigned(
            aggregate_id=self.id, program_id=self.program_id,
            assignee_id=assignee_id, due_date=due_date.isoformat() if due_date else None,
        ))

    def start(self, started_by: str) -> None:
        # Validate FSM state first (a PENDING task can't be started at all),
        # then ownership. This keeps state errors (Conflict) distinct from
        # authorization errors (Validation) and avoids mutating on failure.
        if self.status != TaskStatus.ASSIGNED:
            raise ConflictException(
                f"Cannot start task from {self.status.value}; task must be ASSIGNED."
            )
        if self.assignee_id != started_by:
            raise ValidationException("Only the assigned user can start a task.")
        self._transition(TaskStatus.IN_PROGRESS, started_by)
        self.add_domain_event(TaskStarted(
            aggregate_id=self.id, assignee_id=started_by,
        ))

    def submit(self, submitted_by: str, evidence_ids: List[str], actual_hours: Optional[float] = None) -> None:
        if self.evidence_required and not evidence_ids:
            raise ValidationException("Evidence is required to submit this task.")
        self._transition(TaskStatus.SUBMITTED, submitted_by)
        self.evidence_ids.extend(evidence_ids)
        if actual_hours:
            self.actual_hours = actual_hours

    def verify(self, verified_by: str, note: Optional[str] = None) -> None:
        self._transition(TaskStatus.VERIFIED, verified_by, note)

    def complete(self, completed_by: str) -> None:
        self._transition(TaskStatus.COMPLETED, completed_by)
        self.add_domain_event(TaskCompleted(
            aggregate_id=self.id, assignee_id=self.assignee_id or "",
            completion_evidence_ids=self.evidence_ids,
        ))

    def cancel(self, cancelled_by: str, reason: str) -> None:
        self._transition(TaskStatus.CANCELLED, cancelled_by, reason)

    def is_overdue(self) -> bool:
        if not self.due_date:
            return False
        return (datetime.now(timezone.utc) > self.due_date and
                self.status not in (TaskStatus.COMPLETED, TaskStatus.CANCELLED))
