from typing import List, Optional
from .platform_content import PlatformPost

class PlatformContentRepository:
    async def add_post(self, post: PlatformPost) -> PlatformPost:
        raise NotImplementedError

    async def list_active_posts(self, target_audience: str) -> List[PlatformPost]:
        raise NotImplementedError

    async def save(self, post: PlatformPost) -> PlatformPost:
        raise NotImplementedError
