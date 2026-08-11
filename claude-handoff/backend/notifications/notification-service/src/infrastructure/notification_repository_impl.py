from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import json
from ..domain.notification import Notification, NotificationStatus
from ..domain.notification_repository import NotificationRepository
from .notification_orm import NotificationORM
import uuid

class SQLAlchemyNotificationRepository(NotificationRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    def _to_domain(self, o: NotificationORM) -> Notification:
        return Notification(
            id=str(o.id),
            user_id=str(o.user_id),
            trigger_type=o.trigger_type,
            title=o.title,
            body=o.body,
            payload=json.loads(o.payload) if o.payload else {},
            status=NotificationStatus(o.status),
            channel_used=o.channel_used,
            sent_at=o.sent_at,
            read_at=o.read_at,
            created_at=o.created_at,
            updated_at=o.updated_at
        )

    async def save(self, notification: Notification) -> Notification:
        orm = NotificationORM(
            id=uuid.UUID(notification.id),
            user_id=uuid.UUID(notification.user_id),
            trigger_type=notification.trigger_type,
            title=notification.title,
            body=notification.body,
            payload=json.dumps(notification.payload),
            status=notification.status.value,
            channel_used=notification.channel_used,
            sent_at=notification.sent_at,
            read_at=notification.read_at,
        )
        self._session.merge(orm)
        await self._session.flush()
        return notification

    async def get_by_user(self, user_id: str, limit: int, offset: int) -> List[Notification]:
        stmt = select(NotificationORM).where(NotificationORM.user_id == uuid.UUID(user_id)).order_by(NotificationORM.created_at.desc()).limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        return [self._to_domain(row) for row in result.scalars().all()]

    async def mark_as_read(self, notification_id: str) -> bool:
        orm = await self._session.get(NotificationORM, uuid.UUID(notification_id))
        if orm:
            orm.status = "READ"
            from datetime import datetime, timezone
            orm.read_at = datetime.now(timezone.utc)
            await self._session.flush()
            return True
        return False
