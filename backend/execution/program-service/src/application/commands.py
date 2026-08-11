from dataclasses import dataclass, field
from datetime import date
from typing import List, Optional
from shared.utils.cqrs import Command

@dataclass
class CreateProgramCommand(Command):
    organization_id: str; title: str; created_by: str
    description: Optional[str]=None; sdg_goals: List[int]=field(default_factory=list)
    country: Optional[str]=None; start_date: Optional[date]=None
    end_date: Optional[date]=None; max_participants: Optional[int]=None

@dataclass
class PublishProgramCommand(Command):
    program_id: str; published_by: str

@dataclass
class ActivateProgramCommand(Command):
    program_id: str; activated_by: str

@dataclass
class EnrollParticipantCommand(Command):
    program_id: str; user_id: str

@dataclass
class AddMilestoneCommand(Command):
    program_id: str; title: str; due_date: Optional[date]=None
