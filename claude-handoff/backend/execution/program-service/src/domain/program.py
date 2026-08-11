from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.events.execution_events import ProgramCreated
from shared.exceptions import ValidationException, ConflictException

class ProgramStatus(str, Enum):
    DRAFT     = "DRAFT"
    PUBLISHED = "PUBLISHED"
    ACTIVE    = "ACTIVE"
    PAUSED    = "PAUSED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

@dataclass
class ProgramMilestone:
    id: str; title: str; due_date: Optional[date]; completed: bool = False

@dataclass
class Program(AggregateRoot):
    organization_id:  str                   = ""
    title:            str                   = ""
    description:      Optional[str]         = None
    status:           ProgramStatus         = ProgramStatus.DRAFT
    start_date:       Optional[date]        = None
    end_date:         Optional[date]        = None
    sdg_goals:        List[int]             = field(default_factory=list)
    country:          Optional[str]         = None
    city:             Optional[str]         = None
    latitude:         Optional[float]       = None
    longitude:        Optional[float]       = None
    max_participants: Optional[int]         = None
    enrolled_count:   int                   = 0
    milestones:       List[ProgramMilestone]= field(default_factory=list)
    tags:             List[str]             = field(default_factory=list)
    created_by:       str                   = ""

    @classmethod
    def create(cls, org_id: str, title: str, created_by: str,
               description: Optional[str]=None, sdg_goals: Optional[List[int]]=None,
               country: Optional[str]=None, start_date: Optional[date]=None,
               end_date: Optional[date]=None, max_participants: Optional[int]=None) -> "Program":
        if not title or len(title.strip()) < 3:
            raise ValidationException("Program title must be at least 3 characters.")
        if start_date and end_date and end_date < start_date:
            raise ValidationException("End date cannot be before start date.")
        now = datetime.now(timezone.utc)
        p = cls(id=str(uuid4()), organization_id=org_id, title=title.strip(),
                description=description, status=ProgramStatus.DRAFT,
                sdg_goals=sdg_goals or [], country=country,
                start_date=start_date, end_date=end_date,
                max_participants=max_participants, created_by=created_by,
                created_at=now, updated_at=now)
        p.add_domain_event(ProgramCreated(
            aggregate_id=p.id, title=p.title,
            organization_id=org_id, sdg_goals=p.sdg_goals))
        return p

    def publish(self) -> None:
        if self.status != ProgramStatus.DRAFT:
            raise ConflictException("Only DRAFT programs can be published.")
        self.status = ProgramStatus.PUBLISHED
        self.updated_at = datetime.now(timezone.utc)

    def activate(self) -> None:
        if self.status not in (ProgramStatus.PUBLISHED, ProgramStatus.PAUSED):
            raise ConflictException("Program must be PUBLISHED or PAUSED to activate.")
        self.status = ProgramStatus.ACTIVE
        self.updated_at = datetime.now(timezone.utc)

    def complete(self) -> None:
        self.status = ProgramStatus.COMPLETED
        self.updated_at = datetime.now(timezone.utc)

    def enroll_participant(self) -> None:
        if self.max_participants and self.enrolled_count >= self.max_participants:
            raise ConflictException("Program has reached maximum participant capacity.")
        self.enrolled_count += 1
        self.updated_at = datetime.now(timezone.utc)

    def add_milestone(self, title: str, due_date: Optional[date]=None) -> ProgramMilestone:
        m = ProgramMilestone(id=str(uuid4()), title=title, due_date=due_date)
        self.milestones.append(m)
        self.updated_at = datetime.now(timezone.utc)
        return m
