"""Real subscription repository, persists plan selections per organization.

Plan definitions live in the API (static, real config). Creating/upgrading a
subscription writes a real row keyed by organization_id; it does not fabricate
anything.
"""
from __future__ import annotations
from typing import Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class SubscriptionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def upsert(self, org_id: str, plan: str, billing_email: Optional[str]) -> dict:
        await self._session.execute(text("""
            INSERT INTO subscriptions (organization_id, plan, billing_email, status, updated_at)
            VALUES (:org, :plan, :email, 'ACTIVE', NOW())
            ON CONFLICT (organization_id) DO UPDATE
                SET plan = EXCLUDED.plan, billing_email = EXCLUDED.billing_email,
                    status = 'ACTIVE', updated_at = NOW()
        """), {"org": org_id, "plan": plan, "email": billing_email})
        await self._session.commit()
        return await self.get(org_id)

    async def get(self, org_id: str) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT organization_id, plan, billing_email, status, created_at, updated_at
            FROM subscriptions WHERE organization_id = :org
        """), {"org": org_id})).mappings().first()
        return dict(row) if row else None
