"""Dependency injection for workflow-service."""
from functools import lru_cache
from typing import AsyncGenerator
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository.db import build_engine, build_session_factory, get_db_session as _get_db
from shared.utils.cqrs import CommandBus, QueryBus
from .infrastructure.workflow_repository_impl import (
    SQLAlchemyWorkflowTemplateRepository,
    SQLAlchemyWorkflowInstanceRepository,
)
from .application.handlers import (
    CreateWorkflowTemplateHandler, AddWorkflowStepHandler,
    InstantiateWorkflowHandler, StartWorkflowHandler,
    AdvanceWorkflowStepHandler, PauseWorkflowHandler, CancelWorkflowHandler,
)
from .application.commands import (
    CreateWorkflowTemplateCommand, AddWorkflowStepCommand,
    InstantiateWorkflowCommand, StartWorkflowCommand,
    AdvanceWorkflowStepCommand, PauseWorkflowCommand, CancelWorkflowCommand,
)


_engine = None
_session_factory = None


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


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    tmpl_repo = SQLAlchemyWorkflowTemplateRepository(session)
    inst_repo = SQLAlchemyWorkflowInstanceRepository(session)
    bus = CommandBus()
    bus.register(CreateWorkflowTemplateCommand, CreateWorkflowTemplateHandler(tmpl_repo))
    bus.register(AddWorkflowStepCommand, AddWorkflowStepHandler(tmpl_repo))
    bus.register(InstantiateWorkflowCommand, InstantiateWorkflowHandler(tmpl_repo, inst_repo))
    bus.register(StartWorkflowCommand, StartWorkflowHandler(inst_repo))
    bus.register(AdvanceWorkflowStepCommand, AdvanceWorkflowStepHandler(inst_repo))
    bus.register(PauseWorkflowCommand, PauseWorkflowHandler(inst_repo))
    bus.register(CancelWorkflowCommand, CancelWorkflowHandler(inst_repo))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    inst_repo = SQLAlchemyWorkflowInstanceRepository(session)
    bus = QueryBus()
    bus.register("GetWorkflowInstanceQuery", lambda q: inst_repo.get_by_id(q.instance_id))
    return bus
