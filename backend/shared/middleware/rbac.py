"""RBAC middleware for the MASAREN combined backend.

Provides role-based and permission-based access control decorators
for FastAPI route dependencies. Implements the zero-trust access
model from the Technical Architecture (Doc 1).

Usage in routes:

    from shared.middleware.rbac import require_role, require_permission, require_owner_or_admin

    @router.get("/admin/users")
    async def list_users(user=Depends(require_role("ADMIN", "SUPER_ADMIN"))):
        ...

    @router.delete("/posts/{post_id}")
    async def delete_post(post_id, user=Depends(require_owner_or_admin(PostRepository))):
        ...
"""
from __future__ import annotations

from functools import wraps
from typing import Callable, List, Optional, Set

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import decode_token, TokenPayload


bearer_scheme = HTTPBearer()

# ── Role hierarchy ────────────────────────────────────────────────────────────

ROLE_HIERARCHY = {
    "SUPER_ADMIN": {"ADMIN", "EDITOR", "MODERATOR", "ORGANIZATION", "INDIVIDUAL", "AI_AGENT"},
    "ADMIN": {"EDITOR", "MODERATOR", "ORGANIZATION", "INDIVIDUAL"},
    "EDITOR": {"INDIVIDUAL"},
    "MODERATOR": {"INDIVIDUAL"},
    "ORGANIZATION": {"INDIVIDUAL"},
    "INDIVIDUAL": set(),
    "AI_AGENT": set(),
}


def role_has_permission(role: str, required: str) -> bool:
    """Check if a role has the required role (including hierarchy)."""
    if role == required:
        return True
    return required in ROLE_HIERARCHY.get(role, set())


# ── Permission constants ──────────────────────────────────────────────────────

PERM_POST_CREATE = "post:create"
PERM_POST_DELETE = "post:delete"
PERM_POST_MODERATE = "post:moderate"
PERM_USER_MANAGE = "user:manage"
PERM_ORG_MANAGE = "org:manage"
PERM_EVIDENCE_SUBMIT = "evidence:submit"
PERM_EVIDENCE_VERIFY = "evidence:verify"
PERM_PASSPORT_VIEW_PRIVATE = "passport:view_private"
PERM_WELFARE_VIEW = "welfare:view"
PERM_SPONSOR_MANAGE = "sponsor:manage"
PERM_BILLING_VIEW = "billing:view"

ROLE_PERMISSIONS = {
    "SUPER_ADMIN": {perm for perms in ROLE_HIERARCHY.values() for perm in [
        PERM_POST_CREATE, PERM_POST_DELETE, PERM_POST_MODERATE,
        PERM_USER_MANAGE, PERM_ORG_MANAGE, PERM_EVIDENCE_SUBMIT,
        PERM_EVIDENCE_VERIFY, PERM_PASSPORT_VIEW_PRIVATE, PERM_WELFARE_VIEW,
        PERM_SPONSOR_MANAGE, PERM_BILLING_VIEW,
    ]},
    "ADMIN": {
        PERM_POST_CREATE, PERM_POST_DELETE, PERM_POST_MODERATE,
        PERM_USER_MANAGE, PERM_ORG_MANAGE, PERM_EVIDENCE_SUBMIT,
        PERM_EVIDENCE_VERIFY, PERM_PASSPORT_VIEW_PRIVATE, PERM_WELFARE_VIEW,
        PERM_SPONSOR_MANAGE, PERM_BILLING_VIEW,
    },
    "EDITOR": {PERM_POST_CREATE, PERM_POST_MODERATE, PERM_EVIDENCE_VERIFY},
    "MODERATOR": {PERM_POST_MODERATE, PERM_EVIDENCE_VERIFY},
    "ORGANIZATION": {PERM_POST_CREATE, PERM_EVIDENCE_SUBMIT, PERM_ORG_MANAGE},
    "INDIVIDUAL": {PERM_POST_CREATE, PERM_EVIDENCE_SUBMIT},
    "AI_AGENT": {PERM_POST_CREATE},
}


# ── FastAPI dependencies ──────────────────────────────────────────────────────

def _get_token(request: Request) -> TokenPayload:
    """Extract and verify JWT from request. Raises 401 on failure."""
    auth: Optional[HTTPAuthorizationCredentials] = getattr(request.state, "_auth_creds", None)
    if auth is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    secret = getattr(request.app.state, "jwt_secret", "masaren-alpha-change-me")
    algorithm = getattr(request.app.state, "jwt_algorithm", "HS256")
    return decode_token(auth.credentials, secret, algorithm)


def require_role(*allowed_roles: str):
    """Dependency factory: the caller must have one of the listed roles."""

    async def _check(request: Request) -> TokenPayload:
        token = _get_token(request)
        if not any(role_has_permission(token.role, r) for r in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{token.role}' is not permitted. Required: {allowed_roles}",
            )
        return token

    return _check


def require_permission(*required_perms: str):
    """Dependency factory: the caller must hold all listed permissions."""

    async def _check(request: Request) -> TokenPayload:
        token = _get_token(request)
        user_perms = ROLE_PERMISSIONS.get(token.role, set())
        missing = [p for p in required_perms if p not in user_perms]
        if missing:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permissions: {missing}",
            )
        return token

    return _check


def require_owner_or_admin(resource_owner_fn: Callable):
    """Dependency factory: the caller must be the resource owner or an admin.

    resource_owner_fn should be an async callable that takes (resource_id, token)
    and returns the owner's user_id or None if not found.
    """

    async def _check(resource_id: str, request: Request) -> TokenPayload:
        token = _get_token(request)
        if role_has_permission(token.role, "ADMIN"):
            return token
        owner_id = await resource_owner_fn(resource_id, token)
        if owner_id != token.sub:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have access to this resource.",
            )
        return token

    return _check
