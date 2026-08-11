from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from ..domain.platform_content import PlatformPost, ContentType
from ..domain.platform_content_repository import PlatformContentRepository
from .platform_content_orm import PlatformPostORM
import uuid

class SQLAlchemyPlatformContentRepository(PlatformContentRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    def _to_domain(self, o: PlatformPostORM) -> PlatformPost:
        return PlatformPost(
            id=str(o.id),
            title=o.title,
            body=o.body,
            content_type=ContentType(o.content_type),
            media_url=o.media_url,
            target_audience=o.target_audience.split(",") if o.target_audience else ["ALL"],
            is_active=o.is_active,
            priority=o.priority,
            spend_limit=o.spend_limit,
            current_spend=o.current_spend,
            clicks=o.clicks,
            impressions=o.impressions,
            created_at=o.created_at
        )

    async def add_post(self, post: PlatformPost) -> PlatformPost:
        orm = PlatformPostORM(
            id=uuid.UUID(post.id),
            title=post.title,
            body=post.body,
            content_type=post.content_type.value,
            media_url=post.media_url,
            target_audience=",".join(post.target_audience),
            is_active=post.is_active,
            priority=post.priority,
            spend_limit=post.spend_limit,
            current_spend=post.current_spend,
            clicks=post.clicks,
            impressions=post.impressions,
        )
        self._session.add(orm)
        await self._session.flush()
        return self._to_domain(orm)

    async def list_active_posts(self, target_audience: str) -> List[PlatformPost]:
        # Return active posts that target either "ALL" or the requested audience,
        # highest priority first. Audience is stored as a CSV of segment codes.
        stmt = select(PlatformPostORM).where(
            PlatformPostORM.is_active == True  # noqa: E712
        ).order_by(PlatformPostORM.priority.desc())
        result = await self._session.execute(stmt)
        wanted = (target_audience or "ALL").upper()
        posts: List[PlatformPost] = []
        for row in result.scalars().all():
            segments = {s.strip().upper() for s in (row.target_audience or "ALL").split(",")}
            if "ALL" in segments or wanted in segments:
                posts.append(self._to_domain(row))
        return posts

    async def save(self, post: PlatformPost) -> PlatformPost:
        orm = await self._session.get(PlatformPostORM, uuid.UUID(post.id))
        if not orm: return await self.add_post(post)
        
        orm.title = post.title
        orm.body = post.body
        orm.content_type = post.content_type.value
        orm.media_url = post.media_url
        orm.target_audience = ",".join(post.target_audience)
        orm.is_active = post.is_active
        orm.priority = post.priority
        orm.spend_limit = post.spend_limit
        orm.current_spend = post.current_spend
        orm.clicks = post.clicks
        orm.impressions = post.impressions
        
        await self._session.flush()
        return post
