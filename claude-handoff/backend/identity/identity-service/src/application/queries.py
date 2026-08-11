"""Identity service queries (read-side)."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional

from shared.utils.cqrs import Query


@dataclass
class GetUserByIdQuery(Query):
    user_id: str


@dataclass
class GetUserByEmailQuery(Query):
    email: str


@dataclass
class ListUsersQuery(Query):
    limit:  int = 20
    offset: int = 0
    role:   Optional[str] = None


@dataclass
class GetImpactPassportQuery(Query):
    user_id: str
