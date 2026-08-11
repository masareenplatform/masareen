from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship
import uuid
from shared.base_repository.db import Base

class EntityORM(Base):
    __tablename__ = "entities"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    entity_type = Column(String(50), nullable=False) # INDIVIDUAL, ORGANIZATION, GROUP, etc.
    slug = Column(String(255), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=True)
    logo_url = Column(String(500), nullable=True)
    website = Column(String(500), nullable=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class EntityRelationshipORM(Base):
    __tablename__ = "entity_relationships"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("entities.id"), nullable=False, index=True)
    child_id = Column(UUID(as_uuid=True), ForeignKey("entities.id"), nullable=False, index=True)
    relation_type = Column(String(100), nullable=False) # MEMBER_OF, SPONSOR, etc.
    role = Column(String(100), nullable=True)
    joined_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
