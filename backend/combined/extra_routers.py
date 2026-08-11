"""Extra first-party routers for the combined backend.

Provides real, persisted CRUD for **Courses** and **Projects** (plus enrollment
and progress), so the mobile app can create/list/use them against the same
database the rest of the platform uses. Auth reuses the shared JWT dependency.
"""
from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey, select, func,
    text, JSON,
)
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base

from shared.middleware import TokenPayload, make_auth_dependency

JWT_SECRET = os.getenv("JWT_SECRET", "masaren-alpha-change-me")
JWT_ALGORITHM = "HS256"
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren",
)

engine = create_async_engine(DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
Base = declarative_base()
auth = make_auth_dependency(JWT_SECRET, JWT_ALGORITHM)


# ── Models ──────────────────────────────────────────────────────────────────
class CourseORM(Base):
    __tablename__ = "m_courses"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    provider = Column(String, nullable=True)
    level = Column(String, default="Beginner")
    sdg = Column(Integer, nullable=True)
    thumbnail = Column(String, nullable=True)
    owner_id = Column(String, nullable=False)
    lessons = Column(Integer, default=0)
    duration_min = Column(Integer, default=0)
    status = Column(String, default="PUBLISHED")
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


class ProjectORM(Base):
    __tablename__ = "m_projects"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    category = Column(String, default="Community")
    sdg = Column(Integer, nullable=True)
    cover = Column(String, nullable=True)
    owner_id = Column(String, nullable=False)
    owner_name = Column(String, nullable=True)
    goal = Column(Float, default=0)
    raised = Column(Float, default=0)
    members = Column(Integer, default=0)
    status = Column(String, default="ACTIVE")
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


class EnrollORM(Base):
    __tablename__ = "m_enrollments"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=False)
    item_id = Column(String, nullable=False)
    kind = Column(String, default="COURSE")
    progress = Column(Integer, default=0)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


# ── Schemas ───────────────────────────────────────────────────────────────────
class CreateCourse(BaseModel):
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    provider: Optional[str] = None
    level: str = "Beginner"
    sdg: Optional[int] = None
    lessons: int = 0
    duration_min: int = 0
    thumbnail: Optional[str] = None


class CreateProject(BaseModel):
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    category: str = "Community"
    sdg: Optional[int] = None
    cover: Optional[str] = None
    goal: float = 0


def _course_json(c: CourseORM) -> dict:
    return {
        "id": c.id, "title": c.title, "description": c.description,
        "provider": c.provider, "level": c.level, "sdg": c.sdg,
        "thumbnail": c.thumbnail, "lessons": c.lessons,
        "duration_min": c.duration_min, "status": c.status,
        "owner_id": c.owner_id,
        "created_at": c.created_at.isoformat() if c.created_at else None,
    }


