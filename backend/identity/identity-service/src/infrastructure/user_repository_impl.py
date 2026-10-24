"""
SQLAlchemy implementation of the UserRepository port.
The domain never sees SQLAlchemy, this layer translates between ORM and domain.
"""
from __future__ import annotations
from typing import List, Optional, Tuple

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..domain.user import User, UserProfile, UserSkill, UserRole, UserStatus
from ..domain.user_repository import UserRepository
from .orm_models import UserORM, UserProfileORM, UserSkillORM


class SQLAlchemyUserRepository(UserRepository):

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # ── Mapping helpers ───────────────────────────────────────────────────────
    @staticmethod
    def _to_domain(orm: UserORM) -> User:
        profile = UserProfile(
            bio        = orm.profile.bio        if orm.profile else None,
            avatar_url = orm.profile.avatar_url if orm.profile else None,
            cover_url  = orm.profile.cover_url  if orm.profile else None,
            country    = orm.profile.country    if orm.profile else None,
            city       = orm.profile.city       if orm.profile else None,
            languages  = orm.profile.languages  if orm.profile else [],
            latitude   = orm.profile.latitude   if orm.profile else None,
            longitude  = orm.profile.longitude  if orm.profile else None,
            target_audience = orm.profile.target_audience or "STUDENT",
            gallery_ids = [str(g) for g in (orm.profile.gallery_ids if orm.profile else [])],
            followers_count = orm.profile.followers_count if orm.profile else 0,
            following_count = orm.profile.following_count if orm.profile else 0,
            website    = orm.profile.website    if orm.profile else None,
            social_links = orm.profile.social_links if orm.profile else {},
        )
        skills = [
            UserSkill(
                skill_id    = str(s.skill_id),
                skill_name  = s.skill.name if s.skill else "",
                proficiency = s.proficiency,
                verified    = s.verified,
            )
            for s in (orm.skills or [])
        ]
        return User(
            id              = str(orm.id),
            email           = orm.email,
            full_name        = orm.full_name,
            phone           = orm.phone,
            role            = UserRole(orm.role),
            status          = UserStatus(orm.status),
            hashed_password = orm.hashed_password,
            email_verified  = orm.email_verified,
            phone_verified  = orm.phone_verified,
            pms_score       = orm.pms_score,
            certificate_count = orm.certificate_count,
            impact_asset_count = orm.impact_asset_count,
            profile         = profile,
            skills          = skills,
            created_at      = orm.created_at,
            updated_at      = orm.updated_at,
            version         = orm.version,
        )

    @staticmethod
    def _to_orm(user: User) -> UserORM:
        import uuid
        orm = UserORM(
            id              = uuid.UUID(user.id),
            email           = user.email,
            full_name        = user.full_name,
            phone           = user.phone,
            role            = user.role.value,
            status          = user.status.value,
            hashed_password = user.hashed_password,
            email_verified  = user.email_verified,
            phone_verified  = user.phone_verified,
            pms_score       = user.pms_score,
            certificate_count = user.certificate_count,
            impact_asset_count = user.impact_asset_count,
            version         = user.version + 1,
            created_at      = user.created_at,
            updated_at      = user.updated_at,
        )
        if user.profile:
            orm.profile = UserProfileORM(
                user_id    = uuid.UUID(user.id),
                bio        = user.profile.bio,
                avatar_url = user.profile.avatar_url,
                country    = user.profile.country,
                city       = user.profile.city,
                languages  = user.profile.languages,
                latitude   = user.profile.latitude,
                longitude  = user.profile.longitude,
            )
        return orm

    # ── Interface implementation ──────────────────────────────────────────────
    async def get_by_id(self, user_id: str) -> Optional[User]:
        stmt = (
            select(UserORM)
            .where(UserORM.id == user_id)
            .options(selectinload(UserORM.profile),
                     selectinload(UserORM.skills).selectinload(UserSkillORM.skill))
        )
        result = await self._session.execute(stmt)
        orm = result.scalar_one_or_none()
        return self._to_domain(orm) if orm else None

    async def get_by_email(self, email: str) -> Optional[User]:
        stmt = (
            select(UserORM)
            .where(UserORM.email == email.lower().strip())
            .options(selectinload(UserORM.profile),
                     selectinload(UserORM.skills).selectinload(UserSkillORM.skill))
        )
        result = await self._session.execute(stmt)
        orm = result.scalar_one_or_none()
        return self._to_domain(orm) if orm else None

    async def exists_by_email(self, email: str) -> bool:
        stmt = select(func.count()).where(UserORM.email == email.lower().strip())
        result = await self._session.execute(stmt)
        return result.scalar() > 0

    async def save(self, user: User) -> User:
        orm = self._to_orm(user)
        merged = await self._session.merge(orm)
        await self._session.flush()
        # Re-query with explicit eager loads so _to_domain never triggers a lazy
        # (sync) load, which fails under AsyncSession with MissingGreenlet.
        stmt = (
            select(UserORM)
            .where(UserORM.id == merged.id)
            .options(selectinload(UserORM.profile),
                     selectinload(UserORM.skills).selectinload(UserSkillORM.skill))
        )
        reloaded = (await self._session.execute(stmt)).scalar_one()
        return self._to_domain(reloaded)

    async def delete(self, user_id: str) -> None:
        stmt = select(UserORM).where(UserORM.id == user_id)
        result = await self._session.execute(stmt)
        orm = result.scalar_one_or_none()
        if orm:
            await self._session.delete(orm)

    async def list_users(
        self, limit: int = 20, offset: int = 0, role: Optional[str] = None
    ) -> Tuple[List[User], int]:
        stmt = select(UserORM).options(
            selectinload(UserORM.profile),
            selectinload(UserORM.skills).selectinload(UserSkillORM.skill),
        )
        if role:
            stmt = stmt.where(UserORM.role == role)

        count_stmt = select(func.count()).select_from(stmt.subquery())
        total_result = await self._session.execute(count_stmt)
        total = total_result.scalar() or 0

        stmt = stmt.limit(limit).offset(offset).order_by(UserORM.created_at.desc())
        result = await self._session.execute(stmt)
        users = [self._to_domain(row) for row in result.scalars().all()]
        return users, total
