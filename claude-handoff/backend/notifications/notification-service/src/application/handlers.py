from shared.exceptions import NotFoundException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from ..infrastructure.postgres_repository import NotificationRepository
from ..application.dispatcher import NotificationDispatcher
from .commands import SendNotificationCommand, MarkNotificationReadCommand, UpdateNotificationPreferencesCommand
from .queries import GetUserNotificationsQuery

class SendNotificationHandler(CommandHandler):
    def __init__(self, repo: NotificationRepository, dispatcher: NotificationDispatcher, session, outbox: OutboxWriter):
        self._repo = repo; self._dispatcher = dispatcher; self._session = session; self._outbox = outbox
    async def handle(self, cmd: SendNotificationCommand) -> dict:
        trigger = cmd.data.get("trigger", "GENERAL") if cmd.data else "GENERAL"

        # 1. Persist the notification (real row, auditable, no fake receipts).
        saved = await self._repo.send(cmd.user_id, cmd.channel, cmd.title, cmd.body, cmd.data)

        # 2. Resolve the REAL recipient from the shared users table, then dispatch.
        #    No fabricated tokens: if there's no email/token, the channel is skipped.
        recipient = await self._resolve_recipient(cmd.user_id)
        if recipient and recipient.get("email"):
            tokens = {"EMAIL": recipient["email"]}
            device_token = (cmd.data or {}).get("device_token")
            if device_token:
                tokens["PUSH"] = device_token
            try:
                await self._dispatcher.dispatch(
                    user_id=cmd.user_id, trigger_type=trigger,
                    payload=cmd.data or {},
                    user_profile={"role": recipient.get("role", "INDIVIDUAL"),
                                  "target_audience": recipient.get("target_audience", "STUDENT")},
                    tokens=tokens,
                    title=cmd.title, body=cmd.body,
                )
            except Exception:
                # Delivery failures must not fail persistence; the row stays QUEUED.
                pass

        return {"notification_id": saved["id"], "status": saved["status"]}

    async def _resolve_recipient(self, user_id: str):
        from sqlalchemy import text
        row = (await self._session.execute(text("""
            SELECT u.email AS email, u.role AS role,
                   COALESCE(p.target_audience, 'STUDENT') AS target_audience
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            WHERE u.id = :uid
        """), {"uid": user_id})).mappings().first()
        return dict(row) if row else None

class MarkReadHandler(CommandHandler):
    def __init__(self, repo: NotificationRepository):
        self._repo = repo
    async def handle(self, cmd: MarkNotificationReadCommand) -> dict:
        ok = await self._repo.mark_read(cmd.user_id, cmd.notification_id)
        if not ok: raise NotFoundException("Notification", cmd.notification_id)
        return {"notification_id": cmd.notification_id, "read": True}

class UpdatePreferencesHandler(CommandHandler):
    def __init__(self, repo: NotificationRepository):
        self._repo = repo
    async def handle(self, cmd: UpdateNotificationPreferencesCommand) -> dict:
        data = await self._repo.upsert_preferences(
            cmd.user_id, cmd.push, cmd.email, cmd.sms, cmd.in_app)
        return data

class GetNotificationsHandler(QueryHandler):
    def __init__(self, repo: NotificationRepository):
        self._repo = repo
    async def handle(self, q: GetUserNotificationsQuery):
        return await self._repo.list_for_user(q.user_id, q.unread_only, q.limit)
