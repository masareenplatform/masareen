"""Session repository port for authentication."""
from abc import ABC, abstractmethod
from typing import Optional
from .session import AuthSession


class SessionRepository(ABC):
    @abstractmethod
    async def get_by_refresh_token(self, refresh_token: str) -> Optional[AuthSession]: ...
    @abstractmethod
    async def save(self, session: AuthSession) -> AuthSession: ...
