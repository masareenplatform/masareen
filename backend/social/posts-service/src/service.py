"""Social feed business logic: ranking, CRUD, likes and bookmarks.

The ranking algorithm uses the MASAREN Media Institutions Blueprint formulas:
  - Confidence: C = 0.20S + 0.22E + 0.18K + 0.15R + 0.15T + 0.10H - P
  - Feed rank:  R = 0.24U + 0.16Q + 0.14F + 0.13C + 0.10D + 0.09L + 0.08N + 0.06B - X
"""
from __future__ import annotations

import asyncio
import os
from datetime import datetime, timezone
from typing import Iterable
from uuid import uuid4

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from . import orm
from shared.middleware import TokenPayload  # noqa: F401 (re-exported for type hints)
from shared.utils.confidence import (
    ConfidenceFactors,
    calculate_confidence,
    default_factors_for_post,
)
from shared.utils.feed_ranking import RankingInputs, rank_post

# Best-effort fan-out to the realtime WebSocket hub (backend/ws-server.mjs).
# When the hub is reachable, server-side mutations (create/like/comment/save)
# are pushed to every connected client so the live feed updates across users
# even when the action originated from a non-web client (mobile, API, cron).
REALTIME_HUB_URL = os.getenv("REALTIME_HUB_URL", "http://localhost:8787").rstrip("/")


async def publish_event(topic: str, payload: dict) -> None:
    """Fire-and-forget broadcast to the realtime hub. Never raises."""
    try:
        async with httpx.AsyncClient(timeout=1.0) as client:
            await client.post(f"{REALTIME_HUB_URL}/publish", json={"topic": topic, "payload": payload})
    except Exception:
        pass


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _age_hours(dt) -> float:
    if dt is None:
        return 0.0
    try:
        ref = dt
        if ref.tzinfo is None:
            ref = ref.replace(tzinfo=timezone.utc)
        return max(0.0, (_now() - ref).total_seconds() / 3600.0)
    except Exception:
        return 0.0


def rank_score(p: orm.PostORM) -> float:
    engagement = (p.likes or 0) + (len(p.comments or [])) * 3 + (p.shares or 0) * 2
    impact = min(1.0, (p.impact_value or 0) / 12000.0) * 40.0
    recency = max(0.0, 30.0 - _age_hours(p.created_at) / 12.0)
    return engagement * 0.6 + impact + recency


def to_dict(p: orm.PostORM, liked_by_me: bool = False) -> dict:
    media = p.media or []
    top = media[0] if media else None
    mtype = (top.get("type") if isinstance(top, dict) else None) or "TEXT"
    mtype = str(mtype).upper()
    url = top.get("url") if isinstance(top, dict) else None

    # Compute confidence score using the blueprint formula
    stored_confidence = p.confidence if p.confidence is not None else 50.0
    factors = default_factors_for_post(
        author_verified=bool(p.author_verified),
        has_evidence=bool(media),
        has_corroboration=False,
        has_editorial_review=(stored_confidence >= 70),
        has_transparency=bool(p.author_name),
        has_history=((p.likes or 0) > 5),
    )
    conf_result = calculate_confidence(factors)
    # Blend stored DB confidence with computed score (70% stored / 30% computed)
    blended_score = round(0.7 * (stored_confidence / 100.0) + 0.3 * conf_result.score, 4)

    result = {
        "id": p.id,
        "author": {
            "id": p.author_id,
            "name": p.author_name,
            "handle": p.author_handle,
            "verified": p.author_verified,
            "role": p.author_role,
        },
        "text": p.text,
        "kind": p.kind,
        "programTag": p.program_tag,
        "sdg": p.sdg,
        "impactValue": p.impact_value,
        "impactLabel": p.impact_label,
        # Media type + a renderable URL so UIs can show TEXT/IMAGE/VIDEO/AUDIO/
        # ARTICLE/LINK posts uniformly (the Home feed runs this ranking algo).
        "type": mtype,
        "content_url": url,
        "url": url,
        "confidence": stored_confidence,
        "confidence_score": blended_score,
        "confidence_label": conf_result.label,
        "confidence_factors": conf_result.factors.to_dict(),
        "media": media,
        "comments": p.comments or [],
        "likes": p.likes or 0,
        "shares": p.shares or 0,
        "likedByMe": liked_by_me,
        "createdAt": (p.created_at.isoformat() if p.created_at else _now().isoformat()),
    }
    # Surface article/link metadata (kept inside the first media item) for the
    # richer card variants.
    if mtype in ("ARTICLE", "LINK") and isinstance(top, dict):
        result["title"] = top.get("title")
        result["summary"] = top.get("summary")
        result["source"] = top.get("source")
        result["imageUrl"] = top.get("imageUrl") or url
        result["domain"] = top.get("domain")
    return result


def _blueprint_rank(post_dict: dict, age_hours: float) -> float:
    """Apply the MASAREN feed ranking formula to a single post dict."""
    likes = post_dict.get("likes", 0) or 0
    comments_count = len(post_dict.get("comments", [])) if isinstance(post_dict.get("comments"), list) else 0
    shares_count = post_dict.get("shares", 0) or 0
    engagement = likes + comments_count * 2 + shares_count * 3
    predicted_user_value = min(1.0, engagement / 100.0)

    quality = 0.5
    if post_dict.get("author", {}).get("verified"):
        quality = min(1.0, quality + 0.3)
    if post_dict.get("confidence_score", 0) > 0.6:
        quality = min(1.0, quality + 0.2)

    if age_hours < 1:
        freshness = 1.0
    elif age_hours < 24:
        freshness = 0.9
    elif age_hours < 72:
        freshness = 0.7
    elif age_hours < 168:
        freshness = 0.5
    else:
        freshness = 0.3

    confidence = post_dict.get("confidence_score", 0.5) or 0.5

    inputs = RankingInputs(
        predicted_user_value=predicted_user_value,
        quality=quality,
        freshness=freshness,
        confidence=confidence,
        diversity=0.5,
        local_relevance=0.5,
        novelty=1.0,
        public_service_priority=0.2 if post_dict.get("sdg") else 0.0,
    )
    return rank_post(inputs).score


