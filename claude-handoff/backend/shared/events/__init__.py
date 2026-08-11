"""Base event contracts for MASAREN event-driven architecture."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Optional
import uuid


@dataclass
class DomainEvent:
    """Immutable base class for all domain events."""
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str = field(init=False)
    aggregate_id: str = ""
    aggregate_type: str = ""
    occurred_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    version: int = 1
    correlation_id: Optional[str] = None
    causation_id: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "event_id": self.event_id,
            "event_type": self.event_type,
            "aggregate_id": self.aggregate_id,
            "aggregate_type": self.aggregate_type,
            "occurred_at": self.occurred_at.isoformat(),
            "version": self.version,
            "correlation_id": self.correlation_id,
            "causation_id": self.causation_id,
            "metadata": self.metadata,
        }
