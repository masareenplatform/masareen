"""SQLAlchemy ORM models for the identity-service."""
from __future__ import annotations
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey,
    Index, String, Text, Integer, ARRAY
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import uuid

from shared.base_repository.db import Base


class UserORM(Base):
    __tablename__ = "users"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email            = Column(String(255), unique=True, nullable=False, index=True)
    phone            = Column(String(50), nullable=True)
    full_name         = Column(String(255), nullable=False)
    role             = Column(String(50), nullable=False, default="INDIVIDUAL")
    status           = Column(String(50), nullable=False, default="PENDING_VERIFICATION")
    hashed_password  = Column(String(255), nullable=False)
    email_verified   = Column(Boolean, default=False, nullable=False)
    phone_verified   = Column(Boolean, default=False, nullable=False)
    pms_score        = Column(Float, default=0.0, nullable=False)
    certificate_count = Column(Integer, default=0, nullable=False)
    impact_asset_count = Column(Integer, default=0, nullable=False)
    created_at       = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at       = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    version          = Column(Integer, default=0, nullable=False)

    profile          = relationship("UserProfileORM", back_populates="user", uselist=False, cascade="all, delete-orphan", lazy="selectin")
    skills           = relationship("UserSkillORM", back_populates="user", cascade="all, delete-orphan", lazy="selectin")

    __table_args__ = (
        Index("idx_users_email", "email"),
        Index("idx_users_role",  "role"),
        Index("idx_users_status","status"),
    )


class UserProfileORM(Base):
    __tablename__ = "user_profiles"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    bio        = Column(Text, nullable=True)
    avatar_url = Column(String(500), nullable=True)
    cover_url  = Column(String(500), nullable=True)
    country    = Column(String(100), nullable=True)
    city       = Column(String(100), nullable=True)
    languages  = Column(ARRAY(String), default=list)
    latitude   = Column(Float, nullable=True)
    longitude  = Column(Float, nullable=True)
    target_audience = Column(String(50), nullable=True)
    gallery_ids = Column(ARRAY(UUID(as_uuid=True)), default=list)
    followers_count = Column(Integer, default=0, nullable=False)
    following_count = Column(Integer, default=0, nullable=False)
    website    = Column(String(500), nullable=True)
    social_links = Column(JSONB, default=dict)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user       = relationship("UserORM", back_populates="profile")


class UserSkillORM(Base):
    __tablename__ = "user_skills"

    user_id     = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    skill_id    = Column(UUID(as_uuid=True), ForeignKey("skills.id", ondelete="CASCADE"), primary_key=True)
    proficiency = Column(String(50), default="BEGINNER")
    verified    = Column(Boolean, default=False)

    user        = relationship("UserORM", back_populates="skills")
    skill       = relationship("SkillORM", lazy="selectin")


class FollowORM(Base):
    __tablename__ = "follows"

    follower_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    followee_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at  = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        Index("idx_follows_follower", "follower_id"),
        Index("idx_follows_followee", "followee_id"),
    )


class SkillORM(Base):
    __tablename__ = "skills"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name       = Column(String(255), unique=True, nullable=False)
    category   = Column(String(100), nullable=True)
    slug       = Column(String(255), unique=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
