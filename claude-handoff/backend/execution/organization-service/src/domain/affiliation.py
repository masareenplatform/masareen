"""Affiliation entity for User-Organization relationships."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4

class AffiliationRole(str, Enum):
    MEMBER = "MEMBER"
    CONTRIBUTOR = "CONTRIBUTOR"
    LEAD = "LEAD"
    PARTNER = "PARTNER"
    ALUMNI = "ALUMNI"

@dataclass
class Affiliation:
    id: str = field(default_factory=lambda: str(uuid4()))
    user_id: str = ""
    org_id: str = ""
    role: AffiliationRole = AffiliationRole.MEMBER
    joined_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    verified: bool = False
    metadata: dict = field(default_factory=dict)
