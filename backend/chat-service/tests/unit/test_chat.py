"""Unit tests for the chat service repository and API.

The service persists conversations/messages in PostgreSQL, so we inject a mocked
async session (no database). The LLM client is mocked so assistant replies are
deterministic and we can also assert the honest "unavailable" path.
"""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.infrastructure.chat_repository import ChatRepository
from src.infrastructure.llm_client import ChatLLMClient


def _result(values):
    res = MagicMock()
    res.scalars.return_value.all.return_value = values
    return res


@pytest.mark.asyncio
async def test_create_conversation_persists(mock_session):
    repo = ChatRepository(mock_session)
    mock_session.flush = AsyncMock()
    conv = await repo.create_conversation("user-1", "My chat")
    assert conv.user_id == "user-1"
    assert conv.title == "My chat"
    mock_session.add.assert_called_once()
    mock_session.flush.assert_awaited_once()


@pytest.mark.asyncio
async def test_list_conversations_returns_rows(mock_session):
    repo = ChatRepository(mock_session)
    c1 = MagicMock(); c1.id = "c1"; c1.user_id = "user-1"; c1.title = "A"
    c2 = MagicMock(); c2.id = "c2"; c2.user_id = "user-1"; c2.title = "B"
    mock_session.execute.return_value = _result([c1, c2])
    out = await repo.list_conversations("user-1")
    assert len(out) == 2
    assert out[0].id == "c1"


@pytest.mark.asyncio
async def test_add_message_persists(mock_session):
    repo = ChatRepository(mock_session)
    msg = await repo.add_message("c1", "user", "hello")
    assert msg.role == "user"
    assert msg.content == "hello"
    mock_session.add.assert_called_once()


@pytest.mark.asyncio
async def test_get_messages_returns_history(mock_session):
    repo = ChatRepository(mock_session)
    m1 = MagicMock(); m1.id = "m1"; m1.role = "user"; m1.content = "hi"
    m2 = MagicMock(); m2.id = "m2"; m2.role = "assistant"; m2.content = "yo"
    mock_session.execute.return_value = _result([m1, m2])
    out = await repo.get_messages("c1")
    assert [m.role for m in out] == ["user", "assistant"]


def test_llm_client_unavailable_without_key(monkeypatch):
    monkeypatch.setattr("src.infrastructure.llm_client.get_google_api_key", lambda: "")
    client = ChatLLMClient()
    assert client.available is False


@pytest.mark.asyncio
async def test_llm_reply_none_when_unavailable(monkeypatch):
    monkeypatch.setattr("src.infrastructure.llm_client.get_google_api_key", lambda: "")
    client = ChatLLMClient()
    out = await client.reply([{"role": "user", "content": "hi"}], "hello")
    assert out is None
