"""GPS Repository Interface."""
from abc import ABC, abstractmethod
from typing import Optional, List
from .gps_record import GPSRecord


class GPSRepository(ABC):
    @abstractmethod
    async def get_by_id(self, entity_id: str) -> Optional[GPSRecord]:
        pass

    @abstractmethod
    async def save(self, entity: GPSRecord) -> GPSRecord:
        pass

    @abstractmethod
    async def find_by_checksum(self, checksum: str) -> Optional[GPSRecord]:
        pass

    @abstractmethod
    async def find_by_task_id(self, task_id: str) -> List[GPSRecord]:
        pass

    @abstractmethod
    async def find_by_user_id(self, user_id: str) -> List[GPSRecord]:
        pass

    @abstractmethod
    async def delete(self, entity_id: str) -> None:
        pass