from shared.exceptions import NotFoundException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.task import Task, TaskGeofence
from ..domain.task_repository import TaskRepository
from .commands import (CreateTaskCommand, AssignTaskCommand, StartTaskCommand,
    SubmitTaskCommand, VerifyTaskCommand, CompleteTaskCommand, CancelTaskCommand)
from .queries import GetTaskByIdQuery, ListTasksByProgramQuery, ListTasksByAssigneeQuery, GetTaskStatusHistoryQuery

log = get_logger(__name__)
T_ASSIGNED  = "masaren.execution.task_assigned.v1"
T_STARTED   = "masaren.execution.task_started.v1"
T_COMPLETED = "masaren.execution.task_completed.v1"

class CreateTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository, session, outbox: OutboxWriter):
        self._repo=repo; self._session=session; self._outbox=outbox
    async def handle(self, cmd: CreateTaskCommand) -> dict:
        geofence = None
        if cmd.geofence_lat and cmd.geofence_lon:
            geofence = TaskGeofence(cmd.geofence_lat, cmd.geofence_lon, cmd.geofence_radius)
        task = Task.create(cmd.program_id, cmd.title, cmd.created_by, cmd.description,
            cmd.priority, cmd.due_date, geofence, cmd.evidence_required, cmd.estimated_hours, cmd.supervisor_id)
        saved = await self._repo.save(task)
        log.info("task_created", task_id=saved.id, program_id=saved.program_id)
        return {"task_id": saved.id, "status": saved.status.value}

class AssignTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository, session, outbox: OutboxWriter):
        self._repo=repo; self._session=session; self._outbox=outbox
    async def handle(self, cmd: AssignTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.assign(cmd.assignee_id, cmd.assigned_by, cmd.due_date)
        saved = await self._repo.save(task)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_ASSIGNED)
        log.info("task_assigned", task_id=task.id, assignee=cmd.assignee_id)
        return {"task_id": task.id, "status": task.status.value, "assignee_id": cmd.assignee_id}

class StartTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository, session, outbox: OutboxWriter):
        self._repo=repo; self._session=session; self._outbox=outbox
    async def handle(self, cmd: StartTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.start(cmd.started_by)
        saved = await self._repo.save(task)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_STARTED)
        return {"task_id": task.id, "status": task.status.value}

class SubmitTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, cmd: SubmitTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.submit(cmd.submitted_by, cmd.evidence_ids, cmd.actual_hours)
        await self._repo.save(task)
        return {"task_id": task.id, "status": task.status.value}

class VerifyTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, cmd: VerifyTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.verify(cmd.verified_by, cmd.note)
        await self._repo.save(task)
        return {"task_id": task.id, "status": task.status.value}

class CompleteTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository, session, outbox: OutboxWriter):
        self._repo=repo; self._session=session; self._outbox=outbox
    async def handle(self, cmd: CompleteTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.complete(cmd.completed_by)
        saved = await self._repo.save(task)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, T_COMPLETED)
        log.info("task_completed", task_id=task.id)
        return {"task_id": task.id, "status": task.status.value}

class CancelTaskHandler(CommandHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, cmd: CancelTaskCommand) -> dict:
        task = await self._repo.get_by_id(cmd.task_id)
        if not task: raise NotFoundException("Task", cmd.task_id)
        task.cancel(cmd.cancelled_by, cmd.reason)
        await self._repo.save(task)
        return {"task_id": task.id, "status": task.status.value}

class GetTaskByIdHandler(QueryHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, q: GetTaskByIdQuery):
        task = await self._repo.get_by_id(q.task_id)
        if not task: raise NotFoundException("Task", q.task_id)
        return task

class ListTasksByProgramHandler(QueryHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, q: ListTasksByProgramQuery):
        return await self._repo.list_by_program(q.program_id, q.limit, q.offset)

class ListTasksByAssigneeHandler(QueryHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, q: ListTasksByAssigneeQuery):
        return await self._repo.list_by_assignee(q.assignee_id, q.status, q.limit, q.offset)

class GetTaskStatusHistoryHandler(QueryHandler):
    def __init__(self, repo: TaskRepository):
        self._repo=repo
    async def handle(self, q: GetTaskStatusHistoryQuery):
        task = await self._repo.get_by_id(q.task_id)
        if not task: raise NotFoundException("Task", q.task_id)
        return task.status_history
