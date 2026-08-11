from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, List
from uuid import uuid4
from shared.base_entity import AggregateRoot

class NotificationStatus(str, Enum):
    PENDING = "PENDING"
    SENT = "SENT"
    FAILED = "FAILED"
    READ = "READ"

@dataclass
class Notification(AggregateRoot):
    user_id: str = ""
    trigger_type: str = ""
    title: str = ""
    body: str = ""
    payload: dict = field(default_factory=dict)
    status: NotificationStatus = NotificationStatus.PENDING
    sent_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    channel_used: Optional[str] = None

    @classmethod
    def create(cls, user_id: str, trigger: str, title: str, body: str, payload: dict = None) -> "Notification":
        return cls(
            id=str(uuid4()),
            user_id=user_id,
            trigger_type=trigger,
            title=title,
            body=body,
            payload=payload or {},
            status=NotificationStatus.PENDING,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )

    def mark_sent(self, channel: str):
        self.status = NotificationStatus.SENT
        self.channel_used = channel
        self.sent_at = datetime.now(timezone.utc)
        self.updated_at = datetime.now(timezone.utc)

    def mark_read(self):
        self.status = NotificationStatus.READ
        self.read_at = datetime.now(timezone.utc)
        self.updated_at = datetime.now(timezone.utc)
