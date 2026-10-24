from typing import List, Optional
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
import json
from ..domain.entity import Entity, EntityType, EntityRelationship
from ..domain.entity_repository import EntityRepository
from .entity_orm import EntityORM, EntityRelationshipORM
import uuid

class SQLAlchemyEntityRepository(EntityRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    def _to_domain(self, o: EntityORM) -> Entity:
        return Entity(
            id=str(o.id),
            name=o.name,
            entity_type=EntityType(o.entity_type),
            slug=o.slug,
            description=o.description,
            logo_url=o.logo_url,
            website=o.website,
            metadata=json.loads(o.metadata_json) if o.metadata_json else {},
            created_at=o.created_at,
            updated_at=o.updated_at
        )

    async def save(self, entity: Entity) -> Entity:
        orm = EntityORM(
            id=uuid.UUID(entity.id),
            name=entity.name,
            entity_type=entity.entity_type.value,
            slug=entity.slug,
            description=entity.description,
            logo_url=entity.logo_url,
            website=entity.website,
            metadata_json=json.dumps(entity.metadata),
            updated_at=entity.updated_at
        )
        await self._session.merge(orm)

        # Relationship sync: delete the parent's existing edges, then re-insert
        # the current set. This keeps the stored graph consistent with the
        # aggregate on every save.
        await self._session.execute(
            delete(EntityRelationshipORM).where(
                EntityRelationshipORM.parent_id == uuid.UUID(entity.id))
        )

        for rel in entity.members:
            rel_orm = EntityRelationshipORM(
                parent_id=uuid.UUID(entity.id),
                child_id=uuid.UUID(rel.child_id),
                relation_type=rel.relation_type,
                role=rel.role
            )
            self._session.add(rel_orm)
            
        await self._session.flush()
        return entity

    async def get_by_id(self, entity_id: str) -> Optional[Entity]:
        row = await self._session.get(EntityORM, uuid.UUID(entity_id))
        if not row: return None
        
        entity = self._to_domain(row)

        # Rehydrate relationships directly (do NOT use add_member, that would
        # emit spurious EntityMemberAdded domain events during reconstruction).
        rels = await self._session.execute(
            select(EntityRelationshipORM).where(EntityRelationshipORM.parent_id == uuid.UUID(entity_id))
        )
        for r in rels.scalars().all():
            entity.members.append(EntityRelationship(
                parent_id=str(entity_id),
                child_id=str(r.child_id),
                relation_type=r.relation_type,
                role=r.role,
            ))

        return entity

    async def get_by_slug(self, slug: str) -> Optional[Entity]:
        stmt = select(EntityORM).where(EntityORM.slug == slug)
        result = await self._session.execute(stmt)
        row = result.scalar_one_or_none()
        return self._to_domain(row) if row else None

    async def list_members(self, entity_id: str) -> List[str]:
        stmt = select(EntityRelationshipORM.child_id).where(EntityRelationshipORM.parent_id == uuid.UUID(entity_id))
        result = await self._session.execute(stmt)
        return [str(r) for r in result.scalars().all()]
