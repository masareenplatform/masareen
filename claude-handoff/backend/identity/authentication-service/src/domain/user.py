"""Minimal User domain model for authentication purposes."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional


class UserRole(str, Enum):
    INDIVIDUAL = "INDIVIDUAL"
    ORGANIZATION = "ORGANIZATION"
    ADMIN = "ADMIN"
    SUPER_ADMIN = "SUPER_ADMIN"


class UserStatus(str, Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"


@dataclass
class AuthUser:
    id: str
    email: str
    full_name: str
    role: UserRole
    status: UserStatus
    hashed_password: str
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def is_active(self) -> bool:
        return self.status == UserStatus.ACTIVE
