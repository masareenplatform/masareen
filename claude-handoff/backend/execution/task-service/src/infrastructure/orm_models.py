from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID, ARRAY, JSONB
from shared.base_repository.db import Base
import uuid

class TaskORM(Base):
    __tablename__ = "tasks"
    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    program_id       = Column(UUID(as_uuid=True), nullable=False, index=True)
    title            = Column(String(500), nullable=False)
    description      = Column(Text, nullable=True)
    status           = Column(String(50), nullable=False, default="PENDING", index=True)
    priority         = Column(String(20), nullable=False, default="MEDIUM")
    assignee_id      = Column(UUID(as_uuid=True), nullable=True, index=True)
    supervisor_id    = Column(UUID(as_uuid=True), nullable=True)
    due_date         = Column(DateTime(timezone=True), nullable=True)
    geofence_lat     = Column(Float, nullable=True)
    geofence_lon     = Column(Float, nullable=True)
    geofence_radius  = Column(Integer, default=500)
    evidence_required= Column(Boolean, default=True)
    evidence_ids     = Column(ARRAY(String), default=list)
    status_history   = Column(JSONB, default=list)
    tags             = Column(ARRAY(String), default=list)
    estimated_hours  = Column(Float, nullable=True)
    actual_hours     = Column(Float, nullable=True)
    created_by       = Column(UUID(as_uuid=True), nullable=True)
    created_at       = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at       = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    version          = Column(Integer, default=0)
