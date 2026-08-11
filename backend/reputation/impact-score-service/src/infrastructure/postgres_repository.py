"""Real PMS repository — persists Proof-of-Mission-Score snapshots to PostgreSQL.

Writes to the canonical ``pms_scores`` table (migration V004) so that downstream
consumers (portfolio-service, graph-service) read a single source of truth.
Snapshots are append-only: each recomputation inserts a new row with an
incremented ``version``, preserving full score history. The ``tier`` is derived
from ``composite_score`` at read time (it is not a stored column).
"""
from __future__ import annotations

import json
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..domain.pms_engine import PMSSnapshot


def _tier_for(composite: float) -> str:
    tier = "BRONZE"
    for name, threshold in PMSSnapshot.TIER_THRESHOLDS.items():
        if composite >= threshold:
            tier = name
    return tier


class PMSRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def save_snapshot(self, snapshot: PMSSnapshot) -> PMSSnapshot:
        await self._session.execute(text("""
            INSERT INTO pms_scores
                (id, user_id, composite_score, dimensions, version, computed_at)
            VALUES
                (:id, :uid, :score, CAST(:dims AS JSONB), :ver, :computed_at)
        """), {
            "id": str(uuid4()),
            "uid": snapshot.user_id,
            "score": snapshot.composite_score,
            "dims": json.dumps(snapshot.dimensions),
            "ver": snapshot.version,
            "computed_at": snapshot.computed_at,
        })
        await self._session.commit()
        return snapshot

    async def get_latest_snapshot(self, user_id: str) -> Optional[PMSSnapshot]:
        row = (await self._session.execute(text("""
            SELECT user_id, composite_score, dimensions, version, computed_at
            FROM pms_scores
            WHERE user_id = :uid
            ORDER BY version DESC, computed_at DESC
            LIMIT 1
        """), {"uid": user_id})).mappings().first()
        if not row:
            return None
        return self._to_snapshot(row)

    async def get_history(self, user_id: str, limit: int) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT composite_score, dimensions, version, computed_at
            FROM pms_scores
            WHERE user_id = :uid
            ORDER BY version DESC, computed_at DESC
            LIMIT :lim
        """), {"uid": user_id, "lim": limit})).mappings().all()
        result: List[dict] = []
        for r in rows:
            dims = r["dimensions"]
            if isinstance(dims, str):
                dims = json.loads(dims)
            score = float(r["composite_score"])
            result.append({
                "version": r["version"],
                "composite_score": score,
                "tier": _tier_for(score),
                "dimensions": dims,
                "computed_at": r["computed_at"].isoformat() if r["computed_at"] else None,
            })
        return result

    @staticmethod
    def _to_snapshot(row) -> PMSSnapshot:
        dims = row["dimensions"]
        if isinstance(dims, str):
            dims = json.loads(dims)
        score = float(row["composite_score"])
        return PMSSnapshot(
            user_id=str(row["user_id"]),
            composite_score=score,
            dimensions=dims,
            tier=_tier_for(score),
            version=row["version"],
            computed_at=row["computed_at"],
        )
