"""Cloud LLM client for the chat service.

Reuses the same Google Generative AI provider configured for the rest of the
platform (``GOOGLE_API_KEY`` / ``CLOUD_API_KEY``). The client is built lazily
so the service imports and serves history/persistence even when no key is set; an
assistant reply is only generated when the provider is configured. When it is not,
:meth:`ChatLLMClient.reply` returns ``None`` and the API layer emits an honest
"assistant unavailable" message, never a fabricated answer.
"""
from __future__ import annotations

from typing import List, Dict, Optional

from shared.utils.config_loader import get_google_api_key


class ChatLLMClient:
    def __init__(self) -> None:
        self._client = None
        self._available = False
        key = get_google_api_key()
        if not key:
            return
        try:  # pragma: no cover - requires optional langchain dep + key
            from langchain_google_genai import ChatGoogleGenerativeAI
            self._client = ChatGoogleGenerativeAI(
                model="gemma-4-31b-it",
                google_api_key=key,
                temperature=0.3,
            )
            self._available = True
        except Exception:
            self._client = None
            self._available = False

    @property
    def available(self) -> bool:
        return self._available

    async def reply(self, history: List[Dict[str, str]], user_prompt: str) -> Optional[str]:
        if not self._available or self._client is None:
            return None
        messages = list(history) + [{"role": "user", "content": user_prompt}]
        # langchain expects (role, content) tuples for chat models.
        lc_messages = [(m["role"], m["content"]) for m in messages]
        response = await self._client.ainvoke(lc_messages)
        # AIMessage.content is usually str, but may be a list of parts.
        content = getattr(response, "content", None)
        if isinstance(content, list):
            content = " ".join(
                part if isinstance(part, str) else getattr(part, "text", "")
                for part in content
            ).strip()
        return content or None
