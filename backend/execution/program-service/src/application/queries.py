from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Query

@dataclass
class GetProgramByIdQuery(Query):
    program_id: str

@dataclass
class ListProgramsByOrgQuery(Query):
    org_id: str; limit: int=20; offset: int=0

@dataclass
class ListProgramsQuery(Query):
    limit: int=20; offset: int=0
    status: Optional[str]=None; country: Optional[str]=None
