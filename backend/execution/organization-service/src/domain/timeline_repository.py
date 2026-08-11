from typing import List, Optional
from .timeline import TimelineEvent

class TimelineRepository:
    async def add_event(self, event: TimelineEvent) -> TimelineEvent:
        raise NotImplementedError

    async def get_by_entity_id(self, entity_id: str) -> List[TimelineEvent]:
        raise NotImplementedError

    async def delete_event(self, event_id: str) -> bool:
        raise NotImplementedError
