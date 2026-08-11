"""Wallet + coin ledger repository (MASAREEN Coin / MRC).

All balance changes are transactional and append an immutable ledger row, so a
wallet's balance can always be reconstructed from `coin_transactions`. There are
no fabricated balances: insufficient funds is reported honestly, never faked.
"""
from __future__ import annotations
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.revenue import get_fee_rate, record_revenue


class InsufficientFundsError(Exception):
    """Raised when a debit would take a wallet below zero."""


class WalletRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def _ensure_wallet(self, owner_id) -> None:
        await self._session.execute(text("""
            INSERT INTO wallets (owner_id, balance, currency)
            VALUES (:o, 0, 'MRC') ON CONFLICT (owner_id) DO NOTHING
        """), {"o": owner_id})

    async def get_wallet(self, owner_id) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT owner_id, balance, currency, created_at, updated_at
            FROM wallets WHERE owner_id = :o
        """), {"o": owner_id})).mappings().first()
        return dict(row) if row else None

    async def create_wallet(self, owner_id) -> dict:
        await self._session.execute(text("""
            INSERT INTO wallets (owner_id, balance, currency)
            VALUES (:o, 0, 'MRC') ON CONFLICT (owner_id) DO NOTHING
        """), {"o": owner_id})
        await self._session.commit()
        return await self.get_wallet(owner_id)

    async def transfer(self, from_owner, to_owner, amount: float,
                       reference: Optional[str] = None) -> dict:
        if amount <= 0:
            raise ValueError("amount must be positive")
        fee_rate = await get_fee_rate(self._session)
        fee = round(amount * fee_rate, 4)
        net = round(amount - fee, 4)
        await self._ensure_wallet(to_owner)
        res = await self._session.execute(text("""
            UPDATE wallets SET balance = balance - :amt, updated_at = NOW()
            WHERE owner_id = :f AND balance >= :amt
            RETURNING balance
        """), {"amt": amount, "f": from_owner})
        row = res.mappings().first()
        if not row:
            raise InsufficientFundsError(f"owner {from_owner} has insufficient MRC")
        from_balance = float(row["balance"])
        res2 = await self._session.execute(text("""
            UPDATE wallets SET balance = balance + :net, updated_at = NOW()
            WHERE owner_id = :t RETURNING balance
        """), {"net": net, "t": to_owner})
        to_balance = float(res2.mappings().first()["balance"])
        await self._session.execute(text("""
            INSERT INTO coin_transactions (owner_id, counterparty_id, type, amount, balance_after, reference)
            VALUES (:o, :c, 'TRANSFER_OUT', :amt, :ba, :ref)
        """), {"o": from_owner, "c": to_owner, "amt": amount, "ba": from_balance, "ref": reference})
        await self._session.execute(text("""
            INSERT INTO coin_transactions (owner_id, counterparty_id, type, amount, balance_after, reference)
            VALUES (:o, :c, 'TRANSFER_IN', :amt, :ba, :ref)
        """), {"o": to_owner, "c": from_owner, "amt": net, "ba": to_balance, "ref": reference})
        if fee > 0:
            await record_revenue(self._session, "transfer", "MRC", fee,
                                 f"transfer:{from_owner}->{to_owner}")
        await self._session.commit()
        return {"from_owner": from_owner, "to_owner": to_owner, "amount": amount,
                "fee": fee, "net": net,
                "from_balance": from_balance, "to_balance": to_balance,
                "reference": reference}

    async def adjust(self, owner_id, delta: float, txn_type: str,
                     counterparty: Optional[str] = None,
                     reference: Optional[str] = None) -> dict:
        """Apply a signed delta (EARN/DEPOSIT positive, SPEND/WITHDRAW negative).

        Debits are rejected with InsufficientFundsError if the balance is too low;
        the wallet is created on first use."""
        if delta == 0:
            raise ValueError("delta must be non-zero")
        await self._ensure_wallet(owner_id)
        guard = " AND balance >= :need" if delta < 0 else ""
        res = await self._session.execute(text(f"""
            UPDATE wallets SET balance = balance + :d, updated_at = NOW()
            WHERE owner_id = :o{guard}
            RETURNING balance
        """), {"d": delta, "o": owner_id, "need": abs(delta)})
        row = res.mappings().first()
        if not row:
            raise InsufficientFundsError(f"owner {owner_id} has insufficient MRC")
        balance = float(row["balance"])
        await self._session.execute(text("""
            INSERT INTO coin_transactions (owner_id, counterparty_id, type, amount, balance_after, reference)
            VALUES (:o, :c, :t, :amt, :ba, :ref)
        """), {"o": owner_id, "c": counterparty, "t": txn_type,
                "amt": delta, "ba": balance, "ref": reference})
        await self._session.commit()
        return {"owner_id": owner_id, "type": txn_type, "delta": delta,
                "balance": balance, "reference": reference}

    async def history(self, owner_id, limit: int = 50) -> List[dict]:
        rows = (await self._session.execute(text("""
            SELECT id, owner_id, counterparty_id, type, amount, balance_after, reference, created_at
            FROM coin_transactions WHERE owner_id = :o ORDER BY created_at DESC LIMIT :lim
        """), {"o": owner_id, "lim": limit})).mappings().all()
        return [dict(r) for r in rows]

    async def get_rate(self, currency: str) -> Optional[dict]:
        row = (await self._session.execute(text("""
            SELECT currency, rate_to_mrc, updated_at FROM coin_exchange_rates WHERE currency = :c
        """), {"c": currency})).mappings().first()
        return dict(row) if row else None

    async def set_rate(self, currency: str, rate_to_mrc: float) -> dict:
        await self._session.execute(text("""
            INSERT INTO coin_exchange_rates (currency, rate_to_mrc, updated_at)
            VALUES (:c, :r, NOW())
            ON CONFLICT (currency) DO UPDATE SET rate_to_mrc = :r, updated_at = NOW()
        """), {"c": currency, "r": rate_to_mrc})
        await self._session.commit()
        return await self.get_rate(currency)

    async def convert(self, owner_id, currency: str, fiat_amount: float,
                      direction: str) -> dict:
        """Convert between fiat (EGP) and MRC, routing a brokerage cut to the platform.

        - ``deposit``:  owner receives ``(1 - fee) * fiat * rate`` MRC; the fee MRC
                        is recorded as platform revenue.
        - ``withdraw``: owner is debited ``(1 + fee) * fiat * rate`` MRC; the fee MRC
                        is recorded as platform revenue.
        """
        rate = await self.get_rate(currency)
        if not rate:
            raise ValueError(f"no exchange rate configured for {currency}")
        fee_rate = await get_fee_rate(self._session)
        gross_mrc = round(fiat_amount * float(rate["rate_to_mrc"]), 4)
        fee_mrc = round(gross_mrc * fee_rate, 4)
        if direction == "deposit":
            net_mrc = gross_mrc - fee_mrc
            txn_type = "DEPOSIT"
            delta = net_mrc
        else:
            net_mrc = gross_mrc
            txn_type = "WITHDRAW"
            delta = -(gross_mrc + fee_mrc)
        result = await self.adjust(owner_id, delta, txn_type,
                                   counterparty=None,
                                   reference=f"{direction}:{currency}")
        if fee_mrc > 0:
            await record_revenue(self._session, "coin", "MRC", fee_mrc,
                                 f"{direction}:{currency}:{owner_id}")
        result["fiat_amount"] = fiat_amount
        result["currency"] = currency
        result["rate_to_mrc"] = float(rate["rate_to_mrc"])
        result["gross_mrc"] = gross_mrc
        result["fee_rate"] = fee_rate
        result["fee_mrc"] = fee_mrc
        result["net_mrc"] = net_mrc if direction == "deposit" else gross_mrc
        return result
