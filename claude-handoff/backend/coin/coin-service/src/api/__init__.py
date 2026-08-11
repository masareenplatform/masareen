"""Coin / wallet API — MASAREN Coin (MRC) wallet, transfers and EGP exchange.

Every mutating endpoint requires a valid JWT (enforced by the gateway and re-checked
here via ``make_auth_dependency``), and transfers/spend/withdraw require the caller to
be the wallet owner (or an admin) — money movements are owner-scoped and transactional.
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import Optional

from shared.dtos import ApiResponse
from shared.middleware import make_auth_dependency, TokenPayload
from ...config import settings

from ..infrastructure.database import get_session
from ..infrastructure.repository import WalletRepository, InsufficientFundsError
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()
get_current_user = make_auth_dependency(settings.jwt_secret, settings.jwt_algorithm)


def _repo(session: AsyncSession) -> WalletRepository:
    return WalletRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="coin_store_unavailable: " + str(exc))


def _owner_allowed(token: TokenPayload, owner_id: str) -> None:
    if token.role == "ADMIN":
        return
    if str(token.sub) != str(owner_id):
        raise HTTPException(status_code=403,
                            detail="You may only act on your own wallet.")


class CreateWalletRequest(BaseModel):
    owner_id: Optional[str] = None


class TransferRequest(BaseModel):
    from_owner: str
    to_owner: str
    amount: float
    reference: Optional[str] = None


class AdjustRequest(BaseModel):
    owner_id: str
    amount: float
    reference: Optional[str] = None


class ConvertRequest(BaseModel):
    owner_id: str
    currency: str = "EGP"
    fiat_amount: float
    direction: str  # "deposit" | "withdraw"


class SetRateRequest(BaseModel):
    currency: str
    rate_to_mrc: float


@router.get("/wallets/{owner_id}", response_model=ApiResponse[dict])
async def get_wallet(owner_id: str, token: TokenPayload = Depends(get_current_user),
                     session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, owner_id)
    try:
        data = await _repo(session).get_wallet(owner_id)
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"No wallet for owner '{owner_id}'."])
    return ApiResponse.ok(data)


@router.post("/wallets", status_code=201, response_model=ApiResponse[dict])
async def create_wallet(body: CreateWalletRequest,
                         token: TokenPayload = Depends(get_current_user),
                         session: AsyncSession = Depends(get_session)):
    owner = body.owner_id or str(token.sub)
    _owner_allowed(token, owner)
    try:
        data = await _repo(session).create_wallet(owner)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/transactions/transfer", response_model=ApiResponse[dict])
async def transfer(body: TransferRequest,
                   token: TokenPayload = Depends(get_current_user),
                   session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, body.from_owner)
    if body.amount <= 0:
        return ApiResponse.error(["amount must be positive"])
    try:
        data = await _repo(session).transfer(body.from_owner, body.to_owner,
                                              body.amount, body.reference)
    except InsufficientFundsError as exc:
        return ApiResponse.error([str(exc)])
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/transactions/earn", response_model=ApiResponse[dict])
async def earn(body: AdjustRequest,
               token: TokenPayload = Depends(get_current_user),
               session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, body.owner_id)
    try:
        data = await _repo(session).adjust(body.owner_id, abs(body.amount), "EARN",
                                            reference=body.reference)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/transactions/spend", response_model=ApiResponse[dict])
async def spend(body: AdjustRequest,
                token: TokenPayload = Depends(get_current_user),
                session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, body.owner_id)
    try:
        data = await _repo(session).adjust(body.owner_id, -abs(body.amount), "SPEND",
                                            reference=body.reference)
    except InsufficientFundsError as exc:
        return ApiResponse.error([str(exc)])
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/transactions/{owner_id}", response_model=ApiResponse[list])
async def history(owner_id: str, limit: int = 50,
                  token: TokenPayload = Depends(get_current_user),
                  session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, owner_id)
    try:
        data = await _repo(session).history(owner_id, limit)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/exchange/rate", response_model=ApiResponse[dict])
async def get_rate(currency: str = "EGP",
                  session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).get_rate(currency)
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"No exchange rate for {currency}."])
    return ApiResponse.ok(data)


@router.post("/exchange/rate", response_model=ApiResponse[dict])
async def set_rate(body: SetRateRequest,
                   token: TokenPayload = Depends(get_current_user),
                   session: AsyncSession = Depends(get_session)):
    if token.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Only admins can set exchange rates.")
    try:
        data = await _repo(session).set_rate(body.currency, body.rate_to_mrc)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/exchange/convert", response_model=ApiResponse[dict])
async def convert(body: ConvertRequest,
                  token: TokenPayload = Depends(get_current_user),
                  session: AsyncSession = Depends(get_session)):
    _owner_allowed(token, body.owner_id)
    if body.direction not in ("deposit", "withdraw"):
        return ApiResponse.error(["direction must be 'deposit' or 'withdraw'"])
    try:
        data = await _repo(session).convert(body.owner_id, body.currency,
                                            body.fiat_amount, body.direction)
    except InsufficientFundsError as exc:
        return ApiResponse.error([str(exc)])
    except ValueError as exc:
        return ApiResponse.error([str(exc)])
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)
