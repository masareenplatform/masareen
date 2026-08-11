from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory
from .infrastructure.postgres_repository import PMSRepository
from .application.commands import UpdatePMSCommand
from .application.queries import GetPMSQuery, GetPMSHistoryQuery
from .application.handlers import UpdatePMSHandler, GetPMSHandler, GetPMSHistoryHandler

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
    repo = PMSRepository(session)
    bus.register(UpdatePMSCommand, UpdatePMSHandler(repo, session, outbox))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = PMSRepository(session)
    bus.register(GetPMSQuery, GetPMSHandler(repo))
    bus.register(GetPMSHistoryQuery, GetPMSHistoryHandler(repo))
    return bus
