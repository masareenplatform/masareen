"""Tests for the Python reputation.score capability (pure logic)."""
from src.domain.pms import DIMENSION_KEYS, compute


def test_nonzero():
    dims = {k: v for k, v in zip(DIMENSION_KEYS, [0.9, 0.8, 0.7, 0.6, 0.85, 0.5, 0.75, 0.4, 0.8, 0.6])}
    s = compute("u1", dims)
    assert s.composite_score > 0
    assert s.version == 1


def test_deterministic():
    dims = {k: v for k, v in zip(DIMENSION_KEYS, [0.9] * 10)}
    assert compute("u", dims).composite_score == compute("u", dims).composite_score


def test_tiers():
    zeros = {k: 0.0 for k in DIMENSION_KEYS}
    ones = {k: 1.0 for k in DIMENSION_KEYS}
    assert compute("u", zeros).tier == "BRONZE"
    assert compute("u", ones).tier == "PLATINUM"


def test_clamp():
    s = compute("u", {"reliability": 5.0, "execution_quality": -2.0})
    assert s.dimensions["reliability"] == 1.0
    assert s.dimensions["execution_quality"] == 0.0


def test_weighted_average():
    dims = {"reliability": 1.0, "execution_quality": 1.0}
    s = compute("u", dims)
    assert abs(s.composite_score - 1.0) < 1e-9
