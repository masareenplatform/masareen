"""
Identity service event consumers.
Listens for events from other services that affect user state.
"""
from __future__ import annotations
from typing import Any, Dict

from shared.utils.kafka_consumer import EventConsumer
from shared.utils.logging import get_logger

log = get_logger(__name__)


class IdentityEventConsumer(EventConsumer):
    """
    Consumes events relevant to the Identity domain.
    Example: CertificateIssued → update user certificate count.
    """

    def __init__(self, session_factory, publisher):
        super().__init__(
            topics=[
                "masaren.reputation.certificate_issued.v1",
                "masaren.reputation.impact_asset_created.v1",
            ],
            group_id="identity-service-consumer",
        )
        self._session_factory = session_factory

    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None:
        log.info(
            "event_received",
            event_type=event_type,
            topic=topic,
            aggregate_id=payload.get("aggregate_id"),
        )
        if event_type == "CertificateIssued":
            await self._handle_certificate_issued(payload)
        elif event_type == "ImpactAssetCreated":
            await self._handle_impact_asset_created(payload)

    async def _handle_certificate_issued(self, payload: Dict[str, Any]) -> None:
        user_id = payload.get("metadata", {}).get("user_id") or payload.get("user_id")
        if not user_id:
            return
        from ..infrastructure.user_repository_impl import SQLAlchemyUserRepository
        from ..domain.user_repository import UserRepository
        async with self._session_factory() as session:
            repo: UserRepository = SQLAlchemyUserRepository(session)
            user = await repo.get_by_id(user_id)
            if not user:
                log.warning("certificate_issued_user_not_found", user_id=user_id)
                return
            user.increment_certificate_count()
            await repo.save(user)
            log.info("certificate_count_updated", user_id=user_id, count=user.certificate_count)

    async def _handle_impact_asset_created(self, payload: Dict[str, Any]) -> None:
        user_id = payload.get("metadata", {}).get("user_id") or payload.get("user_id")
        if not user_id:
            return
        from ..infrastructure.user_repository_impl import SQLAlchemyUserRepository
        from ..domain.user_repository import UserRepository
        async with self._session_factory() as session:
            repo: UserRepository = SQLAlchemyUserRepository(session)
            user = await repo.get_by_id(user_id)
            if not user:
                log.warning("impact_asset_user_not_found", user_id=user_id)
                return
            user.increment_impact_asset_count()
            await repo.save(user)
            log.info("impact_asset_count_updated", user_id=user_id, count=user.impact_asset_count)
