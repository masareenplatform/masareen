"""Organizational Impact Index (OII) domain model."""
from dataclasses import dataclass, field
from typing import Dict


@dataclass
class OIIDimension:
    name: str
    value: float = 0.0
    weight: float = 0.0


@dataclass
class OrganizationalImpactIndex:
    """
    Multidimensional reputation profile for organizations.
    Weights are loaded from config — never hardcoded.
    """
    organization_id: str
    dimensions: Dict[str, OIIDimension] = field(default_factory=dict)
    composite_index: float = 0.0
    version: int = 0

    DIMENSION_KEYS = [
        "verified_impact",
        "funding_efficiency",
        "execution_efficiency",
        "reporting_quality",
        "compliance",
        "volunteer_retention",
        "social_reach",
        "environmental_impact",
        "partner_satisfaction",
        "governance",
    ]

    def compute_composite(self) -> float:
        total_weight = sum(d.weight for d in self.dimensions.values())
        if total_weight == 0:
            return 0.0
        weighted_sum = sum(d.value * d.weight for d in self.dimensions.values())
        self.composite_index = round(weighted_sum / total_weight, 4)
        return self.composite_index
