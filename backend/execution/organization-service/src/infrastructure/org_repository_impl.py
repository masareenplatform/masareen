from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.organization import Organization, OrgType, OrgStatus, OrganizationAddress, OrganizationProfile
from ..domain.organization_repository import OrganizationRepository
from .orm_models import (
    OrganizationORM, MediaInstitutionProfileORM, SportsInstitutionProfileORM, 
    EducationInstitutionProfileORM, GovernmentInstitutionProfileORM, TimelineEventORM
)
import uuid

class SQLAlchemyOrgRepository(OrganizationRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    @staticmethod
    async def _fetch_profile_data(session: AsyncSession, org: OrganizationORM) -> Optional[OrganizationProfile]:
        if org.org_type == OrgType.MEDIA.value:
            r = await session.execute(select(MediaInstitutionProfileORM).where(MediaInstitutionProfileORM.org_id == org.id))
            p = r.scalar_one_or_none()
            if p: return OrganizationProfile(data={
                "distribution_channels": p.distribution_channels,
                "content_strategy": p.content_strategy,
                "verification_level": p.verification_level,
                "official_handle": p.official_handle
            })
        elif org.org_type == OrgType.SPORTS.value:
            r = await session.execute(select(SportsInstitutionProfileORM).where(SportsInstitutionProfileORM.org_id == org.id))
            p = r.scalar_one_or_none()
            if p: return OrganizationProfile(data={
                "league": p.league,
                "division": p.division,
                "trophies": p.trophies,
                "stadium_name": p.stadium_name,
                "stadium_capacity": p.stadium_capacity
            })
        elif org.org_type == OrgType.EDUCATION.value:
            r = await session.execute(select(EducationInstitutionProfileORM).where(EducationInstitutionProfileORM.org_id == org.id))
            p = r.scalar_one_or_none()
            if p: return OrganizationProfile(data={
                "accreditations": p.accreditations,
                "ranking_global": p.ranking_global,
                "specializations": p.specializations,
                "campus_count": p.campus_count
            })
        elif org.org_type == OrgType.GOVERNMENT.value:
            r = await session.execute(select(GovernmentInstitutionProfileORM).where(GovernmentInstitutionProfileORM.org_id == org.id))
            p = r.scalar_one_or_none()
            if p: return OrganizationProfile(data={
                "jurisdiction": p.jurisdiction,
                "department_head": p.department_head,
                "transparency_rating": p.transparency_rating,
                "service_categories": p.service_categories
            })
        return None

    async def _to_domain(self, o: OrganizationORM) -> Organization:
        profile = await self._fetch_profile_data(self._session, o)
        return Organization(
            id=str(o.id), name=o.name, slug=o.slug,
            org_type=OrgType(o.org_type), status=OrgStatus(o.status),
            description=o.description, website=o.website, logo_url=o.logo_url,
            address=OrganizationAddress(country=o.country, city=o.city),
            oii_score=o.oii_score, verified=o.verified,
            member_ids=list(o.member_ids or []), admin_ids=list(o.admin_ids or []),
            created_at=o.created_at, updated_at=o.updated_at, version=o.version,
            profile=profile
        )

    @staticmethod
    def _to_orm(org: Organization) -> OrganizationORM:
        return OrganizationORM(
            id=uuid.UUID(org.id), name=org.name, slug=org.slug,
            org_type=org.org_type.value, status=org.status.value,
            description=org.description, website=org.website, logo_url=org.logo_url,
            country=org.address.country if org.address else "",
            city=org.address.city if org.address else None,
            oii_score=org.oii_score, verified=org.verified,
            member_ids=org.member_ids, admin_ids=org.admin_ids,
            created_at=org.created_at, updated_at=org.updated_at, version=org.version + 1,
        )

    async def get_by_id(self, org_id: str) -> Optional[Organization]:
        r = await self._session.execute(select(OrganizationORM).where(OrganizationORM.id == org_id))
        o = r.scalar_one_or_none()
        return await self._to_domain(o) if o else None

    async def get_by_slug(self, slug: str) -> Optional[Organization]:
        r = await self._session.execute(select(OrganizationORM).where(OrganizationORM.slug == slug))
        o = r.scalar_one_or_none()
        return await self._to_domain(o) if o else None

    async def exists_by_slug(self, slug: str) -> bool:
        r = await self._session.execute(select(func.count()).where(OrganizationORM.slug == slug))
        return r.scalar() > 0

    async def save(self, org: Organization) -> Organization:
        merged = await self._session.merge(self._to_orm(org))
        
        if org.profile:
            data = org.profile.data
            if org.org_type == OrgType.MEDIA:
                profile_orm = MediaInstitutionProfileORM(org_id=merged.id, **data)
                await self._session.merge(profile_orm)
            elif org.org_type == OrgType.SPORTS:
                profile_orm = SportsInstitutionProfileORM(org_id=merged.id, **data)
                await self._session.merge(profile_orm)
            elif org.org_type == OrgType.EDUCATION:
                profile_orm = EducationInstitutionProfileORM(org_id=merged.id, **data)
                await self._session.merge(profile_orm)
            elif org.org_type == OrgType.GOVERNMENT:
                profile_orm = GovernmentInstitutionProfileORM(org_id=merged.id, **data)
                await self._session.merge(profile_orm)

        await self._session.flush()
        return await self._to_domain(merged)

    async def list_organizations(self, limit: int, offset: int, org_type: Optional[str]) -> Tuple[List[Organization], int]:
        stmt = select(OrganizationORM)
        if org_type:
            stmt = stmt.where(OrganizationORM.org_type == org_type)
        total = (await self._session.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
        rows  = (await self._session.execute(stmt.limit(limit).offset(offset).order_by(OrganizationORM.created_at.desc()))).scalars().all()
        return [await self._to_domain(r) for r in rows], total
