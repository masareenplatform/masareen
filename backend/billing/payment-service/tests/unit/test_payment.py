"""Unit tests for PaymentRepository, real logic with a mocked async session."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.infrastructure.postgres_repository import PaymentRepository


@pytest.mark.asyncio
async def test_create_intent_returns_captured_ledger_entry(mock_session):
    repo = PaymentRepository(mock_session)
    mock_session.execute = AsyncMock()
    mock_session.commit = AsyncMock()

    d = await repo.create_intent("inv-1", "org-1", 49.0, "pm-1")

    assert d["status"] == "CAPTURED"
    assert d["organization_id"] == "org-1"
    assert d["amount_usd"] == 49.0
    assert "id" in d
    assert mock_session.commit.await_count == 1


@pytest.mark.asyncio
async def test_get_returns_none_when_absent(mock_session):
    repo = PaymentRepository(mock_session)
    res = MagicMock()
    res.mappings.return_value.first.return_value = None
    mock_session.execute.return_value = res

    assert await repo.get("x") is None


@pytest.mark.asyncio
async def test_get_returns_row(mock_session):
    repo = PaymentRepository(mock_session)
    row = {"id": "p1", "status": "SETTLED", "amount_usd": 10.0}
    res = MagicMock()
    res.mappings.return_value.first.return_value = row
    mock_session.execute.return_value = res

    assert await repo.get("p1") == row


@pytest.mark.asyncio
async def test_confirm_marks_settled(mock_session):
    repo = PaymentRepository(mock_session)
    row = {"id": "p1", "status": "SETTLED"}
    res = MagicMock()
    res.mappings.return_value.first.return_value = row
    mock_session.execute.return_value = res

    result = await repo.confirm("p1")

    assert result["status"] == "SETTLED"
    assert mock_session.commit.await_count == 1


@pytest.mark.asyncio
async def test_history_returns_list(mock_session):
    repo = PaymentRepository(mock_session)
    rows = [{"id": "p1"}, {"id": "p2"}]
    res = MagicMock()
    res.mappings.return_value.all.return_value = rows
    mock_session.execute.return_value = res

    assert await repo.history("org-1", 10) == rows
