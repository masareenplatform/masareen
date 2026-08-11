"""Subscription service API — real subscription persistence.

Plans are real static configuration. Creating/upgrading a subscription writes a
real row per organization. If the database is unreachable the endpoints return
HTTP 503 rather than faking a subscription.
"""
from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from shared.dtos import ApiResponse

from ..infrastructure.database import get_session
from ..infrastructure.postgres_repository import SubscriptionRepository
from sqlalchemy.ext.asyncio import AsyncSession

try:
    from config import settings
except Exception:  # pragma: no cover
    from ...config import settings  # type: ignore

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions"])

PLANS = {
    "FREE":       {"price_usd": 0,   "max_programs": 1,  "max_users": 10,  "ai_verifications": 50},
    "STARTER":    {"price_usd": 49,  "max_programs": 5,  "max_users": 100, "ai_verifications": 500},
    "GROWTH":     {"price_usd": 199, "max_programs": 20, "max_users": 500, "ai_verifications": 2000},
    "ENTERPRISE": {"price_usd": 0,   "max_programs": -1, "max_users": -1,  "ai_verifications": -1},
}


def _repo(session: AsyncSession) -> SubscriptionRepository:
    return SubscriptionRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="subscription_store_unavailable: " + str(exc))


class CreateSubscriptionRequest(BaseModel):
    organization_id: str
    plan: str = "FREE"
    billing_email: Optional[str] = None


@router.get("/plans", response_model=ApiResponse[dict])
async def list_plans():
    return ApiResponse.ok(PLANS)


@router.post("/", status_code=201, response_model=ApiResponse[dict])
async def create_subscription(body: CreateSubscriptionRequest, session: AsyncSession = Depends(get_session)):
    plan = body.plan.upper()
    if plan not in PLANS:
        return ApiResponse.error([f"Plan '{body.plan}' not found."])
    try:
        data = await _repo(session).upsert(body.organization_id, plan, body.billing_email)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/{org_id}", response_model=ApiResponse[dict])
async def get_subscription(org_id: str, session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).get(org_id)
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"No subscription for organization '{org_id}'."])
    return ApiResponse.ok(data)


@router.patch("/{org_id}/upgrade", response_model=ApiResponse[dict])
async def upgrade_plan(org_id: str, new_plan: str, session: AsyncSession = Depends(get_session)):
    plan = new_plan.upper()
    if plan not in PLANS:
        return ApiResponse.error([f"Plan '{new_plan}' not found."])
    try:
        data = await _repo(session).upsert(org_id, plan, None)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)
