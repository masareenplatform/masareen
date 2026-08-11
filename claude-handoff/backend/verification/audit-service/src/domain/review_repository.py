from typing import List, Optional
from .review_queue import ReviewQueueItem

class ReviewQueueRepository:
    async def add_item(self, item: ReviewQueueItem) -> ReviewQueueItem:
        raise NotImplementedError

    async def get_pending(self, limit: int, offset: int) -> List[ReviewQueueItem]:
        raise NotImplementedError

    async def get_by_id(self, item_id: str) -> Optional[ReviewQueueItem]:
        raise NotImplementedError

    async def save(self, item: ReviewQueueItem) -> ReviewQueueItem:
        raise NotImplementedError
