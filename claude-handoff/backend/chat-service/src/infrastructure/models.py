"""SQLAlchemy ORM models for the chat service.

Real persistence: conversations group messages; every message is stored with its
role (user | assistant | system) and the optional evidence/task context it was
produced for. No chat content is ever fabricated, assistant replies come from the
configured cloud LLM, or an honest "unavailable" message when not configured.
"""
from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy import String, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from shared.base_repository.db import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Conversation(Base):
    __tablename__ = "chat_conversations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: __import__("uuid").uuid4().hex)
    user_id: Mapped[str] = mapped_column(String(64), index=True)
    title: Mapped[str] = mapped_column(String(200), default="New conversation")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), default=_utcnow,
                                                onupdate=_utcnow)

    messages: Mapped[list["Message"]] = relationship(
        "Message", back_populates="conversation", cascade="all, delete-orphan",
        order_by="Message.created_at",
    )


class Message(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: __import__("uuid").uuid4().hex)
    conversation_id: Mapped[str] = mapped_column(ForeignKey("chat_conversations.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(16))  # user | assistant | system
    content: Mapped[str] = mapped_column(Text)
    context_type: Mapped[str | None] = mapped_column(String(32), nullable=True)  # evidence | task | none
    context_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), default=_utcnow)

    conversation: Mapped["Conversation"] = relationship("Conversation", back_populates="messages")
