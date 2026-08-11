from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from shared.base_repository.db import Base

class ReviewQueueORM(Base):
    __tablename__ = "review_queue"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entity_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    entity_type = Column(String(50), nullable=False)
    confidence_score = Column(Float, nullable=False)
    assigned_admin_id = Column(UUID(as_uuid=True), nullable=True)
    status = Column(String(50), default="PENDING")
    admin_verdict = Column(String(100), nullable=True)
    admin_comments = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    resolved_at = Column(DateTime(timezone=True), nullable=True)
