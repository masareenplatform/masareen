"""Pydantic request schemas for the social-service."""
from __future__ import annotations

from pydantic import BaseModel, Field


class CreatePostRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000)
    kind: str = Field(default="story")
    program_tag: str | None = None
    sdg: int = Field(default=0, ge=0, le=17)
    impact_value: float = Field(default=0)
    impact_label: str | None = None
    media: list[dict] = Field(default_factory=list)
    # Optional author override (e.g. when the gateway does not carry full profile).
    author_name: str | None = None
    author_handle: str | None = None


class CommentRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
