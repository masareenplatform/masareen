"""Marketplace domain event contracts."""
from dataclasses import dataclass
from typing import Optional
from . import DomainEvent


@dataclass
class OpportunityMatched(DomainEvent):
    event_type: str = "OpportunityMatched"
    aggregate_type: str = "Match"
    user_id: str = ""
    opportunity_id: str = ""
    match_score: float = 0.0
    opportunity_type: str = ""  # JOB, FUNDING, SCHOLARSHIP, RESEARCH


@dataclass
class FundingApproved(DomainEvent):
    event_type: str = "FundingApproved"
    aggregate_type: str = "Funding"
    recipient_id: str = ""
    organization_id: str = ""
    amount: float = 0.0
    currency: str = "USD"
