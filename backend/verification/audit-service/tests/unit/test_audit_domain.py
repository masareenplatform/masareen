import pytest
from datetime import datetime, timezone
from src.domain.audit_record import AuditRecord, AuditEventType
from shared.exceptions import ValidationException


def test_record_event(make_uuid):
    record = AuditRecord.record(
        event_type=AuditEventType.SUBMISSION_CREATED,
        aggregate_type="submission",
        aggregate_id=make_uuid(),
        actor_id=make_uuid(),
        action="CREATE",
        details={"key": "value"},
        source_service="verification-service",
    )
    assert record.event_type == AuditEventType.SUBMISSION_CREATED
    assert record.aggregate_type == "submission"
    assert record.action == "CREATE"
    assert record.details == {"key": "value"}
    assert record.source_service == "verification-service"
    assert record.aggregate_id


def test_to_dict():
    now = datetime.now(timezone.utc)
    record = AuditRecord(
        id="rec-1",
        event_type=AuditEventType.MEDIA_UPLOADED,
        aggregate_type="media",
        aggregate_id="agg-1",
        actor_id="user-1",
        action="UPLOAD",
        details={},
        source_service="media-service",
        created_at=now,
        updated_at=now,
    )
    d = record.to_dict()
    assert d["id"] == "rec-1"
    assert d["event_type"] == "MEDIA_UPLOADED"
    assert d["aggregate_type"] == "media"
    assert d["aggregate_id"] == "agg-1"
    assert d["actor_id"] == "user-1"
    assert d["action"] == "UPLOAD"
    assert d["source_service"] == "media-service"
    assert isinstance(d["created_at"], str)
    datetime.fromisoformat(d["created_at"])


def test_to_dict_includes_metadata():
    record = AuditRecord(
        id="rec-2",
        event_type=AuditEventType.GPS_CAPTURED,
        aggregate_type="gps",
        aggregate_id="agg-2",
        actor_id="user-2",
        action="CAPTURE",
        details={"latitude": 30.06, "longitude": 31.25, "accuracy": 12.0},
        source_service="gps-service",
    )
    d = record.to_dict()
    assert d["details"]["latitude"] == 30.06
    assert d["details"]["longitude"] == 31.25
    assert d["details"]["accuracy"] == 12.0


def test_actor_id_optional():
    record = AuditRecord(
        id="rec-3",
        event_type=AuditEventType.EVIDENCE_CAPTURED,
        aggregate_type="evidence",
        aggregate_id="agg-3",
        action="CAPTURE",
    )
    assert record.actor_id == ""


def test_domain_events():
    record = AuditRecord.record(
        event_type=AuditEventType.PIPELINE_STARTED,
        aggregate_type="pipeline",
        aggregate_id="pipe-1",
        actor_id="system",
        action="START",
    )
    events = record.pull_domain_events()
    assert len(events) >= 1
    assert events[0].event_type == "AuditRecorded"


def test_entity_id_optional():
    record = AuditRecord(
        id="rec-4",
        event_type=AuditEventType.AUDIT_EXPORTED,
        aggregate_type="audit",
        action="EXPORT",
    )
    assert record.aggregate_id == ""
