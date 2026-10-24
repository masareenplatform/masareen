"""Real invoice repository, persists invoices and line items to PostgreSQL.

No fabricated invoice ids: rows are inserted and the generated UUID is returned.
Every endpoint that reads/writes goes through this repository; if the database
is unreachable the caller surfaces an honest 503.
"""
from __future__ import annotations
from datetime import date
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class InvoiceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_invoice(self, organization_id: str, currency: str,
                             period_start: Optional[date], period_end: Optional[date],
                             line_items: List[dict]) -> dict:
        invoice_id = str(uuid4())
        subtotal = round(sum(li["total"] for li in line_items), 2)
        total = subtotal  # tax_rate defaults to 0
        await self._session.execute(text("""
            INSERT INTO invoices (id, organization_id, status, currency, subtotal, tax_amount, total, period_start, period_end)
            VALUES (:id, :org, 'DRAFT', :cur, :sub, 0, :tot, :ps, :pe)
        """), {"id": invoice_id, "org": organization_id, "cur": currency,
               "sub": subtotal, "tot": total, "ps": period_start, "pe": period_end})
        for li in line_items:
            await self._session.execute(text("""
                INSERT INTO invoice_line_items (id, invoice_id, description, quantity, unit_price, total)
                VALUES (:id, :inv, :desc, :qty, :price, :tot)
            """), {"id": str(uuid4()), "inv": invoice_id, "desc": li["description"],
                   "qty": li["quantity"], "price": li["unit_price"], "tot": li["total"]})
        await self._session.commit()
        return {"id": invoice_id, "status": "DRAFT", "subtotal": subtotal,
                "tax_amount": 0.0, "total": total, "currency": currency,
                "line_item_count": len(line_items)}

    async def get_invoice(self, invoice_id: str) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT id, organization_id, status, currency, subtotal, tax_amount, total,
                   due_date, paid_at, period_start, period_end, created_at
            FROM invoices WHERE id = :id
        """), {"id": invoice_id})).mappings().first()
        if not row:
            return None
        items = (await self._session.execute(text("""
            SELECT description, quantity, unit_price, total
            FROM invoice_line_items WHERE invoice_id = :id ORDER BY created_at
        """), {"id": invoice_id})).mappings().all()
        return {**dict(row), "line_items": [dict(i) for i in items]}

    async def set_status(self, invoice_id: str, status: str, due_date: Optional[date] = None) -> bool:
        result = await self._session.execute(text("""
            UPDATE invoices SET status = :st, due_date = COALESCE(:due, due_date), updated_at = NOW()
            WHERE id = :id
        """), {"st": status, "due": due_date, "id": invoice_id})
        await self._session.commit()
        return result.rowcount > 0

    async def list_org_invoices(self, org_id: str, limit: int) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT id, status, currency, total, due_date, created_at
            FROM invoices WHERE organization_id = :org ORDER BY created_at DESC LIMIT :lim
        """), {"org": org_id, "lim": limit})).mappings().all()
        return [dict(r) for r in rows]
