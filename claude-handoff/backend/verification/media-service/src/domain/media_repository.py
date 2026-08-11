from abc import ABC, abstractmethod
from typing import List, Optional
from uuid import UUID
from shared.base_repository import Repository, ReadRepository
from .media_asset import MediaAsset


class MediaRepository(Repository[MediaAsset], ReadRepository[MediaAsset], ABC):
    """Repository for MediaAsset aggregates with read operations.
    
    Implements Event Sourcing pattern with projection-based reads.
    This is a port interface for all persistence operations.
    """
    
    @abstractmethod
    async def get_by_id(self, entity_id: str) -> Optional[MediaAsset]: ...
    
    @abstractmethod
    async def get_by_submission(self, submission_id: str) -> List[MediaAsset]: ...
    
    @abstractmethod
    async def get_by_owner(self, owner_id: str, limit: int = 50, offset: int = 0) -> tuple[List[MediaAsset], int]: ...
    
    @abstractmethod
    async def get_by_checksum(self, checksum: str) -> Optional[MediaAsset]: ...


class MediaReadRepository(ReadRepository[MediaAsset], ABC):
    """Read-optimized repository for MediaAsset aggregates."""

    @abstractmethod
    async def list(self, limit: int = 50, offset: int = 0) -> List[MediaAsset]: ...
