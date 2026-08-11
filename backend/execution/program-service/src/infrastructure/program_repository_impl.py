from typing import List, Optional, Tuple
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.program import Program, ProgramStatus, ProgramMilestone
from ..domain.program_repository import ProgramRepository
from .orm_models import ProgramORM
import uuid
from datetime import datetime, timezone


def _looks_like_uuid(value: str) -> bool:
    try:
        uuid.UUID(value)
        return True
    except (ValueError, AttributeError, TypeError):
        return False


class SQLAlchemyProgramRepository(ProgramRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: ProgramORM) -> Program:
        milestones = []
        for m in (o.milestones or []):
            milestones.append(ProgramMilestone(
                id=m.get("id", ""), title=m.get("title", ""),
                due_date=m.get("due_date"), completed=m.get("completed", False),
            ))
        return Program(
            id=str(o.id), organization_id=str(o.organization_id),
            title=o.title, description=o.description,
            status=ProgramStatus(o.status),
            start_date=o.start_date, end_date=o.end_date,
            sdg_goals=list(o.sdg_goals or []), country=o.country,
            city=o.city, latitude=o.latitude, longitude=o.longitude,
            max_participants=o.max_participants, enrolled_count=o.enrolled_count or 0,
            milestones=milestones, tags=list(o.tags or []),
            created_by=str(o.created_by) if o.created_by else "",
            created_at=o.created_at, updated_at=o.updated_at, version=o.version,
        )

    @staticmethod
    def _to_orm(p: Program) -> ProgramORM:
        milestone_dicts = [
            {"id": m.id, "title": m.title, "due_date": m.due_date, "completed": m.completed}
            for m in p.milestones
        ]
        return ProgramORM(
            id=uuid.UUID(p.id), organization_id=uuid.UUID(p.organization_id),
            title=p.title, description=p.description,
            status=p.status.value,
            start_date=p.start_date, end_date=p.end_date,
            sdg_goals=p.sdg_goals, country=p.country,
            city=p.city, latitude=p.latitude, longitude=p.longitude,
            max_participants=p.max_participants, enrolled_count=p.enrolled_count,
            milestones=milestone_dicts, tags=p.tags,
            created_by=(
                uuid.UUID(p.created_by)
                if p.created_by and _looks_like_uuid(p.created_by)
                else None
            ),
            created_at=p.created_at, updated_at=p.updated_at, version=p.version + 1,
        )

    async def get_by_id(self, program_id: str) -> Optional[Program]:
        r = await self._session.execute(select(ProgramORM).where(ProgramORM.id == program_id))
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, program: Program) -> Program:
        merged = await self._session.merge(self._to_orm(program))
        await self._session.flush()
        return self._to_domain(merged)

    async def list_by_organization(self, org_id: str, limit: int, offset: int) -> Tuple[List[Program], int]:
        stmt = select(ProgramORM).where(ProgramORM.organization_id == org_id)
        total = (await self._session.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
        rows = (await self._session.execute(stmt.limit(limit).offset(offset).order_by(ProgramORM.created_at.desc()))).scalars().all()
        return [self._to_domain(r) for r in rows], total

    async def list_programs(self, limit: int, offset: int, status: Optional[str], country: Optional[str]) -> Tuple[List[Program], int]:
        stmt = select(ProgramORM)
        if status: stmt = stmt.where(ProgramORM.status == status)
        if country: stmt = stmt.where(ProgramORM.country == country)
        total = (await self._session.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
        rows = (await self._session.execute(stmt.limit(limit).offset(offset).order_by(ProgramORM.created_at.desc()))).scalars().all()
        return [self._to_domain(r) for r in rows], total
