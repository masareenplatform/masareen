"""Unit tests for the gateway SecurityGuard, service resolution, and rate limiting."""
from unittest.mock import MagicMock, patch
import pytest
from fastapi import Response

import httpx

from src.main import (
    SecurityGuard,
    resolve_service,
    check_rate_limit,
    _rate_store,
    RATE_LIMIT_MAX_REQUESTS,
    TIER_REQUIREMENTS,
    SELECTOR_CAPABILITIES,
    select_variant_url,
    _selector_cache,
)


def test_sanitize_strips_whitespace():
    assert SecurityGuard.sanitize_input("  hi  ") == "hi"


def test_sanitize_blocks_script():
    with pytest.raises(Exception):
        SecurityGuard.sanitize_input("<script>alert(1)</script>")


def test_sanitize_blocks_drop_table():
    with pytest.raises(Exception):
        SecurityGuard.sanitize_input("DROP TABLE users")


def test_sanitize_blocks_union_select():
    with pytest.raises(Exception):
        SecurityGuard.sanitize_input("1 UNION SELECT pass FROM users")


def test_sanitize_recurses_dict_clean():
    out = SecurityGuard.sanitize_input({"a": " x ", "b": [" y "]})
    assert out == {"a": "x", "b": ["y"]}


def test_sanitize_recurses_dict_malicious_raises():
    with pytest.raises(Exception):
        SecurityGuard.sanitize_input({"a": " x ", "b": "<script>"})


def test_sanitize_recurses_list():
    assert SecurityGuard.sanitize_input([" a ", " b "]) == ["a", "b"]


def test_sanitize_passthrough_non_str():
    assert SecurityGuard.sanitize_input(42) == 42
    assert SecurityGuard.sanitize_input(None) is None


def test_apply_secure_headers():
    r = Response()
    SecurityGuard.apply_secure_headers(r)
    assert r.headers["X-Frame-Options"] == "DENY"
    assert "max-age=31536000" in r.headers["Strict-Transport-Security"]
    assert r.headers["X-Content-Type-Options"] == "nosniff"
    assert r.headers["Referrer-Policy"] == "no-referrer"


def test_resolve_service_maps_prefixes():
    users_url = resolve_service("/api/v1/users/123")
    assert users_url is not None
    assert users_url.startswith("http")
    # /api/v1/users routes to the "identity" service in SERVICE_REGISTRY.
    assert "identity" in str(users_url)
    assert resolve_service("/api/v1/opportunities/x") is not None
    assert resolve_service("/unknown/path") is None


def test_rate_limit_allows_within_limit():
    _rate_store.clear()
    try:
        client = "10.0.0.1"
        for _ in range(RATE_LIMIT_MAX_REQUESTS):
            check_rate_limit(client)
        with pytest.raises(Exception):
            check_rate_limit(client)
    finally:
        _rate_store.clear()


def test_tier_requirements_defined_no_crash():
    # Regression: TIER_REQUIREMENTS must be defined so the protected-path branch
    # in the proxy middleware does not raise NameError at runtime.
    assert isinstance(TIER_REQUIREMENTS, dict)
    assert TIER_REQUIREMENTS.get("/api/v1/reports/paid") is None


def test_selector_capability_mapping():
    assert SELECTOR_CAPABILITIES["/fraud"] == "fraud.score"
    assert SELECTOR_CAPABILITIES["/auth/verify"] == "auth.verify"
    assert SELECTOR_CAPABILITIES["/reputation"] == "reputation.score"


def test_select_variant_url_uses_selector():
    _selector_cache.clear()
    class _Resp:
        status_code = 200

        def json(self):
            return {"url": "http://chosen-variant:8090"}

    fake = MagicMock()
    fake.get.return_value = _Resp()
    fake.__enter__.return_value = fake
    fake.__exit__.return_value = None
    with patch.object(httpx, "Client", return_value=fake):
        url = select_variant_url("/fraud/score")
    assert url == "http://chosen-variant:8090"


def test_select_variant_url_falls_back_on_error():
    _selector_cache.clear()
    fake = MagicMock()
    fake.get.side_effect = httpx.ConnectError("down")
    fake.__enter__.return_value = fake
    fake.__exit__.return_value = None
    with patch.object(httpx, "Client", return_value=fake):
        url = select_variant_url("/fraud/score")
    assert url is None


def test_select_variant_url_no_capability_is_none():
    assert select_variant_url("/api/v1/users/123") is None
