"""Unit tests for fraud-service pure logic — no Kafka, no LLM, no I/O."""
import hashlib

from src.agents import haversine_km, compute_image_hash


class TestHaversine:
    def test_zero_distance_for_same_point(self):
        assert haversine_km(30.0444, 31.2357, 30.0444, 31.2357) == 0.0

    def test_cairo_to_alexandria_approx_180km(self):
        # Cairo (30.0444, 31.2357) -> Alexandria (31.2001, 29.9187)
        d = haversine_km(30.0444, 31.2357, 31.2001, 29.9187)
        assert 170 < d < 220  # real great-circle distance ~183 km

    def test_symmetry(self):
        a = haversine_km(0, 0, 10, 10)
        b = haversine_km(10, 10, 0, 0)
        assert round(a, 6) == round(b, 6)


class TestImageHash:
    def test_hash_is_sha256_hex(self):
        data = b"evidence-bytes"
        assert compute_image_hash(data) == hashlib.sha256(data).hexdigest()

    def test_hash_is_deterministic(self):
        assert compute_image_hash(b"x") == compute_image_hash(b"x")

    def test_different_bytes_differ(self):
        assert compute_image_hash(b"a") != compute_image_hash(b"b")
