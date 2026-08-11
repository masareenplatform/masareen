"""Unit tests for report paid-tier purchase (real billing integration, mocked)."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.infrastructure.postgres_repository import ReportRepository


def _make_api():
    import src.api as api
    return api


@pytest.mark.asyncio
async def test_mark_paid_and_is_paid(mock_session):
    repo = ReportRepository(mock_session)
    mock_session.commit = AsyncMock()
    res = MagicMock()
    res.mappings.return_value.first.return_value = {"is_paid": False}
    mock_session.execute.return_value = res
    assert await repo.is_paid("r1") is False
    # mark paid
    await repo.mark_paid("r1", "pay-1")
    mock_session.commit.assert_awaited_once()
    res.mappings.return_value.first.return_value = {"is_paid": True}
    assert await repo.is_paid("r1") is True


@pytest.mark.asyncio
async def test_purchase_creates_real_intent_and_marks_paid(monkeypatch, mock_session):
    api = _make_api()
    # inject a fake billing client returning a real intent dict
    fake_billing = MagicMock()
    fake_billing.create_intent = AsyncMock(return_value={"id": "pay-xyz"})
    monkeypatch.setattr(api, "_billing", fake_billing)

    repo = ReportRepository(mock_session)

    # get_report returns a real row; is_paid False then True
    res = MagicMock()
    res.mappings.return_value.first.side_effect = [
        {"id": "r1", "status": "READY", "is_paid": False},  # get_report
        {"is_paid": False},  # is_paid (before)
        {"is_paid": True},   # is_paid (after mark_paid, read-back)
    ]
    mock_session.execute.return_value = res

    from fastapi.testclient import TestClient
    from src.main import app
    from src.infrastructure.database import get_session
    app.dependency_overrides[get_session] = lambda: mock_session
    try:
        client = TestClient(app)
        resp = client.post("/api/v1/reports/r1/purchase",
                            json={"organization_id": "org-1", "amount_usd": 4.99})
        assert resp.status_code == 200, resp.text
        body = resp.json()["data"]
        assert body["status"] == "paid"
        assert body["payment_id"] == "pay-xyz"
        fake_billing.create_intent.assert_awaited_once()
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_purchase_503_when_billing_down(monkeypatch, mock_session):
    api = _make_api()
    fake_billing = MagicMock()
    fake_billing.create_intent = AsyncMock(side_effect=RuntimeError("payment-svc down"))
    monkeypatch.setattr(api, "_billing", fake_billing)

    res = MagicMock()
    res.mappings.return_value.first.return_value = {"id": "r1", "status": "READY", "is_paid": False}
    mock_session.execute.return_value = res

    from fastapi.testclient import TestClient
    from src.main import app
    from src.infrastructure.database import get_session
    app.dependency_overrides[get_session] = lambda: mock_session
    try:
        client = TestClient(app)
        resp = client.post("/api/v1/reports/r1/purchase",
                            json={"organization_id": "org-1", "amount_usd": 4.99})
        assert resp.status_code == 503
        assert "billing_unavailable" in resp.json()["detail"]
    finally:
        app.dependency_overrides.clear()
