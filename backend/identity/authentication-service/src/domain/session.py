"""Auth session aggregate."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4


class SessionStatus(str, Enum):
    ACTIVE   = "ACTIVE"
    REVOKED  = "REVOKED"
    EXPIRED  = "EXPIRED"


@dataclass
class AuthSession:
    """
    Represents an authenticated session.
    Stores the refresh token and metadata needed to issue new access tokens.
    """
    id:             str
    user_id:        str
    refresh_token:  str
    status:         SessionStatus
    device_info:    Optional[str]  = None
    ip_address:     Optional[str]  = None
    created_at:     datetime       = field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at:     datetime       = field(default_factory=lambda: datetime.now(timezone.utc) + timedelta(days=30))
    revoked_at:     Optional[datetime] = None

    @classmethod
    def create(
        cls,
        user_id: str,
        refresh_token: str,
        device_info: Optional[str] = None,
        ip_address: Optional[str] = None,
        ttl_days: int = 30,
    ) -> "AuthSession":
        now = datetime.now(timezone.utc)
        return cls(
            id=str(uuid4()),
            user_id=user_id,
            refresh_token=refresh_token,
            status=SessionStatus.ACTIVE,
            device_info=device_info,
            ip_address=ip_address,
            created_at=now,
            expires_at=now + timedelta(days=ttl_days),
        )

    def revoke(self) -> None:
        self.status = SessionStatus.REVOKED
        self.revoked_at = datetime.now(timezone.utc)

    @property
    def is_valid(self) -> bool:
        return (
            self.status == SessionStatus.ACTIVE
            and datetime.now(timezone.utc) < self.expires_at
        )
