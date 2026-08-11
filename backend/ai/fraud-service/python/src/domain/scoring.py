"""Pure fraud risk-scoring logic for the Python fraud-score capability service.

Mirrors the Rust variant's contract (haversine + rule penalties) so the
EfficiencySelector can compare engines on identical work. Deterministic, no
network, no randomness.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional


EARTH_RADIUS_KM = 6371.0
MAX_RISK = 100
FLAG_THRESHOLD = 50


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometres."""
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@dataclass
class ReferencePoint:
    latitude: float
    longitude: float
    checksum: Optional[str] = None


@dataclass
class ScoreInput:
    latitude: float
    longitude: float
    accuracy_meters: float
    checksum: Optional[str] = None
    reference_points: List[ReferencePoint] = field(default_factory=list)
    known_checksums: List[str] = field(default_factory=list)


@dataclass
class Check:
    rule: str
    risk: int
    detail: str


@dataclass
class ScoreResult:
    risk_score: int
    fraud_detected: bool
    fraud_type: str
    confidence: float
    checks: List[Check]


def score(inp: ScoreInput) -> ScoreResult:
    checks: List[Check] = []

    if inp.accuracy_meters > 100.0:
        checks.append(Check("LOW_GPS_ACCURACY", 30,
                            f"accuracy {int(inp.accuracy_meters)}m exceeds 100m threshold"))

    if inp.latitude == 0.0 and inp.longitude == 0.0:
        checks.append(Check("NULL_ISLAND", 25, "coordinates are (0,0); likely null/default value"))

    if inp.reference_points:
        min_dist = min(
            (haversine_km(inp.latitude, inp.longitude, rp.latitude, rp.longitude)
             for rp in inp.reference_points),
            default=float("inf"),
        )
        if min_dist < 0.05:
            checks.append(Check("PROXIMITY_REUSE", 20,
                                f"sub-50m reuse of a reference point ({min_dist:.1f} km)"))

    if not inp.checksum:
        checks.append(Check("MISSING_CHECKSUM", 15, "no content checksum; uniqueness cannot be verified"))

    if inp.checksum and inp.checksum in inp.known_checksums:
        checks.append(Check("DUPLICATE_CONTENT", 25, "checksum already seen on platform"))

    risk_score = min(MAX_RISK, sum(c.risk for c in checks))

    fraud_detected = risk_score >= FLAG_THRESHOLD
    if not checks:
        fraud_type = "NONE"
    elif any(c.rule == "DUPLICATE_CONTENT" for c in checks):
        fraud_type = "DUPLICATE_CONTENT"
    elif any(c.rule == "PROXIMITY_REUSE" for c in checks):
        fraud_type = "GPS_SPOOFING"
    else:
        fraud_type = "TIMELINE_MANIPULATION"

    confidence = 0.95 if not checks else min(0.99, 0.6 + 0.1 * len(checks))

    return ScoreResult(risk_score, fraud_detected, fraud_type, confidence, checks)
