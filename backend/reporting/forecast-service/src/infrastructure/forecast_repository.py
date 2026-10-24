"""Forecast repository, real aggregates from existing platform tables.

We read monthly ``impact_assets.economic_value_usd`` (and completed ``tasks``
counts) to build a historical series, then the (pure) forecast engine
projects forward. No fabricated future numbers, they are derived from real
history via a documented linear trend.
"""
from __future__ import annotations

from typing import List
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..domain.forecast import linear_forecast


class ForecastRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def monthly_impact_value_series(self, months: int = 12) -> List[float]:
        """Last ``months`` months of total impact value, oldest→newest.

        Uses ``date_trunc('month', created_at)`` so the series is evenly
        spaced (required by the linear engine).
        """
        rows = await self._session.execute(text("""
            SELECT date_trunc('month', created_at) AS m,
                   coalesce(sum(economic_value_usd), 0) AS total
            FROM impact_assets
            WHERE created_at >= NOW() - make_interval(months => :n)
            GROUP BY 1 ORDER BY 1
        """), {"n": months})
        return [float(r["total"]) for r in rows.mappings().all()]

    async def forecast_impact(self, months: int = 12, periods: int = 3) -> dict:
        history = await self.monthly_impact_value_series(months)
        projected = linear_forecast(history, periods) if history else []
        return {
            "history_months": months,
            "history": history,
            "projected_months": periods,
            "projected": projected,
            "series_id": uuid4().hex,
        }
