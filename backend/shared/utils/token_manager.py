"""JWT TokenManager with RS256 support.

Implements the TokenManager pattern from the Technical Architecture (Doc 1):
asymmetric key signing with public/private key pair for service-to-service
authentication, plus HS256 fallback for single-service deployments.

Usage:
    from shared.utils.token_manager import TokenManager

    manager = TokenManager()  # uses RSA key pair from env / generated
    token = manager.create_access_token(user_id="...", role="INDIVIDUAL")
    payload = manager.verify_token(token)
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from jose import JWTError, jwt

# ── RSA key paths ─────────────────────────────────────────────────────────────
_RSA_PRIVATE_KEY = os.environ.get("JWT_RSA_PRIVATE_KEY", "")
_RSA_PUBLIC_KEY = os.environ.get("JWT_RSA_PUBLIC_KEY", "")
_HS_SECRET = os.environ.get("JWT_SECRET", "masaren-alpha-change-me")


def _get_rsa_key_pair() -> Optional[tuple[str, str]]:
    """Load RSA key pair from env vars. Returns (private, public) or None."""
    if _RSA_PRIVATE_KEY and _RSA_PUBLIC_KEY:
        return _RSA_PRIVATE_KEY, _RSA_PUBLIC_KEY
    return None


class TokenManager:
    """Manages JWT creation and verification with RS256 (preferred) or HS256 fallback."""

    def __init__(
        self,
        algorithm: str = "RS256",
        access_token_ttl_minutes: int = 60,
        refresh_token_ttl_days: int = 30,
    ):
        self._algorithm = algorithm
        self._access_ttl = access_token_ttl_minutes
        self._refresh_ttl = refresh_token_ttl_days

        rsa_pair = _get_rsa_key_pair()
        if rsa_pair and algorithm == "RS256":
            self._private_key, self._public_key = rsa_pair
        else:
            # Fallback to HS256
            self._algorithm = "HS256"
            self._private_key = _HS_SECRET
            self._public_key = _HS_SECRET

    @property
    def algorithm(self) -> str:
        return self._algorithm

    def create_access_token(
        self,
        user_id: str,
        email: str = "",
        role: str = "INDIVIDUAL",
        org_id: Optional[str] = None,
        extra_claims: Optional[Dict[str, Any]] = None,
    ) -> str:
        now = datetime.now(timezone.utc)
        claims: Dict[str, Any] = {
            "sub": user_id,
            "email": email,
            "role": role,
            "type": "access",
            "iat": now,
            "exp": now + timedelta(minutes=self._access_ttl),
        }
        if org_id:
            claims["org_id"] = org_id
        if extra_claims:
            claims.update(extra_claims)
        return jwt.encode(claims, self._private_key, algorithm=self._algorithm)

    def create_refresh_token(self, user_id: str) -> str:
        now = datetime.now(timezone.utc)
        claims = {
            "sub": user_id,
            "type": "refresh",
            "iat": now,
            "exp": now + timedelta(days=self._refresh_ttl),
        }
        return jwt.encode(claims, self._private_key, algorithm=self._algorithm)

    def verify_token(self, token: str) -> Dict[str, Any]:
        """Decode and verify a JWT. Raises JWTError on failure."""
        return jwt.decode(token, self._public_key, algorithms=[self._algorithm])

    def verify_access_token(self, token: str) -> Dict[str, Any]:
        """Verify an access token and ensure it is not a refresh token."""
        payload = self.verify_token(token)
        if payload.get("type") == "refresh":
            raise JWTError("Refresh token cannot be used as access token")
        return payload

    def refresh_access_token(self, refresh_token: str) -> str:
        """Exchange a valid refresh token for a new access token."""
        payload = self.verify_token(refresh_token)
        if payload.get("type") != "refresh":
            raise JWTError("Token is not a refresh token")
        return self.create_access_token(
            user_id=payload["sub"],
            email=payload.get("email", ""),
            role=payload.get("role", "INDIVIDUAL"),
            org_id=payload.get("org_id"),
        )
