"""Feed ranking algorithm for the MASAREN platform.

Implements the ranking formula from the MASAREN Media Institutions Blueprint:

  R = 0.24U + 0.16Q + 0.14F + 0.13C + 0.10D + 0.09L + 0.08N + 0.06B - X

Where:
  U = Predicted user value (engagement history, saves, returns)
  Q = Production and editorial quality
  F = Freshness (recency appropriate to story)
  C = Credibility confidence score
  D = Source and viewpoint diversity contribution
  L = Local or contextual relevance
  N = Novelty (not seen before)
  B = Institutional or public-service priority
  X = Fatigue, duplication, safety, manipulation, rights penalties

The formula is a governance example; weights may be tuned per deployment
but the structure must remain transparent and auditable.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime, timezone


@dataclass
class RankingInputs:
    """Input signals for a single post's ranking score."""
    predicted_user_value: float = 0.0
    quality: float = 0.0
    freshness: float = 0.0
    confidence: float = 0.0
    diversity: float = 0.0
    local_relevance: float = 0.0
    novelty: float = 0.0
    public_service_priority: float = 0.0
    fatigue_penalty: float = 0.0
    duplication_penalty: float = 0.0
    safety_penalty: float = 0.0
    manipulation_penalty: float = 0.0
    rights_penalty: float = 0.0
    weights: Optional[dict] = None

    def _w(self, key: str, default: float) -> float:
        if self.weights and key in self.weights:
            return self.weights[key]
        return default


@dataclass
class RankingResult:
    """Result of the ranking calculation for a single post."""
    score: float
    breakdown: dict
    ranked_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "ranking_score": round(self.score, 4),
            "ranking_breakdown": self.breakdown,
            "ranking_ranked_at": self.ranked_at.isoformat(),
        }


def rank_post(inputs: RankingInputs) -> RankingResult:
    """Calculate the ranking score for a single post.

    R = 0.24U + 0.16Q + 0.14F + 0.13C + 0.10D + 0.09L + 0.08N + 0.06B - X
    """
    w_u = inputs._w("U", 0.24)
    w_q = inputs._w("Q", 0.16)
    w_f = inputs._w("F", 0.14)
    w_c = inputs._w("C", 0.13)
    w_d = inputs._w("D", 0.10)
    w_l = inputs._w("L", 0.09)
    w_n = inputs._w("N", 0.08)
    w_b = inputs._w("B", 0.06)

    positive = (
        w_u * inputs.predicted_user_value
        + w_q * inputs.quality
        + w_f * inputs.freshness
        + w_c * inputs.confidence
        + w_d * inputs.diversity
        + w_l * inputs.local_relevance
        + w_n * inputs.novelty
        + w_b * inputs.public_service_priority
    )

    x = (
        inputs.fatigue_penalty
        + inputs.duplication_penalty
        + inputs.safety_penalty
        + inputs.manipulation_penalty
        + inputs.rights_penalty
    )

    score = max(0.0, min(1.0, positive - x))

    breakdown = {
        "U": round(inputs.predicted_user_value, 4),
        "Q": round(inputs.quality, 4),
        "F": round(inputs.freshness, 4),
        "C": round(inputs.confidence, 4),
        "D": round(inputs.diversity, 4),
        "L": round(inputs.local_relevance, 4),
        "N": round(inputs.novelty, 4),
        "B": round(inputs.public_service_priority, 4),
        "X": round(x, 4),
        "weights": {
            "U": w_u, "Q": w_q, "F": w_f, "C": w_c,
            "D": w_d, "L": w_l, "N": w_n, "B": w_b,
        },
    }

    return RankingResult(score=score, breakdown=breakdown)


