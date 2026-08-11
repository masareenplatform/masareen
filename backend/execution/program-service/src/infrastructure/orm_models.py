from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID, ARRAY, JSONB
from shared.base_repository.db import Base
import uuid

class ProgramORM(Base):
    __tablename__ = "programs"
    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    title           = Column(String(500), nullable=False)
    description     = Column(Text, nullable=True)
    status          = Column(String(50), nullable=False, default="DRAFT")
    start_date      = Column(Date, nullable=True)
    end_date        = Column(Date, nullable=True)
    sdg_goals       = Column(ARRAY(Integer), default=list)
    country         = Column(String(100), nullable=True)
    city            = Column(String(100), nullable=True)
    latitude        = Column(Float, nullable=True)
    longitude       = Column(Float, nullable=True)
    max_participants= Column(Integer, nullable=True)
    enrolled_count  = Column(Integer, default=0)
    milestones      = Column(JSONB, default=list)
    tags            = Column(ARRAY(String), default=list)
    created_by      = Column(UUID(as_uuid=True), nullable=True)
    created_at      = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at      = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    version         = Column(Integer, default=0)
