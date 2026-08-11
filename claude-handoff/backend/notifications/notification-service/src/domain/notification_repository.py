from typing import List, Optional
from .notification import Notification

class NotificationRepository:
    async def save(self, notification: Notification) -> Notification:
        raise NotImplementedError

    async def get_by_user(self, user_id: str, limit: int, offset: int) -> List[Notification]:
        raise NotImplementedError

    async def mark_as_read(self, notification_id: str) -> bool:
        raise NotImplementedError
