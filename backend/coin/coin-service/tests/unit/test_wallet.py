"""Unit tests for the WalletRepository, real ledger logic with a mocked session."""
from unittest.mock import MagicMock, AsyncMock
import pytest

import src.infrastructure.repository as repo_mod
from src.infrastructure.repository import WalletRepository, InsufficientFundsError


def _row(**kw):
    return kw


@pytest.fixture(autouse=True)
def _patch_revenue(monkeypatch):
    """Default: no brokerage fee, revenue recording is a no-op (stable balances)."""
    monkeypatch.setattr(repo_mod, "get_fee_rate", AsyncMock(return_value=0.0))
    monkeypatch.setattr(repo_mod, "record_revenue", AsyncMock(return_value={"id": "rev"}))


@pytest.mark.asyncio
async def test_transfer_moves_balance_and_logs(mock_session):
    repo = WalletRepository(mock_session)
    debit = MagicMock(); debit.mappings.return_value.first.return_value = _row(balance=40.0)
    credit = MagicMock(); credit.mappings.return_value.first.return_value = _row(balance=160.0)
    # execute order: ensure_wallet, debit, credit, insert OUT, insert IN
    mock_session.execute.side_effect = [MagicMock(), debit, credit, MagicMock(), MagicMock()]
    res = await repo.transfer("a", "b", 60.0, reference="tip")
    assert res["from_balance"] == 40.0
    assert res["to_balance"] == 160.0
    assert res["amount"] == 60.0


@pytest.mark.asyncio
async def test_transfer_insufficient_funds(mock_session):
    repo = WalletRepository(mock_session)
    debit = MagicMock(); debit.mappings.return_value.first.return_value = None
    # execute order: ensure_wallet, debit (returns None -> insufficient)
    mock_session.execute.side_effect = [MagicMock(), debit]
    with pytest.raises(InsufficientFundsError):
        await repo.transfer("a", "b", 999.0)


@pytest.mark.asyncio
async def test_adjust_earn_credits_balance(mock_session):
    repo = WalletRepository(mock_session)
    upd = MagicMock(); upd.mappings.return_value.first.return_value = _row(balance=50.0)
    mock_session.execute.side_effect = [MagicMock(), upd, MagicMock()]
    res = await repo.adjust("a", 50.0, "EARN")
    assert res["balance"] == 50.0
    assert res["type"] == "EARN"


@pytest.mark.asyncio
async def test_adjust_spend_rejects_when_broke(mock_session):
    repo = WalletRepository(mock_session)
    upd = MagicMock(); upd.mappings.return_value.first.return_value = None
    mock_session.execute.side_effect = [MagicMock(), upd]
    with pytest.raises(InsufficientFundsError):
        await repo.adjust("a", -10.0, "SPEND")


@pytest.mark.asyncio
async def test_convert_deposit_credits_mrc(mock_session):
    repo = WalletRepository(mock_session)
    rate_row = MagicMock(); rate_row.mappings.return_value.first.return_value = _row(
        currency="EGP", rate_to_mrc=10.0, updated_at="now")
    upd = MagicMock(); upd.mappings.return_value.first.return_value = _row(balance=100.0)
    mock_session.execute.side_effect = [rate_row, MagicMock(), upd, MagicMock()]
    res = await repo.convert("a", "EGP", 10.0, "deposit")
    assert res["balance"] == 100.0
    assert res["fiat_amount"] == 10.0


@pytest.mark.asyncio
async def test_convert_rejects_unknown_currency(mock_session):
    repo = WalletRepository(mock_session)
    rate_row = MagicMock(); rate_row.mappings.return_value.first.return_value = None
    mock_session.execute.side_effect = [rate_row]
    with pytest.raises(ValueError):
        await repo.convert("a", "USD", 10.0, "deposit")


@pytest.mark.asyncio
async def test_transfer_applies_brokerage_fee(mock_session):
    repo = WalletRepository(mock_session)
    repo_mod.get_fee_rate = AsyncMock(return_value=0.025)  # 2.5%
    rec = AsyncMock(return_value={"id": "rev"})
    repo_mod.record_revenue = rec
    debit = MagicMock(); debit.mappings.return_value.first.return_value = _row(balance=100.0)
    credit = MagicMock(); credit.mappings.return_value.first.return_value = _row(balance=58.5)
    mock_session.execute.side_effect = [MagicMock(), debit, credit, MagicMock(), MagicMock()]
    res = await repo.transfer("a", "b", 60.0)
    assert res["fee"] == 1.5
    assert res["net"] == 58.5
    assert res["to_balance"] == 58.5
    rec.assert_awaited_once()
    assert rec.call_args.args[1:4] == ("transfer", "MRC", 1.5)


@pytest.mark.asyncio
async def test_convert_deposit_routes_fee_to_platform(mock_session):
    repo = WalletRepository(mock_session)
    repo_mod.get_fee_rate = AsyncMock(return_value=0.1)  # 10%
    rec = AsyncMock(return_value={"id": "rev"})
    repo_mod.record_revenue = rec
    rate_row = MagicMock(); rate_row.mappings.return_value.first.return_value = _row(
        currency="EGP", rate_to_mrc=10.0, updated_at="now")
    upd = MagicMock(); upd.mappings.return_value.first.return_value = _row(balance=90.0)
    mock_session.execute.side_effect = [rate_row, MagicMock(), upd, MagicMock()]
    res = await repo.convert("a", "EGP", 10.0, "deposit")  # gross 100 MRC, fee 10
    assert res["gross_mrc"] == 100.0
    assert res["fee_mrc"] == 10.0
    assert res["net_mrc"] == 90.0
    rec.assert_awaited_once()
    assert rec.call_args.args[1:4] == ("coin", "MRC", 10.0)
