"""Dependency injection for authentication-service."""
from __future__ import annotations
from functools import lru_cache
from typing import AsyncGenerator
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository.db import build_engine, build_session_factory, get_db_session as _get_db
from shared.utils.cqrs import CommandBus
from shared.middleware import TokenPayload, make_auth_dependency
from .infrastructure.user_repository import SQLAlchemyAuthUserRepository
from .infrastructure.session_repository import SQLAlchemySessionRepository
from .infrastructure.token_store import RedisTokenStore
from .application.handlers import (
    LoginHandler, RefreshTokenHandler, LogoutHandler,
    ChangePasswordHandler, RequestPasswordResetHandler,
)
from .application.commands import (
    LoginCommand, RefreshTokenCommand, LogoutCommand,
    ChangePasswordCommand, RequestPasswordResetCommand,
)


_engine = None
_session_factory = None
_token_store = None


@lru_cache
def get_settings():
    from ..config.settings import Settings
    return Settings()


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
    async for session in _get_db(_get_session_factory()):
        yield session


def get_token_store() -> RedisTokenStore:
    global _token_store
    if _token_store is None:
        _token_store = RedisTokenStore(get_settings().redis_url)
    return _token_store


def get_current_user() -> TokenPayload:
    settings = get_settings()
    return make_auth_dependency(settings.jwt_secret, settings.jwt_algorithm)


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    settings = get_settings()
    user_repo = SQLAlchemyAuthUserRepository(session)
    session_repo = SQLAlchemySessionRepository(session)
    token_store = get_token_store()
    bus = CommandBus()
    bus.register(LoginCommand, LoginHandler(user_repo, session_repo, token_store, settings.jwt_secret, settings.jwt_algorithm))
    bus.register(RefreshTokenCommand, RefreshTokenHandler(session_repo, user_repo, settings.jwt_secret, settings.jwt_algorithm))
    bus.register(LogoutCommand, LogoutHandler(session_repo))
    bus.register(ChangePasswordCommand, ChangePasswordHandler(user_repo))
    bus.register(RequestPasswordResetCommand, RequestPasswordResetHandler(user_repo, token_store))
    return bus
