"""Admin panel endpoints for human verification and platform management.

Provides real, persisted CRUD for the verification pipeline:
- Review queue management (approve/reject submissions)
- Platform statistics
- User management
- Submission projections
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, func, text, and_, or_
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


class ReviewItemResponse(BaseModel):
    id: str
    entity_id: str
    entity_type: str
    confidence_score: Optional[float]
    status: str
    assigned_admin_id: Optional[str]
    created_at: str
    entity_preview: Optional[dict] = None


class AdminStatsResponse(BaseModel):
    total_users: int
    total_posts: int
    total_submissions: int
    pending_reviews: int
    approved_today: int
    rejected_today: int
    avg_confidence: Optional[float]


class UserItemResponse(BaseModel):
    id: str
    full_name: Optional[str]
    email: Optional[str]
    role: Optional[str]
    verified: Optional[bool]
    created_at: Optional[str]


class VerdictRequest(BaseModel):
    verdict: str = Field(..., description="APPROVED or REJECTED")
    comments: Optional[str] = None


class SubmissionItemResponse(BaseModel):
    bundle_id: str
    task_id: Optional[str]
    submitted_by: Optional[str]
    status: str
    evidence_items: Optional[list]
    gps_locations: Optional[list]
    approval_score: Optional[float]
    rejection_reason: Optional[str]
    created_at: str
    submitted_at: Optional[str]


async def get_db():
    async with SessionLocal() as session:
        yield session


router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=AdminStatsResponse)
async def get_admin_stats(
    user: TokenPayload = Depends(auth),
    db: AsyncSession = Depends(get_db),
):
    """Get platform-wide statistics for the admin dashboard."""
    if not user.role or "ADMIN" not in user.role.upper():
        raise HTTPException(status_code=403, detail="Admin access required")

    total_users = await db.scalar(text("SELECT COUNT(*) FROM users"))
    total_posts = await db.scalar(text("SELECT COUNT(*) FROM posts"))
    total_submissions = await db.scalar(text("SELECT COUNT(*) FROM submission_projections"))
    pending_reviews = await db.scalar(
        text("SELECT COUNT(*) FROM review_queue WHERE status = 'PENDING'")
    )
    approved_today = await db.scalar(
        text("SELECT COUNT(*) FROM review_queue WHERE admin_verdict = 'APPROVED' AND DATE(resolved_at) = DATE(NOW())")
    )
    rejected_today = await db.scalar(
        text("SELECT COUNT(*) FROM review_queue WHERE admin_verdict = 'REJECTED' AND DATE(resolved_at) = DATE(NOW())")
    )
    avg_conf = await db.scalar(
        text("SELECT AVG(confidence_score) FROM review_queue WHERE confidence_score IS NOT NULL")
    )

    return AdminStatsResponse(
        total_users=int(total_users or 0),
        total_posts=int(total_posts or 0),
        total_submissions=int(total_submissions or 0),
        pending_reviews=int(pending_reviews or 0),
        approved_today=int(approved_today or 0),
        rejected_today=int(rejected_today or 0),
        avg_confidence=float(avg_conf) if avg_conf else None,
    )


@router.get("/review-queue", response_model=list[ReviewItemResponse])
async def get_review_queue(
    user: TokenPayload = Depends(auth),
    db: AsyncSession = Depends(get_db),
    status: str = Query("PENDING", description="Filter by status"),
    limit: int = Query(50, le=200),
):
    """Get the review queue with entity details."""
    if not user.role or "ADMIN" not in user.role.upper():
        raise HTTPException(status_code=403, detail="Admin access required")

    result = await db.execute(
        text(
            "SELECT id, entity_id, entity_type, confidence_score, status, "
            "assigned_admin_id, created_at FROM review_queue "
            "WHERE status = :status ORDER BY created_at ASC LIMIT :limit"
        ),
        {"status": status, "limit": limit},
    )
    rows = result.fetchall()

    items = []
    for row in rows:
        entity_preview = None
        if row.entity_type == "post":
            post_result = await db.execute(
                text("SELECT id, text, author_name FROM posts WHERE id = :eid"),
                {"eid": row.entity_id},
            )
            post_row = post_result.fetchone()
            if post_row:
                entity_preview = {
                    "text": post_row.text[:200] if post_row.text else "",
                    "author": post_row.author_name,
                }
        elif row.entity_type == "user":
            user_result = await db.execute(
                text("SELECT full_name, email, role FROM users WHERE id = :eid"),
                {"eid": row.entity_id},
            )
            user_row = user_result.fetchone()
            if user_row:
                entity_preview = {
                    "name": user_row.full_name,
                    "email": user_row.email,
                    "role": user_row.role,
                }

        items.append(ReviewItemResponse(
            id=row.id,
            entity_id=row.entity_id,
            entity_type=row.entity_type,
            confidence_score=row.confidence_score,
            status=row.status,
            assigned_admin_id=row.assigned_admin_id,
            created_at=str(row.created_at),
            entity_preview=entity_preview,
        ))

    return items


@router.post("/review/{review_id}/verdict")
async def submit_verdict(
    review_id: str,
    req: VerdictRequest,
    user: TokenPayload = Depends(auth),
    db: AsyncSession = Depends(get_db),
):
    """Submit a verdict on a review item."""
    if not user.role or "ADMIN" not in user.role.upper():
        raise HTTPException(status_code=403, detail="Admin access required")

    if req.verdict.upper() not in ("APPROVED", "REJECTED"):
        raise HTTPException(status_code=400, detail="Verdict must be APPROVED or REJECTED")

    result = await db.execute(
        text(
            "UPDATE review_queue SET status = 'RESOLVED', admin_verdict = :verdict, "
            "admin_comments = :comments, resolved_at = :now, assigned_admin_id = :admin "
            "WHERE id = :rid RETURNING id"
        ),
        {
            "verdict": req.verdict.upper(),
            "comments": req.comments or "",
            "now": datetime.now(timezone.utc),
            "admin": user.sub,
            "rid": review_id,
        },
    )
    await db.commit()

    if result.fetchone() is None:
        raise HTTPException(status_code=404, detail="Review item not found")

    return {"success": True, "message": f"Review {req.verdict} submitted"}


@router.get("/users", response_model=list[UserItemResponse])
async def get_users(
    user: TokenPayload = Depends(auth),
    db: AsyncSession = Depends(get_db),
    search: Optional[str] = Query(None, description="Search by name or email"),
    limit: int = Query(50, le=200),
):
    """List users with optional search."""
    if not user.role or "ADMIN" not in user.role.upper():
        raise HTTPException(status_code=403, detail="Admin access required")

    if search:
        result = await db.execute(
            text(
                "SELECT id, full_name, email, role, verified, created_at "
                "FROM users WHERE full_name ILIKE :q OR email ILIKE :q "
                "ORDER BY created_at DESC LIMIT :limit"
            ),
            {"q": f"%{search}%", "limit": limit},
        )
    else:
        result = await db.execute(
            text(
                "SELECT id, full_name, email, role, verified, created_at "
                "FROM users ORDER BY created_at DESC LIMIT :limit"
            ),
            {"limit": limit},
        )

    rows = result.fetchall()
    return [
        UserItemResponse(
            id=row.id,
            full_name=row.full_name,
            email=row.email,
            role=row.role,
            verified=row.verified,
            created_at=str(row.created_at) if row.created_at else None,
        )
        for row in rows
    ]


@router.get("/submissions", response_model=list[SubmissionItemResponse])
async def get_submissions(
    user: TokenPayload = Depends(auth),
    db: AsyncSession = Depends(get_db),
    status: Optional[str] = Query(None, description="Filter by status"),
    limit: int = Query(50, le=200),
):
    """List submission projections."""
    if not user.role or "ADMIN" not in user.role.upper():
        raise HTTPException(status_code=403, detail="Admin access required")

    if status:
        result = await db.execute(
            text(
                "SELECT bundle_id, task_id, submitted_by, status, evidence_items, "
                "gps_locations, approval_score, rejection_reason, created_at, submitted_at "
                "FROM submission_projections WHERE status = :status "
                "ORDER BY created_at DESC LIMIT :limit"
            ),
            {"status": status, "limit": limit},
        )
    else:
        result = await db.execute(
            text(
                "SELECT bundle_id, task_id, submitted_by, status, evidence_items, "
                "gps_locations, approval_score, rejection_reason, created_at, submitted_at "
                "FROM submission_projections ORDER BY created_at DESC LIMIT :limit"
            ),
            {"limit": limit},
        )

    rows = result.fetchall()
    return [
        SubmissionItemResponse(
            bundle_id=row.bundle_id,
            task_id=row.task_id,
            submitted_by=row.submitted_by,
            status=row.status,
            evidence_items=row.evidence_items or [],
            gps_locations=row.gps_locations or [],
            approval_score=row.approval_score,
            rejection_reason=row.rejection_reason,
            created_at=str(row.created_at) if row.created_at else "",
            submitted_at=str(row.submitted_at) if row.submitted_at else None,
        )
        for row in rows
    ]
