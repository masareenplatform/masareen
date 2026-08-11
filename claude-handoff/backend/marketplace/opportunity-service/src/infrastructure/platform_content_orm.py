from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Float, Integer, String, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from shared.base_repository.db import Base

class PlatformPostORM(Base):
    __tablename__ = "platform_posts"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    content_type = Column(String(50), nullable=False) # AD, EDUCATIONAL, ANNOUNCEMENT
    media_url = Column(String(500), nullable=True)
    target_audience = Column(String, nullable=False) # Comma separated or JSON
    is_active = Column(Boolean, default=True)
    priority = Column(Integer, default=0)
    spend_limit = Column(Float, nullable=True)
    current_spend = Column(Float, default=0.0)
    clicks = Column(Integer, default=0)
    impressions = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
