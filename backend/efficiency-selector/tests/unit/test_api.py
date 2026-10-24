"""API + registry integration tests for the EfficiencySelector.

External HTTP (variant /bench, /health) is mocked because it is, by design, a
call to a separate service, the selection logic itself is fully real and tested.
"""
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from src.app import app, registry
from src.infrastructure.registry import Registry


@pytest.fixture
def client(tmp_path, monkeypatch):
    # Use an isolated store so tests don't clobber real state.
    reg = Registry(str(tmp_path / "state.json"))
    monkeypatch.setattr("src.app.registry", reg)
    with TestClient(app) as c:
        yield c


def test_register_and_route(client):
    r = client.post("/selector/register", json={
        "capability": "fraud.score",
        "language": "python",
        "version": "1",
        "health_url": "http://py/fraud/health",
        "bench_url": "http://py/fraud/bench",
        "business_url": "http://py/fraud",
    })
    assert r.status_code == 200, r.text
    # unmeasured -> route to the python baseline
    route = client.get("/selector/route/fraud.score")
    assert route.status_code == 200
    assert route.json()["language"] == "python"
    assert route.json()["url"] == "http://py/fraud"


def test_policy_set_and_explicit(client):
    client.post("/selector/register", json={
        "capability": "fraud.score", "language": "python", "version": "1",
        "health_url": "h", "bench_url": "b", "business_url": "u"})
    client.post("/selector/register", json={
        "capability": "fraud.score", "language": "rust", "version": "1",
        "health_url": "h", "bench_url": "b", "business_url": "u"})
    r = client.post("/selector/capabilities/fraud.score/policy",
                    json={"policy": "explicit", "pinned": "fraud.score/rust/1"})
    assert r.status_code == 200
    route = client.get("/selector/route/fraud.score")
    assert route.json()["language"] == "rust"


def test_bench_uses_real_variant_response(client):
    client.post("/selector/register", json={
        "capability": "fraud.score", "language": "rust", "version": "1",
        "health_url": "http://rust/fraud/health",
        "bench_url": "http://rust/fraud/bench",
        "business_url": "http://rust/fraud"})

    class _Resp:
        status_code = 200
        def json(self):
            return {"p50_ms": 1.5, "throughput_rps": 1200, "samples": 50}

    with patch("httpx.AsyncClient.get", new=AsyncMock(return_value=_Resp())):
        r = client.post("/selector/capabilities/fraud.score/bench")
    assert r.status_code == 200, r.text
    assert r.json()["results"][0]["measured"] is True

    # now latency policy should pick rust (measured, low p50)
    client.post("/selector/capabilities/fraud.score/policy", json={"policy": "latency"})
    route = client.get("/selector/route/fraud.score")
    assert route.json()["language"] == "rust"


def test_route_no_healthy_503(client):
    # register then mark unhealthy
    client.post("/selector/register", json={
        "capability": "x.y", "language": "python", "version": "1",
        "health_url": "http://py/x/health",
        "bench_url": "http://py/x/bench",
        "business_url": "http://py/x"})

    class _Unhealthy:
        status_code = 500
    with patch("httpx.AsyncClient.get", new=AsyncMock(return_value=_Unhealthy())):
        client.post("/selector/capabilities/x.y/health")
    route = client.get("/selector/route/x.y")
    assert route.status_code == 503


def test_unknown_language_rejected(client):
    r = client.post("/selector/register", json={
        "capability": "c", "language": "cobol", "version": "1",
        "health_url": "h", "bench_url": "b", "business_url": "u"})
    assert r.status_code == 400
