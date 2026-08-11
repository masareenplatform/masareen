from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Query

@dataclass
class GetOpportunityQuery(Query):
    opportunity_id: str

@dataclass
class ListOpportunitiesQuery(Query):
    opp_type: Optional[str] = None
    country: Optional[str] = None
    remote: Optional[bool] = None
    min_pms: float = 0.0
    limit: int = 20
    offset: int = 0

@dataclass
class ListPlatformContentQuery(Query):
    audience: str = "ALL"
