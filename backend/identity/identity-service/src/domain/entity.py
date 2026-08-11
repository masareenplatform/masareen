"""
Universal Entity system for MASAREEN.
Allows for flexible grouping of People, Organizations, or other Entities into a single identity.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional, Dict, Any
from uuid import uuid4

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../../../.."))

from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException
from shared.events.identity_events import EntityCreated, EntityMemberAdded, EntityMemberRemoved

class EntityType(str, Enum):
    INDIVIDUAL = "INDIVIDUAL"
    ORGANIZATION = "ORGANIZATION"
    GROUP = "GROUP"               # e.g., A collaboration of people
    CONSORTIUM = "CONSORTIUM"     # e.g., A partnership of organizations
    GOVERNMENT_BODY = "GOVERNMENT_BODY"

@dataclass
class EntityRelationship:
    """Defines how entities are related (e.g., MemberOf, Sponsoring, Partner)."""
    parent_id: str
    child_id: str
    relation_type: str # "MEMBER_OF", "PARTNER", "SPONSOR"
    role: Optional[str] = None
    joined_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

@dataclass
class Entity(AggregateRoot):
    """
    The Universal Entity. Everything in MASAREEN that can have a reputation 
    or participate in a task is an Entity.
    """
    name: str = ""
    entity_type: EntityType = EntityType.INDIVIDUAL
    slug: str = ""
    description: Optional[str] = None
    logo_url: Optional[str] = None
    website: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    # Relationships to other entities
    members: List[EntityRelationship] = field(default_factory=list)
    
    @classmethod
    def create(cls, name: str, entity_type: EntityType, slug: str, **kwargs) -> "Entity":
        if not name:
            raise ValidationException("Entity name is required.")
        
        now = datetime.now(timezone.utc)
        entity_id = str(uuid4())
        entity = cls(
            id=entity_id,
            name=name,
            entity_type=entity_type,
            slug=slug,
            description=kwargs.get("description"),
            logo_url=kwargs.get("logo_url"),
            website=kwargs.get("website"),
            metadata=kwargs.get("metadata", {}),
            created_at=now,
            updated_at=now
        )
        entity.add_domain_event(EntityCreated(
            entity_id=entity_id,
            name=name,
            entity_type=entity_type.value
        ))
        return entity

    def add_member(self, member_id: str, relation: str = "MEMBER_OF", role: Optional[str] = None) -> None:
        if any(m.child_id == member_id for m in self.members):
            return # Already a member
        
        rel = EntityRelationship(
            parent_id=self.id,
            child_id=member_id,
            relation_type=relation,
            role=role
        )
        self.members.append(rel)
        self.updated_at = datetime.now(timezone.utc)
        self.add_domain_event(EntityMemberAdded(
            entity_id=self.id,
            member_id=member_id,
            relation_type=relation,
            role=role
        ))

    def remove_member(self, member_id: str) -> None:
        self.members = [m for m in self.members if m.child_id != member_id]
        self.updated_at = datetime.now(timezone.utc)
        self.add_domain_event(EntityMemberRemoved(
            entity_id=self.id,
            member_id=member_id
        ))
