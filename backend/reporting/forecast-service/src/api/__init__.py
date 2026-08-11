from typing import AsyncGenerator
"""Forecast service API ??? real impact projection from historical aggregates.

Honest scope (handoff S-002 6.x): this is a deterministic linear-trend
projection over real monthly ``impact_assets`` value, NOT an ML model. The
engine is pure and unit-tested; the endpoint is a thin read over the
repository. If there is no history yet, it returns an empty projection
rather than inventing numbers.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from shared.dtos import ApiResponse
from shared.base_repository.db import build_engine, build_session_factory

from ..infrastructure.database import get_session
from ..infrastructure.forecast_repository import ForecastRepository

router = APIRouter(prefix="/forecast", tags=["Forecast"])

engine = build_engine()
session_factory = build_session_factory(engine)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:  # noqa: F811
    async with session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


def _repo(session: AsyncSession) -> ForecastRepository:
    return ForecastRepository(session)


class ForecastRequest(BaseModel):
    months: int = 12
    periods: int = 3


@router.post("/impact", response_model=ApiResponse[dict])
async def forecast_impact(req: ForecastRequest,
                        session: AsyncSession = Depends(get_db_session)):
    try:
        data = await _repo(session).forecast_impact(months=req.months, periods=req.periods)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"forecast_store_unavailable: {exc}")
    return ApiResponse.ok(data)
