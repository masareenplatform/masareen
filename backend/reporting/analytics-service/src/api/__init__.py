"""Analytics service API — real aggregates over the platform's relational tables.

Every endpoint computes its response from PostgreSQL (see
infrastructure/postgres_repository.py). If the database is unreachable the
endpoint returns HTTP 503 — it never returns fabricated zeros.
"""
from fastapi import APIRouter, Query, Depends, HTTPException
from typing import Optional
from shared.dtos import ApiResponse

from ..infrastructure.database import get_session
from ..infrastructure.postgres_repository import AnalyticsRepository
from sqlalchemy.ext.asyncio import AsyncSession

try:
    from config import settings
except Exception:  # pragma: no cover
    from ...config import settings  # type: ignore

router = APIRouter(prefix="/analytics", tags=["Analytics"])


def _repo(session: AsyncSession) -> AnalyticsRepository:
    return AnalyticsRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="analytics_store_unavailable: " + str(exc))


@router.get("/platform/summary", response_model=ApiResponse[dict])
async def platform_summary(session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).platform_summary()
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/programs/{program_id}/stats", response_model=ApiResponse[dict])
async def program_stats(program_id: str, session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).program_stats(program_id)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/organizations/{org_id}/stats", response_model=ApiResponse[dict])
async def org_stats(org_id: str, session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).org_stats(org_id)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/users/{user_id}/stats", response_model=ApiResponse[dict])
async def user_stats(user_id: str, session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).user_stats(user_id)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/sdg/progress", response_model=ApiResponse[dict])
async def sdg_progress(country: Optional[str] = Query(None),
                       session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).sdg_progress(country)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)
