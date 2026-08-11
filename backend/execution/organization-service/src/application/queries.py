from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Query

@dataclass
class GetOrganizationByIdQuery(Query):
    org_id: str

@dataclass
class GetOrganizationBySlugQuery(Query):
    slug: str

@dataclass
class ListOrganizationsQuery(Query):
    limit: int = 20; offset: int = 0; org_type: Optional[str] = None

@dataclass
class GetTimelineQuery(Query):
    entity_id: str
