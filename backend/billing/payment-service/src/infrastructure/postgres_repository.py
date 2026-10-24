"""Real payment repository, a local payment ledger backed by PostgreSQL.

Records a payment against an invoice/organization. There is no external PSP in
this build, so a payment is recorded honestly as CAPTURED/SETTLED against the
local ledger (no fabricated Stripe/Adyen intent ids).
"""
from __future__ import annotations
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.revenue import get_fee_rate, record_revenue


class PaymentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_intent(self, invoice_id: Optional[str], org_id: str,
                            amount_usd: float, payment_method_id: Optional[str]) -> dict:
        payment_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO payments (id, invoice_id, organization_id, amount_usd, status, payment_method_id)
            VALUES (:id, :inv, :org, :amt, 'CAPTURED', :pm)
        """), {"id": payment_id, "inv": invoice_id, "org": org_id,
               "amt": amount_usd, "pm": payment_method_id})
        await self._session.commit()
        return {"id": payment_id, "invoice_id": invoice_id, "organization_id": org_id,
                "amount_usd": amount_usd, "status": "CAPTURED",
                "payment_method_id": payment_method_id}

    async def confirm(self, payment_id: str) -> Optional[dict]:
        await self._session.execute(text("""
            UPDATE payments SET status = 'SETTLED', settled_at = NOW() WHERE id = :id
        """), {"id": payment_id})
        await self._session.commit()
        return await self.get(payment_id)

    async def create_external_intent(self, invoice_id: Optional[str], org_id: str,
                                     amount_usd: float, external_ref: str,
                                     status: str = "PENDING") -> dict:
        """Record a payment initiated with an external PSP (e.g. Stripe).

        The PSP's intent id is stored in ``payment_method_id`` as the external
        reference. Status stays PENDING until the PSP reports success, the row
        is never pre-marked as settled (no fabricated receipts).
        """
        payment_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO payments (id, invoice_id, organization_id, amount_usd, status, payment_method_id)
            VALUES (:id, :inv, :org, :amt, :st, :ref)
        """), {"id": payment_id, "inv": invoice_id, "org": org_id,
               "amt": amount_usd, "st": status, "ref": external_ref})
        await self._session.commit()
        return {"id": payment_id, "invoice_id": invoice_id, "organization_id": org_id,
                "amount_usd": amount_usd, "status": status, "external_ref": external_ref}

    async def settle_by_external_ref(self, external_ref: str, status: str) -> Optional[dict]:
        """Update a PSP-backed payment's status from the authoritative PSP state."""
        row = (await self._session.execute(text("""
            SELECT id FROM payments WHERE payment_method_id = :ref
        """), {"ref": external_ref})).mappings().first()
        if not row:
            return None
        settled_clause = ", settled_at = NOW()" if status == "SETTLED" else ""
        await self._session.execute(text(f"""
            UPDATE payments SET status = :st{settled_clause} WHERE payment_method_id = :ref
        """), {"st": status, "ref": external_ref})
        await self._session.commit()
        row = await self.get(row["id"])
        if row and status == "SETTLED":
            await self._record_settlement_fee(row)
        return row

    async def create_paymob_intent(self, order_id: str, org_id: str, amount: float,
                                    currency: str, invoice_id: Optional[str] = None,
                                    phone: Optional[str] = None) -> dict:
        """Record a Paymob-initiated payment (PENDING) keyed by the Paymob order id."""
        payment_id = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO payments (id, invoice_id, organization_id, amount_usd, status,
                                  currency, psp_provider, external_ref, payment_method_id)
            VALUES (:id, :inv, :org, :amt, 'PENDING', :cur, 'paymob', :ref, :ref)
        """), {"id": payment_id, "inv": invoice_id, "org": org_id, "amt": amount,
                "cur": currency, "ref": str(order_id), "phone": phone})
        await self._session.commit()
        return {"id": payment_id, "invoice_id": invoice_id, "organization_id": org_id,
                "amount_usd": amount, "currency": currency, "status": "PENDING",
                "psp_provider": "paymob", "external_ref": str(order_id)}

    async def settle_by_order(self, order_id: str, status: str,
                              txn_id: Optional[str] = None) -> Optional[dict]:
        """Update a Paymob-backed payment from the authoritative Paymob state."""
        settled_clause = ", settled_at = NOW()" if status == "SETTLED" else ""
        await self._session.execute(text(f"""
            UPDATE payments SET status = :st{settled_clause} WHERE external_ref = :ref
        """), {"st": status, "ref": str(order_id)})
        await self._session.commit()
        row = (await self._session.execute(text("""
            SELECT id, invoice_id, organization_id, amount_usd, status, currency,
                   psp_provider, external_ref, created_at, settled_at
            FROM payments WHERE external_ref = :ref
        """), {"ref": str(order_id)})).mappings().first()
        if row and status == "SETTLED":
            await self._record_settlement_fee(row)
        return dict(row) if row else None

    async def _record_settlement_fee(self, row: dict) -> None:
        """Route the brokerage cut of a settled payment to the platform ledger."""
        fee_rate = await get_fee_rate(self._session)
        amount = float(row.get("amount_usd") or 0)
        fee = round(amount * fee_rate, 4)
        if fee > 0:
            currency = row.get("currency") or "EGP"
            await record_revenue(self._session, "payment", currency, fee,
                                 f"{row.get('psp_provider')}:{row.get('external_ref')}")

    async def get(self, payment_id: str) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT id, invoice_id, organization_id, amount_usd, status, payment_method_id, created_at, settled_at
            FROM payments WHERE id = :id
        """), {"id": payment_id})).mappings().first()
        return dict(row) if row else None

    async def history(self, org_id: str, limit: int) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT id, invoice_id, amount_usd, status, created_at
            FROM payments WHERE organization_id = :org ORDER BY created_at DESC LIMIT :lim
        """), {"org": org_id, "lim": limit})).mappings().all()
        return [dict(r) for r in rows]
