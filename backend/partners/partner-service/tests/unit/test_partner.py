"""Unit tests for the collaboration / partner-hosting workflow."""
import pytest
from unittest.mock import AsyncMock, MagicMock

from src.api import router
from src.infrastructure.repository import CollaborationRepository


def _result(row):
    """Build an async-execute result mock whose .mappings().first() -> row."""
    res = MagicMock()
    res.mappings.return_value.first.return_value = row
    return res


@pytest.mark.asyncio
async def test_submit_then_review_then_provision(mock_session):
    repo = CollaborationRepository(mock_session)
    results = [
        _result({"id": "c1", "status": "SUBMITTED", "company_name": "Acme"}),
        _result({"id": "c1", "status": "APPROVED"}),
        _result({"id": "c1", "status": "PROVISIONED"}),
    ]
    mock_session.execute = AsyncMock(side_effect=results)

    out = await repo.create({"company_name": "Acme"})
    assert out["status"] == "SUBMITTED"

    out = await repo.review("c1", "APPROVED", "admin-1", "Looks good")
    assert out["status"] == "APPROVED"

    out = await repo.provision("c1", "ops-1", "https://acme.masaren.io")
    assert out["status"] == "PROVISIONED"


@pytest.mark.asyncio
async def test_review_only_from_submitted(mock_session):
    repo = CollaborationRepository(mock_session)
    mock_session.execute = AsyncMock(return_value=_result(None))
    out = await repo.review("c1", "APPROVED", "admin-1", None)
    assert out is None


@pytest.mark.asyncio
async def test_provision_only_from_approved(mock_session):
    repo = CollaborationRepository(mock_session)
    mock_session.execute = AsyncMock(return_value=_result(None))
    out = await repo.provision("c1", "ops-1", None)
    assert out is None


def test_router_registered():
    paths = {r.path for r in router.routes}
    assert "/partners/" in paths
    assert "/partners/{collab_id}/review" in paths
    assert "/partners/{collab_id}/provision" in paths
