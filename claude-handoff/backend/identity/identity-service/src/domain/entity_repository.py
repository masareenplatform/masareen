from typing import List, Optional
from .entity import Entity

class EntityRepository:
    async def save(self, entity: Entity) -> Entity:
        raise NotImplementedError

    async def get_by_id(self, entity_id: str) -> Optional[Entity]:
        raise NotImplementedError

    async def get_by_slug(self, slug: str) -> Optional[Entity]:
        raise NotImplementedError

    async def list_members(self, entity_id: str) -> List[str]:
        raise NotImplementedError
