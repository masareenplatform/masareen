"""
Generic async repository interface.
Every domain repository must implement this contract.
Infrastructure (SQLAlchemy, Neo4j, etc.) provides the concrete implementation.
"""
from abc import ABC, abstractmethod
from typing import Generic, List, Optional, TypeVar
from uuid import UUID

T = TypeVar("T")


class Repository(ABC, Generic[T]):
    """Port (interface) for all persistence operations."""

    @abstractmethod
    async def get_by_id(self, entity_id: UUID) -> Optional[T]: ...

    @abstractmethod
    async def save(self, entity: T) -> T: ...

    @abstractmethod
    async def delete(self, entity_id: UUID) -> None: ...

    @abstractmethod
    async def exists(self, entity_id: UUID) -> bool: ...


class ReadRepository(ABC, Generic[T]):
    """Read-side (query) repository, optimised for projections."""

    @abstractmethod
    async def get_by_id(self, entity_id: UUID) -> Optional[T]: ...

    @abstractmethod
    async def list(self, limit: int = 50, offset: int = 0) -> List[T]: ...
