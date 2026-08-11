"""ORM models for authentication service."""
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from shared.base_repository.db import Base
import uuid


class AuthUserORM(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="INDIVIDUAL")
    status = Column(String(50), nullable=False, default="PENDING_VERIFICATION")
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    version = Column(Integer, default=0)


class AuthSessionORM(Base):
    __tablename__ = "auth_sessions"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    refresh_token = Column(String(500), nullable=False, index=True)
    status = Column(String(50), nullable=False, default="ACTIVE")
    device_info = Column(String(500), nullable=True)
    ip_address = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
