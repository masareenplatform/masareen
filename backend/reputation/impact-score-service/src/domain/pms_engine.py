"""
Proof of Mission Score (PMS) computation engine.
Aggregates verified activities into a multidimensional reputation vector.
Weights are configurable, loaded from DB, never hardcoded.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from uuid import uuid4
from datetime import datetime, timezone
from shared.base_entity import AggregateRoot

DIMENSION_KEYS = [
    "reliability", "execution_quality", "leadership",
    "documentation_quality", "verification_confidence",
    "learning_velocity", "technical_skills", "innovation",
    "consistency", "community_impact",
]

DEFAULT_WEIGHTS: Dict[str, float] = {
    "reliability":              0.15,
    "execution_quality":        0.15,
    "leadership":               0.10,
    "documentation_quality":    0.10,
    "verification_confidence":  0.15,
    "learning_velocity":        0.08,
    "technical_skills":         0.10,
    "innovation":               0.07,
    "consistency":              0.05,
    "community_impact":         0.05,
}

@dataclass
class PMSSnapshot:
    user_id:         str
    composite_score: float
    dimensions:      Dict[str, float]
    tier:            str
    version:         int
    computed_at:     datetime

    TIER_THRESHOLDS = {"BRONZE": 0.0, "SILVER": 0.40, "GOLD": 0.65, "PLATINUM": 0.85}

    @classmethod
    def compute(cls, user_id: str, dimensions: Dict[str, float],
                weights: Optional[Dict[str, float]] = None, version: int = 0) -> "PMSSnapshot":
        w = weights or DEFAULT_WEIGHTS
        total_w = sum(w.get(k, 0) for k in dimensions)
        composite = 0.0
        if total_w > 0:
            composite = round(sum(dimensions.get(k, 0) * w.get(k, 0) for k in dimensions) / total_w, 4)

        tier = "BRONZE"
        for t, threshold in cls.TIER_THRESHOLDS.items():
            if composite >= threshold:
                tier = t

        return cls(user_id=user_id, composite_score=composite, dimensions=dimensions,
                   tier=tier, version=version + 1, computed_at=datetime.now(timezone.utc))

    def apply_delta(self, deltas: Dict[str, float]) -> Dict[str, float]:
        """Apply dimension deltas (from Graph Synthesis Engine), clamped to [0,1]."""
        return self.apply_delta_to(self.dimensions, deltas)

    @staticmethod
    def apply_delta_to(dimensions: Dict[str, float], deltas: Dict[str, float]) -> Dict[str, float]:
        """Apply deltas to a plain dimensions dict (clamped to [0,1]).

        Lets callers transform a dimensions map without first constructing a
        snapshot. Only known dimension keys are affected; missing keys seed at 0.0.
        """
        new_dims = dict(dimensions)
        for dim, delta in deltas.items():
            if dim in DIMENSION_KEYS:
                base = new_dims.get(dim, 0.0)
                new_dims[dim] = round(max(0.0, min(1.0, base + delta)), 4)
        return new_dims

    def to_vector(self) -> List[float]:
        return [self.dimensions.get(k, 0.0) for k in DIMENSION_KEYS]
