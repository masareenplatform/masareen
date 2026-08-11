"""Skill catalogue entity."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional
from uuid import uuid4


@dataclass
class Skill:
    id:       str
    name:     str
    category: Optional[str] = None
    slug:     str = ""

    @classmethod
    def create(cls, name: str, category: Optional[str] = None) -> "Skill":
        slug = name.lower().replace(" ", "-")
        return cls(id=str(uuid4()), name=name, category=category, slug=slug)
