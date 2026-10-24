"""Pure authentication primitives for the Python auth.verify capability service.

Mirrors the Go variant's contract (HS256 JWT verify + bcrypt) so the
EfficiencySelector can compare engines on identical work. Real cryptography via
python-jose and passlib, no mocks, no stubs.
"""
from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Optional

from jose import jwt, JWTError
import bcrypt

ALGORITHM = "HS256"


@dataclass
class VerifyClaims:
    user_id: str
    role: str
    sub: str
    expiry: int


def verify_token(token: str, secret: str) -> VerifyClaims:
    try:
        payload = jwt.decode(token, secret, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise ValueError(f"invalid token: {exc}") from exc
    sub = payload.get("sub")
    if not sub:
        raise ValueError("invalid token: missing sub")
    return VerifyClaims(
        user_id=sub,
        role=payload.get("role", ""),
        sub=sub,
        expiry=int(payload.get("exp", 0)),
    )


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def check_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def mint_token(user_id: str, role: str, secret: str, ttl_seconds: int = 3600) -> str:
    now = int(time.time())
    payload = {"sub": user_id, "role": role, "iat": now, "exp": now + ttl_seconds}
    return jwt.encode(payload, secret, algorithm=ALGORITHM)
