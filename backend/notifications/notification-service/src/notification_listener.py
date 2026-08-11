"""Kafka listener that turns domain events into user notifications.

Recipient contact data is resolved from the real ``users`` / ``user_profiles``
tables (owned by identity, shared Postgres). No fabricated tokens or profiles:
if a user has no resolvable email the event is skipped and logged. Push delivery
is attempted only when a real device token is available (device-token
registration is a separate capability); email is always real.
"""
import asyncio

from sqlalchemy import text

from shared.utils.kafka_consumer import KafkaConsumerBase
from shared.utils.logging import get_logger
from shared.base_repository.db import build_engine, build_session_factory
from .application.dispatcher import NotificationDispatcher
from .infrastructure.notification_repository_impl import SQLAlchemyNotificationRepository
from .infrastructure.providers import EmailProvider

try:
    from config import settings
except Exception:  # pragma: no cover
    from .config import settings  # type: ignore

log = get_logger(__name__)

TRIGGER_MAP = {
    "masaren.execution.evidence_verified": "VERIFICATION_APPROVED",
    "masaren.marketplace.opportunity_matched": "OPPORTUNITY_MATCH",
    "masaren.admin.action_required": "ADMIN_ACTION_REQUIRED",
}


class NotificationConsumer(KafkaConsumerBase):
    """Listens to domain events on Kafka and triggers real notifications."""

    def __init__(self, bootstrap_servers: str, fcm_key: str):
        super().__init__(bootstrap_servers=bootstrap_servers)
        self.fcm_key = fcm_key
        self.engine = build_engine()
        self.session_factory = build_session_factory(self.engine)
        self.email_provider = EmailProvider(
            host=settings.smtp_host, port=settings.smtp_port,
            username=settings.smtp_user, password=settings.smtp_password,
            sender=settings.smtp_from, use_tls=settings.smtp_use_tls,
        )

    async def _resolve_recipient(self, session, user_id: str) -> dict | None:
        """Fetch the user's real email, role and target audience. None if absent."""
        row = (await session.execute(text("""
            SELECT u.email AS email, u.role AS role,
                   COALESCE(p.target_audience, 'STUDENT') AS target_audience
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            WHERE u.id = :uid
        """), {"uid": user_id})).mappings().first()
        return dict(row) if row else None

    async def handle_event(self, event: dict):
        topic = event.get("topic", "")
        payload = event.get("payload", {})
        user_id = payload.get("user_id")
        if not user_id:
            return

        async with self.session_factory() as session:
            recipient = await self._resolve_recipient(session, user_id)
            if not recipient or not recipient.get("email"):
                log.warning("notification_skipped_no_recipient", user_id=user_id, topic=topic)
                return

            repo = SQLAlchemyNotificationRepository(session)
            dispatcher = NotificationDispatcher(
                fcm_key=self.fcm_key, repo=repo, email_provider=self.email_provider)

            # Only real, resolvable channels. Push is included only when a real
            # device token exists in the payload (e.g. forwarded by the client).
            tokens = {"EMAIL": recipient["email"]}
            device_token = payload.get("device_token")
            if device_token:
                tokens["PUSH"] = device_token

            await dispatcher.dispatch(
                user_id=user_id,
                trigger_type=TRIGGER_MAP.get(topic, "DEFAULT_UPDATE"),
                payload=payload,
                user_profile={"role": recipient["role"],
                              "target_audience": recipient["target_audience"]},
                tokens=tokens,
            )


async def start_notification_listener():
    consumer = NotificationConsumer(
        bootstrap_servers=settings.kafka_bootstrap_servers,
        fcm_key=settings.fcm_server_key,
    )
    await consumer.start(list(TRIGGER_MAP.keys()))
