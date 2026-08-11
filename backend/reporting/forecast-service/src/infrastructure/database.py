"""Async SQLAlchemy session management for the forecast service."""
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from shared.utils.config_loader import get_database_url


def build_engine(database_url: str | None = None):
    url = database_url or get_database_url()
    return create_async_engine(url, echo=False, pool_size=10, max_overflow=20, pool_pre_ping=True)


def build_session_factory(engine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(engine, expire_on_commit=False)


async def get_session(session_factory=None) -> AsyncGenerator[AsyncSession, None]:
    if session_factory is None:
        session_factory = build_session_factory(build_engine())
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
