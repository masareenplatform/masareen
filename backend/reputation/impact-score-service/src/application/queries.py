from dataclasses import dataclass
from shared.utils.cqrs import Query


@dataclass
class GetPMSQuery(Query):
    user_id: str


@dataclass
class GetPMSHistoryQuery(Query):
    user_id: str
    limit: int = 20
