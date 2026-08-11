"""Pure PMS (Proof of Mission Score) computation for the Python capability service.

Mirrors the Go variant's contract (10 weighted dimensions + tiering) so the
EfficiencySelector can compare engines on identical work. Deterministic.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


DIMENSION_KEYS: List[str] = [
    "reliability", "execution_quality", "leadership",
    "documentation_quality", "verification_confidence",
    "learning_velocity", "technical_skills", "innovation",
    "consistency", "community_impact",
]

DEFAULT_WEIGHTS: Dict[str, float] = {
    "reliability": 0.15,
    "execution_quality": 0.15,
    "verification_confidence": 0.15,
    "leadership": 0.10,
    "technical_skills": 0.10,
    "documentation_quality": 0.10,
    "learning_velocity": 0.08,
    "innovation": 0.07,
    "consistency": 0.05,
    "community_impact": 0.05,
}

TIER_THRESHOLDS = [("PLATINUM", 0.85), ("GOLD", 0.65), ("SILVER", 0.40), ("BRONZE", 0.0)]


@dataclass
class PMSSnapshot:
    user_id: str
    composite_score: float
    tier: str
    dimensions: Dict[str, float]
    version: int


def _clamp(x: float) -> float:
    return max(0.0, min(1.0, x))


def compute(
    user_id: str,
    dimensions: Dict[str, float],
    weights: Optional[Dict[str, float]] = None,
    version: int = 0,
) -> PMSSnapshot:
    w = weights or DEFAULT_WEIGHTS
    total_w = sum(w.get(k, 0.0) for k in dimensions)
    weighted = sum(_clamp(dimensions.get(k, 0.0)) * w.get(k, 0.0) for k in dimensions)
    composite = round(weighted / total_w, 4) if total_w > 0 else 0.0

    tier = "BRONZE"
    for name, threshold in TIER_THRESHOLDS:
        if composite >= threshold:
            tier = name
            break

    return PMSSnapshot(
        user_id=user_id,
        composite_score=composite,
        tier=tier,
        dimensions={k: _clamp(v) for k, v in dimensions.items()},
        version=version + 1,
    )
