"""Statistical reports endpoint, Python equivalent of the R analytics scripts.

Uses the actual platform tables:
  users, programs, tasks, posts, platform_posts, organizations,
  submission_events, submission_projections, review_queue,
  coin_transactions, post_likes, follows, timeline_events, ad_campaigns,
  post_bookmarks, opportunities, program_enrollments.

Provides JSON-serialisable data for:
  1. Evidence/submission analysis (by status, type, time series)
  2. Verification pipeline (confidence, review queue)
  3. Audit trail (submission events by type, timeline)
  4. Institution performance (programs, members per org)
  5. Impact forecast (linear trend projection)
  6. Coin economy (transactions, exchange rates)
"""
from __future__ import annotations

import os
from typing import AsyncGenerator

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

router = APIRouter(prefix="/analytics", tags=["Statistical Reports"])

_engine = None
_session_factory = None


def _get_engine():
    global _engine, _session_factory
    if _engine is None:
        url = os.environ.get(
            "DATABASE_URL",
            "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren",
        )
        _engine = create_async_engine(url, echo=False, future=True)
        _session_factory = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)
    return _session_factory


async def _dep_session() -> AsyncGenerator[AsyncSession, None]:
    factory = _get_engine()
    async with factory() as session:
        yield session


async def _q(session: AsyncSession, sql: str, params: dict | None = None):
    rows = await session.execute(text(sql), params or {})
    return [dict(r._mapping) for r in rows]


# ── 1. Submission / evidence analysis ─────────────────────────────────────────

@router.get("/reports/evidence")
async def evidence_report(session: AsyncSession = Depends(_dep_session)):
    """Submission analytics, uses submission_events + submission_projections."""
    try:
        by_type = await _q(session, """
            SELECT event_type, COUNT(*)::int AS count
            FROM submission_events
            GROUP BY event_type ORDER BY count DESC
        """)
        over_time = await _q(session, """
            SELECT DATE(created_at) AS date, COUNT(*)::int AS submissions
            FROM submission_events
            GROUP BY DATE(created_at) ORDER BY date
        """)
        totals = await _q(session, """
            SELECT COUNT(*)::int AS total
            FROM submission_events
        """)
        proj_by_status = await _q(session, """
            SELECT status, COUNT(*)::int AS count
            FROM submission_projections
            GROUP BY status ORDER BY count DESC
        """)
        proj_confidence = await _q(session, """
            SELECT
                ROUND(AVG(approval_score)::numeric, 3)::float AS avg_approval,
                COUNT(*)::int AS total_projections
            FROM submission_projections
            WHERE approval_score IS NOT NULL
        """)
        return {
            "by_status": proj_by_status,
            "by_type": by_type,
            "over_time": over_time,
            "summary": {
                "total": totals[0]["total"] if totals else 0,
                "approved": next((p["count"] for p in proj_by_status if p["status"] == "APPROVED"), 0),
                "rejected": next((p["count"] for p in proj_by_status if p["status"] == "REJECTED"), 0),
                "pending": next((p["count"] for p in proj_by_status if p["status"] == "PENDING"), 0),
                "approval_rate": 0,
                **(proj_confidence[0] if proj_confidence else {}),
            },
            "confidence_distribution": proj_by_status,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"evidence_report_unavailable: {exc}")


# ── 2. Verification / review pipeline ────────────────────────────────────────

@router.get("/reports/verification")
async def verification_report(session: AsyncSession = Depends(_dep_session)):
    """Verification pipeline, uses review_queue + submission_projections."""
    try:
        funnel = await _q(session, """
            SELECT status, COUNT(*)::int AS count
            FROM review_queue
            GROUP BY status ORDER BY count DESC
        """)
        confidence = await _q(session, """
            SELECT
                ROUND(AVG(approval_score)::numeric, 3)::float AS avg_confidence,
                ROUND(MIN(approval_score)::numeric, 3)::float AS min_confidence,
                ROUND(MAX(approval_score)::numeric, 3)::float AS max_confidence,
                COUNT(*) FILTER (WHERE approval_score >= 0.8)::int AS high_confidence,
                COUNT(*) FILTER (WHERE approval_score < 0.5)::int AS low_confidence,
                COUNT(*)::int AS total
            FROM submission_projections
            WHERE approval_score IS NOT NULL
        """)
        verdicts = await _q(session, """
            SELECT admin_verdict, COUNT(*)::int AS count
            FROM review_queue
            WHERE admin_verdict IS NOT NULL
            GROUP BY admin_verdict ORDER BY count DESC
        """)
        return {
            "funnel": funnel,
            "confidence": confidence[0] if confidence else {},
            "verdicts": verdicts,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"verification_report_unavailable: {exc}")


