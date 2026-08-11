from abc import ABC, abstractmethod
from typing import List, Optional
from uuid import UUID
from shared.base_repository import Repository, ReadRepository
from .submission import SubmissionBundle


class SubmissionRepository(Repository[SubmissionBundle], ReadRepository[SubmissionBundle], ABC):
    """Repository for SubmissionBundle aggregates with read operations.
    
    Implements Event Sourcing pattern with projection-based reads.
    This is a port interface for all persistence operations.
    """
    
    @abstractmethod
    async def get_by_id(self, entity_id: UUID) -> Optional[SubmissionBundle]: ...
    
    @abstractmethod
    async def get_by_task(self, task_id: str) -> Optional[SubmissionBundle]: ...
    
    @abstractmethod
    async def get_by_submitter(self, user_id: str, limit: int = 50, offset: int = 0) -> tuple[List[SubmissionBundle], int]: ...
