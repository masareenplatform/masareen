"""
Event Sourced Command and Query Bus for Submission Service.

Implements Domain-Driven Design with Event Sourcing and CQRS.
"""
from __future__ import annotations
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, Generic, Optional, Type, TypeVar
import asyncio

from shared.base_repository.db import get_db_session
from shared.utils.outbox import OutboxWriter
from shared.utils.kafka_producer import EventPublisher

TResult = TypeVar("TResult")


@dataclass
class Command:
    """Marker base for all write-side commands."""


@dataclass
class Query(Generic[TResult]):
    """Marker base for all read-side queries."""


class CommandHandler(ABC, Generic[TResult]):
    @abstractmethod
    async def handle(self, command: Command) -> TResult: ...


class QueryHandler(ABC, Generic[TResult]):
    @abstractmethod
    async def handle(self, query: Query[TResult]) -> TResult: ...


class CommandBus:
    """Dispatches commands to their registered handlers."""

    def __init__(self) -> None:
        self._handlers: Dict[Type[Command], CommandHandler] = {}

    def register(self, command_type: Type[Command], handler: CommandHandler) -> None:
        if command_type in self._handlers:
            raise ValueError(f"Handler already registered for {command_type.__name__}")
        self._handlers[command_type] = handler

    async def dispatch(self, command: Command) -> Any:
        handler = self._handlers.get(type(command))
        if not handler:
            raise LookupError(f"No handler registered for command: {type(command).__name__}")
        return await handler.handle(command)


class QueryBus:
    """Dispatches queries to their registered handlers."""

    def __init__(self) -> None:
        self._handlers: Dict[Type[Query], QueryHandler] = {}

    def register(self, query_type: Type[Query], handler: QueryHandler) -> None:
        self._handlers[query_type] = handler

    async def dispatch(self, query: Query[TResult]) -> TResult:
        handler = self._handlers.get(type(query))
        if not handler:
            raise LookupError(f"No handler registered for query: {type(query).__name__}")
        return await handler.handle(query)
