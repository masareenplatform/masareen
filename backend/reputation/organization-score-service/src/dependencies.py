from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory
from .infrastructure.postgres_repository import OIIRepository
from .application.commands import UpdateOIICommand
from .application.queries import GetOIIQuery, GetOIIHistoryQuery, OIILeaderboardQuery
from .application.handlers import (
    UpdateOIIHandler, GetOIIHandler, GetOIIHistoryHandler, OIILeaderboardHandler,
)

engine = build_engine()
session_factory = build_session_factory(engine)


async def get_db_session():
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    repo = OIIRepository(session)
    bus.register(UpdateOIICommand, UpdateOIIHandler(repo, session, outbox))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = OIIRepository(session)
    bus.register(GetOIIQuery, GetOIIHandler(repo))
    bus.register(GetOIIHistoryQuery, GetOIIHistoryHandler(repo))
    bus.register(OIILeaderboardQuery, OIILeaderboardHandler(repo))
    return bus
