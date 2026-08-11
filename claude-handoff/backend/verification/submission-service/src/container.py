"""Submission service dependency injection container."""
from fastapi import Depends
from shared.utils.cqrs import CommandBus, QueryBus
from typing import Dict, Type, Callable


class SubmissionCommandBus(CommandBus):
    pass


class SubmissionQueryBus(QueryBus):
    pass


class SubmissionServiceContainer:
    """Dependency injection container for submission service."""

    def __init__(self):
        self._command_bus = SubmissionCommandBus()
        self._query_bus = SubmissionQueryBus()
        self._resolvers: Dict[Type, Callable] = {}

    def register_command_handler(self, command_type: Type, handler_instance) -> None:
        self._command_bus.register(command_type, handler_instance)

    def register_query_handler(self, query_type: Type, handler_instance) -> None:
        self._query_bus.register(query_type, handler_instance)

    def register_type(self, type_hint: Type, resolver: Callable) -> None:
        self._resolvers[type_hint] = resolver

    def get_command_bus(self) -> CommandBus:
        return self._command_bus

    def get_query_bus(self) -> QueryBus:
        return self._query_bus

    async def resolve(self, dependency_type: Type):
        if dependency_type in self._resolvers:
            return await self._resolvers[dependency_type]()
        raise ValueError(f"No resolver registered for {dependency_type}")


async def get_command_bus(container: SubmissionServiceContainer = Depends()) -> CommandBus:
    return container.get_command_bus()

async def get_query_bus(container: SubmissionServiceContainer = Depends()) -> QueryBus:
    return container.get_query_bus()
