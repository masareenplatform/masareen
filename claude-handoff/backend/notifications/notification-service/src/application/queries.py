from dataclasses import dataclass
from shared.utils.cqrs import Query

@dataclass
class GetUserNotificationsQuery(Query):
    user_id: str
    unread_only: bool
    limit: int
