"""External Payment Service Provider (PSP) integration for MASAREEN.

Real HTTP integration with Stripe's PaymentIntents API. There are **no simulated
responses**: if ``STRIPE_SECRET_KEY`` is not configured the PSP is reported as
disabled and callers fall back to the local ledger; if a real Stripe call fails
the error is surfaced honestly (never a fabricated intent id or receipt).

Vodafone Cash (Egypt) is represented by an interface stub that raises
``PspNotConfiguredError`` until a real merchant integration + credentials are
supplied, it deliberately does not fake a gateway response.

Config (env):
- ``STRIPE_SECRET_KEY``, Stripe secret API key (``sk_live_...`` / ``sk_test_...``)
- ``STRIPE_API_BASE``, override for tests / Stripe-compatible gateways
"""
from __future__ import annotations

import os
import hmac
import hashlib
from typing import Optional

import httpx


class PspError(Exception):
    """Raised when a real PSP call fails (surfaced, never swallowed into a fake OK)."""


class PspNotConfiguredError(PspError):
    """Raised when a PSP is invoked without the required live credentials."""


class StripePspClient:
    """Thin, real Stripe PaymentIntents client (form-encoded REST API)."""

    def __init__(self, secret_key: Optional[str] = None, api_base: Optional[str] = None):
        self.secret_key = secret_key if secret_key is not None else os.getenv("STRIPE_SECRET_KEY", "")
        self.api_base = api_base or os.getenv("STRIPE_API_BASE", "https://api.stripe.com/v1")

    @property
    def enabled(self) -> bool:
        return bool(self.secret_key)

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.secret_key}",
            "Content-Type": "application/x-www-form-urlencoded",
        }

    async def create_payment_intent(self, amount_usd: float, org_id: str,
                                    invoice_id: Optional[str] = None,
                                    idempotency_key: Optional[str] = None) -> dict:
        """Create a real Stripe PaymentIntent. Returns the Stripe object dict."""
        if not self.enabled:
            raise PspNotConfiguredError("Stripe is not configured (STRIPE_SECRET_KEY missing).")
        # Stripe amounts are in the smallest currency unit (USD cents).
        form = {
            "amount": str(int(round(amount_usd * 100))),
            "currency": "usd",
            "automatic_payment_methods[enabled]": "true",
            "metadata[org_id]": org_id,
        }
        if invoice_id:
            form["metadata[invoice_id]"] = invoice_id
        headers = self._headers()
        if idempotency_key:
            headers["Idempotency-Key"] = idempotency_key
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(f"{self.api_base}/payment_intents",
                                     headers=headers, data=form)
        if resp.status_code >= 400:
            raise PspError(f"stripe_create_intent_failed: {resp.status_code} {resp.text}")
        return resp.json()

    async def retrieve_payment_intent(self, intent_id: str) -> dict:
        """Fetch the current, authoritative status of a PaymentIntent from Stripe."""
        if not self.enabled:
            raise PspNotConfiguredError("Stripe is not configured (STRIPE_SECRET_KEY missing).")
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(f"{self.api_base}/payment_intents/{intent_id}",
                                    headers=self._headers())
        if resp.status_code >= 400:
            raise PspError(f"stripe_retrieve_intent_failed: {resp.status_code} {resp.text}")
        return resp.json()


