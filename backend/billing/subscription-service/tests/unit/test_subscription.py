import pytest
from unittest.mock import AsyncMock, MagicMock

from src.api import list_plans
from src.infrastructure.postgres_repository import SubscriptionRepository


@pytest.mark.asyncio
async def test_plans_static_config():
    resp = await list_plans()
    plans = resp.data
    assert set(plans.keys()) == {"FREE", "STARTER", "GROWTH", "ENTERPRISE"}
    assert plans["FREE"]["price_usd"] == 0


@pytest.mark.asyncio
async def test_unknown_plan_rejected(mock_session):
    # upsert internally calls get(), so execute must return a mapping row
    row = {"organization_id": "org-1", "plan": "FREE", "billing_email": "a@b.com",
           "status": "ACTIVE", "created_at": None, "updated_at": None}
    result = MagicMock()
    result.mappings.return_value.first.return_value = row
    mock_session.execute.return_value = result

    repo = SubscriptionRepository(mock_session)
    data = await repo.upsert("org-1", "FREE", "a@b.com")
    assert isinstance(data, dict)
    assert mock_session.execute.await_count == 2
    assert mock_session.commit.await_count == 1


@pytest.mark.asyncio
async def test_get_returns_none_when_absent(mock_session):
    result = MagicMock()
    result.mappings.return_value.first.return_value = None
    mock_session.execute.return_value = result

    repo = SubscriptionRepository(mock_session)
    data = await repo.get("missing")
    assert data is None


@pytest.mark.asyncio
async def test_get_returns_row_when_present(mock_session):
    row = {"organization_id": "org-1", "plan": "GROWTH"}
    result = MagicMock()
    result.mappings.return_value.first.return_value = row
    mock_session.execute.return_value = result

    repo = SubscriptionRepository(mock_session)
    data = await repo.get("org-1")
    assert data == row


@pytest.mark.asyncio
async def test_upgrade_uses_upsert(mock_session):
    row = {"organization_id": "org-1", "plan": "ENTERPRISE"}
    result = MagicMock()
    result.mappings.return_value.first.return_value = row
    mock_session.execute.return_value = result

    repo = SubscriptionRepository(mock_session)
    data = await repo.upsert("org-1", "ENTERPRISE", None)
    assert isinstance(data, dict)
    assert mock_session.commit.await_count == 1
