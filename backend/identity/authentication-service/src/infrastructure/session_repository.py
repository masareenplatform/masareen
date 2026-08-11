"""SQLAlchemy implementation of SessionRepository."""
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.session import AuthSession, SessionStatus
from ..domain.session_repository import SessionRepository
from .orm_models import AuthSessionORM
from datetime import datetime, timezone
import uuid


class SQLAlchemySessionRepository(SessionRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: AuthSessionORM) -> AuthSession:
        return AuthSession(
            id=str(o.id), user_id=str(o.user_id),
            refresh_token=o.refresh_token,
            status=SessionStatus(o.status),
            device_info=o.device_info, ip_address=o.ip_address,
            created_at=o.created_at, expires_at=o.expires_at,
            revoked_at=o.revoked_at,
        )

    @staticmethod
    def _to_orm(s: AuthSession) -> AuthSessionORM:
        return AuthSessionORM(
            id=uuid.UUID(s.id), user_id=uuid.UUID(s.user_id),
            refresh_token=s.refresh_token, status=s.status.value,
            device_info=s.device_info, ip_address=s.ip_address,
            created_at=s.created_at, expires_at=s.expires_at,
            revoked_at=s.revoked_at,
        )

    async def get_by_refresh_token(self, refresh_token: str) -> Optional[AuthSession]:
        r = await self._session.execute(
            select(AuthSessionORM).where(AuthSessionORM.refresh_token == refresh_token)
        )
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, session: AuthSession) -> AuthSession:
        merged = await self._session.merge(self._to_orm(session))
        await self._session.flush()
        return self._to_domain(merged)
