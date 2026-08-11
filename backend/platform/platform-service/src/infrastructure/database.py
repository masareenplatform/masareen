"""PostgreSQL session factory for the platform-service.

Reads/writes the shared platform_config + platform_revenue tables. When the
database is unreachable the API surfaces an honest 503.
"""
from __future__ import annotations
from typing import AsyncGenerator, Optional

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

try:
    from config.settings import settings
except Exception:  # pragma: no cover
    from ...config.settings import settings  # type: ignore

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
    get_engine()
    return _session_factory
