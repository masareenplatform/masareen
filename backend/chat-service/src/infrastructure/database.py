"""PostgreSQL session factory for the chat-service."""
from __future__ import annotations

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from shared.base_repository.db import build_engine, build_session_factory

_engine = None
_session_factory = None


def get_engine():
    global _engine, _session_factory
    if _engine is None:
        _engine = build_engine()
        _session_factory = build_session_factory(_engine)
    return _engine


def get_session_factory():
    get_engine()
    return _session_factory


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
