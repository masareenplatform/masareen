"""Dependency injection for task-service."""
from functools import lru_cache
from typing import AsyncGenerator
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository.db import build_engine, build_session_factory, get_db_session as _get_db
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.utils.kafka_producer import EventPublisher
from .infrastructure.task_repository_impl import SQLAlchemyTaskRepository
from .application.handlers import (
    CreateTaskHandler, AssignTaskHandler, StartTaskHandler, SubmitTaskHandler,
    VerifyTaskHandler, CompleteTaskHandler, CancelTaskHandler,
    GetTaskByIdHandler, ListTasksByProgramHandler, ListTasksByAssigneeHandler,
    GetTaskStatusHistoryHandler,
)
from .application.commands import (
    CreateTaskCommand, AssignTaskCommand, StartTaskCommand, SubmitTaskCommand,
    VerifyTaskCommand, CompleteTaskCommand, CancelTaskCommand,
)
from .application.queries import (
    GetTaskByIdQuery, ListTasksByProgramQuery, ListTasksByAssigneeQuery, GetTaskStatusHistoryQuery,
)


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
    repo = SQLAlchemyTaskRepository(session)
    outbox = OutboxWriter()
    bus = CommandBus()
    bus.register(CreateTaskCommand, CreateTaskHandler(repo, session, outbox))
    bus.register(AssignTaskCommand, AssignTaskHandler(repo, session, outbox))
    bus.register(StartTaskCommand, StartTaskHandler(repo, session, outbox))
    bus.register(SubmitTaskCommand, SubmitTaskHandler(repo))
    bus.register(VerifyTaskCommand, VerifyTaskHandler(repo))
    bus.register(CompleteTaskCommand, CompleteTaskHandler(repo, session, outbox))
    bus.register(CancelTaskCommand, CancelTaskHandler(repo))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    repo = SQLAlchemyTaskRepository(session)
    bus = QueryBus()
    bus.register(GetTaskByIdQuery, GetTaskByIdHandler(repo))
    bus.register(ListTasksByProgramQuery, ListTasksByProgramHandler(repo))
    bus.register(ListTasksByAssigneeQuery, ListTasksByAssigneeHandler(repo))
    bus.register(GetTaskStatusHistoryQuery, GetTaskStatusHistoryHandler(repo))
    return bus
