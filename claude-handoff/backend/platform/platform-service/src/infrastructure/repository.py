"""Platform revenue repository — brokerage config + auditable profit ledger.

Reads the global fee rate (shared.revenue) and aggregates the platform_revenue
ledger so the admin panel can show profit margins. All amounts come straight
from the append-only ledger — never estimated or fabricated.
"""
from __future__ import annotations
from typing import List, Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from shared.revenue import get_fee_rate, set_fee_rate


class PlatformRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def fee_rate(self) -> float:
        return await get_fee_rate(self._session)

    async def set_fee_rate(self, rate: float) -> float:
        return await set_fee_rate(self._session, rate)

    async def summary(self) -> dict:
        rows = (await self._session.execute(text("""
            SELECT source_service, currency, COALESCE(SUM(amount), 0) AS total
            FROM platform_revenue GROUP BY source_service, currency
        """))).mappings().all()
        by_source: dict = {}
        totals = {"MRC": 0.0, "EGP": 0.0}
        for r in rows:
            src = r["source_service"]
            cur = r["currency"]
            amt = float(r["total"])
            by_source.setdefault(src, {})[cur] = amt
            totals[cur] = totals.get(cur, 0.0) + amt
        return {"totals": totals, "by_source": by_source,
                "fee_rate": await self.fee_rate()}

    async def recent_events(self, limit: int = 50) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT id, source_service, currency, amount, reference, created_at
            FROM platform_revenue ORDER BY created_at DESC LIMIT :lim
        """), {"lim": limit})).mappings().all()
        return [dict(r) for r in rows]
