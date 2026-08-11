"""User repository port for authentication."""
from abc import ABC, abstractmethod
from typing import Optional
from .user import AuthUser


class AuthUserRepository(ABC):
    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[AuthUser]: ...
    @abstractmethod
    async def get_by_id(self, user_id: str) -> Optional[AuthUser]: ...
    @abstractmethod
    async def save(self, user: AuthUser) -> AuthUser: ...
