"""Athlete passport model, implements the canonical sports profile
from the MASAREN Sports Profiling Blueprint (Doc 3, §2 Canonical Sports Profile).

The passport is composed of five independent record domains, each owned by
a specific authoritative source. The athlete controls public visibility;
institutions own registrations; federations own eligibility; medical professionals
own welfare records.

Usage:
    from shared.utils.athlete_passport import (
        AthletePassport,
        ProfileIdentity,
        SportParticipation,
        PerformanceRecord,
        WelfareRecord,
        PublicShowcase,
    )
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID, uuid4


# ── Enums ─────────────────────────────────────────────────────────────────────

class VerificationSource(str, Enum):
    """Who issued a verification claim."""
    FEDERATION = "federation"
    CLUB = "club"
    ACADEMY = "academy"
    COMPETITION_ORGANIZER = "competition_organizer"
    TIMING_PROVIDER = "timing_provider"
    COACH = "coach"
    ATHLETE = "athlete"
    EDITORIAL = "editorial"
    MINISTRY = "ministry"


class WelfareStatus(str, Enum):
    """Public-facing welfare statement (Doc 3 §2 Private welfare record)."""
    ELIGIBLE = "eligible"
    TEMPORARILY_UNAVAILABLE = "temporarily_unavailable"
    CLEARANCE_REQUIRED = "clearance_required"


class RegistrationStatus(str, Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    TRANSFERRED = "transferred"
    RETIRED = "retired"
    EXPIRED = "expired"


class ConsentLevel(str, Enum):
    """Visibility levels for profile data."""
    PRIVATE = "private"
    INSTITUTION = "institution"
    PUBLIC = "public"


# ── Value objects ─────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class VerifiedClaim:
    """A claim attached to a specific source with provenance."""
    claim: str
    source: VerificationSource
    source_id: Optional[str] = None          # issuer's own ID (e.g. federation licence number)
    verified_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    evidence_url: Optional[str] = None
    confidence: float = 1.0

    def to_dict(self) -> dict:
        return {
            "claim": self.claim,
            "source": self.source.value,
            "source_id": self.source_id,
            "verified_at": self.verified_at.isoformat() if self.verified_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "evidence_url": self.evidence_url,
            "confidence": self.confidence,
        }


@dataclass
class ProfileIdentity:
    """§2 Profile identity, stable athlete identifier with verified personal data.

    Public pages never expose government identifiers, precise home location,
    or private contact details.
    """
    athlete_id: UUID = field(default_factory=uuid4)
    full_name_en: str = ""
    full_name_ar: str = ""
    preferred_public_name: str = ""
    date_of_birth: Optional[date] = None
    nationality: str = ""
    representation_country: Optional[str] = None
    guardian_id: Optional[UUID] = None        # required for minors
    is_minor: bool = False
    government_id_hash: Optional[str] = None  # stored hashed, never exposed
    federation_ids: Dict[str, str] = field(default_factory=dict)  # federation → athlete identifier
    consent_level: ConsentLevel = ConsentLevel.PRIVATE
    identity_verified: bool = False

    def to_dict(self) -> dict:
        return {
            "athlete_id": str(self.athlete_id),
            "full_name_en": self.full_name_en,
            "full_name_ar": self.full_name_ar,
            "preferred_public_name": self.preferred_public_name,
            "date_of_birth": self.date_of_birth.isoformat() if self.date_of_birth else None,
            "nationality": self.nationality,
            "representation_country": self.representation_country,
            "is_minor": self.is_minor,
            "consent_level": self.consent_level.value,
            "identity_verified": self.identity_verified,
            "federation_ids": self.federation_ids,
        }


@dataclass
class SportParticipation:
    """§2 Sport participation, disciplines, teams, registrations, validity periods."""
    id: UUID = field(default_factory=uuid4)
    sport: str = ""
    discipline: Optional[str] = None         # e.g. "freestyle 100m", "middleweight"
    position: Optional[str] = None
    classification: Optional[str] = None     # para-sport classification
    club_id: Optional[UUID] = None
    club_name: Optional[str] = None
    federation_id: Optional[UUID] = None
    federation_name: Optional[str] = None
    registration_status: RegistrationStatus = RegistrationStatus.ACTIVE
    valid_from: Optional[date] = None
    valid_until: Optional[date] = None
    season: Optional[str] = None             # e.g. "2025-2026"
    evidence: List[VerifiedClaim] = field(default_factory=list)
    revoked: bool = False
    revocation_reason: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "sport": self.sport,
            "discipline": self.discipline,
            "position": self.position,
            "classification": self.classification,
            "club_name": self.club_name,
            "federation_name": self.federation_name,
            "registration_status": self.registration_status.value,
            "valid_from": self.valid_from.isoformat() if self.valid_from else None,
            "valid_until": self.valid_until.isoformat() if self.valid_until else None,
            "season": self.season,
            "revoked": self.revoked,
            "evidence": [e.to_dict() for e in self.evidence],
        }


@dataclass
class PerformanceMetric:
    """§2 Performance record, a signed observation from an authorized source."""
    id: UUID = field(default_factory=uuid4)
    sport: str = ""
    event: str = ""                           # e.g. "100m freestyle", "clean & jerk"
    metric_name: str = ""                     # e.g. "finish_time", "total_kg"
    value: float = 0.0
    unit: str = ""                            # e.g. "seconds", "kg", "points"
    context: str = ""                         # e.g. "competition", "training", "test"
    source: VerificationSource = VerificationSource.ATHLETE
    source_detail: str = ""                   # e.g. "FINA", "Egyptian Weightlifting Fed."
    collection_method: Optional[str] = None   # e.g. "official_timing", "coach_assessment"
    confidence: float = 1.0
    recorded_at: Optional[datetime] = None
    competition_id: Optional[str] = None
    rank: Optional[int] = None
    medal: Optional[str] = None               # "gold", "silver", "bronze"
    is_official: bool = False                 # competition result vs training data
    correction_history: List[Dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "sport": self.sport,
            "event": self.event,
            "metric_name": self.metric_name,
            "value": self.value,
            "unit": self.unit,
            "context": self.context,
            "source": self.source.value,
            "source_detail": self.source_detail,
            "confidence": self.confidence,
            "recorded_at": self.recorded_at.isoformat() if self.recorded_at else None,
            "rank": self.rank,
            "medal": self.medal,
            "is_official": self.is_official,
        }


@dataclass
class DevelopmentRecord:
    """Coach-issued development observations (Doc 3 §3 Performance and Development)."""
    id: UUID = field(default_factory=uuid4)
    coach_id: Optional[UUID] = None
    coach_name: Optional[str] = None
    plan_name: Optional[str] = None
    goals: List[str] = field(default_factory=list)
    observations: List[str] = field(default_factory=list)
    attendance_pct: Optional[float] = None
    next_action: Optional[str] = None
    review_date: Optional[date] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "id": str(self.id),
            "coach_name": self.coach_name,
            "plan_name": self.plan_name,
            "goals": self.goals,
            "observations": self.observations,
            "attendance_pct": self.attendance_pct,
            "next_action": self.next_action,
            "review_date": self.review_date.isoformat() if self.review_date else None,
        }


@dataclass
class WelfareRecord:
    """§2 Private welfare record, restricted to authorized personnel only.

    Public profile may show only a safe availability statement.
    """
    id: UUID = field(default_factory=uuid4)
    status: WelfareStatus = WelfareStatus.ELIGIBLE
    medical_notes_hash: Optional[str] = None  # stored hashed, never exposed
    injury_summary_public: Optional[str] = None  # e.g. "ankle sprain, recovery in progress"
    anti_doping_status: Optional[str] = None     # only accessible by authorized officers
    safeguarding_case_id: Optional[str] = None
    return_to_play_date: Optional[date] = None
    last_assessed_at: Optional[datetime] = None
    access_log: List[Dict[str, Any]] = field(default_factory=list)

    def to_public_dict(self) -> dict:
        """Public view, only the welfare status."""
        return {"welfare_status": self.status.value}

    def to_full_dict(self) -> dict:
        """Full view, restricted to authorized personnel."""
        return {
            "id": str(self.id),
            "status": self.status.value,
            "injury_summary_public": self.injury_summary_public,
            "anti_doping_status": self.anti_doping_status,
            "return_to_play_date": self.return_to_play_date.isoformat() if self.return_to_play_date else None,
            "last_assessed_at": self.last_assessed_at.isoformat() if self.last_assessed_at else None,
        }


@dataclass
class PublicShowcase:
    """§2 Public showcase record, athlete chooses what is visible publicly."""
    id: UUID = field(default_factory=uuid4)
    biography: Optional[str] = None
    photo_urls: List[str] = field(default_factory=list)
    highlight_urls: List[str] = field(default_factory=list)
    sponsor_relationships: List[Dict[str, Any]] = field(default_factory=list)
    community_contributions: List[Dict[str, Any]] = field(default_factory=list)
    contact_route: Optional[str] = None       # e.g. "agent_email", "platform_message"
    languages: List[str] = field(default_factory=list)
    audience_reach: Optional[Dict[str, Any]] = None
    verified_at: Optional[datetime] = None

    def to_dict(self) -> dict:
        return {
            "biography": self.biography,
            "photo_urls": self.photo_urls,
            "highlight_urls": self.highlight_urls,
            "sponsor_relationships": self.sponsor_relationships,
            "community_contributions": self.community_contributions,
            "contact_route": self.contact_route,
            "languages": self.languages,
            "audience_reach": self.audience_reach,
        }


# ── Aggregate root ────────────────────────────────────────────────────────────

@dataclass
class AthletePassport:
    """Canonical athlete passport aggregating all five record domains.

    Each domain is independently owned and verified. The passport itself
    is an aggregation that does NOT own the underlying data, it references
    authoritative records from their respective bounded contexts.
    """
    id: UUID = field(default_factory=uuid4)
    identity: ProfileIdentity = field(default_factory=ProfileIdentity)
    participations: List[SportParticipation] = field(default_factory=list)
    performance_records: List[PerformanceMetric] = field(default_factory=list)
    development_records: List[DevelopmentRecord] = field(default_factory=list)
    welfare: WelfareRecord = field(default_factory=WelfareRecord)
    showcase: PublicShowcase = field(default_factory=PublicShowcase)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def public_summary(self) -> Dict[str, Any]:
        """Public-facing summary, excludes private welfare and government IDs."""
        return {
            "athlete_id": str(self.id),
            "name": self.identity.preferred_public_name or self.identity.full_name_en,
            "nationality": self.identity.nationality,
            "sports": [p.sport for p in self.participations if not p.revoked],
            "welfare_status": self.welfare.status.value,
            "showcase": self.showcase.to_dict(),
            "performance_count": len([p for p in self.performance_records if p.is_official]),
            "updated_at": self.updated_at.isoformat(),
        }

    def full_dict(self) -> Dict[str, Any]:
        """Full passport, restricted to the athlete and authorized institutions."""
        return {
            "id": str(self.id),
            "identity": self.identity.to_dict(),
            "participations": [p.to_dict() for p in self.participations],
            "performance_records": [p.to_dict() for p in self.performance_records],
            "development_records": [d.to_dict() for d in self.development_records],
            "welfare": self.welfare.to_full_dict(),
            "showcase": self.showcase.to_dict(),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }
