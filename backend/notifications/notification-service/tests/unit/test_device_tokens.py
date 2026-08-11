"""Unit tests for notification repository device-token persistence (real, no DB)."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.infrastructure.postgres_repository import NotificationRepository


def _row(d):
    return d


@pytest.mark.asyncio
async def test_register_device_token_persists(mock_session):
    repo = NotificationRepository(mock_session)
    mock_session.commit = AsyncMock()
    out = await repo.register_device_token("user-1", "tok-abc", "ios")
    assert out["user_id"] == "user-1"
    assert out["platform"] == "ios"
    mock_session.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_register_device_token_rejects_empty(mock_session):
    repo = NotificationRepository(mock_session)
    try:
        await repo.register_device_token("user-1", "", "android")
        assert False, "expected ValueError"
    except ValueError:
        pass


@pytest.mark.asyncio
async def test_list_device_tokens_returns_rows(mock_session):
    repo = NotificationRepository(mock_session)
    res = MagicMock()
    res.mappings.return_value.all.return_value = [
        {"id": "t1", "user_id": "user-1", "device_token": "tok", "platform": "android", "created_at": None}
    ]
    mock_session.execute.return_value = res
    out = await repo.list_device_tokens("user-1")
    assert len(out) == 1
    assert out[0]["device_token"] == "tok"
