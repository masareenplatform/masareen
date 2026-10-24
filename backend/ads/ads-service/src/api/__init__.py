"""Ads manager API, campaign lifecycle, creatives and delivery tracking.

Campaigns are funded in MASAREEN Coin (MRC). Creating/listing requires a valid JWT;
a campaign can only be managed by its owning advertiser or an admin. Delivery events
deduct from the budget via the repository (never overspend).
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List

from shared.dtos import ApiResponse
from shared.middleware import make_auth_dependency, TokenPayload
from ...config import settings

from ..infrastructure.database import get_session
from ..infrastructure.repository import AdsRepository
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()
get_current_user = make_auth_dependency(settings.jwt_secret, settings.jwt_algorithm)


def _repo(session: AsyncSession) -> AdsRepository:
    return AdsRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="ads_store_unavailable: " + str(exc))


def _owner_allowed(token: TokenPayload, owner_id: str) -> None:
    if token.role == "ADMIN":
        return
    if str(token.sub) != str(owner_id):
        raise HTTPException(status_code=403, detail="You may only manage your own campaigns.")


class CreateCampaignRequest(BaseModel):
    name: str
    budget_coins: float
    currency: str = "MRC"
    targeting: dict = {}
    start_date: Optional[str] = None
    end_date: Optional[str] = None


class AddCreativeRequest(BaseModel):
    title: str
    body: str
    media_url: Optional[str] = None
    cta_url: Optional[str] = None


class SetStatusRequest(BaseModel):
    status: str  # DRAFT | ACTIVE | PAUSED | COMPLETED


@router.post("/campaigns", status_code=201, response_model=ApiResponse[dict])
async def create_campaign(body: CreateCampaignRequest,
                           token: TokenPayload = Depends(get_current_user),
                           session: AsyncSession = Depends(get_session)):
    if body.budget_coins <= 0:
        return ApiResponse.error(["budget_coins must be positive"])
    try:
        data = await _repo(session).create_campaign(
            owner_id=str(token.sub), name=body.name, budget_coins=body.budget_coins,
            currency=body.currency, targeting=body.targeting,
            start_date=body.start_date, end_date=body.end_date)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/campaigns", response_model=ApiResponse[list])
async def list_campaigns(status: Optional[str] = None,
                         token: TokenPayload = Depends(get_current_user),
                         session: AsyncSession = Depends(get_session)):
    owner = None if token.role == "ADMIN" else str(token.sub)
    try:
        data = await _repo(session).list_campaigns(owner_id=owner, status=status)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/campaigns/{campaign_id}", response_model=ApiResponse[dict])
async def get_campaign(campaign_id: str,
                       token: TokenPayload = Depends(get_current_user),
                       session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).get_campaign(campaign_id)
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
    _owner_allowed(token, data["owner_id"])
    return ApiResponse.ok(data)


@router.patch("/campaigns/{campaign_id}/status", response_model=ApiResponse[dict])
async def set_status(campaign_id: str, body: SetStatusRequest,
                     token: TokenPayload = Depends(get_current_user),
                     session: AsyncSession = Depends(get_session)):
    try:
        camp = await _repo(session).get_campaign(campaign_id)
        if camp is None:
            return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
        _owner_allowed(token, camp["owner_id"])
        data = await _repo(session).set_status(campaign_id, body.status)
    except HTTPException:
        raise
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/campaigns/{campaign_id}/creatives", status_code=201,
             response_model=ApiResponse[dict])
async def add_creative(campaign_id: str, body: AddCreativeRequest,
                       token: TokenPayload = Depends(get_current_user),
                       session: AsyncSession = Depends(get_session)):
    try:
        camp = await _repo(session).get_campaign(campaign_id)
        if camp is None:
            return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
        _owner_allowed(token, camp["owner_id"])
        data = await _repo(session).add_creative(
            campaign_id, body.title, body.body, body.media_url, body.cta_url)
    except HTTPException:
        raise
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/campaigns/{campaign_id}/impression", response_model=ApiResponse[dict])
async def record_impression(campaign_id: str,
                            token: TokenPayload = Depends(get_current_user),
                            session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).record_event(campaign_id, "impression")
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
    return ApiResponse.ok(data)


@router.post("/campaigns/{campaign_id}/click", response_model=ApiResponse[dict])
async def record_click(campaign_id: str,
                       token: TokenPayload = Depends(get_current_user),
                       session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).record_event(campaign_id, "click")
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
    return ApiResponse.ok(data)


@router.get("/campaigns/{campaign_id}/stats", response_model=ApiResponse[dict])
async def campaign_stats(campaign_id: str,
                         token: TokenPayload = Depends(get_current_user),
                         session: AsyncSession = Depends(get_session)):
    try:
        camp = await _repo(session).get_campaign(campaign_id)
        if camp is None:
            return ApiResponse.error([f"Campaign '{campaign_id}' not found."])
        _owner_allowed(token, camp["owner_id"])
        data = await _repo(session).stats(campaign_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)
