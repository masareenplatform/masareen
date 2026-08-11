from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from shared.utils.cqrs import Command

@dataclass
class CreateTaskCommand(Command):
    program_id: str; title: str; created_by: str
    description: Optional[str] = None; priority: str = "MEDIUM"
    due_date: Optional[datetime] = None; evidence_required: bool = True
    estimated_hours: Optional[float] = None; supervisor_id: Optional[str] = None
    geofence_lat: Optional[float] = None; geofence_lon: Optional[float] = None
    geofence_radius: int = 500

@dataclass
class AssignTaskCommand(Command):
    task_id: str; assignee_id: str; assigned_by: str
    due_date: Optional[datetime] = None

@dataclass
class StartTaskCommand(Command):
    task_id: str; started_by: str

@dataclass
class SubmitTaskCommand(Command):
    task_id: str; submitted_by: str
    evidence_ids: List[str] = field(default_factory=list)
    actual_hours: Optional[float] = None

@dataclass
class VerifyTaskCommand(Command):
    task_id: str; verified_by: str; note: Optional[str] = None

@dataclass
class CompleteTaskCommand(Command):
    task_id: str; completed_by: str

@dataclass
class CancelTaskCommand(Command):
    task_id: str; cancelled_by: str; reason: str
