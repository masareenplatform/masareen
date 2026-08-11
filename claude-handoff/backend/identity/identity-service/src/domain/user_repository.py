"""User repository port (interface). Infrastructure provides the implementation."""
from abc import ABC, abstractmethod
from typing import List, Optional
from uuid import UUID

from .user import User


class UserRepository(ABC):
    @abstractmethod
    async def get_by_id(self, user_id: str) -> Optional[User]: ...

    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[User]: ...

    @abstractmethod
    async def save(self, user: User) -> User: ...

    @abstractmethod
    async def exists_by_email(self, email: str) -> bool: ...

    @abstractmethod
    async def list_users(
        self, limit: int = 20, offset: int = 0, role: Optional[str] = None
    ) -> tuple[List[User], int]: ...
