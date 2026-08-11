from dataclasses import dataclass
from datetime import date
from typing import List, Optional, Dict, Any
from shared.utils.cqrs import Command

@dataclass
class CreateOpportunityCommand(Command):
    organization_id: str
    title: str
    opp_type: str
    description: Optional[str] = None
    country: Optional[str] = None
    min_pms_score: float = 0.0
    required_skills: List[str] = None
    required_sdgs: List[int] = None
    deadline: Optional[date] = None
    compensation_usd: Optional[float] = None
    remote: bool = False

@dataclass
class PublishOpportunityCommand(Command):
    opportunity_id: str

@dataclass
class ApplyToOpportunityCommand(Command):
    opportunity_id: str
    user_id: str

@dataclass
class CreatePlatformPostCommand(Command):
    title: str
    body: str
    content_type: str
    media_url: Optional[str] = None
    target_audience: List[str] = None
    budget: Optional[float] = None
