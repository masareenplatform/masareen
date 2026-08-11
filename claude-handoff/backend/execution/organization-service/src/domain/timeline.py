"""Timeline event for career and institutional history."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from uuid import uuid4

@dataclass
class TimelineEvent:
    id: str = field(default_factory=lambda: str(uuid4()))
    entity_id: str = "" # User ID or Org ID
    event_type: str = "" # e.g., "MATCH_WIN", "DEGREE_EARNED", "OFFICE_APPOINTED"
    title: str = ""
    description: str = ""
    date: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    media_url: Optional[str] = None
    metric_value: Optional[float] = None # e.g., goal count, GPA, budget managed
    metadata: Dict[str, Any] = field(default_factory=dict)
