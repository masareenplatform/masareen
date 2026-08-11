"""
JWT Authentication middleware and dependency injection.
Used by all MASAREN services via FastAPI depends().
"""
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

# ── Password hashing ──────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ── JWT ───────────────────────────────────────────────────────────────────────
@dataclass
class TokenPayload:
    sub: str          # user_id (UUID as string)
    email: str
    role: str
    org_id: Optional[str] = None
    exp: Optional[datetime] = None


def create_access_token(
    payload: TokenPayload,
    secret: str,
    algorithm: str = "HS256",
    expires_minutes: int = 60,
) -> str:
    data = {
        "sub": payload.sub,
        "email": payload.email,
        "role": payload.role,
        "org_id": payload.org_id,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=expires_minutes),
    }
    return jwt.encode(data, secret, algorithm=algorithm)


def create_refresh_token(
    user_id: str,
    secret: str,
    algorithm: str = "HS256",
    expires_days: int = 30,
) -> str:
    data = {
        "sub": user_id,
        "type": "refresh",
        "exp": datetime.now(timezone.utc) + timedelta(days=expires_days),
    }
    return jwt.encode(data, secret, algorithm=algorithm)


def decode_token(token: str, secret: str, algorithm: str = "HS256") -> TokenPayload:
    try:
        payload = jwt.decode(token, secret, algorithms=[algorithm])
        return TokenPayload(
            sub=payload["sub"],
            email=payload.get("email", ""),
            role=payload.get("role", "INDIVIDUAL"),
            org_id=payload.get("org_id"),
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


# ── FastAPI dependency ────────────────────────────────────────────────────────
bearer_scheme = HTTPBearer()


def make_auth_dependency(secret: str, algorithm: str = "HS256"):
    """Factory that returns a FastAPI dependency for a specific service's JWT config."""

    async def get_current_user(
        credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    ) -> TokenPayload:
        return decode_token(credentials.credentials, secret, algorithm)

    return get_current_user


def require_role(*roles: str):
    """Role-based access control decorator factory for FastAPI route dependencies."""

    def role_checker(token: TokenPayload) -> TokenPayload:
        if token.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{token.role}' is not permitted for this operation.",
            )
        return token

    return role_checker
