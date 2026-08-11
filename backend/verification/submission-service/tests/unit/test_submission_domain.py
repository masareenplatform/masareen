import pytest
from src.domain.submission import SubmissionBundle, EvidenceItem, GpsLocation, BundleStatus
from shared.exceptions import ValidationException, ConflictException


class TestSubmissionBundle:
    def test_create_submission(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
                latitude=25.0,
                longitude=55.0,
            )
        ]
        gps = [
            GpsLocation(latitude=25.0, longitude=55.0, accuracy_meters=10.0, provider="GPS")
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence, gps)
        assert bundle.id is not None
        assert bundle.task_id == "task-1"
        assert bundle.submitted_by == "user-1"
        assert bundle.evidence_items == evidence
        assert bundle.gps_locations == gps
        assert bundle.status == BundleStatus.DRAFT
        assert bundle.created_at is not None
        assert bundle.submitted_at is not None

    def test_validate_bundle(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.validate_bundle()
        assert bundle.status == BundleStatus.VALIDATED
        assert bundle.approval_score is not None
        assert bundle.approval_score > 0

    def test_submit(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.validate_bundle()
        bundle.submit()
        assert bundle.status == BundleStatus.SUBMITTED
        assert bundle.submitted_at is not None

    def test_create_pipeline(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.validate_bundle()
        bundle.submit()
        bundle.create_verification_pipeline()
        assert bundle.status == BundleStatus.PENDING_VERIFICATION

    def test_reject(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        bundle.reject("Insufficient evidence quality")
        assert bundle.status == BundleStatus.REJECTED
        assert bundle.rejection_reason == "Insufficient evidence quality"

    def test_cannot_submit_invalid(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        with pytest.raises(ConflictException, match="Can only submit validated bundles"):
            bundle.submit()

    def test_cannot_validate_empty(self):
        with pytest.raises(ValidationException, match="at least one evidence item is required"):
            SubmissionBundle.create("task-1", "user-1", [])

    def test_domain_events_emitted(self):
        evidence = [
            EvidenceItem(
                evidence_id="ev-1",
                media_type="image/jpeg",
                file_size_bytes=1000,
                checksum="abc123",
                storage_url="http://example.com/img.jpg",
            )
        ]
        bundle = SubmissionBundle.create("task-1", "user-1", evidence)
        events = bundle.pull_domain_events()
        assert len(events) == 1
        assert events[0].event_type == "SubmissionCreated"

        bundle.validate_bundle()
        events = bundle.pull_domain_events()
        assert len(events) == 0

        bundle.submit()
        events = bundle.pull_domain_events()
        assert len(events) == 1
        assert events[0].event_type == "SubmissionSubmitted"

        bundle.create_verification_pipeline()
        events = bundle.pull_domain_events()
        assert len(events) == 1
        assert events[0].event_type == "PipelineCreated"

        bundle2 = SubmissionBundle.create("task-2", "user-1", evidence)
        bundle2.pull_domain_events()
        bundle2.reject("Bad data")
        events = bundle2.pull_domain_events()
        assert len(events) == 1
        assert events[0].event_type == "BundleRejected"
        assert events[0].rejection_reason == "Bad data"
