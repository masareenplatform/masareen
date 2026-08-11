from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.review_queue import ReviewQueueItem, ReviewStatus
from ..domain.review_repository import ReviewQueueRepository
from .review_orm import ReviewQueueORM
import uuid
from datetime import datetime, timezone

class SQLAlchemyReviewRepository(ReviewQueueRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    def _to_domain(self, o: ReviewQueueORM) -> ReviewQueueItem:
        return ReviewQueueItem(
            id=str(o.id),
            entity_id=str(o.entity_id),
            entity_type=o.entity_type,
            confidence_score=o.confidence_score,
            assigned_admin_id=str(o.assigned_admin_id) if o.assigned_admin_id else None,
            status=ReviewStatus(o.status),
            admin_verdict=o.admin_verdict,
            admin_comments=o.admin_comments,
            created_at=o.created_at,
            resolved_at=o.resolved_at
        )

    async def add_item(self, item: ReviewQueueItem) -> ReviewQueueItem:
        orm = ReviewQueueORM(
            id=uuid.UUID(item.id) if item.id else uuid.uuid4(),
            entity_id=uuid.UUID(item.entity_id),
            entity_type=item.entity_type,
            confidence_score=item.confidence_score,
            assigned_admin_id=uuid.UUID(item.assigned_admin_id) if item.assigned_admin_id else None,
            status=item.status.value,
            admin_verdict=item.admin_verdict,
            admin_comments=item.admin_comments,
        )
        self._session.add(orm)
        await self._session.flush()
        return self._to_domain(orm)

    async def get_pending(self, limit: int, offset: int) -> List[ReviewQueueItem]:
        stmt = select(ReviewQueueORM).where(ReviewQueueORM.status == "PENDING").limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        return [self._to_domain(row) for row in result.scalars().all()]

    async def get_by_id(self, item_id: str) -> Optional[ReviewQueueItem]:
        stmt = select(ReviewQueueORM).where(ReviewQueueORM.id == uuid.UUID(item_id))
        result = await self._session.execute(stmt)
        orm = result.scalar_one_or_none()
        return self._to_domain(orm) if orm else None

    async def save(self, item: ReviewQueueItem) -> ReviewQueueItem:
        existing = await self.get_by_id(item.id)
        if not existing:
            return await self.add_item(item)

        # Upsert the full row by primary key via merge (real update path).
        orm_update = ReviewQueueORM(
            id=uuid.UUID(item.id),
            entity_id=uuid.UUID(item.entity_id),
            entity_type=item.entity_type,
            confidence_score=item.confidence_score,
            assigned_admin_id=uuid.UUID(item.assigned_admin_id) if item.assigned_admin_id else None,
            status=item.status.value,
            admin_verdict=item.admin_verdict,
            admin_comments=item.admin_comments,
            resolved_at=item.resolved_at
        )
        await self._session.merge(orm_update)
        await self._session.flush()
        return item
