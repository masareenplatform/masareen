"""PostgreSQL session factory for the analytics-service.

Uses SQLAlchemy async engine. When the database is unreachable, callers that
open a session will raise — the API layer converts that into an honest 503
rather than returning fabricated zeros.
"""
from __future__ import annotations
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from ...config import settings

_engine = None
_session_factory: Optional[async_sessionmaker] = None


def get_engine():
    global _engine, _session_factory
    if _engine is None:
        _engine = create_async_engine(settings.database_url, echo=False, future=True)
        _session_factory = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)
    return _engine


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    factory = get_session_factory()
    async with factory() as session:
        yield session


def get_session_factory() -> async_sessionmaker:
    # Ensure engine is created (also importable without an event loop).
    get_engine()
    return _session_factory
