from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import (
    CreateWorkflowTemplateCommand, AddWorkflowStepCommand,
    InstantiateWorkflowCommand, StartWorkflowCommand,
    AdvanceWorkflowStepCommand, PauseWorkflowCommand, CancelWorkflowCommand,
)
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/workflows", tags=["Workflows"])


class CreateTemplateRequest(BaseModel):
    name: str = Field(..., min_length=2)
    description: Optional[str] = None
    program_id: Optional[str] = None


class AddStepRequest(BaseModel):
    step_name: str
    order: int
    depends_on: List[str] = []
    metadata: Dict = {}


class InstantiateRequest(BaseModel):
    program_id: str
    assignee_id: str


class AdvanceStepRequest(BaseModel):
    step_id: str
    task_id: Optional[str] = None


@router.post("/templates", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_template(body: CreateTemplateRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreateWorkflowTemplateCommand(
        name=body.name, created_by="system",
        program_id=body.program_id, description=body.description,
    ))
    return ApiResponse.ok(result)


@router.post("/templates/{template_id}/steps", response_model=ApiResponse[dict])
async def add_step(template_id: str, body: AddStepRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(AddWorkflowStepCommand(
        template_id=template_id, step_name=body.step_name,
        order=body.order, depends_on=body.depends_on, metadata=body.metadata,
    ))
    return ApiResponse.ok(result)


@router.post("/templates/{template_id}/instantiate", response_model=ApiResponse[dict])
async def instantiate(template_id: str, body: InstantiateRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(InstantiateWorkflowCommand(
        template_id=template_id, program_id=body.program_id, assignee_id=body.assignee_id,
    ))
    return ApiResponse.ok(result)


@router.post("/instances/{instance_id}/start", response_model=ApiResponse[dict])
async def start_workflow(instance_id: str, started_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(StartWorkflowCommand(instance_id=instance_id, started_by=started_by))
    return ApiResponse.ok(result)


@router.post("/instances/{instance_id}/advance", response_model=ApiResponse[dict])
async def advance_step(instance_id: str, body: AdvanceStepRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(AdvanceWorkflowStepCommand(
        instance_id=instance_id, step_id=body.step_id, task_id=body.task_id,
    ))
    return ApiResponse.ok(result)


@router.post("/instances/{instance_id}/pause", response_model=ApiResponse[dict])
async def pause_workflow(instance_id: str, paused_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(PauseWorkflowCommand(instance_id=instance_id, paused_by=paused_by))
    return ApiResponse.ok(result)


@router.post("/instances/{instance_id}/cancel", response_model=ApiResponse[dict])
async def cancel_workflow(instance_id: str, cancelled_by: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CancelWorkflowCommand(instance_id=instance_id, cancelled_by=cancelled_by))
    return ApiResponse.ok(result)


@router.get("/instances/{instance_id}", response_model=ApiResponse[dict])
async def get_instance(instance_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    from ..domain.workflow import WorkflowInstance
    inst = await query_bus.dispatch(type("GetWorkflowInstanceQuery", (), {"instance_id": instance_id})())
    return ApiResponse.ok({
        "instance_id": inst.id, "status": inst.status.value,
        "progress": inst.progress_percent, "steps": len(inst.steps),
        "completed_steps": len(inst.completed_steps),
    })
