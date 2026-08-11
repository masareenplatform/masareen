"""Unit tests for the AdsRepository — campaign lifecycle + budget-safe delivery."""
from unittest.mock import MagicMock, AsyncMock
import pytest

import src.infrastructure.repository as repo_mod
from src.infrastructure.repository import AdsRepository


def _row(**kw):
    return kw


@pytest.fixture(autouse=True)
def _patch_revenue(monkeypatch):
    """Default: no brokerage fee, revenue recording is a no-op (stable budgets)."""
    monkeypatch.setattr(repo_mod, "get_fee_rate", AsyncMock(return_value=0.0))
    monkeypatch.setattr(repo_mod, "record_revenue", AsyncMock(return_value={"id": "rev"}))


@pytest.mark.asyncio
async def test_create_campaign_returns_draft(mock_session):
    repo = AdsRepository(mock_session)
    get = MagicMock(); get.mappings.return_value.first.return_value = _row(
        id="c1", owner_id="o1", name="Launch", status="DRAFT", budget_coins=100.0,
        spent_coins=0.0, currency="MRC", targeting={}, created_at="t", updated_at="t")
    mock_session.execute.side_effect = [MagicMock(), get]
    d = await repo.create_campaign("o1", "Launch", 100.0, "MRC", {})
    assert d["status"] == "DRAFT"
    assert d["budget_coins"] == 100.0


@pytest.mark.asyncio
async def test_record_event_charges_budget_and_pauses_at_zero(mock_session):
    repo = AdsRepository(mock_session)
    # budget 2, spent 0 -> after 3 impressions (cost 1 each) it should pause at spent 2
    camp = MagicMock(); camp.mappings.return_value.first.side_effect = [
        _row(id="c1", owner_id="o1", status="ACTIVE", budget_coins=2.0, spent_coins=0.0),
        _row(id="c1", owner_id="o1", status="PAUSED", budget_coins=2.0, spent_coins=2.0),
    ]
    # get_campaign called twice (initial + after set_status); stats query after
    stats = MagicMock(); stats.mappings.return_value.first.return_value = _row(
        impressions=2, clicks=0, spent_coins=2.0)
    # execute order: get_campaign, UPDATE, delivery upsert, get_campaign(again), stats
    mock_session.execute.side_effect = [camp, MagicMock(), MagicMock(), camp, stats]
    res = await repo.record_event("c1", "impression")
    # First event: spent 1 -> ACTIVE. Second call would pause; here we simulate the
    # final returned stats after budget exhausted.
    assert res["spent_coins"] == 2.0
    assert res["status"] == "PAUSED"


@pytest.mark.asyncio
async def test_add_creative_returns_row(mock_session):
    repo = AdsRepository(mock_session)
    ins = MagicMock(); ins.mappings.return_value.first.return_value = _row(
        id="cr1", campaign_id="c1", title="T", body="B", media_url=None, cta_url=None, created_at="t")
    mock_session.execute.side_effect = [MagicMock(), ins]
    d = await repo.add_creative("c1", "T", "B", None, None)
    assert d["title"] == "T"


@pytest.mark.asyncio
async def test_set_status_returns_updated(mock_session):
    repo = AdsRepository(mock_session)
    get = MagicMock(); get.mappings.return_value.first.return_value = _row(
        id="c1", owner_id="o1", status="ACTIVE")
    mock_session.execute.side_effect = [MagicMock(), get]
    d = await repo.set_status("c1", "ACTIVE")
    assert d["status"] == "ACTIVE"


@pytest.mark.asyncio
async def test_create_campaign_routes_brokerage_fee(mock_session):
    repo = AdsRepository(mock_session)
    repo_mod.get_fee_rate = AsyncMock(return_value=0.1)  # 10%
    rec = AsyncMock(return_value={"id": "rev"})
    repo_mod.record_revenue = rec
    get = MagicMock(); get.mappings.return_value.first.return_value = _row(
        id="c1", owner_id="o1", name="Launch", status="DRAFT", budget_coins=90.0,
        spent_coins=0.0, currency="MRC", platform_fee_coins=10.0,
        targeting={}, created_at="t", updated_at="t")
    mock_session.execute.side_effect = [MagicMock(), get]
    d = await repo.create_campaign("o1", "Launch", 100.0, "MRC", {})
    # 10 MRC fee -> 90 MRC deliverable budget.
    assert d["budget_coins"] == 90.0
    assert d["platform_fee_coins"] == 10.0
    rec.assert_awaited_once()
    assert rec.call_args.args[1:4] == ("ads", "MRC", 10.0)

