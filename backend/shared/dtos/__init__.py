"""
Shared Pydantic schemas used across multiple services.
These are the canonical API contract types, never import domain entities here.
"""
from __future__ import annotations
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Generic, List, Optional, TypeVar
from uuid import UUID

from pydantic import BaseModel, Field

T = TypeVar("T")


# ── Pagination ────────────────────────────────────────────────────────────────
class PaginationParams(BaseModel):
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


class PaginatedResponse(BaseModel, Generic[T]):
    items: List[T]
    total: int
    limit: int
    offset: int
    has_more: bool

    @classmethod
    def build(cls, items: List[T], total: int, limit: int, offset: int) -> "PaginatedResponse[T]":
        return cls(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
            has_more=(offset + limit) < total,
        )


# ── Standard API response envelope ────────────────────────────────────────────
class ApiResponse(BaseModel, Generic[T]):
    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None
    errors: Optional[List[str]] = None
    meta: Optional[Dict[str, Any]] = None

    @classmethod
    def ok(cls, data: T, message: str | None = None) -> "ApiResponse[T]":
        return cls(success=True, data=data, message=message)

    @classmethod
    def error(cls, errors: List[str], message: str | None = None) -> "ApiResponse[None]":
        return cls(success=False, errors=errors, message=message)


# ── Common enums (shared across services) ─────────────────────────────────────
class UserRole(str, Enum):
    INDIVIDUAL    = "INDIVIDUAL"
    ORGANIZATION  = "ORGANIZATION"
    ADMIN         = "ADMIN"
    SUPER_ADMIN   = "SUPER_ADMIN"
    AI_AGENT      = "AI_AGENT"

    @classmethod
    def _missing_(cls, value):
        obj = str.__new__(cls, value)
        obj._name = value.upper()
        obj._value_ = value
        return obj


class VerificationStatus(str, Enum):
    PENDING        = "PENDING"
    IN_REVIEW      = "IN_REVIEW"
    APPROVED       = "APPROVED"
    REJECTED       = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"


class EvidenceMediaType(str, Enum):
    PHOTO    = "PHOTO"
    VIDEO    = "VIDEO"
    AUDIO    = "AUDIO"
    DOCUMENT = "DOCUMENT"
    GPS_TRACK = "GPS_TRACK"


class TaskStatus(str, Enum):
    PENDING    = "PENDING"
    ASSIGNED   = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    SUBMITTED  = "SUBMITTED"
    VERIFIED   = "VERIFIED"
    COMPLETED  = "COMPLETED"
    CANCELLED  = "CANCELLED"


class OpportunityType(str, Enum):
    JOB          = "JOB"
    FUNDING      = "FUNDING"
    SCHOLARSHIP  = "SCHOLARSHIP"
    RESEARCH     = "RESEARCH"
    CONSULTING   = "CONSULTING"
    PARTNERSHIP  = "PARTNERSHIP"

# ── Verification ──────────────────────────────────────────────────────────────────
class VerificationRequest(BaseModel):
    request_id: Optional[UUID] = None
    submission_id: Optional[UUID] = None
    evidence_id: Optional[UUID] = None
    verification_type: str = Field(..., description="manual | automated")
    priority: str = Field(..., description="high | medium | low")
    requested_by: str

class VerificationResultRequest(BaseModel):
    evidence_id: UUID
    verifier_type: str
    verdict: str = Field(..., description="APPROVED | REJECTED | NEEDS_REVIEW")
    confidence: float = Field(..., ge=0.0, le=1.0)
    verifier_id: Optional[str] = None
    notes: Optional[str] = None


# ── Audit base ────────────────────────────────────────────────────────────────
class AuditableDTO(BaseModel):

    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
