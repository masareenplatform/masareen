"""
RBAC permission domain model.
Permissions are resource:action pairs. Roles aggregate permissions.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Set


class Action(str, Enum):
    CREATE = "create"
    READ   = "read"
    UPDATE = "update"
    DELETE = "delete"
    LIST   = "list"
    VERIFY = "verify"
    APPROVE = "approve"
    REJECT  = "reject"
    PUBLISH = "publish"
    ADMIN   = "admin"


@dataclass(frozen=True)
class Permission:
    """A single resource:action pair."""
    resource: str
    action:   Action

    def __str__(self) -> str:
        return f"{self.resource}:{self.action.value}"

    @classmethod
    def from_string(cls, s: str) -> "Permission":
        parts = s.split(":")
        if len(parts) != 2:
            raise ValueError(f"Invalid permission string: {s}")
        return cls(resource=parts[0], action=Action(parts[1]))


@dataclass
class Role:
    name:        str
    permissions: Set[Permission] = field(default_factory=set)
    description: str = ""

    def grant(self, permission: Permission) -> None:
        self.permissions.add(permission)

    def revoke(self, permission: Permission) -> None:
        self.permissions.discard(permission)

    def has_permission(self, resource: str, action: Action) -> bool:
        return Permission(resource, action) in self.permissions


# ── Default role definitions (loaded from DB in production) ───────────────────
ROLE_DEFINITIONS: dict[str, List[str]] = {
    "INDIVIDUAL": [
        "user:read", "user:update",
        "task:read", "task:create",
        "evidence:create", "evidence:read",
        "program:read",
        "portfolio:read", "portfolio:update",
        "opportunity:read",
    ],
    "ORGANIZATION": [
        "user:read",
        "program:create", "program:read", "program:update", "program:delete",
        "task:create", "task:read", "task:update", "task:delete",
        "evidence:read", "evidence:verify",
        "report:create", "report:read",
        "organization:read", "organization:update",
    ],
    "ADMIN": [
        "user:read", "user:update", "user:delete", "user:list",
        "program:admin", "task:admin", "evidence:admin",
        "organization:admin", "report:admin",
        "verification:approve", "verification:reject",
    ],
    "SUPER_ADMIN": [
        "user:admin", "organization:admin", "program:admin",
        "task:admin", "evidence:admin", "verification:admin",
        "billing:admin", "system:admin",
    ],
}


def build_role(name: str) -> Role:
    perms = ROLE_DEFINITIONS.get(name, [])
    role = Role(name=name)
    for p in perms:
        role.grant(Permission.from_string(p))
    return role