# ── 3. Submission events (audit-like) ────────────────────────────────────────

@router.get("/reports/audit")
async def audit_report(session: AsyncSession = Depends(_dep_session)):
    """Submission events breakdown, analogous to audit trail."""
    try:
        by_type = await _q(session, """
            SELECT event_type, COUNT(*)::int AS count
            FROM submission_events
            GROUP BY event_type ORDER BY count DESC
        """)
        over_time = await _q(session, """
            SELECT DATE(created_at) AS date, COUNT(*)::int AS events
            FROM submission_events
            WHERE created_at IS NOT NULL
            GROUP BY DATE(created_at) ORDER BY date
        """)
        total = await _q(session, "SELECT COUNT(*)::int AS total FROM submission_events")
        by_aggregate = await _q(session, """
            SELECT aggregate_id, COUNT(*)::int AS count
            FROM submission_events
            GROUP BY aggregate_id ORDER BY count DESC LIMIT 10
        """)
        return {
            "by_type": by_type,
            "over_time": over_time,
            "total_events": total[0]["total"] if total else 0,
            "top_aggregates": by_aggregate,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"audit_report_unavailable: {exc}")


# ── 4. Institution performance ────────────────────────────────────────────────

@router.get("/reports/institutions")
async def institution_report(session: AsyncSession = Depends(_dep_session)):
    """Institution performance, programs, members, OII score."""
    try:
        rows = await _q(session, """
            SELECT
                o.id AS org_id,
                o.name AS org_name,
                o.org_type,
                COALESCE(o.oii_score, 0)::float AS oii_score,
                (SELECT COUNT(*) FROM programs p WHERE p.organization_id = o.id AND p.status <> 'DRAFT')::int AS programs,
                COALESCE(array_length(o.member_ids, 1), 0)::int AS members
            FROM organizations o
            ORDER BY o.oii_score DESC NULLS LAST
        """)
        programs_by_org = await _q(session, """
            SELECT
                p.status,
                COUNT(*)::int AS count
            FROM programs p
            GROUP BY p.status ORDER BY count DESC
        """)
        return {
            "institutions": rows,
            "programs_by_status": programs_by_org,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"institution_report_unavailable: {exc}")


# ── 5. Impact forecast (linear trend) ────────────────────────────────────────

@router.get("/reports/forecast")
async def impact_forecast(
    months: int = Query(6, ge=1, le=24),
    session: AsyncSession = Depends(_dep_session),
):
    """Linear-trend impact projection, uses submission_events over time."""
    try:
        history_rows = await _q(session, """
            SELECT DATE_TRUNC('month', created_at) AS month,
                   COUNT(*)::int AS actions
            FROM submission_events
            WHERE created_at IS NOT NULL
            GROUP BY DATE_TRUNC('month', created_at)
            ORDER BY month
        """)

        if len(history_rows) < 2:
            return {"history": history_rows, "forecast": [], "slope": 0, "intercept": 0}

        xs = list(range(len(history_rows)))
        ys = [r["actions"] for r in history_rows]
        n = len(xs)
        sum_x = sum(xs)
        sum_y = sum(ys)
        sum_xy = sum(x * y for x, y in zip(xs, ys))
        sum_x2 = sum(x * x for x in xs)
        denom = n * sum_x2 - sum_x * sum_x
        if denom == 0:
            slope, intercept = 0.0, float(ys[-1])
        else:
            slope = (n * sum_xy - sum_x * sum_y) / denom
            intercept = (sum_y - slope * sum_x) / n

        import calendar
        from datetime import datetime

        last_month = history_rows[-1]["month"]
        if isinstance(last_month, str):
            last_month = datetime.fromisoformat(last_month)
        forecast = []
        for i in range(1, months + 1):
            m = last_month.month + i
            y = last_month.year + (m - 1) // 12
            m = ((m - 1) % 12) + 1
            _, last_day = calendar.monthrange(y, m)
            proj = max(0, round(slope * (len(xs) + i - 1) + intercept))
            forecast.append({"month": f"{y}-{m:02d}-01", "projected": proj})

        return {
            "history": history_rows,
            "forecast": forecast,
            "slope": round(slope, 2),
            "intercept": round(intercept, 2),
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"forecast_report_unavailable: {exc}")


