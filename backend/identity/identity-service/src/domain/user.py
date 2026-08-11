"""
User aggregate root — the central entity of the Identity domain.

Rules:
- All state changes emit domain events
- No direct field mutation outside named methods
- Business logic lives here, NOT in the API or infrastructure layer
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, List, Optional
from uuid import uuid4

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../../..'))

from shared.base_entity import AggregateRoot
from shared.events.identity_events import UserRegistered, UserVerified, PMSUpdated
from shared.exceptions import ValidationException, ConflictException


class UserStatus(str, Enum):
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    ACTIVE               = "ACTIVE"
    SUSPENDED            = "SUSPENDED"
    DEACTIVATED          = "DEACTIVATED"


class UserRole(str, Enum):
    INDIVIDUAL   = "INDIVIDUAL"
    ORGANIZATION = "ORGANIZATION"
    ADMIN        = "ADMIN"
    SUPER_ADMIN  = "SUPER_ADMIN"

    @classmethod
    def _missing_(cls, value):
        obj = str.__new__(cls, value)
        obj._name = value.upper()
        obj._value_ = value
        return obj


class UserTargetAudience(str, Enum):
    STUDENT      = "STUDENT"
    PROFESSIONAL = "PROFESSIONAL"
    NGO          = "NGO"
    CORPORATE    = "CORPORATE"
    GOVERNMENT   = "GOVERNMENT"


@dataclass
class UserProfile:
    bio:        Optional[str]    = None
    avatar_url: Optional[str]    = None
    cover_url:  Optional[str]    = None
    country:    Optional[str]    = None
    city:       Optional[str]    = None
    languages:  List[str]        = field(default_factory=list)
    latitude:   Optional[float]  = None
    longitude:  Optional[float]  = None
    target_audience: UserTargetAudience = UserTargetAudience.STUDENT
    gallery_ids: List[str]       = field(default_factory=list)  # Impact asset IDs
    followers_count: int         = 0
    following_count: int         = 0
    website:    Optional[str]    = None
    social_links: Dict[str, str] = field(default_factory=dict)


@dataclass
class UserSkill:
    skill_id:    str
    skill_name:  str
    proficiency: str = "BEGINNER"   # BEGINNER | INTERMEDIATE | EXPERT
    verified:    bool = False


@dataclass
class User(AggregateRoot):
    """
    User aggregate root.
    Owns identity, profile, skills, and PMS score reference.
    """
    email:              str             = ""
    full_name:          str             = ""
    phone:              str             = ""            # optional at registration, validated if provided
    national_id:        str             = ""            # KYC — captured at registration or later verification
    university_id:      Optional[str]   = None          # relevant when audience == STUDENT
    role:               UserRole        = UserRole.INDIVIDUAL
    status:             UserStatus      = UserStatus.PENDING_VERIFICATION
    hashed_password:    str             = ""
    profile:            UserProfile     = field(default_factory=UserProfile)
    skills:             List[UserSkill] = field(default_factory=list)
    pms_score:          float           = 0.0
    email_verified:     bool            = False
    phone_verified:     bool            = False
    certificate_count:  int             = 0
    impact_asset_count: int             = 0

    # ── Factory ────────────────────────────────────────────────────────────────
    @classmethod
    def register(
        cls,
        email: str,
        full_name: str,
        hashed_password: str,
        phone: Optional[str] = None,
        national_id: Optional[str] = None,
        university_id: Optional[str] = None,
        role: UserRole = UserRole.INDIVIDUAL,
        audience: UserTargetAudience = UserTargetAudience.STUDENT,
    ) -> "User":
        if not email or "@" not in email:
            raise ValidationException("Invalid email address.")
        if not full_name or len(full_name.strip()) < 2:
            raise ValidationException("Full name must be at least 2 characters.")
        if not hashed_password:
            raise ValidationException("A password is required.")
        # KYC fields are optional at registration but validated when supplied.
        if phone and len(phone) < 10:
            raise ValidationException("Phone number must be at least 10 digits.")

        now = datetime.now(timezone.utc)
        user = cls(
            id=str(uuid4()),
            email=email.lower().strip(),
            full_name=full_name.strip(),
            hashed_password=hashed_password,
            phone=phone or "",
            national_id=national_id or "",
            university_id=university_id,
            role=role,
            status=UserStatus.PENDING_VERIFICATION,
            created_at=now,
            updated_at=now,
        )
        user.profile.target_audience = audience
        user.add_domain_event(UserRegistered(
            aggregate_id=user.id,
            email=user.email,
            full_name=user.full_name,
            phone=user.phone or None,
            role=user.role.value,
        ))
        return user

    # ── State transitions ─────────────────────────────────────────────────────
    def verify_email(self) -> None:
        self.email_verified = True
        self.updated_at = datetime.now(timezone.utc)
        if self.status == UserStatus.PENDING_VERIFICATION:
            self.status = UserStatus.ACTIVE
            self.add_domain_event(UserVerified(
                aggregate_id=self.id,
                verification_method="EMAIL",
            ))

    def activate(self) -> None:
        if self.status == UserStatus.ACTIVE:
            raise ConflictException("User is already active.")
        self.status = UserStatus.ACTIVE
        self.updated_at = datetime.now(timezone.utc)

    def suspend(self, reason: str) -> None:
        if self.status == UserStatus.SUSPENDED:
            raise ConflictException("User is already suspended.")
        self.status = UserStatus.SUSPENDED
        self.updated_at = datetime.now(timezone.utc)

    def update_profile(self, profile: UserProfile) -> None:
        self.profile = profile
        self.updated_at = datetime.now(timezone.utc)

    def add_skill(self, skill: UserSkill) -> None:
        existing = [s for s in self.skills if s.skill_id == skill.skill_id]
        if existing:
            raise ConflictException(f"Skill {skill.skill_id} already added.")
        self.skills.append(skill)
        self.updated_at = datetime.now(timezone.utc)

    def update_pms_score(self, new_score: float, dimensions: dict) -> None:
        previous = self.pms_score
        self.pms_score = round(new_score, 4)
        self.updated_at = datetime.now(timezone.utc)
        self.add_domain_event(PMSUpdated(
            aggregate_id=self.id,
            previous_score=previous,
            new_score=self.pms_score,
            dimensions=dimensions,
        ))

    def increment_certificate_count(self) -> None:
        self.certificate_count += 1
        self.updated_at = datetime.now(timezone.utc)

    def increment_impact_asset_count(self) -> None:
        self.impact_asset_count += 1
        self.updated_at = datetime.now(timezone.utc)

    # ── Guards ──────────────────────────────────────────────────────────────────
    @property
    def is_active(self) -> bool:
        return self.status == UserStatus.ACTIVE

    @property
    def can_submit_evidence(self) -> bool:
        return self.is_active and self.email_verified
