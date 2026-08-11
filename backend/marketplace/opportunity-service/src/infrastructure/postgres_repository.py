"""Real opportunity repository — persists and queries opportunities and
applications against the `opportunities` / `opportunity_applications` tables.
"""
from __future__ import annotations
from typing import Dict, List, Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..domain.opportunity import (
    Opportunity, OpportunityType, OpportunityStatus, PMSRequirement,
)


class OpportunityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _row_to_domain(r) -> Opportunity:
        return Opportunity(
            id=str(r["id"]), organization_id=str(r["organization_id"]),
            title=r["title"], opp_type=OpportunityType(r["opp_type"]),
            status=OpportunityStatus(r["status"]), description=r["description"],
            country=r["country"], city=r["city"],
            remote=bool(r["remote"]), min_pms_score=float(r["min_pms_score"] or 0.0),
            required_skills=list(r["required_skills"] or []),
            required_sdgs=list(r["required_sdgs"] or []),
            compensation_usd=float(r["compensation_usd"]) if r["compensation_usd"] is not None else None,
            deadline=r["deadline"], applicant_count=int(r["applicant_count"] or 0),
            created_by=str(r["created_by"] or ""),
        )

    async def create(self, opp: Opportunity) -> Opportunity:
        await self._session.execute(text("""
            INSERT INTO opportunities
                (id, organization_id, title, opp_type, status, description, country,
                 city, remote, min_pms_score, required_skills, required_sdgs,
                 compensation_usd, deadline, applicant_count, created_by, created_at, updated_at)
            VALUES (:id, :org, :title, :ot, :st, :desc, :country, :city, :remote,
                    :minpms, :skills, :sdgs, :comp, :deadline, 0, :cb, NOW(), NOW())
        """), {
            "id": opp.id, "org": opp.organization_id, "title": opp.title,
            "ot": opp.opp_type.value, "st": opp.status.value, "desc": opp.description,
            "country": opp.country, "city": opp.city, "remote": opp.remote,
            "minpms": opp.min_pms_score, "skills": opp.required_skills,
            "sdgs": opp.required_sdgs, "comp": opp.compensation_usd,
            "deadline": opp.deadline, "cb": opp.created_by,
        })
        await self._session.commit()
        return opp

    async def get(self, opp_id: str) -> Optional[Opportunity]:
        rows = await self._session.execute(
            text("SELECT * FROM opportunities WHERE id=:oid"), {"oid": opp_id})
        r = rows.mappings().first()
        return self._row_to_domain(r) if r else None

    async def list(self, opp_type: Optional[str], country: Optional[str],
                   remote: Optional[bool], min_pms: float, limit: int, offset: int) -> List[Opportunity]:
        clauses, params = [], {"lim": limit, "off": offset, "minpms": min_pms}
        if opp_type:
            clauses.append("opp_type = :ot"); params["ot"] = opp_type
        if country:
            clauses.append("country = :c"); params["c"] = country
        if remote is not None:
            clauses.append("remote = :r"); params["r"] = remote
        where = (" WHERE " + " AND ".join(clauses) + " AND min_pms_score >= :minpms") if clauses \
            else " WHERE min_pms_score >= :minpms"
        rows = await self._session.execute(text(
            f"SELECT * FROM opportunities{where} ORDER BY created_at DESC LIMIT :lim OFFSET :off"),
            params)
        return [self._row_to_domain(r) for r in rows.mappings()]

    async def set_status(self, opp_id: str, status: str) -> None:
        await self._session.execute(text(
            "UPDATE opportunities SET status=:st, updated_at=NOW() WHERE id=:oid"),
            {"st": status, "oid": opp_id})
        await self._session.commit()

    async def get_applicant_profile(self, user_id: str) -> dict:
        """Real applicant profile for matching: latest PMS, verified skills, and
        SDG experience derived from the applicant's impact assets. Missing data
        yields empty/zero values (never fabricated)."""
        pms = (await self._session.execute(text(
            "SELECT composite_score FROM pms_scores WHERE user_id=:uid "
            "ORDER BY computed_at DESC LIMIT 1"), {"uid": user_id})).scalar()
        skill_rows = (await self._session.execute(text(
            "SELECT s.name FROM user_skills us JOIN skills s ON s.id = us.skill_id "
            "WHERE us.user_id = :uid"), {"uid": user_id})).fetchall()
        sdg_rows = (await self._session.execute(text(
            "SELECT DISTINCT unnest(sdg_tags) AS sdg FROM impact_assets "
            "WHERE user_id = :uid"), {"uid": user_id})).fetchall()
        return {
            "pms_score": float(pms) if pms is not None else 0.0,
            "skills": [r[0] for r in skill_rows if r[0]],
            "sdg_experience": [int(r[0]) for r in sdg_rows if r[0] is not None],
        }

    async def apply(self, opp_id: str, user_id: str, match_score: float) -> str:
        from uuid import uuid4
        app_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO opportunity_applications
                (id, opportunity_id, applicant_id, status, match_score, applied_at, updated_at)
            VALUES (:id, :oid, :uid, 'SUBMITTED', :ms, NOW(), NOW())
            ON CONFLICT (opportunity_id, applicant_id) DO NOTHING
        """), {"id": app_id, "oid": opp_id, "uid": user_id, "ms": match_score})
        await self._session.execute(text(
            "UPDATE opportunities SET applicant_count = ("
            "SELECT count(*) FROM opportunity_applications WHERE opportunity_id=:oid) "
            "WHERE id=:oid"), {"oid": opp_id})
        await self._session.commit()
        return app_id
