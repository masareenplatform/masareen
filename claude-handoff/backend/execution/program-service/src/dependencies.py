"""Dependency injection for program-service."""
from functools import lru_cache
from typing import AsyncGenerator
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository.db import build_engine, build_session_factory, get_db_session as _get_db
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.utils.kafka_producer import EventPublisher
from .infrastructure.program_repository_impl import SQLAlchemyProgramRepository
from .application.handlers import (
    CreateProgramHandler, PublishProgramHandler, EnrollParticipantHandler,
    GetProgramByIdHandler, ListProgramsHandler,
)
from .application.commands import (
    CreateProgramCommand, PublishProgramCommand, EnrollParticipantCommand,
)
from .application.queries import GetProgramByIdQuery, ListProgramsQuery


_engine = None
_session_factory = None
_publisher = None


def _get_engine():
    global _engine
    if _engine is None:
        import os
        _engine = build_engine(os.getenv("DATABASE_URL", "postgresql+asyncpg://masaren:masaren_dev@localhost:5432/masaren"))
    return _engine


def _get_session_factory():
    global _session_factory
    if _session_factory is None:
        _session_factory = build_session_factory(_get_engine())
    return _session_factory


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async for session in _get_db(_get_session_factory()):
        yield session


def get_publisher():
    global _publisher
    if _publisher is None:
        import os
        _publisher = EventPublisher(os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"))
    return _publisher


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    repo = SQLAlchemyProgramRepository(session)
    outbox = OutboxWriter()
    bus = CommandBus()
    bus.register(CreateProgramCommand, CreateProgramHandler(repo, session, outbox))
    bus.register(PublishProgramCommand, PublishProgramHandler(repo))
    bus.register(EnrollParticipantCommand, EnrollParticipantHandler(repo))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    repo = SQLAlchemyProgramRepository(session)
    bus = QueryBus()
    bus.register(GetProgramByIdQuery, GetProgramByIdHandler(repo))
    bus.register(ListProgramsQuery, ListProgramsHandler(repo))
    return bus
