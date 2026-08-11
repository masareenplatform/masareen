"""Request and response schemas for the identity-service API."""
from __future__ import annotations
from datetime import datetime
from typing import Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator


# ── Request schemas ───────────────────────────────────────────────────────────
class RegisterUserRequest(BaseModel):
    email:     EmailStr
    full_name: str  = Field(..., min_length=2, max_length=255)
    password:  str  = Field(..., min_length=8, max_length=128)
    phone:     Optional[str] = None
    national_id: Optional[str] = Field(None, max_length=64)
    university_id: Optional[str] = Field(None, max_length=64)
    role:      str  = Field(default="INDIVIDUAL")
    audience:  str  = Field(default="STUDENT")

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        import re
        password_regex = r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$"
        if not re.match(password_regex, v):
            raise ValueError("Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one digit, and one special character.")
        return v

    @field_validator("role")
    @classmethod
    def valid_role(cls, v: str) -> str:
        allowed = {"INDIVIDUAL", "ORGANIZATION"}
        if v not in allowed:
            raise ValueError(f"Role must be one of {allowed}")
        return v

    @field_validator("audience")
    @classmethod
    def valid_audience(cls, v: str) -> str:
        allowed = {"STUDENT", "PROFESSIONAL", "NGO", "CORPORATE", "GOVERNMENT"}
        if v not in allowed:
            raise ValueError(f"Audience must be one of {allowed}")
        return v


class UpdateProfileRequest(BaseModel):
    bio:        Optional[str]        = Field(None, max_length=1000)
    avatar_url: Optional[str]        = None
    country:    Optional[str]        = None
    city:       Optional[str]        = None
    languages:  Optional[List[str]]  = None
    latitude:   Optional[float]      = Field(None, ge=-90,  le=90)
    longitude:  Optional[float]      = Field(None, ge=-180, le=180)


class AddSkillRequest(BaseModel):
    skill_id:   str
    skill_name: str  = Field(..., min_length=2, max_length=100)
    proficiency: str = Field(default="BEGINNER")

    @field_validator("proficiency")
    @classmethod
    def valid_proficiency(cls, v: str) -> str:
        if v not in {"BEGINNER", "INTERMEDIATE", "EXPERT"}:
            raise ValueError("proficiency must be BEGINNER | INTERMEDIATE | EXPERT")
        return v


class VerifyEmailRequest(BaseModel):
    token: str = Field(..., min_length=6)


# ── Response schemas ──────────────────────────────────────────────────────────
class SkillResponse(BaseModel):
    skill_id:    str
    skill_name:  str
    proficiency: str
    verified:    bool

    class Config:
        from_attributes = True


class UserProfileResponse(BaseModel):
    bio:        Optional[str]
    avatar_url: Optional[str]
    cover_url:  Optional[str]
    country:    Optional[str]
    city:       Optional[str]
    languages:  List[str]
    latitude:   Optional[float]
    longitude:  Optional[float]
    target_audience: Optional[str]
    gallery_ids: List[str] = Field(default_factory=list)
    followers_count: int = 0
    following_count: int = 0
    website:    Optional[str]
    social_links: Dict[str, str] = Field(default_factory=dict)


class UserResponse(BaseModel):
    id:             str
    email:          str
    full_name:      str
    phone:          Optional[str]
    role:           str
    status:         str
    pms_score:      float
    email_verified: bool
    skills:         List[SkillResponse]
    profile:        Optional[UserProfileResponse]
    created_at:     datetime
    updated_at:     datetime


class ImpactPassportResponse(BaseModel):
    user_id:        str
    full_name:      str
    pms_score:      float
    tier:           str
    passport_id:    str
    email_verified: bool
    skills_count:   int


class RegisterUserResponse(BaseModel):
    user_id: str
    email:   str
    status:  str
    auto_verified: bool = False
    message: str = "Registration successful."
