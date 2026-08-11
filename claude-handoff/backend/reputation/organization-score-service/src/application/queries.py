from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Query


@dataclass
class GetOIIQuery(Query):
    organization_id: str


@dataclass
class GetOIIHistoryQuery(Query):
    organization_id: str
    limit: int = 20


@dataclass
class OIILeaderboardQuery(Query):
    limit: int = 20
    org_type: Optional[str] = None