async def list_posts(
    session: AsyncSession,
    *,
    author_id: str | None = None,
    kind: str | None = None,
    user_id: str | None = None,
    limit: int = 40,
    offset: int = 0,
) -> list[dict]:
    stmt = select(orm.PostORM)
    if author_id:
        stmt = stmt.where(orm.PostORM.author_id == author_id)
    if kind:
        stmt = stmt.where(orm.PostORM.kind == kind)
    rows = (await session.execute(stmt)).scalars().all()
    if user_id:
        liked = await _liked_map(session, user_id, {p.id for p in rows})
    else:
        liked = {}
    # Convert to dicts first so we can apply the blueprint ranking
    dicts = [to_dict(p, liked.get(p.id, False)) for p in rows]
    # Apply the MASAREN Media Institutions Blueprint ranking formula
    now = _now()
    for d in dicts:
        age = _age_hours(_parse_iso(d.get("createdAt")))
        d["_ranking_score"] = _blueprint_rank(d, age)
    dicts.sort(key=lambda d: d.get("_ranking_score", 0), reverse=True)
    # Attach ranking_score to each post for the client
    for d in dicts:
        d["ranking_score"] = round(d.pop("_ranking_score"), 4)
    return dicts[offset : offset + limit]


def _parse_iso(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


async def get_post(session: AsyncSession, post_id: str, user_id: str | None = None) -> dict | None:
    p = (await session.get(orm.PostORM, post_id))
    if p is None:
        return None
    liked = False
    if user_id:
        liked = (await session.get(orm.LikeORM, (user_id, post_id))) is not None
    return to_dict(p, liked)


async def create_post(session: AsyncSession, token, body) -> dict:
    pid = uuid4().hex
    # Guard against JWTs that omit the ``email`` claim (e.g. service/API tokens):
    # fall back to the subject id so ``create_post`` never raises AttributeError.
    identity = token.email or token.sub or "user"
    handle = (body.author_handle or identity).split("@")[0]
    name = body.author_name or identity.split("@")[0].title()
    p = orm.PostORM(
        id=pid,
        author_id=token.sub,
        author_name=name,
        author_handle=handle,
        author_verified=False,
        author_role=token.role or "Individual",
        text=body.text,
        kind=body.kind,
        program_tag=body.program_tag,
        sdg=body.sdg,
        impact_value=body.impact_value,
        impact_label=body.impact_label,
        media=body.media or [],
        comments=[],
        likes=0,
        shares=0,
        created_at=_now(),
    )
    session.add(p)
    await session.commit()
    await session.refresh(p)
    return to_dict(p, False)


async def toggle_like(session: AsyncSession, post_id: str, user_id: str) -> dict:
    p = await session.get(orm.PostORM, post_id)
    if p is None:
        return {}
    row = await session.get(orm.LikeORM, (user_id, post_id))
    liked = row is None
    if liked:
        session.add(orm.LikeORM(user_id=user_id, post_id=post_id))
        p.likes = (p.likes or 0) + 1
    else:
        await session.delete(row)
        p.likes = max(0, (p.likes or 0) - 1)
    await session.commit()
    await session.refresh(p)
    return {"likes": p.likes, "likedByMe": liked}


async def add_comment(session: AsyncSession, post_id: str, user_id: str, text: str) -> dict:
    p = await session.get(orm.PostORM, post_id)
    if p is None:
        return {}
    comment = {
        "id": uuid4().hex,
        "author": {"id": user_id, "name": user_id, "handle": user_id},
        "text": text,
        "createdAt": _now().isoformat(),
    }
    comments = list(p.comments or [])
    comments.append(comment)
    p.comments = comments
    await session.commit()
    return comment


async def toggle_save(session: AsyncSession, post_id: str, user_id: str) -> dict:
    row = await session.get(orm.BookmarkORM, (user_id, post_id))
    saved = row is None
    if saved:
        session.add(orm.BookmarkORM(user_id=user_id, post_id=post_id))
    else:
        await session.delete(row)
    await session.commit()
    return {"saved": saved}


async def list_saved(session: AsyncSession, user_id: str) -> list[dict]:
    stmt = (
        select(orm.PostORM)
        .join(orm.BookmarkORM, orm.BookmarkORM.post_id == orm.PostORM.id)
        .where(orm.BookmarkORM.user_id == user_id)
    )
    rows = (await session.execute(stmt)).scalars().all()
    posts = sorted(rows, key=rank_score, reverse=True)
    return [to_dict(p, True) for p in posts]


async def _liked_map(session: AsyncSession, user_id: str, post_ids: Iterable[str]) -> dict[str, bool]:
    ids = list(post_ids)
    if not ids:
        return {}
    stmt = select(orm.LikeORM).where(
        orm.LikeORM.user_id == user_id, orm.LikeORM.post_id.in_(ids)
    )
    rows = (await session.execute(stmt)).scalars().all()
    return {r.post_id: True for r in rows}
