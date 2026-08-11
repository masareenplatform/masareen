"""Tests for Paymob PSP client, HMAC verification, and Paymob ledger methods."""
import os
import hmac
import hashlib
from unittest.mock import AsyncMock, MagicMock, patch
import pytest

from src.infrastructure.psp_client import (
    PaymobPspClient, verify_paymob_hmac, PspNotConfiguredError,
)
from src.infrastructure.postgres_repository import PaymentRepository


# ── HMAC verification ────────────────────────────────────────────────────────────
def _s(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    return "" if v is None else str(v)


def _build_payload(secret: str) -> dict:
    payload = {
        "id": 123, "amount_cents": 10000, "created_at": "2024-01-01T00:00:00",
        "currency": "EGP", "error_occured": False, "integration_id": 1,
        "is_3d_secure": False, "is_auth": False, "is_capture": False,
        "is_refunded": False, "is_standalone_payment": True, "is_voided": False,
        "owner": 9, "payment_key_claims": None, "pending": False,
        "source_data": {"code": "VCASH", "sub_type": "VODAFONE_CASH", "type": "wallet"},
        "status": "APPROVED", "success": True,
        "order": {"id": 555, "hashed_order": "abc"},
    }
    fields = [
        _s(payload["amount_cents"]), _s(payload["created_at"]), _s(payload["currency"]),
        _s(payload["error_occured"]), _s(payload["order"]["hashed_order"]), _s(payload["id"]),
        _s(payload["integration_id"]), _s(payload["is_3d_secure"]), _s(payload["is_auth"]),
        _s(payload["is_capture"]), _s(payload["is_refunded"]), _s(payload["is_standalone_payment"]),
        _s(payload["is_voided"]), _s(payload["order"]["id"]), _s(payload["owner"]),
        _s(payload["payment_key_claims"]), _s(payload["pending"]),
        _s(payload["source_data"]["code"]), _s(payload["source_data"]["sub_type"]),
        _s(payload["source_data"]["type"]), _s(payload["status"]), _s(payload["success"]),
    ]
    payload["hmac"] = hmac.new(secret.encode(), "".join(fields).encode(),
                               hashlib.sha512).hexdigest()
    return payload


def test_verify_paymob_hmac_valid():
    secret = "super-secret"
    payload = _build_payload(secret)
    assert verify_paymob_hmac(payload, secret) is True


def test_verify_paymob_hmac_invalid():
    payload = _build_payload("super-secret")
    payload["hmac"] = "deadbeef"
    assert verify_paymob_hmac(payload, "super-secret") is False


# ── Client configuration ──────────────────────────────────────────────────────────
def test_paymob_disabled_without_credentials():
    client = PaymobPspClient(api_key="", hmac_secret="")
    assert client.enabled is False


def test_paymob_enabled_with_credentials():
    client = PaymobPspClient(api_key="k", hmac_secret="s")
    assert client.enabled is True


@pytest.mark.asyncio
async def test_paymob_authenticate_raises_when_not_configured():
    client = PaymobPspClient(api_key="", hmac_secret="")
    with pytest.raises(PspNotConfiguredError):
        await client.authenticate()


# ── Order + payment key (mocked HTTP) ─────────────────────────────────────────────
def _patched_http(responses: dict):
    """Patch httpx.AsyncClient so POST/GET to a URL fragment returns the mapped JSON."""
    def make_resp(payload, status=200):
        r = MagicMock()
        r.status_code = status
        r.text = ""
        r.json.return_value = payload
        return r

    def client_factory(*a, **k):
        cm = AsyncMock()
        c = MagicMock()
        c.get = AsyncMock(return_value=make_resp({}))
        post = AsyncMock()

        def side_effect(url, **kw):
            for frag, payload in responses.items():
                if frag in str(url):
                    return make_resp(payload)
            return make_resp({}, status=404)

        post.side_effect = side_effect
        c.post = post
        cm.__aenter__.return_value = c
        cm.__aexit__.return_value = False
        return cm

    return patch("httpx.AsyncClient", side_effect=client_factory)


@pytest.mark.asyncio
async def test_create_order_and_payment_key():
    client = PaymobPspClient(api_key="k", hmac_secret="s")
    with _patched_http({
        "/api/auth/tokens": {"token": "auth-tok"},
        "/api/ecommerce/orders": {"id": 42},
        "/api/acceptance/payment_keys": {"token": "pay-key"},
    }):
        order_id = await client.create_order(100.0, [])
        assert order_id == 42
        key = await client.create_payment_key(100.0, order_id, {}, "1")
    assert key == "pay-key"


@pytest.mark.asyncio
async def test_initiate_vodafone_cash():
    client = PaymobPspClient(api_key="k", hmac_secret="s", vodafone_integration_id="7")
    with _patched_http({
        "/api/auth/tokens": {"token": "auth-tok"},
        "/api/ecommerce/orders": {"id": 42},
        "/api/acceptance/payment_keys": {"token": "pay-key"},
        "/api/acceptance/payments/pay": {"redirect_url": "https://vodafone.cash/x"},
    }):
        key = await client.create_payment_key(100.0, 42, {}, "7")
        res = await client.initiate_vodafone_cash(key, "01001234567")
    assert res["redirect_url"].endswith("/x")


# ── Ledger methods (mocked session) ───────────────────────────────────────────────
@pytest.mark.asyncio
async def test_create_paymob_intent_records_pending(mock_session):
    repo = PaymentRepository(mock_session)
    mock_session.execute = AsyncMock()
    mock_session.commit = AsyncMock()
    d = await repo.create_paymob_intent(
        order_id="555", org_id="org-1", amount=100.0, currency="EGP", invoice_id="inv-1")
    assert d["status"] == "PENDING"
    assert d["psp_provider"] == "paymob"
    assert d["external_ref"] == "555"
    assert d["currency"] == "EGP"


@pytest.mark.asyncio
async def test_settle_by_order_marks_settled(mock_session):
    repo = PaymentRepository(mock_session)
    import src.infrastructure.postgres_repository as prepo
    prepo.get_fee_rate = AsyncMock(return_value=0.025)
    prepo.record_revenue = AsyncMock(return_value={"id": "rev"})
    res = MagicMock()
    res.mappings.return_value.first.return_value = {
        "id": "p1", "status": "SETTLED", "external_ref": "555",
        "amount_usd": 100.0, "currency": "EGP", "psp_provider": "paymob"}
    mock_session.execute.return_value = res
    row = await repo.settle_by_order("555", "SETTLED", txn_id="999")
    assert row["status"] == "SETTLED"
