"""SQLAlchemy ORM models for posts, likes and bookmarks."""
from __future__ import annotations

from sqlalchemy import JSON, Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class PostORM(Base):
    __tablename__ = "posts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    author_id: Mapped[str] = mapped_column(String, index=True)
    author_name: Mapped[str] = mapped_column(String, default="")
    author_handle: Mapped[str] = mapped_column(String, default="")
    author_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    author_role: Mapped[str] = mapped_column(String, default="Individual")
    text: Mapped[str] = mapped_column(String, default="")
    kind: Mapped[str] = mapped_column(String, default="story")
    program_tag: Mapped[str | None] = mapped_column(String, nullable=True)
    sdg: Mapped[int] = mapped_column(Integer, default=0)
    impact_value: Mapped[float] = mapped_column(Float, default=0)
    impact_label: Mapped[str | None] = mapped_column(String, nullable=True)
    confidence: Mapped[float] = mapped_column(Float, default=50.0)
    media: Mapped[list] = mapped_column(JSON, default=list)
    comments: Mapped[list] = mapped_column(JSON, default=list)
    likes: Mapped[int] = mapped_column(Integer, default=0)
    shares: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[object] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class LikeORM(Base):
    """Per-user like rows so `likedByMe` is accurate per requesting user."""

    __tablename__ = "post_likes"
    user_id: Mapped[str] = mapped_column(String, primary_key=True)
    post_id: Mapped[str] = mapped_column(String, primary_key=True)


class BookmarkORM(Base):
    """Per-user saved posts (bookmarks)."""

    __tablename__ = "post_bookmarks"
    user_id: Mapped[str] = mapped_column(String, primary_key=True)
    post_id: Mapped[str] = mapped_column(String, primary_key=True)
