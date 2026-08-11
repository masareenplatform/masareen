from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Index, Integer, String, Text, JSON
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship
import uuid
from shared.base_repository.db import Base

class OrganizationORM(Base):
    __tablename__ = "organizations"
    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name        = Column(String(255), nullable=False)
    slug        = Column(String(255), unique=True, nullable=False, index=True)
    org_type    = Column(String(100), nullable=False)
    status      = Column(String(50), nullable=False, default="PENDING")
    description = Column(Text, nullable=True)
    website     = Column(String(500), nullable=True)
    logo_url    = Column(String(500), nullable=True)
    country     = Column(String(100), nullable=False)
    city        = Column(String(100), nullable=True)
    oii_score   = Column(Float, default=0.0)
    verified    = Column(Boolean, default=False)
    member_ids  = Column(ARRAY(String), default=list)
    admin_ids   = Column(ARRAY(String), default=list)
    created_at  = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at  = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    version     = Column(Integer, default=0)

class MediaInstitutionProfileORM(Base):
    __tablename__ = "media_profiles"
    org_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), primary_key=True)
    distribution_channels = Column(ARRAY(String), default=list)
    content_strategy = Column(Text, nullable=True)
    verification_level = Column(String(100), default="STANDARD")
    official_handle = Column(String(255), nullable=True)

class SportsInstitutionProfileORM(Base):
    __tablename__ = "sports_profiles"
    org_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), primary_key=True)
    league = Column(String(255), nullable=True)
    division = Column(String(255), nullable=True)
    trophies = Column(JSON, default=list)
    stadium_name = Column(String(255), nullable=True)
    stadium_capacity = Column(Integer, nullable=True)

class PlayerProfileORM(Base):
    __tablename__ = "player_profiles"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    org_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=True)
    position = Column(String(100), nullable=True)
    jersey_number = Column(Integer, nullable=True)
    career_stats = Column(JSON, default=dict)
    birth_date = Column(DateTime(timezone=True), nullable=True)
    nationality = Column(String(100), nullable=True)

class EducationInstitutionProfileORM(Base):
    __tablename__ = "education_profiles"
    org_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), primary_key=True)
    accreditations = Column(ARRAY(String), default=list)
    ranking_global = Column(Integer, nullable=True)
    specializations = Column(ARRAY(String), default=list)
    campus_count = Column(Integer, default=1)

class GovernmentInstitutionProfileORM(Base):
    __tablename__ = "government_profiles"
    org_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), primary_key=True)
    jurisdiction = Column(String(255), nullable=False)
    department_head = Column(String(255), nullable=True)
    transparency_rating = Column(Float, default=0.0)
    service_categories = Column(ARRAY(String), default=list)

class TimelineEventORM(Base):
    __tablename__ = "timeline_events"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entity_id = Column(UUID(as_uuid=True), nullable=False, index=True) # User or Org ID
    event_type = Column(String(100), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    media_url = Column(String(500), nullable=True)
    metric_value = Column(Float, nullable=True)
    metadata_json = Column(JSON, default=dict)
