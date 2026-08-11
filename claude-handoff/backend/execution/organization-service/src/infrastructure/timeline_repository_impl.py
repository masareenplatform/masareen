from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.timeline import TimelineEvent
from ..domain.timeline_repository import TimelineRepository
from .orm_models import TimelineEventORM
import uuid
from datetime import datetime, timezone

class SQLAlchemyTimelineRepository(TimelineRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    def _to_domain(self, o: TimelineEventORM) -> TimelineEvent:
        return TimelineEvent(
            id=str(o.id),
            entity_id=str(o.entity_id),
            event_type=o.event_type,
            title=o.title,
            description=o.description or "",
            date=o.date,
            media_url=o.media_url,
            metric_value=o.metric_value,
            metadata=o.metadata_json or {}
        )

    async def add_event(self, event: TimelineEvent) -> TimelineEvent:
        orm = TimelineEventORM(
            id=uuid.UUID(event.id),
            entity_id=uuid.UUID(event.entity_id),
            event_type=event.event_type,
            title=event.title,
            description=event.description,
            date=event.date,
            media_url=event.media_url,
            metric_value=event.metric_value,
            metadata_json=event.metadata
        )
        self._session.add(orm)
        await self._session.flush()
        return self._to_domain(orm)

    async def get_by_entity_id(self, entity_id: str) -> List[TimelineEvent]:
        stmt = select(TimelineEventORM).where(TimelineEventORM.entity_id == uuid.UUID(entity_id))
        result = await self._session.execute(stmt)
        return [self._to_domain(row) for row in result.scalars().all()]

    async def delete_event(self, event_id: str) -> bool:
        stmt = select(TimelineEventORM).where(TimelineEventORM.id == uuid.UUID(event_id))
        result = await self._session.execute(stmt)
        orm = result.scalar_one_or_none()
        if orm:
            await self._session.delete(orm)
            await self._session.flush()
            return True
        return False
