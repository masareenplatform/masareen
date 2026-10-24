"""Platform revenue + brokerage fee ledger (shared across MASAREN services).

Every monetisable action (fiat<->coin conversion, peer transfers, PSP payments,
ads) routes a configurable brokerage cut to the platform. The rate lives in
``platform_config`` (tweakable by an admin at runtime) and every collected fee is
appended to ``platform_revenue`` so profit is always auditable and never fabricated.

All functions take the caller's async SQLAlchemy session and run inside its
transaction, there are no standalone balances to desync.
"""
from __future__ import annotations
from typing import Optional
from uuid import uuid4

from sqlalchemy import text

DEFAULT_FEE_RATE = 0.025  # 2.5% brokerage by default
FEE_KEY = "platform_fee_rate"


async def get_fee_rate(session, key: str = FEE_KEY, default: float = DEFAULT_FEE_RATE) -> float:
    """Read the current brokerage rate (0..1). Falls back to the default."""
    row = (await session.execute(text(
        "SELECT value_numeric FROM platform_config WHERE key = :k"), {"k": key})
    ).mappings().first()
    if row is None or row["value_numeric"] is None:
        return default
    return float(row["value_numeric"])


async def set_fee_rate(session, rate: float, key: str = FEE_KEY) -> float:
    """Persist a new brokerage rate (clamped to 0..1). Returns the stored rate."""
    rate = max(0.0, min(1.0, float(rate)))
    await session.execute(text("""
        INSERT INTO platform_config (key, value_numeric, updated_at)
        VALUES (:k, :v, NOW())
        ON CONFLICT (key) DO UPDATE SET value_numeric = :v, updated_at = NOW()
    """), {"k": key, "v": rate})
    await session.commit()
    return rate


async def record_revenue(session, source: str, currency: str, amount: float,
                          reference: Optional[str] = None) -> dict:
    """Append a collected brokerage fee to the platform revenue ledger."""
    rid = str(uuid4())
    await session.execute(text("""
        INSERT INTO platform_revenue (id, source_service, currency, amount, reference)
        VALUES (:id, :s, :c, :a, :r)
    """), {"id": rid, "s": source, "c": currency, "a": amount, "r": reference})
    await session.commit()
    return {"id": rid, "source": source, "currency": currency,
            "amount": amount, "reference": reference}
