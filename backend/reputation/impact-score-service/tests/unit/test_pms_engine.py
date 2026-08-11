"""Unit tests for PMS computation engine."""
import pytest
from src.domain.pms_engine import PMSSnapshot, DEFAULT_WEIGHTS, DIMENSION_KEYS


class TestPMSComputation:
    def test_zero_dimensions_gives_zero_composite(self):
        dims = {k: 0.0 for k in DIMENSION_KEYS}
        snap = PMSSnapshot.compute("u1", dims)
        assert snap.composite_score == 0.0
        assert snap.tier == "BRONZE"

    def test_full_score_gives_one_composite(self):
        dims = {k: 1.0 for k in DIMENSION_KEYS}
        snap = PMSSnapshot.compute("u1", dims)
        assert snap.composite_score == pytest.approx(1.0, abs=0.001)
        assert snap.tier == "PLATINUM"

    def test_tier_thresholds(self):
        cases = [
            (0.00, "BRONZE"), (0.39, "BRONZE"),
            (0.40, "SILVER"), (0.64, "SILVER"),
            (0.65, "GOLD"),   (0.84, "GOLD"),
            (0.85, "PLATINUM"), (1.0, "PLATINUM"),
        ]
        for score, expected_tier in cases:
            dims = {k: score for k in DIMENSION_KEYS}
            snap = PMSSnapshot.compute("u1", dims)
            assert snap.tier == expected_tier, f"score={score} expected {expected_tier} got {snap.tier}"

    def test_custom_weights_applied(self):
        dims = {k: 0.0 for k in DIMENSION_KEYS}
        dims["community_impact"] = 1.0
        custom_w = {k: 0.0 for k in DIMENSION_KEYS}
        custom_w["community_impact"] = 1.0
        snap = PMSSnapshot.compute("u1", dims, weights=custom_w)
        assert snap.composite_score == pytest.approx(1.0, abs=0.001)

    def test_version_increments(self):
        dims = {k: 0.5 for k in DIMENSION_KEYS}
        snap1 = PMSSnapshot.compute("u1", dims, version=0)
        snap2 = PMSSnapshot.compute("u1", dims, version=snap1.version)
        assert snap2.version == snap1.version + 1

    def test_delta_application_clamped(self):
        dims = {k: 0.5 for k in DIMENSION_KEYS}
        snap = PMSSnapshot.compute("u1", dims)
        # Large positive delta — should clamp to 1.0
        new_dims = snap.apply_delta({"reliability": 2.0})
        assert new_dims["reliability"] == pytest.approx(1.0)
        # Large negative delta — should clamp to 0.0
        new_dims2 = snap.apply_delta({"reliability": -2.0})
        assert new_dims2["reliability"] == pytest.approx(0.0)

    def test_delta_only_affects_specified_dimensions(self):
        dims = {k: 0.5 for k in DIMENSION_KEYS}
        snap = PMSSnapshot.compute("u1", dims)
        new_dims = snap.apply_delta({"reliability": 0.05})
        assert new_dims["reliability"] == pytest.approx(0.55)
        assert new_dims["leadership"]  == pytest.approx(0.50)  # unchanged

    def test_to_vector_returns_ordered_list(self):
        dims = {k: float(i) / len(DIMENSION_KEYS) for i, k in enumerate(DIMENSION_KEYS)}
        snap = PMSSnapshot.compute("u1", dims)
        vec  = snap.to_vector()
        assert len(vec) == len(DIMENSION_KEYS)
        assert vec[0] == dims[DIMENSION_KEYS[0]]
