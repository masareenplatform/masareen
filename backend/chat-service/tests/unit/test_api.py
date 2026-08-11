"""API-level tests for chat endpoints (session + LLM mocked)."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.main import app
from src.api import _llm
from src.infrastructure.database import get_session


def _client_with(mock_session, llm_available=True, reply="Assistant says hi"):
    from fastapi.testclient import TestClient

    client = TestClient(app)
    app.dependency_overrides[get_session] = lambda: mock_session
    # patch the module-level client singleton
    fake_llm = MagicMock()
    fake_llm.available = llm_available
    fake_llm.reply = AsyncMock(return_value=reply)
    import src.api as api_mod
    api_mod._llm = fake_llm
    return client, fake_llm


@pytest.mark.asyncio
async def test_send_message_persists_user_and_assistant(mock_session):
    # arrange conversation + message persistence rows
    conv = MagicMock(); conv.id = "c1"; conv.user_id = "u1"; conv.title = "t"
    msg = MagicMock(); msg.id = "m1"; msg.role = "user"; msg.content = "hi"
    msg2 = MagicMock(); msg2.id = "m2"; msg2.role = "assistant"; msg2.content = "Assistant says hi"

    def _execute_side_effect(*a, **k):
        res = MagicMock()
        res.scalars.return_value.all.return_value = [conv]
        res.scalars.return_value.first.return_value = conv
        res.mappings.return_value.all.return_value = [msg, msg2]
        res.mappings.return_value.first.return_value = conv
        return res
    mock_session.execute = AsyncMock(side_effect=_execute_side_effect)
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock()
    mock_session.get = AsyncMock(return_value=conv)
    mock_session.commit = AsyncMock()

    client, fake_llm = _client_with(mock_session, reply="Assistant says hi")
    try:
        # create conversation then send
        r = client.post("/api/v1/chat/conversations", json={"user_id": "u1", "title": "t"})
        assert r.status_code == 201, r.text
        cid = r.json()["data"]["id"]
        s = client.post(f"/api/v1/chat/conversations/{cid}/messages",
                        json={"user_id": "u1", "content": "hi"})
        assert s.status_code == 200, s.text
        assert s.json()["data"]["assistant_reply"] == "Assistant says hi"
        fake_llm.reply.assert_awaited_once()
    finally:
        app.dependency_overrides.clear()
        import src.api as api_mod
        api_mod._llm = _llm


@pytest.mark.asyncio
async def test_send_message_honest_when_llm_unavailable(mock_session):
    conv = MagicMock(); conv.id = "c1"; conv.user_id = "u1"; conv.title = "t"

    def _execute_side_effect(*a, **k):
        res = MagicMock()
        res.scalars.return_value.all.return_value = [conv]
        res.scalars.return_value.first.return_value = conv
        res.mappings.return_value.all.return_value = []
        res.mappings.return_value.first.return_value = conv
        return res
    mock_session.execute = AsyncMock(side_effect=_execute_side_effect)
    mock_session.add = MagicMock()
    mock_session.flush = AsyncMock()
    mock_session.get = AsyncMock(return_value=conv)
    mock_session.commit = AsyncMock()

    client, _ = _client_with(mock_session, llm_available=False, reply=None)
    try:
        r = client.post("/api/v1/chat/conversations", json={"user_id": "u1", "title": "t"})
        cid = r.json()["data"]["id"]
        s = client.post(f"/api/v1/chat/conversations/{cid}/messages",
                        json={"user_id": "u1", "content": "hi"})
        assert s.status_code == 200
        # honest 'unavailable' notice rather than a fabricated answer
        assert "unavailable" in s.json()["data"]["assistant_reply"]
    finally:
        app.dependency_overrides.clear()
        import src.api as api_mod
        api_mod._llm = _llm
