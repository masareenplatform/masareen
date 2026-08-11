"""SQLAlchemy implementations of workflow repositories."""
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.workflow import (
    WorkflowTemplate, WorkflowInstance, WorkflowStep, WorkflowStatus, StepStatus,
)
from ..domain.workflow_repository import WorkflowTemplateRepository, WorkflowInstanceRepository
from .orm_models import WorkflowTemplateORM, WorkflowInstanceORM
from datetime import datetime, timezone
import uuid


class SQLAlchemyWorkflowTemplateRepository(WorkflowTemplateRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: WorkflowTemplateORM) -> WorkflowTemplate:
        steps = []
        for s in (o.steps or []):
            steps.append(WorkflowStep(
                id=s.get("id", ""), name=s.get("name", ""),
                order=s.get("order", 0),
                status=StepStatus(s.get("status", "WAITING")),
                task_id=s.get("task_id"), depends_on=s.get("depends_on", []),
                completed_at=s.get("completed_at"),
                metadata=s.get("metadata", {}),
            ))
        return WorkflowTemplate(
            id=str(o.id), name=o.name, description=o.description,
            steps=steps,
            program_id=str(o.program_id) if o.program_id else None,
            created_by=str(o.created_by) if o.created_by else "",
            created_at=o.created_at,
        )

    @staticmethod
    def _to_orm(t: WorkflowTemplate) -> WorkflowTemplateORM:
        step_dicts = [
            {"id": s.id, "name": s.name, "order": s.order,
             "status": s.status.value, "task_id": s.task_id,
             "depends_on": s.depends_on,
             "completed_at": s.completed_at.isoformat() if s.completed_at else None,
             "metadata": s.meta}
            for s in t.steps
        ]
        return WorkflowTemplateORM(
            id=uuid.UUID(t.id), name=t.name, description=t.description,
            steps=step_dicts,
            program_id=uuid.UUID(t.program_id) if t.program_id else None,
            created_by=uuid.UUID(t.created_by) if t.created_by else None,
            created_at=t.created_at,
        )

    async def get_by_id(self, template_id: str) -> Optional[WorkflowTemplate]:
        r = await self._session.execute(select(WorkflowTemplateORM).where(WorkflowTemplateORM.id == template_id))
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, template: WorkflowTemplate) -> WorkflowTemplate:
        merged = await self._session.merge(self._to_orm(template))
        await self._session.flush()
        return self._to_domain(merged)


class SQLAlchemyWorkflowInstanceRepository(WorkflowInstanceRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: WorkflowInstanceORM) -> WorkflowInstance:
        steps = []
        for s in (o.steps or []):
            steps.append(WorkflowStep(
                id=s.get("id", ""), name=s.get("name", ""),
                order=s.get("order", 0),
                status=StepStatus(s.get("status", "WAITING")),
                task_id=s.get("task_id"), depends_on=s.get("depends_on", []),
                completed_at=(
                    datetime.fromisoformat(s["completed_at"]) if s.get("completed_at") else None
                ),
                metadata=s.get("metadata", {}),
            ))
        return WorkflowInstance(
            id=str(o.id), template_id=str(o.template_id),
            program_id=str(o.program_id), assignee_id=str(o.assignee_id),
            status=WorkflowStatus(o.status), steps=steps,
            current_step=o.current_step or 0,
            completed_steps=list(o.completed_steps or []),
            metadata=dict(o.metadata or {}),
            created_at=o.created_at, updated_at=o.updated_at, version=o.version,
        )

    @staticmethod
    def _to_orm(inst: WorkflowInstance) -> WorkflowInstanceORM:
        step_dicts = [
            {"id": s.id, "name": s.name, "order": s.order,
             "status": s.status.value, "task_id": s.task_id,
             "depends_on": s.depends_on,
             "completed_at": s.completed_at.isoformat() if s.completed_at else None,
             "metadata": s.meta}
            for s in inst.steps
        ]
        return WorkflowInstanceORM(
            id=uuid.UUID(inst.id), template_id=uuid.UUID(inst.template_id),
            program_id=uuid.UUID(inst.program_id),
            assignee_id=uuid.UUID(inst.assignee_id),
            status=inst.status.value, steps=step_dicts,
            current_step=inst.current_step,
            completed_steps=inst.completed_steps,
            metadata=inst.metadata, progress=inst.progress_percent,
            created_at=inst.created_at, updated_at=inst.updated_at,
            version=(inst.version or 0) + 1,
        )

    async def get_by_id(self, instance_id: str) -> Optional[WorkflowInstance]:
        r = await self._session.execute(select(WorkflowInstanceORM).where(WorkflowInstanceORM.id == instance_id))
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, instance: WorkflowInstance) -> WorkflowInstance:
        merged = await self._session.merge(self._to_orm(instance))
        await self._session.flush()
        return self._to_domain(merged)
