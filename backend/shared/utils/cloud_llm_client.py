"""
Cloud LLM Client abstraction for MASAREEN AI agents.
Sourced from Gemini 1.5's multimodal capabilities to handle PDF, Video, Audio, and Images.
"""
from __future__ import annotations
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional
import httpx
import json
import logging

logger = logging.getLogger(__name__)

class LLMProvider(str, Enum):
    OPENAI  = "openai"
    GOOGLE  = "google"
    BEDROCK = "bedrock"

@dataclass
class LLMMessage:
    role:    str   # "system" | "user" | "assistant"
    content: str

@dataclass
class LLMResponse:
    text:        str
    provider:    str
    model:       str
    input_tokens:  int = 0
    output_tokens: int = 0
    raw:         Optional[Dict] = None

class CloudLLMClient(ABC):
    """Port (interface) for all cloud LLM interactions."""

    @abstractmethod
    async def complete(
        self,
        messages: List[LLMMessage],
        model: Optional[str] = None,
        temperature: float = 0.2,
        max_tokens: int = 2048,
        json_mode: bool = False,
    ) -> LLMResponse: ...

    @abstractmethod
    async def complete_with_media(
        self,
        prompt: str,
        media_bytes: bytes,
        mime_type: str,
        model: Optional[str] = None,
    ) -> LLMResponse: ...

    @abstractmethod
    async def embed(self, text: str) -> List[float]: ...

class OpenAIClient(CloudLLMClient):
    DEFAULT_MODEL = "gpt-4o"
    DEFAULT_VISION_MODEL = "gpt-4o"
    DEFAULT_EMBED_MODEL = "text-embedding-3-small"
    BASE_URL = "https://api.openai.com/v1"

    def __init__(self, api_key: str) -> None:
        self._api_key = api_key
        self._headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    async def complete(self, messages: List[LLMMessage], model: Optional[str] = None, temperature: float = 0.2, max_tokens: int = 2048, json_mode: bool = False) -> LLMResponse:
        body = {"model": model or self.DEFAULT_MODEL, "messages": [{"role": m.role, "content": m.content} for m in messages], "temperature": temperature, "max_tokens": max_tokens}
        if json_mode: body["response_format"] = {"type": "json_object"}
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{self.BASE_URL}/chat/completions", headers=self._headers, json=body)
            resp.raise_for_status()
            data = resp.json()
        return LLMResponse(text=data["choices"][0]["message"]["content"], provider="openai", model=data.get("model", self.DEFAULT_MODEL), raw=data)

    async def complete_with_media(self, prompt: str, media_bytes: bytes, mime_type: str, model: Optional[str] = None) -> LLMResponse:
        import base64
        b64 = base64.b64encode(media_bytes).decode()
        messages = [{"role": "user", "content": [{"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{b64}"}}, {"type": "text", "text": prompt}]}]
        body = {"model": model or self.DEFAULT_VISION_MODEL, "messages": messages, "max_tokens": 2048}
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(f"{self.BASE_URL}/chat/completions", headers=self._headers, json=body)
            resp.raise_for_status()
            data = resp.json()
        return LLMResponse(text=data["choices"][0]["message"]["content"], provider="openai", model=data.get("model", self.DEFAULT_VISION_MODEL), raw=data)

    async def embed(self, text: str) -> List[float]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(f"{self.BASE_URL}/embeddings", headers=self._headers, json={"model": self.DEFAULT_EMBED_MODEL, "input": text})
            resp.raise_for_status()
            return resp.json()["data"][0]["embedding"]

class GoogleAIClient(CloudLLMClient):
    DEFAULT_MODEL = "gemini-1.5-flash"
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: str) -> None:
        self._api_key = api_key

    async def complete(self, messages: List[LLMMessage], model: Optional[str] = None, temperature: float = 0.2, max_tokens: int = 2048, json_mode: bool = False) -> LLMResponse:
        mdl = model or self.DEFAULT_MODEL
        parts = []
        for m in messages:
            if m.role == "system": parts.insert(0, {"role": "user", "parts": [{"text": f"[System]: {m.content}"}]})
            else: parts.append({"role": m.role, "parts": [{"text": m.content}]})
        body = {"contents": parts, "generationConfig": {"temperature": temperature, "maxOutputTokens": max_tokens}}
        if json_mode: body["generationConfig"]["responseMimeType"] = "application/json"
        url = f"{self.BASE_URL}/{mdl}:generateContent?key={self._api_key}"
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, json=body)
            resp.raise_for_status()
            data = resp.json()
        return LLMResponse(text=data["candidates"][0]["content"]["parts"][0]["text"], provider="google", model=mdl, raw=data)

    async def complete_with_media(self, prompt: str, media_bytes: bytes, mime_type: str, model: Optional[str] = None) -> LLMResponse:
        import base64
        mdl = model or "gemini-1.5-pro"
        b64 = base64.b64encode(media_bytes).decode()
        body = {"contents": [{"parts": [{"inline_data": {"mime_type": mime_type, "data": b64}}, {"text": prompt}]}]}
        url = f"{self.BASE_URL}/{mdl}:generateContent?key={self._api_key}"
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(url, json=body)
            resp.raise_for_status()
            data = resp.json()
        return LLMResponse(text=data["candidates"][0]["content"]["parts"][0]["text"], provider="google", model=mdl, raw=data)

    async def embed(self, text: str) -> List[float]:
        url = f"{self.BASE_URL}/text-embedding-004:embedContent?key={self._api_key}"
        body = {"model": "models/text-embedding-004", "content": {"parts": [{"text": text}]}}
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=body)
            resp.raise_for_status()
            return resp.json()["embedding"]["values"]

def build_llm_client(provider: str, api_key: str) -> CloudLLMClient:
    p = LLMProvider(provider.lower())
    if p == LLMProvider.OPENAI: return OpenAIClient(api_key)
    if p == LLMProvider.GOOGLE: return GoogleAIClient(api_key)
    raise NotImplementedError(f"Provider '{provider}' not yet implemented.")
