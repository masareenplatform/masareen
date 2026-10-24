"""Opportunity aggregate, jobs, funding, scholarships, research, consulting."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException, ConflictException


class OpportunityType(str, Enum):
    JOB         = "JOB"
    FUNDING     = "FUNDING"
    SCHOLARSHIP = "SCHOLARSHIP"
    RESEARCH    = "RESEARCH"
    CONSULTING  = "CONSULTING"
    PARTNERSHIP = "PARTNERSHIP"
    VOLUNTEER   = "VOLUNTEER"


class OpportunityStatus(str, Enum):
    DRAFT     = "DRAFT"
    PUBLISHED = "PUBLISHED"
    CLOSED    = "CLOSED"
    CANCELLED = "CANCELLED"


@dataclass
class PMSRequirement:
    dimension:   str
    min_value:   float
    description: str


@dataclass
class Opportunity(AggregateRoot):
    organization_id:  str                    = ""
    title:            str                    = ""
    opp_type:         OpportunityType        = OpportunityType.JOB
    status:           OpportunityStatus      = OpportunityStatus.DRAFT
    description:      Optional[str]          = None
    country:          Optional[str]          = None
    city:             Optional[str]          = None
    remote:           bool                   = False
    min_pms_score:    float                  = 0.0
    required_skills:  List[str]              = field(default_factory=list)
    required_sdgs:    List[int]              = field(default_factory=list)
    pms_requirements: List[PMSRequirement]   = field(default_factory=list)
    compensation_usd: Optional[float]        = None
    deadline:         Optional[date]         = None
    max_applicants:   Optional[int]          = None
    applicant_count:  int                    = 0
    created_by:       str                    = ""
    tags:             List[str]              = field(default_factory=list)

    @classmethod
    def create(cls, org_id: str, title: str, opp_type: str, created_by: str,
               description: Optional[str]=None, country: Optional[str]=None,
               min_pms_score: float=0.0, required_skills: Optional[List[str]]=None,
               deadline: Optional[date]=None) -> "Opportunity":
        if not title or len(title.strip()) < 5:
            raise ValidationException("Opportunity title must be at least 5 characters.")
        now = datetime.now(timezone.utc)
        return cls(id=str(uuid4()), organization_id=org_id, title=title.strip(),
                   opp_type=OpportunityType(opp_type), status=OpportunityStatus.DRAFT,
                   description=description, country=country,
                   min_pms_score=min_pms_score,
                   required_skills=required_skills or [],
                   deadline=deadline, created_by=created_by,
                   created_at=now, updated_at=now)

    def publish(self) -> None:
        if self.status != OpportunityStatus.DRAFT:
            raise ConflictException("Only DRAFT opportunities can be published.")
        self.status = OpportunityStatus.PUBLISHED
        self.updated_at = datetime.now(timezone.utc)

    def close(self) -> None:
        self.status = OpportunityStatus.CLOSED
        self.updated_at = datetime.now(timezone.utc)

    def matches_profile(self, pms_score: float, skills: List[str], sdg_experience: List[int]) -> tuple[bool, float]:
        """Returns (matches, match_score 0-1)."""
        if pms_score < self.min_pms_score:
            return False, 0.0
        skill_overlap = len(set(skills) & set(self.required_skills))
        skill_score   = skill_overlap / len(self.required_skills) if self.required_skills else 1.0
        sdg_overlap   = len(set(sdg_experience) & set(self.required_sdgs))
        sdg_score     = sdg_overlap / len(self.required_sdgs) if self.required_sdgs else 1.0
        pms_score_norm = min(pms_score / max(self.min_pms_score, 0.01), 1.0) if self.min_pms_score > 0 else 1.0
        match_score = round((skill_score * 0.4 + sdg_score * 0.3 + pms_score_norm * 0.3), 3)
        return match_score >= 0.5, match_score
