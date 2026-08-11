from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from shared.base_repository.db import Base

class NotificationORM(Base):
    __tablename__ = "notifications"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    trigger_type = Column(String(100), nullable=False)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    payload = Column(Text, nullable=True) # Stored as JSON string
    status = Column(String(50), default="PENDING")
    channel_used = Column(String(50), nullable=True)
    sent_at = Column(DateTime(timezone=True), nullable=True)
    read_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
