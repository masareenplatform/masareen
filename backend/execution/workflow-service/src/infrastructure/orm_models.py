"""ORM models for workflow-service."""
from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from shared.base_repository.db import Base
import uuid


class WorkflowTemplateORM(Base):
    __tablename__ = "workflow_templates"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    program_id = Column(UUID(as_uuid=True), nullable=True)
    created_by = Column(UUID(as_uuid=True), nullable=True)
    steps = Column(JSONB, default=list)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class WorkflowInstanceORM(Base):
    __tablename__ = "workflow_instances"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    template_id = Column(UUID(as_uuid=True), nullable=False)
    program_id = Column(UUID(as_uuid=True), nullable=False)
    assignee_id = Column(UUID(as_uuid=True), nullable=False)
    status = Column(String(50), nullable=False, default="DRAFT")
    steps = Column(JSONB, default=list)
    current_step = Column(Integer, default=0)
    completed_steps = Column(JSONB, default=list)
    meta = Column("metadata", JSONB, default=dict)
    progress = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    version = Column(Integer, default=0)
