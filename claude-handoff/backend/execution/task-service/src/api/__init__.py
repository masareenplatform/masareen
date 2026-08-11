from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import (
    CreateTaskCommand, AssignTaskCommand, StartTaskCommand, SubmitTaskCommand,
    VerifyTaskCommand, CompleteTaskCommand, CancelTaskCommand,
)
from ..application.queries import (
    GetTaskByIdQuery, ListTasksByProgramQuery, ListTasksByAssigneeQuery, GetTaskStatusHistoryQuery,
)
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/tasks", tags=["Tasks"])


class CreateTaskRequest(BaseModel):
    program_id: str
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    priority: str = "MEDIUM"
    due_date: Optional[datetime] = None
    evidence_required: bool = True
    estimated_hours: Optional[float] = None
    supervisor_id: Optional[str] = None
    geofence_lat: Optional[float] = None
    geofence_lon: Optional[float] = None
    geofence_radius: int = 500


class AssignTaskRequest(BaseModel):
    assignee_id: str
    due_date: Optional[datetime] = None


class SubmitTaskRequest(BaseModel):
    evidence_ids: List[str] = Field(default_factory=list)
    actual_hours: Optional[float] = None


class TaskResponse(BaseModel):
    id: str
    program_id: str
    title: str
    status: str
    priority: str
    assignee_id: Optional[str] = None
    due_date: Optional[datetime] = None
    evidence_required: bool = True
    evidence_ids: List[str] = []
    description: Optional[str] = None
    estimated_hours: Optional[float] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class StatusHistoryEntry(BaseModel):
    from_status: str
    to_status: str
    changed_by: str
    changed_at: datetime
    note: Optional[str] = None


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_task(body: CreateTaskRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreateTaskCommand(
        program_id=body.program_id, title=body.title, created_by="system",
        description=body.description, priority=body.priority,
        due_date=body.due_date, evidence_required=body.evidence_required,
        estimated_hours=body.estimated_hours, supervisor_id=body.supervisor_id,
        geofence_lat=body.geofence_lat, geofence_lon=body.geofence_lon,
        geofence_radius=body.geofence_radius,
    ))
    return ApiResponse.ok(result)


@router.get("/{task_id}", response_model=ApiResponse[TaskResponse])
async def get_task(task_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    t = await query_bus.dispatch(GetTaskByIdQuery(task_id=task_id))
    return ApiResponse.ok(TaskResponse(
        id=t.id, program_id=t.program_id, title=t.title, status=t.status.value,
        priority=t.priority.value, assignee_id=t.assignee_id,
        due_date=t.due_date, evidence_required=t.evidence_required,
        evidence_ids=t.evidence_ids, description=t.description,
        estimated_hours=t.estimated_hours,
        created_at=t.created_at.isoformat() if t.created_at else None,
        updated_at=t.updated_at.isoformat() if t.updated_at else None,
    ))


@router.post("/{task_id}/assign", response_model=ApiResponse[dict])
async def assign_task(task_id: str, body: AssignTaskRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(AssignTaskCommand(
        task_id=task_id, assignee_id=body.assignee_id,
        assigned_by="system", due_date=body.due_date,
    ))
    return ApiResponse.ok(result)


@router.post("/{task_id}/start", response_model=ApiResponse[dict])
async def start_task(task_id: str, started_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(StartTaskCommand(task_id=task_id, started_by=started_by))
    return ApiResponse.ok(result)


@router.post("/{task_id}/submit", response_model=ApiResponse[dict])
async def submit_task(task_id: str, body: SubmitTaskRequest, submitted_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(SubmitTaskCommand(
        task_id=task_id, submitted_by=submitted_by,
        evidence_ids=body.evidence_ids, actual_hours=body.actual_hours,
    ))
    return ApiResponse.ok(result)


@router.post("/{task_id}/verify", response_model=ApiResponse[dict])
async def verify_task(task_id: str, verified_by: str, note: Optional[str] = None, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(VerifyTaskCommand(task_id=task_id, verified_by=verified_by, note=note))
    return ApiResponse.ok(result)


@router.post("/{task_id}/complete", response_model=ApiResponse[dict])
async def complete_task(task_id: str, completed_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CompleteTaskCommand(task_id=task_id, completed_by=completed_by))
    return ApiResponse.ok(result)


@router.post("/{task_id}/cancel", response_model=ApiResponse[dict])
async def cancel_task(task_id: str, cancelled_by: str, reason: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CancelTaskCommand(task_id=task_id, cancelled_by=cancelled_by, reason=reason))
    return ApiResponse.ok(result)


@router.get("/{task_id}/history", response_model=ApiResponse[List[StatusHistoryEntry]])
async def get_history(task_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    history = await query_bus.dispatch(GetTaskStatusHistoryQuery(task_id=task_id))
    return ApiResponse.ok(history)


@router.get("/", response_model=ApiResponse[dict])
async def list_tasks(
    program_id: Optional[str] = Query(None),
    assignee_id: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20), offset: int = Query(0),
    query_bus: QueryBus = Depends(get_query_bus),
):
    if program_id:
        items, total = await query_bus.dispatch(ListTasksByProgramQuery(program_id=program_id, limit=limit, offset=offset))
    elif assignee_id:
        items, total = await query_bus.dispatch(ListTasksByAssigneeQuery(assignee_id=assignee_id, status=status_filter, limit=limit, offset=offset))
    else:
        items, total = [], 0
    return ApiResponse.ok({"items": items, "total": total, "limit": limit, "offset": offset})
