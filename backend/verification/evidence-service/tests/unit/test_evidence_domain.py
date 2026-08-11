"""Unit tests for Evidence aggregate lifecycle."""
import pytest
from src.domain.evidence import Evidence, EvidenceStatus, MediaType
from shared.exceptions import ValidationException, ConflictException


def make_evidence(**kwargs) -> Evidence:
    defaults = dict(task_id="task-1", submitted_by="user-1",
                    media_type="PHOTO", file_size_bytes=2_000_000)
    return Evidence.capture(**{**defaults, **kwargs})


class TestEvidenceCapture:
    def test_capture_creates_with_captured_status(self):
        ev = make_evidence()
        assert ev.status == EvidenceStatus.CAPTURED
        assert ev.media_type == MediaType.PHOTO

    def test_capture_emits_evidence_captured_event(self):
        ev = make_evidence()
        events = ev.pull_domain_events()
        assert any(e.event_type == "EvidenceCaptured" for e in events)

    def test_capture_rejects_missing_task_id(self):
        with pytest.raises(ValidationException):
            make_evidence(task_id="")

    def test_capture_rejects_missing_submitted_by(self):
        with pytest.raises(ValidationException):
            make_evidence(submitted_by="")

    def test_capture_stores_geolocation(self):
        ev = make_evidence(latitude=30.0626, longitude=31.2497)
        assert ev.latitude == pytest.approx(30.0626)
        assert ev.longitude == pytest.approx(31.2497)


class TestEvidenceUpload:
    def test_mark_uploaded_sets_storage_url_and_checksum(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev-1.jpg", "sha256abc", "https://cdn.masaren.io/ev-1-thumb.jpg")
        assert ev.storage_url == "https://cdn.masaren.io/ev-1.jpg"
        assert ev.checksum    == "sha256abc"
        assert ev.thumbnail_url is not None
        assert ev.status == EvidenceStatus.UPLOADED

    def test_mark_uploaded_emits_evidence_uploaded_event(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev.jpg", "hash123")
        events = ev.pull_domain_events()
        assert any(e.event_type == "EvidenceUploaded" for e in events)

    def test_mark_uploaded_rejects_empty_url(self):
        ev = make_evidence()
        with pytest.raises(ValidationException):
            ev.mark_uploaded("", "hash123")

    def test_submit_for_review_requires_uploaded_status(self):
        ev = make_evidence()  # still CAPTURED
        with pytest.raises(ConflictException):
            ev.submit_for_review()


class TestEvidenceVerification:
    def test_approved_verdict_sets_approved_status(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev.jpg", "hash")
        ev.submit_for_review()
        ev.record_verification("AI", "APPROVED", 0.94)
        assert ev.status == EvidenceStatus.APPROVED
        assert ev.is_approved is True

    def test_rejected_verdict_sets_rejected_status(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev.jpg", "hash")
        ev.submit_for_review()
        ev.record_verification("AI", "REJECTED", 0.88, notes="GPS spoofing detected")
        assert ev.status == EvidenceStatus.REJECTED
        assert ev.is_approved is False

    def test_verification_emits_evidence_verified_event(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev.jpg", "hash")
        ev.submit_for_review()
        ev.record_verification("HUMAN", "APPROVED", 1.0)
        events = ev.pull_domain_events()
        assert any(e.event_type == "EvidenceVerified" for e in events)

    def test_multiple_verification_records_stored(self):
        ev = make_evidence()
        ev.mark_uploaded("https://cdn.masaren.io/ev.jpg", "hash")
        ev.submit_for_review()
        ev.record_verification("AI",    "NEEDS_REVISION", 0.55)
        ev.record_verification("HUMAN", "APPROVED",       1.0)
        assert len(ev.verifications) == 2
        assert ev.latest_verdict == "APPROVED"
        assert ev.status == EvidenceStatus.APPROVED
