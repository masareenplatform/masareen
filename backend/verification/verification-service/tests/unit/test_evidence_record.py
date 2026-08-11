import pytest
from src.domain.evidence_record import EvidenceRecord, EvidenceStatus, FinalVerdict
from shared.events.verification_events import EvidenceCaptured, EvidenceVerified


class TestEvidenceRecord:
    def test_capture(self):
        record = EvidenceRecord.capture(
            task_id="task-1",
            submitted_by="user-1",
            media_type="PHOTO",
            file_size_bytes=1024,
            latitude=30.0626,
            longitude=31.2497,
        )
        assert record.task_id == "task-1"
        assert record.submitted_by == "user-1"
        assert record.media_type == "PHOTO"
        assert record.file_size_bytes == 1024
        assert record.status == EvidenceStatus.CAPTURED
        assert record.latitude == 30.0626
        assert record.longitude == 31.2497
        assert record.evidence_id is not None
        assert record.captured_at is not None

    def test_mark_uploaded(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.mark_uploaded(
            storage_url="https://storage/evidence/1",
            checksum="abc123def",
            thumbnail_url="https://storage/thumbs/1",
        )
        assert record.storage_url == "https://storage/evidence/1"
        assert record.checksum == "abc123def"
        assert record.thumbnail_url == "https://storage/thumbs/1"
        assert record.status == EvidenceStatus.UPLOADED
        assert record.uploaded_at is not None

    def test_record_human_verdict_approved(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.record_human_verdict(
            verdict="APPROVED",
            reviewer_id="reviewer-1",
            confidence=0.95,
            notes="Evidence verified successfully",
        )
        assert record.final_verdict == FinalVerdict.APPROVED
        assert record.status == EvidenceStatus.APPROVED
        assert record.confidence_score == 0.95
        assert record.notes == "Evidence verified successfully"
        assert record.verifier_type == "HUMAN"
        assert record.verified_at is not None

    def test_record_human_verdict_rejected(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.record_human_verdict(
            verdict="REJECTED",
            reviewer_id="reviewer-1",
            confidence=0.80,
        )
        assert record.final_verdict == FinalVerdict.REJECTED
        assert record.status == EvidenceStatus.REJECTED
        assert record.verifier_type == "HUMAN"

    def test_assign_reviewer(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        record.assign_reviewer("reviewer-42")
        assert record.assigned_reviewer == "reviewer-42"

    def test_domain_events_emitted(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        events = record.pull_domain_events()
        assert len(events) == 1
        assert isinstance(events[0], EvidenceCaptured)

        record.record_human_verdict("APPROVED", "reviewer-1", 0.95)
        events = record.pull_domain_events()
        assert len(events) == 1
        assert isinstance(events[0], EvidenceVerified)

    def test_status_transitions(self):
        record = EvidenceRecord.capture("task-1", "user-1", "PHOTO", 1024)
        assert record.status == EvidenceStatus.CAPTURED

        record.mark_uploaded("https://storage/1", "checksum")
        assert record.status == EvidenceStatus.UPLOADED

        record.start_human_review()
        assert record.status == EvidenceStatus.UNDER_REVIEW

        record.record_human_verdict("APPROVED", "reviewer-1", 0.95)
        assert record.status == EvidenceStatus.APPROVED
