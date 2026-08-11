"""Credibility confidence scoring for media content.

Implements the confidence formula from the MASAREN Media Institutions Blueprint:

  C = 0.20S + 0.22E + 0.18K + 0.15R + 0.15T + 0.10H - P

Where:
  S = Source assurance (identity, directness, reliability, conflicts)
  E = Evidence completeness (document, recording, data, location, timestamp, chain of custody)
  K = Corroboration (independent support for material claims)
  R = Editorial review (named accountability, specialist review, legal review, claim checklist)
  T = Transparency (author, type, method, citations, funding, correction route, rights)
  H = Correction and reliability history
  P = Bounded penalty for unresolved manipulation, conflict, or rights risk

The score is accompanied by the factors, missing evidence, responsible editor,
policy version, update time, and challenge route.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional
from datetime import datetime, timezone


@dataclass
class ConfidenceFactors:
    """Input dimensions for the confidence score."""
    source_assurance: float = 0.0
    evidence_completeness: float = 0.0
    corroboration: float = 0.0
    editorial_review: float = 0.0
    transparency: float = 0.0
    history: float = 0.0
    penalty: float = 0.0
    missing_evidence: List[str] = field(default_factory=list)
    policy_version: str = "1.0.0"

    def to_dict(self) -> dict:
        return {
            "source_assurance": self.source_assurance,
            "evidence_completeness": self.evidence_completeness,
            "corroboration": self.corroboration,
            "editorial_review": self.editorial_review,
            "transparency": self.transparency,
            "history": self.history,
            "penalty": self.penalty,
            "missing_evidence": self.missing_evidence,
            "policy_version": self.policy_version,
        }


@dataclass
class ConfidenceResult:
    """Result of the confidence calculation."""
    score: float
    label: str
    factors: ConfidenceFactors
    computed_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    explanation: str = ""

    def to_dict(self) -> dict:
        return {
            "confidence_score": round(self.score, 4),
            "confidence_label": self.label,
            "confidence_factors": self.factors.to_dict(),
            "confidence_computed_at": self.computed_at.isoformat(),
            "confidence_explanation": self.explanation,
        }


def _label_for(score: float) -> str:
    """Map a confidence score to a human-readable label."""
    if score >= 0.90:
        return "Verified"
    if score >= 0.75:
        return "High"
    if score >= 0.60:
        return "Medium"
    if score >= 0.40:
        return "Low"
    if score > 0.0:
        return "Unverified"
    return "Unverified"


def calculate_confidence(factors: ConfidenceFactors) -> ConfidenceResult:
    """Calculate the credibility confidence score.

    C = 0.20S + 0.22E + 0.18K + 0.15R + 0.15T + 0.10H - P
    """
    raw = (
        0.20 * factors.source_assurance
        + 0.22 * factors.evidence_completeness
        + 0.18 * factors.corroboration
        + 0.15 * factors.editorial_review
        + 0.15 * factors.transparency
        + 0.10 * factors.history
        - factors.penalty
    )
    score = max(0.0, min(1.0, raw))
    label = _label_for(score)

    missing = ", ".join(factors.missing_evidence) if factors.missing_evidence else "none"
    explanation = (
        f"Source={factors.source_assurance:.2f}, Evidence={factors.evidence_completeness:.2f}, "
        f"Corroboration={factors.corroboration:.2f}, Editorial={factors.editorial_review:.2f}, "
        f"Transparency={factors.transparency:.2f}, History={factors.history:.2f}, "
        f"Penalty={factors.penalty:.2f}. Missing: {missing}."
    )

    return ConfidenceResult(
        score=score,
        label=label,
        factors=factors,
        explanation=explanation,
    )


def default_factors_for_post(
    author_verified: bool = False,
    has_evidence: bool = False,
    has_corroboration: bool = False,
    has_editorial_review: bool = False,
    has_transparency: bool = False,
    has_history: bool = False,
    has_manipulation_risk: bool = False,
    missing_evidence: Optional[List[str]] = None,
) -> ConfidenceFactors:
    """Build default confidence factors for a post based on available signals."""
    return ConfidenceFactors(
        source_assurance=0.8 if author_verified else 0.3,
        evidence_completeness=0.9 if has_evidence else 0.2,
        corroboration=0.8 if has_corroboration else 0.3,
        editorial_review=0.7 if has_editorial_review else 0.2,
        transparency=0.8 if has_transparency else 0.4,
        history=0.8 if has_history else 0.3,
        penalty=0.3 if has_manipulation_risk else 0.0,
        missing_evidence=missing_evidence or [],
    )
