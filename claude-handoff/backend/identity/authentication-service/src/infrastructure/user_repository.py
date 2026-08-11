"""SQLAlchemy implementation of AuthUserRepository."""
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.user import AuthUser, UserRole, UserStatus
from ..domain.user_repository import AuthUserRepository
from .orm_models import AuthUserORM
import uuid


class SQLAlchemyAuthUserRepository(AuthUserRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    def _to_domain(o: AuthUserORM) -> AuthUser:
        return AuthUser(
            id=str(o.id), email=o.email, full_name=o.full_name,
            role=UserRole(o.role), status=UserStatus(o.status),
            hashed_password=o.hashed_password,
            created_at=o.created_at, updated_at=o.updated_at,
        )

    @staticmethod
    def _to_orm(u: AuthUser) -> AuthUserORM:
        return AuthUserORM(
            id=uuid.UUID(u.id), email=u.email, full_name=u.full_name,
            role=u.role.value, status=u.status.value,
            hashed_password=u.hashed_password,
            created_at=u.created_at, updated_at=u.updated_at,
        )

    async def get_by_email(self, email: str) -> Optional[AuthUser]:
        r = await self._session.execute(
            select(AuthUserORM).where(AuthUserORM.email == email.lower().strip())
        )
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def get_by_id(self, user_id: str) -> Optional[AuthUser]:
        r = await self._session.execute(
            select(AuthUserORM).where(AuthUserORM.id == user_id)
        )
        o = r.scalar_one_or_none()
        return self._to_domain(o) if o else None

    async def save(self, user: AuthUser) -> AuthUser:
        merged = await self._session.merge(self._to_orm(user))
        await self._session.flush()
        return self._to_domain(merged)