def rank_posts(posts: List[dict], user_context: Optional[dict] = None,
               weights: Optional[dict] = None) -> List[dict]:
    """Rank a list of posts and return them sorted by ranking score (descending).

    Each post dict should contain fields like:
      - id, created_at, confidence_score, likes, comments, shares,
      - author_verified, sdg, location, etc.

    user_context can contain:
      - followed_authors: set of author IDs
      - seen_post_ids: set of post IDs already seen
      - location: user's location for local relevance
      - followed_topics: set of topics/SDGs the user follows
    """
    ctx = user_context or {}
    followed_authors = ctx.get("followed_authors", set())
    seen_post_ids = ctx.get("seen_post_ids", set())
    user_location = ctx.get("location")
    followed_topics = ctx.get("followed_topics", set())

    now = datetime.now(timezone.utc)
    results = []

    for post in posts:
        post_id = post.get("id", "")
        author_id = post.get("author", {}).get("id", "") if isinstance(post.get("author"), dict) else ""
        sdg = post.get("sdg")
        post_location = post.get("location")
        created_at_str = post.get("created_at") or post.get("createdAt")

        # Predicted user value: engagement signals
        likes = post.get("likes", 0) or 0
        comments_count = post.get("comments", 0) or 0
        shares_count = post.get("shares", 0) or 0
        saves = post.get("saves", 0) or 0
        engagement = (likes + comments_count * 2 + shares_count * 3 + saves * 4)
        predicted_user_value = min(1.0, engagement / 100.0)
        if author_id in followed_authors:
            predicted_user_value = min(1.0, predicted_user_value + 0.3)

        # Quality: editorial signals
        quality = 0.5
        if post.get("author_verified") or (isinstance(post.get("author"), dict) and post["author"].get("verified")):
            quality = min(1.0, quality + 0.3)
        if post.get("evidence_count", 0) > 0:
            quality = min(1.0, quality + 0.2)

        # Freshness: decay over time
        freshness = 0.5
        if created_at_str:
            try:
                created = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
                age_hours = (now - created).total_seconds() / 3600
                if age_hours < 1:
                    freshness = 1.0
                elif age_hours < 24:
                    freshness = 0.9
                elif age_hours < 72:
                    freshness = 0.7
                elif age_hours < 168:
                    freshness = 0.5
                else:
                    freshness = 0.3
            except (ValueError, TypeError):
                pass

        # Confidence: from the credibility scoring
        confidence = post.get("confidence_score", 0.5) or 0.5

        # Diversity: contribution to source/viewpoint diversity
        diversity = 0.5
        if author_id not in followed_authors:
            diversity = min(1.0, diversity + 0.2)
        if sdg and sdg not in followed_topics:
            diversity = min(1.0, diversity + 0.1)

        # Local relevance
        local_relevance = 0.5
        if user_location and post_location:
            if user_location == post_location:
                local_relevance = 1.0
            elif isinstance(post_location, dict) and post_location.get("country") == user_location:
                local_relevance = 0.8

        # Novelty: not seen before
        novelty = 0.0 if post_id in seen_post_ids else 1.0

        # Public-service priority: SDG-aligned, verified orgs
        public_service_priority = 0.0
        if sdg:
            public_service_priority = min(1.0, public_service_priority + 0.2)
        if post.get("program_tag"):
            public_service_priority = min(1.0, public_service_priority + 0.1)

        # Penalties
        fatigue_penalty = 0.0
        if post_id in seen_post_ids:
            fatigue_penalty = 0.5

        duplication_penalty = 0.0
        if post.get("duplicate_of"):
            duplication_penalty = 0.4

        safety_penalty = 0.0
        if post.get("safety_flag"):
            safety_penalty = 1.0

        manipulation_penalty = 0.0
        if post.get("manipulation_risk"):
            manipulation_penalty = 0.5

        rights_penalty = 0.0
        if post.get("rights_issue"):
            rights_penalty = 0.6

        inputs = RankingInputs(
            predicted_user_value=predicted_user_value,
            quality=quality,
            freshness=freshness,
            confidence=confidence,
            diversity=diversity,
            local_relevance=local_relevance,
            novelty=novelty,
            public_service_priority=public_service_priority,
            fatigue_penalty=fatigue_penalty,
            duplication_penalty=duplication_penalty,
            safety_penalty=safety_penalty,
            manipulation_penalty=manipulation_penalty,
            rights_penalty=rights_penalty,
            weights=weights,
        )

        result = rank_post(inputs)
        results.append((post_id, result.score, result))

    # Sort by score descending
    results.sort(key=lambda x: x[1], reverse=True)

    ranked_posts = []
    for post_id, score, result in results:
        for post in posts:
            if post.get("id") == post_id:
                post_copy = dict(post)
                post_copy["ranking_score"] = score
                post_copy["ranking_breakdown"] = result.breakdown
                ranked_posts.append(post_copy)
                break

    return ranked_posts
