"""Tests for the Python fraud-score capability (pure logic)."""
from src.domain.scoring import ReferencePoint, ScoreInput, haversine_km, score


def test_haversine_zero_same_point():
    assert haversine_km(30.0444, 31.2357, 30.0444, 31.2357) == 0.0


def test_haversine_cairo_alexandria():
    d = haversine_km(30.0444, 31.2357, 31.2001, 29.9187)
    assert 170 < d < 220


def test_clean_scores_zero():
    r = score(ScoreInput(latitude=30.0, longitude=31.0, accuracy_meters=10.0, checksum="x"))
    assert r.risk_score == 0
    assert r.fraud_type == "NONE"


def test_low_accuracy():
    r = score(ScoreInput(latitude=30.0, longitude=31.0, accuracy_meters=250.0, checksum="x"))
    assert r.risk_score == 30


def test_duplicate_content():
    r = score(ScoreInput(latitude=30.0, longitude=31.0, accuracy_meters=5.0,
                         checksum="dup", known_checksums=["dup"]))
    assert any(c.rule == "DUPLICATE_CONTENT" for c in r.checks)
    assert r.fraud_type == "DUPLICATE_CONTENT"


def test_proximity_reuse():
    r = score(ScoreInput(latitude=30.0444, longitude=31.2357, accuracy_meters=5.0,
                         checksum="x",
                         reference_points=[ReferencePoint(latitude=30.0444, longitude=31.2357)]))
    assert any(c.rule == "PROXIMITY_REUSE" for c in r.checks)


def test_risk_capped():
    r = score(ScoreInput(latitude=0.0, longitude=0.0, accuracy_meters=999.0,
                         checksum="dup", known_checksums=["dup"],
                         reference_points=[ReferencePoint(latitude=0.0, longitude=0.0)]))
    assert r.risk_score <= 100
    assert r.fraud_detected
