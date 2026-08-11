from typing import List, Optional, Tuple
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.task import Task, TaskStatus, TaskPriority, TaskGeofence, TaskStatusHistoryEntry
from ..domain.task_repository import TaskRepository
from .orm_models import TaskORM
from datetime import datetime, timezone
import uuid, json

class SQLAlchemyTaskRepository(TaskRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: TaskORM) -> Task:
        geofence = None
        if o.geofence_lat and o.geofence_lon:
            geofence = TaskGeofence(o.geofence_lat, o.geofence_lon, o.geofence_radius or 500)
        history = []
        for h in (o.status_history or []):
            history.append(TaskStatusHistoryEntry(
                from_status=h.get("from_status",""), to_status=h.get("to_status",""),
                changed_by=h.get("changed_by",""),
                changed_at=datetime.fromisoformat(h.get("changed_at", datetime.now(timezone.utc).isoformat())),
                note=h.get("note"),
            ))
        return Task(
            id=str(o.id), program_id=str(o.program_id),
            title=o.title, description=o.description,
            status=TaskStatus(o.status), priority=TaskPriority(o.priority),
            assignee_id=str(o.assignee_id) if o.assignee_id else None,
            supervisor_id=str(o.supervisor_id) if o.supervisor_id else None,
            due_date=o.due_date, geofence=geofence,
            evidence_required=o.evidence_required,
            evidence_ids=list(o.evidence_ids or []),
            status_history=history, tags=list(o.tags or []),
            estimated_hours=o.estimated_hours, actual_hours=o.actual_hours,
            created_by=str(o.created_by) if o.created_by else "",
            created_at=o.created_at, updated_at=o.updated_at, version=o.version,
        )

    @staticmethod
    def _to_orm(t: Task) -> TaskORM:
        history_dicts = [
            {"from_status": h.from_status, "to_status": h.to_status,
             "changed_by": h.changed_by, "changed_at": h.changed_at.isoformat(), "note": h.note}
            for h in t.status_history
        ]
        return TaskORM(
            id=uuid.UUID(t.id), program_id=uuid.UUID(t.program_id),
            title=t.title, description=t.description,
            status=t.status.value, priority=t.priority.value,
            assignee_id=uuid.UUID(t.assignee_id) if t.assignee_id else None,
            supervisor_id=uuid.UUID(t.supervisor_id) if t.supervisor_id else None,
            due_date=t.due_date,
            geofence_lat=t.geofence.latitude if t.geofence else None,
            geofence_lon=t.geofence.longitude if t.geofence else None,
            geofence_radius=t.geofence.radius_meters if t.geofence else 500,
            evidence_required=t.evidence_required, evidence_ids=t.evidence_ids,
            status_history=history_dicts, tags=t.tags,
            estimated_hours=t.estimated_hours, actual_hours=t.actual_hours,
            created_by=uuid.UUID(t.created_by) if t.created_by else None,
            created_at=t.created_at, updated_at=t.updated_at, version=t.version + 1,
        )

    async def get_by_id(self, task_id: str) -> Optional[Task]:
        r = await self._session.execute(select(TaskORM).where(TaskORM.id == task_id))
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def get_by_evidence_id(self, evidence_id: str) -> Optional[Task]:
        r = await self._session.execute(
            select(TaskORM).where(TaskORM.evidence_ids.contains([evidence_id]))
        )
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, task: Task) -> Task:
        merged = await self._session.merge(self._to_orm(task))
        await self._session.flush()
        return self._to_domain(merged)

    async def list_by_program(self, program_id: str, limit: int, offset: int) -> Tuple[List[Task], int]:
        stmt = select(TaskORM).where(TaskORM.program_id == program_id)
        total = (await self._session.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
        rows = (await self._session.execute(stmt.limit(limit).offset(offset).order_by(TaskORM.created_at.desc()))).scalars().all()
        return [self._to_domain(r) for r in rows], total

    async def list_by_assignee(self, assignee_id: str, status: Optional[str], limit: int, offset: int) -> Tuple[List[Task], int]:
        stmt = select(TaskORM).where(TaskORM.assignee_id == assignee_id)
        if status: stmt = stmt.where(TaskORM.status == status)
        total = (await self._session.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
        rows = (await self._session.execute(stmt.limit(limit).offset(offset))).scalars().all()
        return [self._to_domain(r) for r in rows], total

    async def count_by_program(self, program_id: str) -> int:
        r = await self._session.execute(select(func.count()).where(TaskORM.program_id == program_id))
        return r.scalar() or 0
