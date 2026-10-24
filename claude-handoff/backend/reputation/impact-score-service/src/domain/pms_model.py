"""Proof of Mission Score (PMS) domain model."""
from dataclasses import dataclass, field
from typing import Dict


@dataclass
class PMSDimension:
    name: str
    value: float = 0.0
    weight: float = 0.0
    evidence_count: int = 0


@dataclass
class ProofOfMissionScore:
    """
    Multidimensional reputation vector for individuals.
    Weights are configurable, never hardcoded.
    """
    user_id: str
    dimensions: Dict[str, PMSDimension] = field(default_factory=dict)
    composite_score: float = 0.0
    version: int = 0

    # Dimension registry (loaded from config/DB, not hardcoded)
    DIMENSION_KEYS = [
        "reliability",
        "execution_quality",
        "leadership",
        "documentation_quality",
        "verification_confidence",
        "learning_velocity",
        "technical_skills",
        "innovation",
        "consistency",
        "community_impact",
    ]

    def compute_composite(self) -> float:
        """Weighted sum of all dimension scores."""
        total_weight = sum(d.weight for d in self.dimensions.values())
        if total_weight == 0:
            return 0.0
        weighted_sum = sum(d.value * d.weight for d in self.dimensions.values())
        self.composite_score = round(weighted_sum / total_weight, 4)
        return self.composite_score

    def to_vector(self) -> list:
        """Return ordered vector for AI consumption."""
        return [self.dimensions.get(k, PMSDimension(k)).value for k in self.DIMENSION_KEYS]
