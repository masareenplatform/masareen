"""Audit service commands."""
from dataclasses import dataclass, field
from typing import Optional
from shared.utils.cqrs import Command


@dataclass
class RecordAuditEventCommand(Command):
    event_type: str = ""
    aggregate_type: str = ""
    aggregate_id: str = ""
    actor_id: str = ""
    action: str = ""
    details: Optional[dict] = None
    source_service: str = ""


@dataclass
class ExportAuditTrailCommand(Command):
    aggregate_id: str = ""
    from_date: Optional[str] = None
    to_date: Optional[str] = None


@dataclass
class RouteToReviewCommand(Command):
    entity_id: str = ""
    entity_type: str = ""
    confidence_score: float = 0.0


@dataclass
class ResolveReviewCommand(Command):
    review_id: str = ""
    verdict: str = ""
    comments: str = ""
    admin_id: str = ""
