"""Repository for chat persistence, real PostgreSQL via SQLAlchemy async sessions."""
from __future__ import annotations

from typing import List, Optional
from uuid import uuid4

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from .models import Conversation, Message


class ChatRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_conversation(self, user_id: str, title: str = "New conversation") -> Conversation:
        conv = Conversation(id=uuid4().hex, user_id=user_id, title=title)
        self._session.add(conv)
        await self._session.flush()
        return conv

    async def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        return await self._session.get(Conversation, conversation_id)

    async def list_conversations(self, user_id: str, limit: int = 50, offset: int = 0) -> List[Conversation]:
        result = await self._session.execute(
            select(Conversation)
            .where(Conversation.user_id == user_id)
            .order_by(desc(Conversation.updated_at))
            .limit(limit).offset(offset)
        )
        return list(result.scalars().all())

    async def add_message(self, conversation_id: str, role: str, content: str,
                         context_type: Optional[str] = None,
                         context_id: Optional[str] = None) -> Message:
        msg = Message(
            id=uuid4().hex,
            conversation_id=conversation_id,
            role=role,
            content=content,
            context_type=context_type,
            context_id=context_id,
        )
        self._session.add(msg)
        await self._session.flush()
        return msg

    async def get_messages(self, conversation_id: str) -> List[Message]:
        result = await self._session.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at)
        )
        return list(result.scalars().all())
