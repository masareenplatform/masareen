"""Ads repository — campaigns, creatives and a real delivery/spend ledger.

Campaigns are funded in MASAREEN Coin (MRC). Each impression/click deducts the
configured cost from the remaining budget and is never allowed to overspend: when
the budget is exhausted the campaign is auto-paused. Delivery stats are accumulated
per day so spend is auditable.
"""
from __future__ import annotations
from typing import List, Optional

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.revenue import get_fee_rate, record_revenue


class AdsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_campaign(self, owner_id, name: str, budget_coins: float,
                              currency: str, targeting: dict,
                              start_date=None, end_date=None) -> dict:
        from uuid import uuid4
        # Brokerage: the platform takes a cut of the funded budget. The advertiser's
        # deliverable budget is the gross minus the fee; the fee is recorded as
        # auditable platform revenue (source = 'ads').
        fee_rate = await get_fee_rate(self._session)
        fee = round(float(budget_coins) * fee_rate, 4)
        deliverable = round(float(budget_coins) - fee, 4)
        cid = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO ad_campaigns (id, owner_id, name, status, budget_coins, spent_coins,
                                      currency, targeting, start_date, end_date,
                                      platform_fee_coins)
            VALUES (:id, :o, :n, 'DRAFT', :b, 0, :c, :t, :sd, :ed, :f)
        """), {"id": cid, "o": owner_id, "n": name, "b": deliverable, "c": currency,
                "t": targeting, "sd": start_date, "ed": end_date, "f": fee})
        if fee > 0:
            await record_revenue(self._session, "ads", "MRC", fee,
                                 f"campaign:{cid}:{owner_id}")
        await self._session.commit()
        return await self.get_campaign(cid)

    async def get_campaign(self, campaign_id) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT id, owner_id, name, status, budget_coins, spent_coins, currency,
                   targeting, start_date, end_date, created_at, updated_at
            FROM ad_campaigns WHERE id = :id
        """), {"id": campaign_id})).mappings().first()
        return dict(row) if row else None

    async def list_campaigns(self, owner_id=None, status: Optional[str] = None) -> List[dict]:
        sql = "SELECT id, owner_id, name, status, budget_coins, spent_coins, currency, created_at FROM ad_campaigns WHERE 1=1"
        params = {}
        if owner_id:
            sql += " AND owner_id = :o"; params["o"] = owner_id
        if status:
            sql += " AND status = :s"; params["s"] = status
        sql += " ORDER BY created_at DESC"
        rows = (await self._session.execute(text(sql), params)).mappings().all()
        return [dict(r) for r in rows]

    async def set_status(self, campaign_id, status: str) -> Optional[dict]:
        await self._session.execute(text("""
            UPDATE ad_campaigns SET status = :s, updated_at = NOW() WHERE id = :id
        """), {"s": status, "id": campaign_id})
        await self._session.commit()
        return await self.get_campaign(campaign_id)

    async def add_creative(self, campaign_id, title: str, body: str,
                           media_url: Optional[str], cta_url: Optional[str]) -> dict:
        from uuid import uuid4
        cid = str(uuid4())
        await self._session.execute(text("""
            INSERT INTO ad_creatives (id, campaign_id, title, body, media_url, cta_url)
            VALUES (:id, :c, :t, :b, :m, :u)
        """), {"id": cid, "c": campaign_id, "t": title, "b": body,
                "m": media_url, "u": cta_url})
        await self._session.commit()
        row = (await self._session.execute(text("""
            SELECT id, campaign_id, title, body, media_url, cta_url, created_at
            FROM ad_creatives WHERE id = :id
        """), {"id": cid})).mappings().first()
        return dict(row)

    async def record_event(self, campaign_id, event_type: str) -> dict:
        """Record an impression/click, charging the campaign's MRC budget.

        Never overspends: when the remaining budget can't cover the event cost the
        campaign is auto-paused and the event is still recorded (spend capped at the
        remaining budget). Returns the live stats."""
        from config.settings import settings
        cost = settings.ad_impression_cost_mrc if event_type == "impression" else settings.ad_click_cost_mrc
        camp = await self.get_campaign(campaign_id)
        if not camp:
            return None
        budget = float(camp["budget_coins"])
        spent = float(camp["spent_coins"])
        remaining = budget - spent
        if remaining <= 0:
            await self.set_status(campaign_id, "PAUSED")
            return await self.stats(campaign_id)
        charged = min(cost, remaining)
        new_spent = spent + charged
        new_status = camp["status"]
        if new_spent >= budget:
            new_status = "PAUSED"
        await self._session.execute(text("""
            UPDATE ad_campaigns SET spent_coins = :sp, status = :st, updated_at = NOW()
            WHERE id = :id
        """), {"sp": new_spent, "st": new_status, "id": campaign_id})
        col = "impressions" if event_type == "impression" else "clicks"
        await self._session.execute(text(f"""
            INSERT INTO ad_delivery (campaign_id, date, impressions, clicks, spent_coins)
            VALUES (:id, CURRENT_DATE, :inc, :clc, :sp)
            ON CONFLICT (campaign_id, date) DO UPDATE
            SET impressions = ad_delivery.impressions + :inc,
                clicks = ad_delivery.clicks + :clc,
                spent_coins = ad_delivery.spent_coins + :sp
        """), {"id": campaign_id, "inc": 1 if event_type == "impression" else 0,
                "clc": 1 if event_type == "click" else 0, "sp": charged})
        await self._session.commit()
        return await self.stats(campaign_id)

    async def stats(self, campaign_id) -> dict:
        camp = await self.get_campaign(campaign_id)
        rows = (await self._session.execute(text("""
            SELECT COALESCE(SUM(impressions),0) AS impressions,
                   COALESCE(SUM(clicks),0) AS clicks,
                   COALESCE(SUM(spent_coins),0) AS spent_coins
            FROM ad_delivery WHERE campaign_id = :id
        """), {"id": campaign_id})).mappings().first()
        return {
            "campaign_id": campaign_id,
            "budget_coins": float(camp["budget_coins"]) if camp else 0,
            "status": camp["status"] if camp else None,
            "impressions": int(rows["impressions"]),
            "clicks": int(rows["clicks"]),
            "spent_coins": float(rows["spent_coins"]),
        }