def _project_json(p: ProjectORM) -> dict:
    return {
        "id": p.id, "title": p.title, "description": p.description,
        "category": p.category, "sdg": p.sdg, "cover": p.cover,
        "owner_id": p.owner_id, "owner_name": p.owner_name,
        "goal": p.goal, "raised": p.raised, "members": p.members,
        "status": p.status,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


async def get_session() -> AsyncSession:
    async with SessionLocal() as s:
        yield s


# ── Courses router ─────────────────────────────────────────────────────────────
courses = APIRouter(prefix="/courses", tags=["Courses"])


@courses.get("")
async def list_courses(
    sdg: Optional[int] = None,
    q: Optional[str] = None,
    limit: int = Query(40, ge=1, le=100),
    offset: int = 0,
    session: AsyncSession = Depends(get_session),
):
    stmt = select(CourseORM)
    if sdg is not None:
        stmt = stmt.where(CourseORM.sdg == sdg)
    if q:
        stmt = stmt.where(CourseORM.title.ilike(f"%{q}%"))
    stmt = stmt.order_by(CourseORM.created_at.desc()).limit(limit).offset(offset)
    rows = (await session.execute(stmt)).scalars().all()
    return {"success": True, "data": [_course_json(c) for c in rows], "errors": None,
            "message": None, "meta": None}


@courses.post("", status_code=201)
async def create_course(
    body: CreateCourse,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    c = CourseORM(**body.model_dump(), owner_id=str(token.sub))
    session.add(c)
    await session.commit()
    await session.refresh(c)
    return {"success": True, "data": _course_json(c), "errors": None,
            "message": None, "meta": None}


@courses.post("/{course_id}/enroll")
async def enroll_course(
    course_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    exists = (await session.execute(
        select(EnrollORM).where(EnrollORM.user_id == str(token.sub),
                                EnrollORM.item_id == course_id))).scalar_one_or_none()
    if exists is None:
        session.add(EnrollORM(user_id=str(token.sub), item_id=course_id, kind="COURSE"))
        await session.commit()
    return {"success": True, "data": {"enrolled": True}, "errors": None,
            "message": None, "meta": None}


# ── Projects router ─────────────────────────────────────────────────────────────
projects = APIRouter(prefix="/projects", tags=["Projects"])


@projects.get("")
async def list_projects(
    category: Optional[str] = None,
    q: Optional[str] = None,
    limit: int = Query(40, ge=1, le=100),
    offset: int = 0,
    session: AsyncSession = Depends(get_session),
):
    stmt = select(ProjectORM)
    if category:
        stmt = stmt.where(ProjectORM.category == category)
    if q:
        stmt = stmt.where(ProjectORM.title.ilike(f"%{q}%"))
    stmt = stmt.order_by(ProjectORM.created_at.desc()).limit(limit).offset(offset)
    rows = (await session.execute(stmt)).scalars().all()
    return {"success": True, "data": [_project_json(p) for p in rows], "errors": None,
            "message": None, "meta": None}


@projects.post("", status_code=201)
async def create_project(
    body: CreateProject,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    p = ProjectORM(**body.model_dump(), owner_id=str(token.sub),
                   owner_name=token.sub)
    session.add(p)
    await session.commit()
    await session.refresh(p)
    return {"success": True, "data": _project_json(p), "errors": None,
            "message": None, "meta": None}


@projects.post("/{project_id}/join")
async def join_project(
    project_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    p = (await session.execute(
        select(ProjectORM).where(ProjectORM.id == project_id))).scalar_one_or_none()
    if p is None:
        raise HTTPException(status_code=404, detail="Project not found")
    p.members = (p.members or 0) + 1
    session.add(p)
    await session.commit()
    return {"success": True, "data": _project_json(p), "errors": None,
            "message": None, "meta": None}


# ── Notifications router ──────────────────────────────────────────────────────
class NotificationORM(Base):
    __tablename__ = "m_notifications"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, nullable=False, index=True)
    type = Column(String, default="system")
    title = Column(String, nullable=False)
    body = Column(String, nullable=True)
    read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


class NotificationCreate(BaseModel):
    user_id: str
    type: str = "system"
    title: str
    body: Optional[str] = None


notifications = APIRouter(prefix="/notifications", tags=["Notifications"])


@notifications.get("/{user_id}", response_model=None)
async def list_notifications(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    if str(token.sub) != str(user_id):
        raise HTTPException(status_code=403, detail="Not your notifications")
    rows = (await session.execute(
        select(NotificationORM)
        .where(NotificationORM.user_id == user_id)
        .order_by(NotificationORM.created_at.desc())
        .limit(50)
    )).scalars().all()
    out = [
        {
            "id": n.id,
            "type": n.type,
            "title": n.title,
            "body": n.body,
            "read": n.read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in rows
    ]
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@notifications.post("/send", status_code=202, response_model=None)
async def send_notification(
    body: NotificationCreate,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    n = NotificationORM(
        user_id=str(body.user_id), type=body.type,
        title=body.title, body=body.body)
    session.add(n)
    await session.commit()
    return {"success": True, "data": {"id": n.id}, "errors": None,
            "message": None, "meta": None}


@notifications.post("/{user_id}/{notification_id}/read", response_model=None)
async def mark_read(
    user_id: str,
    notification_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    n = (await session.execute(
        select(NotificationORM).where(NotificationORM.id == notification_id,
                                      NotificationORM.user_id == user_id)
    )).scalar_one_or_none()
    if n is not None:
        n.read = True
        session.add(n)
        await session.commit()
    return {"success": True, "data": {"read": True}, "errors": None,
            "message": None, "meta": None}


async def _create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


# ─────────────────────────────────────────────────────────────────────────────
# Media Personnel Professional Profile
# ─────────────────────────────────────────────────────────────────────────────
class PersonnelORM(Base):
    __tablename__ = "m_personnel"
    user_id = Column(String, primary_key=True)
    headline = Column(String, nullable=True)
    summary = Column(String, nullable=True)
    mission = Column(String, nullable=True)
    beat = Column(String, nullable=True)                 # primary beat
    expertise = Column(JSON, default=list)               # areas of expertise
    specializations = Column(JSON, default=list)
    skills = Column(JSON, default=list)                  # {name, endorsements}
    education = Column(JSON, default=list)
    experience = Column(JSON, default=list)              # {role, org, from, to}
    certificates = Column(JSON, default=list)
    awards = Column(JSON, default=list)
    publications = Column(JSON, default=list)
    memberships = Column(JSON, default=list)
    employment_status = Column(String, default="Independent")
    availability = Column(String, default="Open to opportunities")
    verification_level = Column(String, default="VERIFIED")
    impact_tier = Column(String, default="Contributor")
    professional_rank = Column(String, default="Field Reporter")
    languages = Column(JSON, default=list)
    social_links = Column(JSON, default=dict)
    endorsements_count = Column(Integer, default=0)
    followers_count = Column(Integer, default=0)
    following_count = Column(Integer, default=0)
    updated_at = Column(DateTime, default=lambda: datetime.utcnow())


class PersonnelMetricORM(Base):
    __tablename__ = "m_personnel_metrics"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    period = Column(String, default="lifetime")          # weekly/monthly/...
    bucket = Column(String, nullable=False)             # 2026-W01 / 2026-01 / ...
    impact_score = Column(Float, default=0)
    reach = Column(Float, default=0)
    engagement = Column(Float, default=0)
    verified_reports = Column(Integer, default=0)
    evidence = Column(Integer, default=0)
    trust_score = Column(Float, default=0)
    knowledge = Column(Float, default=0)
    influence = Column(Float, default=0)
    missions = Column(Integer, default=0)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


class PersonnelTimelineORM(Base):
    __tablename__ = "m_personnel_timeline"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    kind = Column(String)                                # report/mission/evidence/award/...
    title = Column(String)
    detail = Column(String, nullable=True)
    ref_id = Column(String, nullable=True)
    happened_at = Column(DateTime, default=lambda: datetime.utcnow())


class PersonnelAchievementORM(Base):
    __tablename__ = "m_personnel_achievements"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    kind = Column(String, default="badge")
    title = Column(String)
    detail = Column(String, nullable=True)
    awarded_at = Column(DateTime, default=lambda: datetime.utcnow())


class PersonnelOrgORM(Base):
    __tablename__ = "m_personnel_orgs"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    name = Column(String)
    role = Column(String, nullable=True)
    duration = Column(String, nullable=True)
    impact = Column(String, nullable=True)
    logo = Column(String, nullable=True)


class PersonnelCoverageORM(Base):
    __tablename__ = "m_personnel_coverage"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    country = Column(String, nullable=True)
    city = Column(String, nullable=True)
    region = Column(String, nullable=True)
    assignments = Column(Integer, default=0)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)


class PersonnelRecommendationORM(Base):
    __tablename__ = "m_personnel_recommendations"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    author_name = Column(String)
    author_role = Column(String, nullable=True)
    relation = Column(String, nullable=True)             # peer/supervisor/org/reader
    text = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.utcnow())


async def _ensure_personnel(session, user_id: str) -> PersonnelORM:
    p = (await session.execute(
        select(PersonnelORM).where(PersonnelORM.user_id == user_id)
    )).scalar_one_or_none()
    if p is None:
        p = PersonnelORM(user_id=user_id)
        session.add(p)
        await session.commit()
    return p


_BASE_URL = os.environ.get("PUBLIC_BASE_URL", "https://masareen.mediahubnetwork.net")


def _resolve_media_url(url: Optional[str]) -> Optional[str]:
    """Ensure media URLs are absolute — prefix relative paths with the base URL."""
    if not url:
        return None
    if url.startswith("http://") or url.startswith("https://"):
        return url
    if url.startswith("/"):
        return f"{_BASE_URL}{url}"
    return url


async def _read_user_row(user_id: str) -> Optional[dict]:
    async with engine.connect() as conn:
        r = (await conn.execute(text(
            "SELECT id, email, full_name, role, status, pms_score, "
            "email_verified, created_at FROM users WHERE id = :uid"
        ), {"uid": user_id})).mappings().first()
        return dict(r) if r else None


async def _read_profile_row(user_id: str) -> Optional[dict]:
    async with engine.connect() as conn:
        r = (await conn.execute(text(
            "SELECT bio, avatar_url, cover_url, country, city, languages, "
            "followers_count, following_count, website, social_links, latitude, longitude "
            "FROM user_profiles WHERE user_id = :uid"
        ), {"uid": user_id})).mappings().first()
        return dict(r) if r else None


async def _read_posts(user_id: str, limit: int = 100) -> list:
    async with engine.connect() as conn:
        rows = (await conn.execute(text(
            "SELECT id, text, kind, program_tag, sdg, impact_value, impact_label, "
            "confidence, media, comments, likes, shares, created_at, author_role, "
            "author_verified FROM posts WHERE author_id = :uid "
            "ORDER BY created_at DESC LIMIT :lim"
        ), {"uid": user_id, "lim": limit})).mappings().all()
        return [dict(r) for r in rows]


def _iso(x):
    return x.isoformat() if x else None


def _impact_tier_from_pms(pms: float) -> str:
    if pms >= 90: return "Luminary"
    if pms >= 75: return "Authority"
    if pms >= 55: return "Professional"
    if pms >= 35: return "Contributor"
    return "Emerging"


def _rank_from_pms(pms: float) -> str:
    if pms >= 90: return "Senior Correspondent"
    if pms >= 75: return "Correspondent"
    if pms >= 55: return "Field Reporter II"
    if pms >= 35: return "Field Reporter"
    return "Contributor I"


def _build_overview(user_id, urow, prow, personnel, posts) -> dict:
    total_reach = sum(int(p.get("likes", 0) or 0) for p in posts)
    verified_reports = sum(1 for p in posts if (p.get("author_verified") or p.get("confidence", 0) >= 70))
    pms = float(urow.get("pms_score") or 0)
    skills = personnel.skills or []
    expertise = personnel.expertise or (skills[:6] if skills else ["General Reporting"])
    return {
        "user_id": user_id,
        "name": urow.get("full_name", ""),
        "email": urow.get("email", ""),
        "role": urow.get("role", "Individual"),
        "role_type": (urow.get("role") or "Individual").upper(),
        "status": urow.get("status", "ACTIVE"),
        "email_verified": bool(urow.get("email_verified")),
        "avatar_url": _resolve_media_url((prow or {}).get("avatar_url")),
        "cover_url": _resolve_media_url((prow or {}).get("cover_url")),
        "country": (prow or {}).get("country"),
        "city": (prow or {}).get("city"),
        "latitude": (prow or {}).get("latitude"),
        "longitude": (prow or {}).get("longitude"),
        "website": (prow or {}).get("website"),
        "social_links": (prow or {}).get("social_links") or {},
        "bio": (prow or {}).get("bio", ""),
        "joined": _iso(urow.get("created_at")),
        "member_since": _iso(urow.get("created_at")),
        "headline": personnel.headline or f"Verified {urow.get('role', 'Media')} Professional",
        "summary": personnel.summary or "",
        "mission": personnel.mission or "",
        "beat": personnel.beat or "General News",
        "expertise": expertise,
        "specializations": personnel.specializations or [],
        "skills": skills,
        "languages": personnel.languages or (prow or {}).get("languages") or ["English"],
        "education": personnel.education or [],
        "experience": personnel.experience or [],
        "certificates": personnel.certificates or [],
        "awards": personnel.awards or [],
        "publications": personnel.publications or [],
        "memberships": personnel.memberships or [],
        "employment_status": personnel.employment_status,
        "availability": personnel.availability,
        "verification_level": personnel.verification_level,
        "impact_tier": personnel.impact_tier or _impact_tier_from_pms(pms),
        "professional_rank": personnel.professional_rank or _rank_from_pms(pms),
        # impact metrics
        "impact_score": round(pms, 1),
        "trust_score": round(min(100.0, pms + 8.0), 1),
        "verification_confidence": round(min(100.0, (prow and (prow.get("id") and 88)) or 80.0), 1),
        "community_rating": round(min(5.0, 3.2 + pms / 50.0), 1),
        "current_reach": total_reach,
        "lifetime_reach": total_reach * 7 + 1200,
        "average_reach": round(total_reach / max(1, len(posts)), 0),
        "audience_growth": 12.4,
        "average_engagement": round(min(100.0, 30 + pms / 3.0), 1),
        "media_value": round(total_reach * 0.8, 0),
        "contribution_score": round(pms * 1.1, 1),
        "knowledge_score": round(min(100.0, pms + 5.0), 1),
        "field_activity_score": round(min(100.0, 40 + len(posts) * 4.0), 1),
        "professional_consistency": round(min(100.0, 50 + len(posts) * 3.0), 1),
        # KPI
        "kpi": {
            "total_reports": len(posts),
            "verified_reports": verified_reports,
            "verified_missions": 0,
            "evidence_submitted": 0,
            "organizations": len(personnel.experience or []),
            "countries_covered": 1,
            "coverage_hours": len(posts) * 3,
            "average_quality_score": round(min(100.0, 60 + pms / 2.0), 1),
            "average_review_time": 4.2,
            "trust_score": round(min(100.0, pms + 8.0), 1),
            "ai_confidence": round(min(100.0, (prow and 86) or 78.0), 1),
            "community_rating": round(min(5.0, 3.2 + pms / 50.0), 1),
            "monthly_growth": 12.4,
            "followers": personnel.followers_count or (prow or {}).get("followers_count") or 0,
            "following": personnel.following_count or (prow or {}).get("following_count") or 0,
            "bookmarks": 0,
            "saved_reports": 0,
            "recommendations": 0,
            "research_citations": 0,
            "media_mentions": 0,
            "endorsements": personnel.endorsements_count or 0,
        },
    }


personnel = APIRouter(prefix="/personnel", tags=["Media Personnel"])


@personnel.get("/{user_id}", response_model=None)
async def get_personnel(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    urow = await _read_user_row(user_id)
    if urow is None:
        raise HTTPException(status_code=404, detail="Person not found")
    prow = await _read_profile_row(user_id)
    p = await _ensure_personnel(session, user_id)
    posts = await _read_posts(user_id)
    return {"success": True, "data": _build_overview(user_id, urow, prow, p, posts),
            "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/overview", response_model=None)
async def get_overview(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    return await get_personnel(user_id, token, session)


@personnel.get("/{user_id}/reports", response_model=None)
async def get_reports(
    user_id: str,
    limit: int = Query(40, ge=1, le=100),
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    posts = await _read_posts(user_id, limit)
    out = []
    for p in posts:
        media = p.get("media") or []
        out.append({
            "id": p["id"],
            "headline": (p.get("text") or "")[:120],
            "text": p.get("text", ""),
            "category": p.get("kind", "story"),
            "program_tag": p.get("program_tag"),
            "sdg": p.get("sdg", 0),
            "status": "PUBLISHED",
            "verification_status": "VERIFIED" if (p.get("confidence") or 0) >= 70 else "REVIEW",
            "published_at": _iso(p.get("created_at")),
            "reach": int(p.get("likes", 0) or 0) * 12,
            "engagement": int(p.get("likes", 0) or 0) + int(p.get("shares", 0) or 0),
            "evidence_count": len(media),
            "quality_score": round(60 + (p.get("confidence") or 0) / 2.0, 1),
            "impact_score": round(float(p.get("impact_value") or 0), 1),
            "cover_image": media[0] if media else None,
            "comments": len(p.get("comments") or []),
            "likes": int(p.get("likes", 0) or 0),
        })
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/analytics", response_model=None)
async def get_analytics(
    user_id: str,
    period: str = Query("lifetime"),
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    rows = (await session.execute(
        select(PersonnelMetricORM)
        .where(PersonnelMetricORM.user_id == user_id)
        .order_by(PersonnelMetricORM.bucket)
    )).scalars().all()
    if not rows:
        # synthesize a baseline series from lifetime totals so charts always render
        posts = await _read_posts(user_id)
        total = max(1, len(posts))
        buckets = ["2025-Q1", "2025-Q2", "2025-Q3", "2025-Q4", "2026-Q1", "2026-Q2"]
        rows = []
        for i, b in enumerate(buckets):
            f = (i + 1) / len(buckets)
            rows.append(PersonnelMetricORM(
                user_id=user_id, period="quarterly", bucket=b,
                impact_score=round(40 + 50 * f, 1),
                reach=round(total * 100 * f, 0),
                engagement=round(20 + 60 * f, 1),
                verified_reports=round(total * f),
                evidence=round(total * 0.5 * f),
                trust_score=round(70 + 25 * f, 1),
                knowledge=round(60 + 35 * f, 1),
                influence=round(50 + 45 * f, 1),
                missions=round(total * 0.3 * f),
            ))
    data = [{
        "bucket": r.bucket,
        "impact_score": r.impact_score,
        "reach": r.reach,
        "engagement": r.engagement,
        "verified_reports": r.verified_reports,
        "evidence": r.evidence,
        "trust_score": r.trust_score,
        "knowledge": r.knowledge,
        "influence": r.influence,
        "missions": r.missions,
    } for r in rows]
    return {"success": True, "data": {"period": period, "series": data},
            "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/timeline", response_model=None)
async def get_timeline(
    user_id: str,
    limit: int = Query(30, ge=1, le=100),
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    rows = (await session.execute(
        select(PersonnelTimelineORM)
        .where(PersonnelTimelineORM.user_id == user_id)
        .order_by(PersonnelTimelineORM.happened_at.desc())
        .limit(limit)
    )).scalars().all()
    if not rows:
        posts = await _read_posts(user_id, 10)
        rows = [PersonnelTimelineORM(
            user_id=user_id, kind="report",
            title=(p.get("text") or "Published a report")[:80],
            ref_id=p.get("id"), happened_at=p.get("created_at")
        ) for p in posts]
    out = [{
        "id": r.id, "kind": r.kind, "title": r.title, "detail": r.detail,
        "ref_id": r.ref_id, "happened_at": _iso(r.happened_at),
    } for r in rows]
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/achievements", response_model=None)
async def get_achievements(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    rows = (await session.execute(
        select(PersonnelAchievementORM).where(PersonnelAchievementORM.user_id == user_id)
    )).scalars().all()
    out = [{
        "id": r.id, "kind": r.kind, "title": r.title, "detail": r.detail,
        "awarded_at": _iso(r.awarded_at),
    } for r in rows]
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/organizations", response_model=None)
async def get_orgs(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    p = await _ensure_personnel(session, user_id)
    exp = p.experience or []
    rows = (await session.execute(
        select(PersonnelOrgORM).where(PersonnelOrgORM.user_id == user_id)
    )).scalars().all()
    out = [{"name": o.name, "role": o.role, "duration": o.duration,
            "impact": o.impact, "logo": o.logo} for o in rows]
    for e in exp:
        if isinstance(e, dict) and e.get("org"):
            out.append({"name": e.get("org"), "role": e.get("role"),
                        "duration": f"{e.get('from','')}–{e.get('to','')}",
                        "impact": e.get("impact")})
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/coverage", response_model=None)
async def get_coverage(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    prow = await _read_profile_row(user_id)
    rows = (await session.execute(
        select(PersonnelCoverageORM).where(PersonnelCoverageORM.user_id == user_id)
    )).scalars().all()
    out = [{
        "country": r.country, "city": r.city, "region": r.region,
        "assignments": r.assignments, "lat": r.lat, "lng": r.lng,
    } for r in rows]
    if not out and prow:
        out.append({
            "country": prow.get("country"),
            "city": prow.get("city"),
            "region": prow.get("country"),
            "assignments": 0,
            "lat": prow.get("latitude"),
            "lng": prow.get("longitude"),
        })
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.get("/{user_id}/recommendations", response_model=None)
async def get_recommendations(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    rows = (await session.execute(
        select(PersonnelRecommendationORM).where(PersonnelRecommendationORM.user_id == user_id)
    )).scalars().all()
    out = [{
        "id": r.id, "author_name": r.author_name, "author_role": r.author_role,
        "relation": r.relation, "text": r.text, "created_at": _iso(r.created_at),
    } for r in rows]
    return {"success": True, "data": out, "errors": None, "message": None, "meta": None}


@personnel.post("/{user_id}/follow", response_model=None)
async def follow_personnel(
    user_id: str,
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    p = await _ensure_personnel(session, user_id)
    p.followers_count = (p.followers_count or 0) + 1
    session.add(p)
    await session.commit()
    return {"success": True, "data": {"followers": p.followers_count},
            "errors": None, "message": None, "meta": None}


@personnel.post("/{user_id}/endorse", response_model=None)
async def endorse_personnel(
    user_id: str,
    body: dict = {},
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    skill = (body or {}).get("skill")
    p = await _ensure_personnel(session, user_id)
    p.endorsements_count = (p.endorsements_count or 0) + 1
    skills = p.skills or []
    if skill:
        found = False
        for s in skills:
            if isinstance(s, dict) and s.get("name") == skill:
                s["endorsements"] = (s.get("endorsements") or 0) + 1
                found = True
                break
        if not found:
            skills.append({"name": skill, "endorsements": 1})
        p.skills = skills
    session.add(p)
    await session.commit()
    return {"success": True,
            "data": {"endorsements": p.endorsements_count, "skills": p.skills},
            "errors": None, "message": None, "meta": None}


@personnel.patch("/{user_id}", response_model=None)
async def patch_personnel(
    user_id: str,
    body: dict = {},
    token: TokenPayload = Depends(auth),
    session: AsyncSession = Depends(get_session),
):
    if str(token.sub) != str(user_id):
        raise HTTPException(status_code=403, detail="Not your profile")
    p = await _ensure_personnel(session, user_id)
    for k in ("headline", "summary", "mission", "beat", "employment_status",
              "availability", "verification_level", "impact_tier",
              "professional_rank"):
        if k in body:
            setattr(p, k, body[k])
    for k in ("expertise", "specializations", "skills", "languages",
              "education", "experience", "certificates", "awards",
              "publications", "memberships", "social_links"):
        if k in body:
            setattr(p, k, body[k])
    p.updated_at = datetime.utcnow()
    session.add(p)
    await session.commit()
    return {"success": True, "data": {"updated": True}, "errors": None,
            "message": None, "meta": None}
