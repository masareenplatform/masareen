"""Platform admin API, brokerage fee config + revenue/profit summary.

The fee rate is the single, tweakable brokerage knob applied to every monetisable
action across the platform (coin conversions, transfers, PSP payments, ads). Only
admins can change it; anyone authenticated can read the current rate and totals.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from shared.dtos import ApiResponse
from shared.middleware import make_auth_dependency, TokenPayload
from ...config import settings

from ..infrastructure.database import get_session
from ..infrastructure.repository import PlatformRepository
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()
get_current_user = make_auth_dependency(settings.jwt_secret, settings.jwt_algorithm)


def _repo(session: AsyncSession) -> PlatformRepository:
    return PlatformRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="platform_store_unavailable: " + str(exc))


class SetFeeRequest(BaseModel):
    rate: float  # 0..1, e.g. 0.025 for 2.5%


@router.get("/config/fee", response_model=ApiResponse[dict])
async def get_fee(token: TokenPayload = Depends(get_current_user),
                 session: AsyncSession = Depends(get_session)):
    try:
        rate = await _repo(session).fee_rate()
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({"fee_rate": rate})


@router.post("/config/fee", response_model=ApiResponse[dict])
async def set_fee(body: SetFeeRequest,
                  token: TokenPayload = Depends(get_current_user),
                  session: AsyncSession = Depends(get_session)):
    if token.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only admins can set the brokerage fee.")
    if body.rate < 0 or body.rate > 1:
        return ApiResponse.error(["rate must be between 0 and 1"])
    try:
        rate = await _repo(session).set_fee_rate(body.rate)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({"fee_rate": rate})


@router.get("/revenue/summary", response_model=ApiResponse[dict])
async def revenue_summary(token: TokenPayload = Depends(get_current_user),
                          session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).summary()
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/revenue/events", response_model=ApiResponse[list])
async def revenue_events(limit: int = 50,
                         token: TokenPayload = Depends(get_current_user),
                         session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).recent_events(limit)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)
