"""Thin client to the real payment-service local ledger.

Used by the report-service paid-tier gating. It is intentionally a real HTTP
call (no stubbed Stripe/Adyen). Unit tests inject a fake that returns a
canned intent dict, so no network is touched at test time.
"""
from __future__ import annotations

from typing import Optional

import httpx


class PaymentServiceClient:
    def __init__(self, base_url: str, timeout: float = 10.0) -> None:
        self.base_url = base_url.rstrip("/")

    async def create_intent(self, invoice_id: Optional[str], org_id: str,
                            amount_usd: float, payment_method_id: Optional[str]) -> dict:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            resp = await client.post(
                f"{self.base_url}/payments",
                json={
                    "invoice_id": invoice_id,
                    "organization_id": org_id,
                    "amount_usd": amount_usd,
                    "payment_method_id": payment_method_id,
                },
            )
            resp.raise_for_status()
            return resp.json().get("data", {})
