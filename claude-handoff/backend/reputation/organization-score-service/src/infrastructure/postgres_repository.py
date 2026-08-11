"""Real OII repository — persists Organizational Impact Index rows to PostgreSQL.

Writes to the canonical ``oii_scores`` table (migration V004). Append-only:
each recomputation inserts a new row with an incremented ``version`` so the full
index history is preserved. The tier is derived from ``composite_index`` at read
time (not a stored column).
"""
from __future__ import annotations

import json
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

TIER_THRESHOLDS = {"BRONZE": 0.0, "SILVER": 0.40, "GOLD": 0.65, "PLATINUM": 0.85}


def tier_for(composite: float) -> str:
    tier = "BRONZE"
    for name, threshold in TIER_THRESHOLDS.items():
        if composite >= threshold:
            tier = name
    return tier


class OIIRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def save(self, organization_id: str, composite_index: float,
                   dimensions: dict, version: int) -> dict:
        await self._session.execute(text("""
            INSERT INTO oii_scores
                (id, organization_id, composite_index, dimensions, version)
            VALUES
                (:id, :org, :idx, CAST(:dims AS JSONB), :ver)
        """), {
            "id": str(uuid4()),
            "org": organization_id,
            "idx": composite_index,
            "dims": json.dumps(dimensions),
            "ver": version,
        })
        await self._session.commit()
        return {
            "organization_id": organization_id,
            "composite_index": composite_index,
            "tier": tier_for(composite_index),
            "dimensions": dimensions,
            "version": version,
        }

    async def get_latest(self, organization_id: str) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT organization_id, composite_index, dimensions, version, computed_at
            FROM oii_scores
            WHERE organization_id = :org
            ORDER BY version DESC, computed_at DESC
            LIMIT 1
        """), {"org": organization_id})).mappings().first()
        if not row:
            return None
        return self._to_dict(row)

    async def get_history(self, organization_id: str, limit: int) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT organization_id, composite_index, dimensions, version, computed_at
            FROM oii_scores
            WHERE organization_id = :org
            ORDER BY version DESC, computed_at DESC
            LIMIT :lim
        """), {"org": organization_id, "lim": limit})).mappings().all()
        return [self._to_dict(r) for r in rows]

    async def leaderboard(self, limit: int) -> List[dict]:
        # Latest version per organization, ranked by composite_index.
        rows = (await self._session.execute(text("""
            SELECT DISTINCT ON (organization_id)
                   organization_id, composite_index, version
            FROM oii_scores
            ORDER BY organization_id, version DESC, computed_at DESC
        """))).mappings().all()
        ranked = sorted(rows, key=lambda r: r["composite_index"], reverse=True)[:limit]
        return [{
            "organization_id": str(r["organization_id"]),
            "composite_index": float(r["composite_index"]),
            "tier": tier_for(float(r["composite_index"])),
        } for r in ranked]

    @staticmethod
    def _to_dict(row) -> dict:
        dims = row["dimensions"]
        if isinstance(dims, str):
            dims = json.loads(dims)
        idx = float(row["composite_index"])
        return {
            "organization_id": str(row["organization_id"]),
            "composite_index": idx,
            "tier": tier_for(idx),
            "dimensions": dims,
            "version": row["version"],
            "computed_at": row["computed_at"].isoformat() if row["computed_at"] else None,
        }
