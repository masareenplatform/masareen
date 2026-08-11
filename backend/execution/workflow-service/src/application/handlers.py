"""Command handlers for workflow-service — now DB-backed via repositories."""
from shared.exceptions import NotFoundException
from shared.utils.cqrs import CommandHandler
from shared.utils.logging import get_logger
from ..domain.workflow import WorkflowInstance, WorkflowTemplate, WorkflowStep
from ..domain.workflow_repository import WorkflowTemplateRepository, WorkflowInstanceRepository
from .commands import (
    CreateWorkflowTemplateCommand, AddWorkflowStepCommand,
    InstantiateWorkflowCommand, StartWorkflowCommand, AdvanceWorkflowStepCommand,
    PauseWorkflowCommand, CancelWorkflowCommand,
)
from uuid import uuid4

log = get_logger(__name__)


class CreateWorkflowTemplateHandler(CommandHandler):
    def __init__(self, repo: WorkflowTemplateRepository):
        self._repo = repo

    async def handle(self, cmd: CreateWorkflowTemplateCommand) -> dict:
        t = WorkflowTemplate(
            id=str(uuid4()), name=cmd.name,
            description=cmd.description, program_id=cmd.program_id,
            created_by=cmd.created_by,
        )
        saved = await self._repo.save(t)
        log.info("workflow_template_created", template_id=saved.id)
        return {"template_id": saved.id, "name": saved.name}


class AddWorkflowStepHandler(CommandHandler):
    def __init__(self, repo: WorkflowTemplateRepository):
        self._repo = repo

    async def handle(self, cmd: AddWorkflowStepCommand) -> dict:
        t = await self._repo.get_by_id(cmd.template_id)
        if not t:
            raise NotFoundException("WorkflowTemplate", cmd.template_id)
        step = WorkflowStep(id=str(uuid4()), name=cmd.step_name, order=cmd.order,
                            depends_on=cmd.depends_on, metadata=cmd.metadata)
        t.steps.append(step)
        await self._repo.save(t)
        return {"step_id": step.id, "name": step.name, "order": step.order}


class InstantiateWorkflowHandler(CommandHandler):
    def __init__(self, tmpl_repo: WorkflowTemplateRepository, inst_repo: WorkflowInstanceRepository):
        self._tmpl_repo = tmpl_repo
        self._inst_repo = inst_repo

    async def handle(self, cmd: InstantiateWorkflowCommand) -> dict:
        t = await self._tmpl_repo.get_by_id(cmd.template_id)
        if not t:
            raise NotFoundException("WorkflowTemplate", cmd.template_id)
        inst = WorkflowInstance.instantiate(t, cmd.program_id, cmd.assignee_id)
        saved = await self._inst_repo.save(inst)
        log.info("workflow_instantiated", instance_id=saved.id, template_id=cmd.template_id)
        return {"instance_id": saved.id, "status": saved.status.value, "steps": len(saved.steps)}


class StartWorkflowHandler(CommandHandler):
    def __init__(self, repo: WorkflowInstanceRepository):
        self._repo = repo

    async def handle(self, cmd: StartWorkflowCommand) -> dict:
        inst = await self._repo.get_by_id(cmd.instance_id)
        if not inst:
            raise NotFoundException("WorkflowInstance", cmd.instance_id)
        inst.start()
        saved = await self._repo.save(inst)
        active = [s.name for s in saved.steps if s.status.value == "ACTIVE"]
        return {"instance_id": saved.id, "status": saved.status.value, "active_steps": active}


class AdvanceWorkflowStepHandler(CommandHandler):
    def __init__(self, repo: WorkflowInstanceRepository):
        self._repo = repo

    async def handle(self, cmd: AdvanceWorkflowStepCommand) -> dict:
        inst = await self._repo.get_by_id(cmd.instance_id)
        if not inst:
            raise NotFoundException("WorkflowInstance", cmd.instance_id)
        step = inst.advance_step(cmd.step_id, cmd.task_id)
        saved = await self._repo.save(inst)
        return {
            "instance_id": saved.id, "completed_step": step.name,
            "status": saved.status.value, "progress": saved.progress_percent,
        }


class PauseWorkflowHandler(CommandHandler):
    def __init__(self, repo: WorkflowInstanceRepository):
        self._repo = repo

    async def handle(self, cmd: PauseWorkflowCommand) -> dict:
        inst = await self._repo.get_by_id(cmd.instance_id)
        if not inst:
            raise NotFoundException("WorkflowInstance", cmd.instance_id)
        inst.pause()
        saved = await self._repo.save(inst)
        return {"instance_id": saved.id, "status": saved.status.value}


class CancelWorkflowHandler(CommandHandler):
    def __init__(self, repo: WorkflowInstanceRepository):
        self._repo = repo

    async def handle(self, cmd: CancelWorkflowCommand) -> dict:
        inst = await self._repo.get_by_id(cmd.instance_id)
        if not inst:
            raise NotFoundException("WorkflowInstance", cmd.instance_id)
        inst.cancel()
        saved = await self._repo.save(inst)
        return {"instance_id": saved.id, "status": saved.status.value}
