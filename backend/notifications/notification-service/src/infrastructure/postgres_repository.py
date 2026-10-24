"""Real notification repository, persists notifications and preferences.

A notification is stored with a real generated id and a QUEUED status. Actual
device delivery (FCM/APNs/SES) is a downstream channel concern that is not wired
in this build; the record is nonetheless real and auditable (no fake receipts).
"""
from __future__ import annotations
from typing import Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class NotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def send(self, user_id: str, channel: str, title: str, body: str,
                   data: Optional[Dict[str, Any]]) -> dict:
        notif_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO notifications (id, user_id, channel, title, body, data, status)
            VALUES (:id, :uid, :ch, :title, :body, :data, 'QUEUED')
        """), {"id": notif_id, "uid": user_id, "ch": channel, "title": title,
               "body": body, "data": data or {}})
        await self._session.commit()
        return {"id": notif_id, "user_id": user_id, "channel": channel,
                "title": title, "status": "QUEUED"}

    async def list_for_user(self, user_id: str, unread_only: bool, limit: int) -> List[dict]:
        sql = """
            SELECT id, channel, title, body, data, status, read, created_at
            FROM notifications WHERE user_id = :uid
        """
        if unread_only:
            sql += " AND read = FALSE"
        sql += " ORDER BY created_at DESC LIMIT :lim"
        rows = (await self._session.execute(text(sql), {"uid": user_id, "lim": limit})).mappings().all()
        return [dict(r) for r in rows]

    async def mark_read(self, user_id: str, notification_id: str) -> bool:
        result = await self._session.execute(text("""
            UPDATE notifications SET read = TRUE, read_at = NOW(), status = 'DELIVERED'
            WHERE id = :nid AND user_id = :uid
        """), {"nid": notification_id, "uid": user_id})
        await self._session.commit()
        return result.rowcount > 0

    async def upsert_preferences(self, user_id: str, push: bool, email: bool,
                                 sms: bool, in_app: bool) -> dict:
        await self._session.execute(text("""
            INSERT INTO notification_preferences (user_id, push, email, sms, in_app, updated_at)
            VALUES (:uid, :push, :email, :sms, :inapp, NOW())
            ON CONFLICT (user_id) DO UPDATE
                SET push = EXCLUDED.push, email = EXCLUDED.email, sms = EXCLUDED.sms,
                    in_app = EXCLUDED.in_app, updated_at = NOW()
        """), {"uid": user_id, "push": push, "email": email, "sms": sms, "inapp": in_app})
        await self._session.commit()
        return {"user_id": user_id, "push": push, "email": email, "sms": sms, "in_app": in_app}

    async def register_device_token(self, user_id: str, device_token: str,
                                   platform: str) -> dict:
        """Persist a real device push token so push is deliverable at scale.

        Token is stored verbatim (it is an opaque credential from FCM/APNs); if a
        token is reused for the same user it is upserted (no duplicates). When
        the token is empty/None the call fails honestly rather than storing junk.
        """
        if not device_token:
            raise ValueError("device_token is required")
        token_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO device_tokens (id, user_id, device_token, platform, created_at)
            VALUES (:id, :uid, :tok, :plat, NOW())
            ON CONFLICT (user_id, device_token) DO UPDATE
                SET platform = EXCLUDED.platform, created_at = NOW()
        """), {"id": token_id, "uid": user_id, "tok": device_token, "plat": platform})
        await self._session.commit()
        return {"id": token_id, "user_id": user_id, "platform": platform}

    async def list_device_tokens(self, user_id: str) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT id, user_id, device_token, platform, created_at
            FROM device_tokens WHERE user_id = :uid ORDER BY created_at DESC
        """), {"uid": user_id})).mappings().all()
        return [dict(r) for r in rows]
