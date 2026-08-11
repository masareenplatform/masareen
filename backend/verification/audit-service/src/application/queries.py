"""Audit service queries."""
from dataclasses import dataclass
from shared.utils.cqrs import Query


@dataclass
class GetAuditTrailQuery(Query):
    aggregate_id: str = ""


@dataclass
class GetPendingReviewsQuery(Query):
    limit: int = 20
    offset: int = 0
