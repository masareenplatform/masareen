"""Chat service API — conversational assistant with real persistence.

Assistant replies come from the configured cloud LLM (``ChatLLMClient``). When no
provider key is configured the client is unavailable and the API returns an honest
"assistant unavailable" message — it never fabricates a reply.
"""
from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from ..infrastructure.chat_repository import ChatRepository
from ..infrastructure.database import get_session
from ..infrastructure.llm_client import ChatLLMClient

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])

# Module-level singleton — swapped by tests via ``src.api._llm``.
_llm = ChatLLMClient()


class ConversationCreate(BaseModel):
    user_id: str
    title: str = "New conversation"


class MessageCreate(BaseModel):
    user_id: str
    content: str
    context_type: Optional[str] = None
    context_id: Optional[str] = None


class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    context_type: Optional[str] = None
    context_id: Optional[str] = None


@router.post("/conversations", status_code=201)
async def create_conversation(
    payload: ConversationCreate,
    session: AsyncSession = Depends(get_session),
):
    repo = ChatRepository(session)
    conv = await repo.create_conversation(payload.user_id, payload.title)
    return {"data": {"id": conv.id, "user_id": conv.user_id, "title": conv.title}}


@router.get("/conversations")
async def list_conversations(
    user_id: str,
    limit: int = 50,
    offset: int = 0,
    session: AsyncSession = Depends(get_session),
):
    repo = ChatRepository(session)
    convs = await repo.list_conversations(user_id, limit=limit, offset=offset)
    return {
        "data": [
            {"id": c.id, "user_id": c.user_id, "title": c.title} for c in convs
        ]
    }


@router.get("/conversations/{conversation_id}/messages")
async def get_messages(
    conversation_id: str,
    session: AsyncSession = Depends(get_session),
):
    repo = ChatRepository(session)
    msgs = await repo.get_messages(conversation_id)
    return {
        "data": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "context_type": m.context_type,
                "context_id": m.context_id,
            }
            for m in msgs
        ]
    }


@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: str,
    payload: MessageCreate,
    session: AsyncSession = Depends(get_session),
):
    repo = ChatRepository(session)
    conv = await repo.get_conversation(conversation_id)
    if conv is None:
        raise HTTPException(status_code=404, detail="conversation_not_found")

    await repo.add_message(
        conversation_id, "user", payload.content,
        context_type=payload.context_type, context_id=payload.context_id,
    )

    history: List[dict] = [
        {"role": m.role, "content": m.content}
        for m in await repo.get_messages(conversation_id)
    ]
    # drop the just-added user message from history sent to the model
    model_history = history[:-1] if history else []

    reply = await _llm.reply(model_history, payload.content)
    if reply is None:
        reply = (
            "Assistant is currently unavailable. Your message was saved — "
            "please try again later."
        )

    await repo.add_message(conversation_id, "assistant", reply,
                           context_type=payload.context_type,
                           context_id=payload.context_id)
    return {"data": {"assistant_reply": reply}}
