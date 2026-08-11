"""EfficiencySelector domain model — capabilities, variants, selection policy.

Pure, framework-free logic. A *capability* is a logical function (e.g.
``fraud.score``); a *variant* is one concrete implementation of it in a language.
Selection picks the best variant under a policy using *measured* benchmark data —
never hardcoded performance numbers.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class Language(str, Enum):
    PYTHON = "python"
    GO = "go"
    RUST = "rust"


class Policy(str, Enum):
    LATENCY = "latency"
    THROUGHPUT = "throughput"
    EXPLICIT = "explicit"


@dataclass
class Variant:
    capability: str
    language: Language
    version: str
    health_url: str
    bench_url: str
    business_url: str
    healthy: bool = True
    # Measured benchmark results (populated by real /bench calls).
    p50_ms: Optional[float] = None
    throughput_rps: Optional[float] = None
    samples: int = 0
    last_bench_at: Optional[str] = None

    @property
    def key(self) -> str:
        return f"{self.capability}/{self.language.value}/{self.version}"

    def measured(self) -> bool:
        return self.p50_ms is not None and self.throughput_rps is not None

    def to_dict(self) -> dict:
        return {
            "capability": self.capability,
            "language": self.language.value,
            "version": self.version,
            "healthy": self.healthy,
            "health_url": self.health_url,
            "bench_url": self.bench_url,
            "business_url": self.business_url,
            "p50_ms": self.p50_ms,
            "throughput_rps": self.throughput_rps,
            "samples": self.samples,
            "last_bench_at": self.last_bench_at,
            "measured": self.measured(),
        }


@dataclass
class CapabilityState:
    name: str
    variants: dict[str, Variant] = field(default_factory=dict)
    policy: Policy = Policy.LATENCY
    pinned: Optional[str] = None  # variant key when policy == EXPLICIT

    def add(self, v: Variant) -> None:
        self.variants[v.key] = v

    def get(self, key: str) -> Optional[Variant]:
        return self.variants.get(key)

    def select(self) -> Optional[Variant]:
        """Return the best *healthy, measured* variant under the active policy.

        Falls back to any healthy variant if none have measurements yet, and to
        the first registered variant if nothing is healthy (so the system still
        routes, never fabricating a winner).
        """
        healthy = [v for v in self.variants.values() if v.healthy]
        if not healthy:
            return None

        if self.policy == Policy.EXPLICIT and self.pinned:
            pinned_v = self.variants.get(self.pinned)
            if pinned_v and pinned_v.healthy:
                return pinned_v

        measured = [v for v in healthy if v.measured()]
        if not measured:
            # No measurements yet: prefer the Python baseline if present.
            for v in healthy:
                if v.language == Language.PYTHON:
                    return v
            return healthy[0]

        if self.policy == Policy.THROUGHPUT:
            return max(measured, key=lambda v: v.throughput_rps or 0.0)
        # LATENCY (default): lowest p50 wins.
        return min(measured, key=lambda v: v.p50_ms or float("inf"))

    def ranking(self) -> list[Variant]:
        """All healthy variants ranked best-first under the active policy."""
        pool = [v for v in self.variants.values() if v.healthy]
        if self.policy == Policy.THROUGHPUT:
            pool.sort(key=lambda v: (v.measured(), v.throughput_rps or 0.0),
                      reverse=True)
        else:  # LATENCY (and EXPLICIT-style fallback): lowest p50 first
            pool.sort(key=lambda v: (v.measured(), v.p50_ms or float("inf")))
        return pool
