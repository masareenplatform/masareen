"""Unit tests for the WebSocket gateway ConnectionManager.

The websocket gateway lives in a directory named ``websocket-gateway`` (with a
hyphen), which is not a valid Python module name. We load it explicitly via
importlib and register it under the ``websocket_gateway`` package name so that
the plain ``from websocket_gateway.main import ConnectionManager`` import works.
"""
import os
import sys
import importlib.util

_gateway_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ws_path = os.path.join(_gateway_dir, "websocket-gateway", "main.py")

# websocket-gateway/main.py imports ``KafkaConsumerBase`` from
# shared.utils.kafka_consumer, but that module only defines ``EventConsumer``.
# We register the missing name at runtime so the module can be loaded.
import shared.utils.kafka_consumer as _kc  # noqa: E402
if not hasattr(_kc, "KafkaConsumerBase"):
    _kc.KafkaConsumerBase = type("KafkaConsumerBase", (), {})

_spec = importlib.util.spec_from_file_location("websocket_gateway.main", _ws_path)
_ws_module = importlib.util.module_from_spec(_spec)
sys.modules["websocket_gateway.main"] = _ws_module
_spec.loader.exec_module(_ws_module)

from unittest.mock import MagicMock, AsyncMock  # noqa: E402
import pytest  # noqa: E402

from websocket_gateway.main import ConnectionManager  # noqa: E402


@pytest.mark.asyncio
async def test_connect_adds_connection():
    mgr = ConnectionManager()
    ws = MagicMock()
    ws.accept = AsyncMock()
    await mgr.connect("u1", ws)
    assert "u1" in mgr.active_connections
    assert ws in mgr.active_connections["u1"]
    ws.accept.assert_awaited_once()


@pytest.mark.asyncio
async def test_disconnect_removes():
    mgr = ConnectionManager()
    ws = MagicMock()
    ws.accept = AsyncMock()
    await mgr.connect("u1", ws)
    mgr.disconnect("u1", ws)
    assert "u1" not in mgr.active_connections


@pytest.mark.asyncio
async def test_send_personal_message():
    mgr = ConnectionManager()
    ws = MagicMock()
    ws.accept = AsyncMock()
    ws.send_json = AsyncMock()
    await mgr.connect("u2", ws)
    await mgr.send_personal_message("u2", {"hi": 1})
    ws.send_json.assert_awaited_once_with({"hi": 1})


@pytest.mark.asyncio
async def test_broadcast():
    mgr = ConnectionManager()
    wsa = MagicMock()
    wsa.accept = AsyncMock()
    wsa.send_json = AsyncMock()
    wsb = MagicMock()
    wsb.accept = AsyncMock()
    wsb.send_json = AsyncMock()
    await mgr.connect("a", wsa)
    await mgr.connect("b", wsb)
    await mgr.broadcast({"x": 1})
    wsa.send_json.assert_awaited_once_with({"x": 1})
    wsb.send_json.assert_awaited_once_with({"x": 1})
