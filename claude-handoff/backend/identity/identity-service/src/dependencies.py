"""
Dependency injection for the identity-service.
All dependencies are wired here and injected via FastAPI's Depends().
"""
from __future__ import annotations
from functools import lru_cache
from typing import AsyncGenerator

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from shared.middleware import TokenPayload, make_auth_dependency
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.kafka_producer import EventPublisher
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory

from ..config.settings import Settings
from .infrastructure.user_repository_impl import SQLAlchemyUserRepository
from .infrastructure.token_store import RedisTokenStore
from .application.handlers import (
    RegisterUserHandler, VerifyEmailHandler, UpdateUserProfileHandler,
    AddSkillHandler, SuspendUserHandler, UpdatePMSScoreHandler,
    GetUserByIdHandler, GetUserByEmailHandler, ListUsersHandler,
    GetImpactPassportHandler,
)
from .application.commands import (
    RegisterUserCommand, VerifyEmailCommand, UpdateUserProfileCommand,
    AddSkillToUserCommand, SuspendUserCommand, UpdatePMSScoreCommand,
)
from .application.queries import (
    GetUserByIdQuery, GetUserByEmailQuery, ListUsersQuery, GetImpactPassportQuery,
)


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Lazy singletons
_engine = None
_session_factory = None
_publisher = None
_token_store = None


def _get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        _engine = build_engine(settings.database_url)
    return _engine


def _get_session_factory():
    global _session_factory
    if _session_factory is None:
        _session_factory = build_session_factory(_get_engine())
    return _session_factory


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    from shared.base_repository.db import get_db_session as _get_db
    async for session in _get_db(_get_session_factory()):
        yield session


def get_token_store() -> RedisTokenStore:
    global _token_store
    if _token_store is None:
        _token_store = RedisTokenStore(get_settings().redis_url)
    return _token_store


def get_publisher() -> EventPublisher:
    global _publisher
    if _publisher is None:
        _publisher = EventPublisher(get_settings().kafka_bootstrap_servers)
    return _publisher


# Auth dependency
def get_current_user() -> TokenPayload:
    settings = get_settings()
    return make_auth_dependency(settings.jwt_secret, settings.jwt_algorithm)


# Bus factories
async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    repo        = SQLAlchemyUserRepository(session)
    token_store = get_token_store()
    outbox      = OutboxWriter()
    bus         = CommandBus()
    bus.register(RegisterUserCommand,        RegisterUserHandler(repo, session, outbox))
    bus.register(VerifyEmailCommand,         VerifyEmailHandler(repo, session, token_store))
    bus.register(UpdateUserProfileCommand,   UpdateUserProfileHandler(repo))
    bus.register(AddSkillToUserCommand,      AddSkillHandler(repo))
    bus.register(SuspendUserCommand,         SuspendUserHandler(repo))
    bus.register(UpdatePMSScoreCommand,      UpdatePMSScoreHandler(repo, session, outbox))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    repo = SQLAlchemyUserRepository(session)
    bus  = QueryBus()
    bus.register(GetUserByIdQuery,       GetUserByIdHandler(repo))
    bus.register(GetUserByEmailQuery,    GetUserByEmailHandler(repo))
    bus.register(ListUsersQuery,         ListUsersHandler(repo))
    bus.register(GetImpactPassportQuery, GetImpactPassportHandler(repo))
    return bus
