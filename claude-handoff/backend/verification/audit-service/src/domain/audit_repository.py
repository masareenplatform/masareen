"""Audit repository interface."""
from abc import ABC, abstractmethod
from typing import List, Optional
from .audit_record import AuditRecord


class AuditRepository(ABC):
    @abstractmethod
    async def save(self, record: AuditRecord) -> AuditRecord: ...

    @abstractmethod
    async def get_by_id(self, record_id: str) -> Optional[AuditRecord]: ...

    @abstractmethod
    async def list_by_aggregate(self, aggregate_id: str) -> List[AuditRecord]: ...

    @abstractmethod
    async def list_by_actor(self, actor_id: str, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]: ...

    @abstractmethod
    async def list_by_event_type(self, event_type: str, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]: ...

    @abstractmethod
    async def list_all(self, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]: ...
