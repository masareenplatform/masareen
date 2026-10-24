from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from .infrastructure.database import get_session as get_db_session
from .infrastructure.postgres_repository import NotificationRepository
from .infrastructure.providers import FCMProvider, EmailProvider
from .application.dispatcher import NotificationDispatcher
from .application.commands import SendNotificationCommand, MarkNotificationReadCommand, UpdateNotificationPreferencesCommand
from .application.queries import GetUserNotificationsQuery
from .application.handlers import (
    SendNotificationHandler, MarkReadHandler, UpdatePreferencesHandler, GetNotificationsHandler
)


def _build_dispatcher(repo) -> NotificationDispatcher:
    """Construct the dispatcher from real environment configuration.

    Missing credentials disable the corresponding channel (honest no-op that
    returns False), they never produce fabricated delivery receipts.
    """
    try:
        from config import settings
    except Exception:  # pragma: no cover
        from ..config import settings  # type: ignore
    email_provider = EmailProvider(
        host=settings.smtp_host, port=settings.smtp_port,
        username=settings.smtp_user, password=settings.smtp_password,
        sender=settings.smtp_from, use_tls=settings.smtp_use_tls,
    )
    return NotificationDispatcher(fcm_key=settings.fcm_server_key, repo=repo,
                                  email_provider=email_provider)


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    repo = NotificationRepository(session)
    dispatcher = _build_dispatcher(repo)
    bus.register(SendNotificationCommand, SendNotificationHandler(repo, dispatcher, session, outbox))
    bus.register(MarkNotificationReadCommand, MarkReadHandler(repo))
    bus.register(UpdateNotificationPreferencesCommand, UpdatePreferencesHandler(repo))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = NotificationRepository(session)
    bus.register(GetUserNotificationsQuery, GetNotificationsHandler(repo))
    return bus
