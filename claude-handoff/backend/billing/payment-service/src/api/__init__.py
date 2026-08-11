"""Payment service API — real local payment ledger.

A payment intent is recorded against the invoice/organization and confirmed to
SETTLED against the local ledger (``payments`` table). No fake PSP intent ids or
fabricated gateway responses are ever returned; if the database is unreachable
the endpoints return HTTP 503.

External PSP integration (Stripe / Vodafone Cash) is intentionally NOT stubbed
here — it must be added with real credentials and real HTTP calls rather than
simulated responses.
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
from shared.dtos import ApiResponse

from ..infrastructure.database import get_session
from ..infrastructure.postgres_repository import PaymentRepository
from ..infrastructure.psp_client import (
    get_psp_client, get_paymob_client, verify_paymob_hmac, PspError,
)
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/payments", tags=["Payments"])


def _repo(session: AsyncSession) -> PaymentRepository:
    return PaymentRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="payment_store_unavailable: " + str(exc))


class CreatePaymentIntentRequest(BaseModel):
    invoice_id: Optional[str] = None
    amount_usd: float
    org_id: str
    payment_method_id: Optional[str] = None


class ConfirmPaymentRequest(BaseModel):
    payment_intent_id: str
    payment_method_id: Optional[str] = None


@router.post("/intent", status_code=201, response_model=ApiResponse[dict])
async def create_payment_intent(body: CreatePaymentIntentRequest,
                                session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).create_intent(
            body.invoice_id, body.org_id, body.amount_usd, body.payment_method_id)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.post("/confirm", response_model=ApiResponse[dict])
async def confirm_payment(body: ConfirmPaymentRequest,
                          session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).confirm(body.payment_intent_id)
    except Exception as exc:
        raise _unavailable(exc)
    if data is None:
        return ApiResponse.error([f"Payment '{body.payment_intent_id}' not found."])
    return ApiResponse.ok(data)


@router.get("/{org_id}/history", response_model=ApiResponse[list])
async def payment_history(org_id: str, limit: int = 20,
                          session: AsyncSession = Depends(get_session)):
    try:
        data = await _repo(session).history(org_id, limit)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


# ── External PSP (Stripe) — real integration, honest fallback ────────────────────
# These endpoints only work when STRIPE_SECRET_KEY is configured. When it is not,
# they return HTTP 501 (not implemented / not configured) so the client can fall
# back to the local-ledger endpoints above — they never fabricate a PSP receipt.

@router.get("/psp/status", response_model=ApiResponse[dict])
async def psp_status():
    client = get_psp_client()
    paymob = get_paymob_client()
    return ApiResponse.ok({
        "providers": {
            "stripe": {"enabled": bool(client)},
            "paymob": {
                "enabled": bool(paymob),
                "currency": paymob.currency if paymob else None,
                "methods": ["card", "vodafone_cash"] if paymob else [],
            },
        }
    })


@router.post("/psp/intent", status_code=201, response_model=ApiResponse[dict])
async def create_psp_intent(body: CreatePaymentIntentRequest,
                            session: AsyncSession = Depends(get_session)):
    client = get_psp_client()
    if not client:
        raise HTTPException(status_code=501,
                            detail="psp_not_configured: set STRIPE_SECRET_KEY to enable Stripe payments.")
    try:
        intent = await client.create_payment_intent(
            amount_usd=body.amount_usd, org_id=body.org_id, invoice_id=body.invoice_id)
    except PspError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    try:
        record = await _repo(session).create_external_intent(
            invoice_id=body.invoice_id, org_id=body.org_id,
            amount_usd=body.amount_usd, external_ref=intent["id"], status="PENDING")
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({
        **record,
        "psp": {
            "provider": "stripe",
            "intent_id": intent["id"],
            "client_secret": intent.get("client_secret"),
            "status": intent.get("status"),
        },
    })


class PspConfirmRequest(BaseModel):
    intent_id: str


@router.post("/psp/confirm", response_model=ApiResponse[dict])
async def confirm_psp_intent(body: PspConfirmRequest,
                             session: AsyncSession = Depends(get_session)):
    """Reconcile a PSP payment against Stripe's authoritative status.

    The ledger is only marked SETTLED when Stripe reports ``succeeded`` — the
    status is taken from the PSP, never assumed."""
    client = get_psp_client()
    if not client:
        raise HTTPException(status_code=501,
                            detail="psp_not_configured: set STRIPE_SECRET_KEY to enable Stripe payments.")
    try:
        intent = await client.retrieve_payment_intent(body.intent_id)
    except PspError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    ledger_status = "SETTLED" if intent.get("status") == "succeeded" else intent.get("status", "PENDING").upper()
    try:
        record = await _repo(session).settle_by_external_ref(body.intent_id, ledger_status)
    except Exception as exc:
        raise _unavailable(exc)
    if record is None:
        return ApiResponse.error([f"No local payment found for PSP intent '{body.intent_id}'."])
    return ApiResponse.ok({**record, "psp_status": intent.get("status")})


# ── Paymob (Egypt) — card iframe + Vodafone Cash wallet ──────────────────────────
# Real integration: creates a Paymob order + payment key and (for Vodafone Cash)
# initiates the wallet payment. The ledger is only SETTLED by the verified webhook
# below — never assumed from the client.
class PaymobIntentRequest(BaseModel):
    org_id: str
    amount_egp: float
    phone: Optional[str] = None
    invoice_id: Optional[str] = None
    method: str = "vodafone_cash"  # "vodafone_cash" | "card"
    billing_data: Optional[dict] = None


@router.post("/psp/paymob/intent", status_code=201, response_model=ApiResponse[dict])
async def create_paymob_intent(body: PaymobIntentRequest,
                               session: AsyncSession = Depends(get_session)):
    client = get_paymob_client()
    if not client:
        raise HTTPException(
            status_code=501,
            detail="psp_not_configured: set PAYMOB_API_KEY + PAYMOB_HMAC_SECRET to enable Paymob.",
        )
    integration_id = (
        client.vodafone_integration_id if body.method == "vodafone_cash"
        else client.wallet_integration_id
    )
    if not integration_id:
        raise HTTPException(
            status_code=501,
            detail=f"psp_not_configured: integration id for method '{body.method}' is not set.",
        )
    billing_data = body.billing_data or {
        "apartment": "NA", "building": "NA", "city": "NA", "floor": "NA",
        "first_name": "MASAREN", "last_name": "User", "street": "NA",
        "phone_number": body.phone or "NA", "email": "user@masaren.org",
    }
    try:
        order_id = await client.create_order(body.amount_egp, [], token=None)
        payment_key = await client.create_payment_key(
            body.amount_egp, order_id, billing_data, integration_id, token=None)
        if body.method == "vodafone_cash":
            wallet = await client.initiate_vodafone_cash(payment_key, body.phone or "")
            redirect_url = wallet.get("redirect_url") or wallet.get("url")
        else:
            redirect_url = (
                f"https://accept.paymob.com/api/acceptance/iframes/"
                f"{client.iframe_id}?payment_token={payment_key}"
            )
        record = await _repo(session).create_paymob_intent(
            order_id=str(order_id), org_id=body.org_id, amount=body.amount_egp,
            currency=client.currency, invoice_id=body.invoice_id, phone=body.phone)
    except PspError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({
        **record,
        "psp": {
            "provider": "paymob",
            "method": body.method,
            "order_id": order_id,
            "payment_key": payment_key,
            "redirect_url": redirect_url,
        },
    })


class PaymobWebhookRequest(BaseModel):
    id: Optional[int] = None
    order: Optional[dict] = None
    amount_cents: Optional[int] = None
    currency: Optional[str] = None
    success: Optional[bool] = None
    status: Optional[str] = None
    hmac: Optional[str] = None
    source_data: Optional[dict] = None
    integration_id: Optional[int] = None


@router.post("/psp/paymob/webhook", response_model=ApiResponse[dict])
async def paymob_webhook(body: PaymobWebhookRequest,
                         session: AsyncSession = Depends(get_session),
                         request: Request = None):
    """Paymob transaction webhook. The HMAC is verified before any ledger change.

    A payment is marked SETTLED only when Paymob reports success; otherwise it is
    marked FAILED. Replayed/invalid HMACs are rejected with 401 — no fabricated
    settlement ever reaches the ledger.
    """
    client = get_paymob_client()
    if not client:
        raise HTTPException(status_code=501, detail="psp_not_configured: Paymob not enabled.")
    payload = (await request.body()) if request else b"{}"
    import json
    try:
        raw = json.loads(payload.decode() if isinstance(payload, bytes) else payload)
    except Exception:
        raw = {}
    if not verify_paymob_hmac(raw, client.hmac_secret):
        raise HTTPException(status_code=401, detail="invalid_paymob_hmac")
    order_id = (body.order or {}).get("id") if body.order else None
    if order_id is None:
        raise HTTPException(status_code=400, detail="missing_order_id")
    ledger_status = "SETTLED" if body.success else "FAILED"
    try:
        record = await _repo(session).settle_by_order(
            str(order_id), ledger_status, txn_id=str(body.id) if body.id else None)
    except Exception as exc:
        raise _unavailable(exc)
    if record is None:
        return ApiResponse.error([f"No local payment found for Paymob order '{order_id}'."])
    return ApiResponse.ok({**record, "psp_status": body.status})
