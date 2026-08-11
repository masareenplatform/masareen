from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Query

@dataclass
class GetTaskByIdQuery(Query):
    task_id: str

@dataclass
class ListTasksByProgramQuery(Query):
    program_id: str; limit: int = 20; offset: int = 0

@dataclass
class ListTasksByAssigneeQuery(Query):
    assignee_id: str; status: Optional[str] = None; limit: int = 20; offset: int = 0

@dataclass
class GetTaskStatusHistoryQuery(Query):
    task_id: str
