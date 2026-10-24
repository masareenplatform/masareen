"""Application CQRS command bus and query bus infrastructure."""
from typing import Any
from shared.utils.cqrs import Command, CommandHandler, Query, QueryHandler, CommandBus as SharedCommandBus, QueryBus as SharedQueryBus
from shared.utils.logging import get_logger

log = get_logger(__name__)


class CommandBus:
    """Command bus for executing commands, wraps shared kernel bus."""

    def __init__(self):
        self._bus = SharedCommandBus()

    def register_handler(self, command_type: type, handler: CommandHandler) -> None:
        self._bus.register(command_type, handler)

    async def send(self, command: Command) -> Any:
        return await self._bus.dispatch(command)


class QueryBus:
    """Query bus for executing queries, wraps shared kernel bus."""

    def __init__(self):
        self._bus = SharedQueryBus()

    def register_handler(self, query_type: type, handler: QueryHandler) -> None:
        self._bus.register(query_type, handler)

    async def ask(self, query: Query) -> Any:
        return await self._bus.dispatch(query)
