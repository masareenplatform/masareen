"""Audit domain aggregate — append-only immutable audit trail."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from dataclasses import dataclass
from shared.base_entity import AggregateRoot
from shared.events import DomainEvent
from shared.exceptions import ValidationException


@dataclass
class AuditRecordedEvent(DomainEvent):
    event_type: str = "AuditRecorded"
    aggregate_type: str = "AuditRecord"


class AuditEventType(str, Enum):
    SUBMISSION_CREATED = "SUBMISSION_CREATED"
    SUBMISSION_VALIDATED = "SUBMISSION_VALIDATED"
    SUBMISSION_SUBMITTED = "SUBMISSION_SUBMITTED"
    SUBMISSION_REJECTED = "SUBMISSION_REJECTED"
    MEDIA_UPLOADED = "MEDIA_UPLOADED"
    MEDIA_PROCESSED = "MEDIA_PROCESSED"
    MEDIA_DELETED = "MEDIA_DELETED"
    GPS_CAPTURED = "GPS_CAPTURED"
    GPS_VERIFIED = "GPS_VERIFIED"
    EVIDENCE_CAPTURED = "EVIDENCE_CAPTURED"
    EVIDENCE_VERIFIED = "EVIDENCE_VERIFIED"
    PIPELINE_STARTED = "PIPELINE_STARTED"
    PIPELINE_COMPLETED = "PIPELINE_COMPLETED"
    HUMAN_REVIEW_STARTED = "HUMAN_REVIEW_STARTED"
    HUMAN_VERDICT_RECORDED = "HUMAN_VERDICT_RECORDED"
    AUDIT_EXPORTED = "AUDIT_EXPORTED"


@dataclass
class AuditRecord(AggregateRoot):
    event_type: AuditEventType = AuditEventType.SUBMISSION_CREATED
    aggregate_type: str = ""
    aggregate_id: str = ""
    actor_id: str = ""
    action: str = ""
    details: dict = field(default_factory=dict)
    source_service: str = ""
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

    @classmethod
    def record(
        cls,
        event_type: AuditEventType,
        aggregate_type: str,
        aggregate_id: str,
        actor_id: str,
        action: str,
        details: Optional[dict] = None,
        source_service: str = "",
    ) -> "AuditRecord":
        if not aggregate_type:
            raise ValidationException("aggregate_type is required")
        if not aggregate_id:
            raise ValidationException("aggregate_id is required")
        if not actor_id:
            raise ValidationException("actor_id is required")
        if not action:
            raise ValidationException("action is required")

        record = cls(
            id=aggregate_id,
            event_type=event_type,
            aggregate_type=aggregate_type,
            aggregate_id=aggregate_id,
            actor_id=actor_id,
            action=action,
            details=details or {},
            source_service=source_service,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        record.add_domain_event(AuditRecordedEvent(
            aggregate_id=record.id, aggregate_type=aggregate_type,
        ))
        return record

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "event_type": self.event_type.value,
            "aggregate_type": self.aggregate_type,
            "aggregate_id": self.aggregate_id,
            "actor_id": self.actor_id,
            "action": self.action,
            "details": self.details,
            "source_service": self.source_service,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
