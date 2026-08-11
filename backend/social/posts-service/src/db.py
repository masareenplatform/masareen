"""Async SQLAlchemy engine/session for the social-service.

Uses SQLite by default (zero external infrastructure, fully runnable for
local dev and tests). Override with SOCIAL_DATABASE_URL for Postgres in prod.
"""
from __future__ import annotations

import os

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

# Use the SHARED declarative Base so the combined monolith's single
# `Base.metadata.create_all` provisions the posts/likes/bookmarks tables
# alongside every other service's tables on the one shared database.
from shared.base_repository.db import Base  # noqa: E402

# Honour the combined monolith's DATABASE_URL (Postgres) when present; fall back
# to a local SQLite file for standalone dev/test so the service runs with zero
# external infrastructure.
DATABASE_URL = os.getenv("DATABASE_URL") or os.getenv(
    "SOCIAL_DATABASE_URL", "sqlite+aiosqlite:///./social.db"
)

engine = create_async_engine(DATABASE_URL, echo=False, future=True)
SessionFactory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_session() -> AsyncSession:
    """FastAPI dependency that yields a request-scoped async session."""
    async with SessionFactory() as session:
        yield session


async def init_db() -> None:
    """Create tables (idempotent) and seed demo content if the store is empty."""
    from . import orm  # noqa: F401  (register models on the Base metadata)

    async with engine.begin() as conn:
        await conn.run_sync(orm.Base.metadata.create_all)
    await _seed_if_empty()


async def _seed_if_empty() -> None:
    from sqlalchemy import func, select

    from . import orm

    async with SessionFactory() as s:
        count = (await s.execute(select(func.count()).select_from(orm.PostORM))).scalar() or 0
        if count > 0:
            return
        from .seed import SEED_POSTS

        for p in SEED_POSTS:
            s.add(orm.PostORM(**p))
        await s.commit()
