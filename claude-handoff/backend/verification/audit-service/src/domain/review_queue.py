from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, List
from uuid import uuid4
from shared.base_entity import AggregateRoot

class ReviewStatus(str, Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    REQUEST_INFO = "REQUEST_INFO"

@dataclass
class ReviewQueueItem(AggregateRoot):
    entity_id: str = ""       # Evidence ID or Submission ID
    entity_type: str = ""     # "EVIDENCE" | "SUBMISSION"
    confidence_score: float = 0.0
    assigned_admin_id: Optional[str] = None
    status: ReviewStatus = ReviewStatus.PENDING
    admin_verdict: Optional[str] = None
    admin_comments: Optional[str] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    resolved_at: Optional[datetime] = None

    def resolve(self, admin_id: str, verdict: ReviewStatus, comments: str) -> None:
        self.assigned_admin_id = admin_id
        self.status = verdict
        self.admin_comments = comments
        self.resolved_at = datetime.now(timezone.utc)
        self.updated_at = datetime.now(timezone.utc)