# ── Paymob (Egypt), real Accept API client with Vodafone Cash ───────────────────
class PaymobPspClient:
    """Real Paymob Accept API client (Egypt).

    Supports card payments through the hosted iframe and **Vodafone Cash** through
    Paymob's wallet flow. Every call hits the live Paymob API; if credentials are
    missing the client reports ``enabled = False`` and callers return an honest 501.
    Webhook authenticity is verified with Paymob's HMAC-SHA512 scheme, no fabricated
    transaction is ever accepted.

    Required config (env):
    - ``PAYMOB_API_KEY``, Paymob API key
    - ``PAYMOB_HMAC_SECRET``, webhook HMAC secret
    - ``PAYMOB_WALLET_INTEGRATION_ID``, wallet integration id (Vodafone Cash etc.)
    - ``PAYMOB_VODAFONE_INTEGRATION_ID``, Vodafone Cash-specific integration id
    - ``PAYMOB_IFRAME_ID``, card iframe id
    - ``PAYMOB_CURRENCY``, default ``EGP``
    """

    def __init__(self, api_key: Optional[str] = None, hmac_secret: Optional[str] = None,
                 wallet_integration_id: Optional[str] = None,
                 vodafone_integration_id: Optional[str] = None,
                 iframe_id: Optional[str] = None, base_url: Optional[str] = None,
                 currency: Optional[str] = None):
        self.api_key = api_key if api_key is not None else os.getenv("PAYMOB_API_KEY", "")
        self.hmac_secret = hmac_secret if hmac_secret is not None else os.getenv("PAYMOB_HMAC_SECRET", "")
        self.wallet_integration_id = wallet_integration_id if wallet_integration_id is not None else os.getenv("PAYMOB_WALLET_INTEGRATION_ID", "")
        self.vodafone_integration_id = vodafone_integration_id if vodafone_integration_id is not None else os.getenv("PAYMOB_VODAFONE_INTEGRATION_ID", "")
        self.iframe_id = iframe_id if iframe_id is not None else os.getenv("PAYMOB_IFRAME_ID", "")
        self.base_url = (base_url or os.getenv("PAYMOB_API_BASE", "https://accept.paymob.com")).rstrip("/")
        self.currency = currency or os.getenv("PAYMOB_CURRENCY", "EGP")

    @property
    def enabled(self) -> bool:
        return bool(self.api_key and self.hmac_secret)

    def _headers(self, token: Optional[str] = None) -> dict:
        h = {"Content-Type": "application/json"}
        if token:
            h["Authorization"] = f"Bearer {token}"
        return h

    async def authenticate(self) -> str:
        """Exchange the API key for a short-lived auth token."""
        if not self.api_key:
            raise PspNotConfiguredError("Paymob is not configured (PAYMOB_API_KEY missing).")
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(f"{self.base_url}/api/auth/tokens",
                                     json={"api_key": self.api_key})
        if resp.status_code >= 400:
            raise PspError(f"paymob_auth_failed: {resp.status_code} {resp.text}")
        return resp.json()["token"]

    async def create_payment_key(self, amount: float, order_id: int,
                                 billing_data: dict, integration_id: str,
                                 token: Optional[str] = None) -> str:
        """Create a Paymob payment key (the token the client/iframe/wallet uses)."""
        if token is None:
            token = await self.authenticate()
        amount_cents = int(round(amount * 100))
        payload = {
            "auth_token": token,
            "amount_cents": amount_cents,
            "expiration": 3600,
            "order_id": order_id,
            "billing_data": billing_data,
            "currency": self.currency,
            "integration_id": int(integration_id),
            "lock_order_when_paid": True,
        }
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(f"{self.base_url}/api/acceptance/payment_keys",
                                     json=payload, headers=self._headers(token))
        if resp.status_code >= 400:
            raise PspError(f"paymob_payment_key_failed: {resp.status_code} {resp.text}")
        return resp.json()["token"]

    async def create_order(self, amount: float, items: list, token: Optional[str] = None) -> int:
        """Create a Paymob e-commerce order; returns the Paymob order id."""
        if token is None:
            token = await self.authenticate()
        amount_cents = int(round(amount * 100))
        payload = {
            "auth_token": token,
            "delivery_needed": False,
            "amount_cents": amount_cents,
            "currency": self.currency,
            "items": items or [],
        }
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(f"{self.base_url}/api/ecommerce/orders",
                                     json=payload, headers=self._headers(token))
        if resp.status_code >= 400:
            raise PspError(f"paymob_create_order_failed: {resp.status_code} {resp.text}")
        return int(resp.json()["id"])

    async def initiate_vodafone_cash(self, payment_key: str, phone: str) -> dict:
        """Initiate a Vodafone Cash wallet payment using the payment key.

        Returns the Paymob wallet-pay response (contains the redirect URL the user
        opens in the Vodafone Cash app / SMS flow)."""
        if not self.vodafone_integration_id:
            raise PspNotConfiguredError(
                "Vodafone Cash integration id not configured (PAYMOB_VODAFONE_INTEGRATION_ID).")
        payload = {
            "source": {"identifier": phone, "subtype": "VODAFONE_CASH", "type": "wallet"},
            "payment_token": payment_key,
        }
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(f"{self.base_url}/api/acceptance/payments/pay",
                                     json=payload)
        if resp.status_code >= 400:
            raise PspError(f"paymob_vodafone_cash_failed: {resp.status_code} {resp.text}")
        return resp.json()

    async def retrieve_transaction(self, transaction_id: str) -> dict:
        """Fetch the authoritative transaction state from Paymob."""
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(
                f"{self.base_url}/api/acceptance/transactions/{transaction_id}")
        if resp.status_code >= 400:
            raise PspError(f"paymob_retrieve_txn_failed: {resp.status_code} {resp.text}")
        return resp.json()


def verify_paymob_hmac(payload: dict, hmac_secret: str) -> bool:
    """Verify a Paymob webhook/transaction HMAC (HMAC-SHA512 over the documented
    ordered field concatenation). Returns True only for a genuine Paymob payload."""
    def _str(v) -> str:
        if isinstance(v, bool):
            return "true" if v else "false"
        return "" if v is None else str(v)

    source = payload.get("source_data", {}) or {}
    order = payload.get("order", {}) or {}
    fields = [
        _str(payload.get("amount_cents")),
        _str(payload.get("created_at")),
        _str(payload.get("currency")),
        _str(payload.get("error_occured")),
        _str(order.get("hashed_order")),
        _str(payload.get("id")),
        _str(payload.get("integration_id")),
        _str(payload.get("is_3d_secure")),
        _str(payload.get("is_auth")),
        _str(payload.get("is_capture")),
        _str(payload.get("is_refunded")),
        _str(payload.get("is_standalone_payment")),
        _str(payload.get("is_voided")),
        _str(order.get("id")),
        _str(payload.get("owner")),
        _str(payload.get("payment_key_claims")),
        _str(payload.get("pending")),
        _str(source.get("code")),
        _str(source.get("sub_type")),
        _str(source.get("type")),
        _str(payload.get("status")),
        _str(payload.get("success")),
    ]
    joined = "".join(fields)
    computed = hmac.new(hmac_secret.encode(), joined.encode(), hashlib.sha512).hexdigest()
    return hmac.compare_digest(computed, str(payload.get("hmac", "")))


# Backwards-compatible alias: Vodafone Cash is delivered via the Paymob wallet flow.
VodafoneCashPspClient = PaymobPspClient


def get_psp_client() -> Optional[StripePspClient]:
    """Return a configured Stripe client, or ``None`` when no PSP is set up."""
    client = StripePspClient()
    return client if client.enabled else None


def get_paymob_client() -> Optional[PaymobPspClient]:
    """Return a configured Paymob client, or ``None`` when it is not set up."""
    client = PaymobPspClient()
    return client if client.enabled else None
