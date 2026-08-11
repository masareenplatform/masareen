from dataclasses import dataclass, field
from typing import Dict, List, Optional
from shared.utils.cqrs import Command

@dataclass
class CreateWorkflowTemplateCommand(Command):
    name: str; created_by: str; program_id: Optional[str]=None
    description: Optional[str]=None

@dataclass
class AddWorkflowStepCommand(Command):
    template_id: str; step_name: str; order: int
    depends_on: List[str]=field(default_factory=list)
    metadata: Dict=field(default_factory=dict)

@dataclass
class InstantiateWorkflowCommand(Command):
    template_id: str; program_id: str; assignee_id: str

@dataclass
class StartWorkflowCommand(Command):
    instance_id: str; started_by: str

@dataclass
class AdvanceWorkflowStepCommand(Command):
    instance_id: str; step_id: str; task_id: Optional[str]=None

@dataclass
class PauseWorkflowCommand(Command):
    instance_id: str; paused_by: str

@dataclass
class CancelWorkflowCommand(Command):
    instance_id: str; cancelled_by: str
