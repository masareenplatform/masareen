"""Unit tests for the chat LLM client reply flow (langchain mocked)."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.infrastructure.llm_client import ChatLLMClient


def _make_client_with_langchain(ainvoke_return):
    client = ChatLLMClient.__new__(ChatLLMClient)
    fake = MagicMock()
    fake.ainvoke = AsyncMock(return_value=ainvoke_return)
    client._client = fake
    client._available = True
    return client


@pytest.mark.asyncio
async def test_reply_returns_text_from_langchain():
    msg = MagicMock()
    msg.content = "Hello from the model"
    client = _make_client_with_langchain(msg)
    out = await client.reply([{"role": "user", "content": "hi"}], "hello")
    assert out == "Hello from the model"
    # history is forwarded as (role, content) tuples incl. the new prompt
    args, _ = client._client.ainvoke.call_args
    sent = args[0]
    assert sent[-1] == ("user", "hello")
    assert sent[0] == ("user", "hi")


@pytest.mark.asyncio
async def test_reply_handles_content_list():
    msg = MagicMock()
    msg.content = ["part one", "part two"]
    client = _make_client_with_langchain(msg)
    out = await client.reply([], "hey")
    assert out == "part one part two"


@pytest.mark.asyncio
async def test_reply_returns_none_when_unavailable(monkeypatch):
    monkeypatch.setattr("src.infrastructure.llm_client.get_google_api_key", lambda: "")
    client = ChatLLMClient()
    assert client.available is False
    assert await client.reply([{"role": "user", "content": "x"}], "y") is None