# ── 6. Coin economy ──────────────────────────────────────────────────────────

@router.get("/reports/coin")
async def coin_report(session: AsyncSession = Depends(_dep_session)):
    """Coin transaction analytics, volume, types, exchange rates."""
    try:
        by_type = await _q(session, """
            SELECT type, COUNT(*)::int AS count,
                   ROUND(SUM(amount)::numeric, 2)::float AS total_amount
            FROM coin_transactions
            GROUP BY type ORDER BY count DESC
        """)
        over_time = await _q(session, """
            SELECT DATE(created_at) AS date,
                   COUNT(*)::int AS transactions,
                   ROUND(SUM(amount)::numeric, 2)::float AS volume
            FROM coin_transactions
            WHERE created_at IS NOT NULL
            GROUP BY DATE(created_at) ORDER BY date
        """)
        rates = await _q(session, """
            SELECT * FROM coin_exchange_rates ORDER BY updated_at DESC LIMIT 5
        """)
        totals = await _q(session, """
            SELECT
                COUNT(*)::int AS total_transactions,
                ROUND(SUM(amount)::numeric, 2)::float AS total_volume,
                ROUND(AVG(amount)::numeric, 2)::float AS avg_amount
            FROM coin_transactions
        """)
        return {
            "by_type": by_type,
            "over_time": over_time,
            "exchange_rates": rates,
            "summary": totals[0] if totals else {},
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"coin_report_unavailable: {exc}")


# ── 7. User engagement ───────────────────────────────────────────────────────

@router.get("/reports/engagement")
async def engagement_report(session: AsyncSession = Depends(_dep_session)):
    """User engagement, posts, likes, follows, user growth."""
    try:
        posts_by_kind = await _q(session, """
            SELECT kind, COUNT(*)::int AS count
            FROM posts
            WHERE kind IS NOT NULL
            GROUP BY kind ORDER BY count DESC
        """)
        posts_over_time = await _q(session, """
            SELECT DATE(created_at) AS date, COUNT(*)::int AS posts
            FROM posts WHERE created_at IS NOT NULL
            GROUP BY DATE(created_at) ORDER BY date
        """)
        user_growth = await _q(session, """
            SELECT DATE_TRUNC('month', created_at) AS month,
                   COUNT(*)::int AS signups
            FROM users WHERE created_at IS NOT NULL
            GROUP BY DATE_TRUNC('month', created_at) ORDER BY month
        """)
        role_dist = await _q(session, """
            SELECT role, COUNT(*)::int AS count
            FROM users GROUP BY role ORDER BY count DESC
        """)
        totals = await _q(session, """
            SELECT
                (SELECT COUNT(*) FROM users)::int AS total_users,
                (SELECT COUNT(*) FROM posts)::int AS total_posts,
                (SELECT COUNT(*) FROM post_likes)::int AS total_likes,
                (SELECT COUNT(*) FROM follows)::int AS total_follows
        """)
        return {
            "posts_by_kind": posts_by_kind,
            "posts_over_time": posts_over_time,
            "user_growth": user_growth,
            "role_distribution": role_dist,
            "totals": totals[0] if totals else {},
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"engagement_report_unavailable: {exc}")
