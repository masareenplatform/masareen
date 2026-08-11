"""Unit tests for GPS domain logic."""
import pytest
from src.domain.gps_record import GPSRecord, haversine_km, LOW_ACCURACY_THRESHOLD_M
from shared.exceptions import ValidationException


class TestGPSRecordCapture:
    def test_capture_valid(self):
        rec = GPSRecord.capture("task-1", "user-1", "PHOTO", 1024,
                                latitude=30.0626, longitude=31.2497, accuracy_meters=15.0)
        assert rec.task_id == "task-1"
        assert rec.submitted_by == "user-1"
        assert rec.latitude == pytest.approx(30.0626)
        assert rec.longitude == pytest.approx(31.2497)
        assert rec.accuracy_meters == 15.0
        assert rec.status.value == "CAPTURED"

    def test_capture_emits_location_reached_event(self):
        rec = GPSRecord.capture("task-1", "user-1", "PHOTO", 512,
                                latitude=30.0, longitude=31.0)
        events = rec.pull_domain_events()
        assert any(e.event_type == "LocationReached" for e in events)

    def test_rejects_null_island(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("t1", "u1", "PHOTO", 100,
                              latitude=0.0, longitude=0.0)

    def test_rejects_invalid_latitude(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("t1", "u1", "PHOTO", 100,
                              latitude=95.0, longitude=31.0)

    def test_rejects_invalid_longitude(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("t1", "u1", "PHOTO", 100,
                              latitude=30.0, longitude=200.0)

    def test_rejects_negative_accuracy(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("t1", "u1", "PHOTO", 100,
                              latitude=30.0, longitude=31.0, accuracy_meters=-5.0)

    def test_rejects_empty_task_id(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("", "u1", "PHOTO", 100)

    def test_rejects_empty_submitted_by(self):
        with pytest.raises(ValidationException):
            GPSRecord.capture("t1", "", "PHOTO", 100)

    def test_capture_without_coordinates(self):
        rec = GPSRecord.capture("t1", "u1", "VIDEO", 2048)
        assert rec.latitude is None
        assert rec.longitude is None


class TestGPSRecordLifecycle:
    def test_mark_uploaded(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 500)
        rec.mark_uploaded("https://storage/1", "abc123", "https://thumb/1")
        assert rec.storage_url == "https://storage/1"
        assert rec.checksum == "abc123"
        assert rec.status.value == "VALIDATING"

    def test_submit_for_review_validates_state(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 500)
        rec.mark_uploaded("url", "cs")
        rec.submit_for_review()
        assert rec.status.value == "VALIDATING"

    def test_submit_for_review_wrong_state_raises(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 500)
        with pytest.raises(Exception):
            rec.submit_for_review()

    def test_record_verification_approved(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 500)
        rec.record_verification("AI", "APPROVED", 0.95)
        assert rec.is_approved is True
        assert len(rec.verifications) == 1

    def test_record_verification_rejected(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 500)
        rec.record_verification("HUMAN", "REJECTED", 1.0)
        assert rec.status.value == "REJECTED"

    def test_low_accuracy_detection(self):
        precise = GPSRecord.capture("t1", "u1", "PHOTO", 100, accuracy_meters=20.0)
        imprecise = GPSRecord.capture("t1", "u1", "PHOTO", 100, accuracy_meters=150.0)
        assert precise.is_low_accuracy is False
        assert imprecise.is_low_accuracy is True


class TestGeofence:
    def test_inside_geofence(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 100,
                                latitude=30.0626, longitude=31.2497, accuracy_meters=10.0)
        result = rec.check_geofence(30.0626, 31.2497, radius_m=500)
        assert result.inside is True
        assert result.distance_meters < 1.0

    def test_outside_geofence(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 100,
                                latitude=30.0626, longitude=31.2497, accuracy_meters=10.0)
        result = rec.check_geofence(30.0131, 31.2089, radius_m=500)
        assert result.inside is False
        assert result.distance_meters > 500

    def test_no_coordinates_returns_false(self):
        rec = GPSRecord.capture("t1", "u1", "PHOTO", 100)
        result = rec.check_geofence(30.0, 31.0, radius_m=500)
        assert result.inside is False


class TestHaversine:
    def test_same_point_is_zero(self):
        assert haversine_km(30.0, 31.0, 30.0, 31.0) == pytest.approx(0.0, abs=0.001)

    def test_cairo_to_alex_approx_179km(self):
        dist = haversine_km(30.06, 31.24, 31.20, 29.92)
        assert 175 < dist < 185
