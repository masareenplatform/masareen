"""
Shared test utilities and fixtures for MASAREEN microservices.
Import these in each service's conftest.py.
"""
from __future__ import annotations
import asyncio
from typing import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from ..base_repository.db import Base


# ── In-memory SQLite engine for unit tests ────────────────────────────────────
@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def test_engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    factory = async_sessionmaker(test_engine, expire_on_commit=False)
    async with factory() as session:
        yield session
        await session.rollback()


# ── Mock event publisher ───────────────────────────────────────────────────────
@pytest.fixture
def mock_publisher():
    pub = AsyncMock()
    pub.publish = AsyncMock()
    pub.publish_raw = AsyncMock()
    return pub


# ── Helpers ────────────────────────────────────────────────────────────────────
def make_uuid() -> str:
    return str(uuid4())


def make_token_payload(role: str = "INDIVIDUAL", org_id: str | None = None):
    from ..middleware import TokenPayload
    return TokenPayload(
        sub=make_uuid(),
        email="test@masaren.io",
        role=role,
        org_id=org_id,
    )
