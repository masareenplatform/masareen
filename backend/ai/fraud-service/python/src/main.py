"""Python fraud-score capability service (baseline for the EfficiencySelector).

Exposes the same HTTP+JSON contract as the Rust variant of `fraud.score` so the
selector can benchmark Python vs Rust on identical work. Real logic, no mocks.
"""
from __future__ import annotations

import os
import time

from fastapi import FastAPI, Request
from pydantic import BaseModel
from shared.utils.app_factory import create_app

from .domain.scoring import ReferencePoint, ScoreInput, score


class ScoreRequest(BaseModel):
    latitude: float
    longitude: float
    accuracy_meters: float = 0.0
    checksum: str | None = None
    reference_points: list[dict] = []
    known_checksums: list[str] = []


def _to_input(req: ScoreRequest) -> ScoreInput:
    return ScoreInput(
        latitude=req.latitude,
        longitude=req.longitude,
        accuracy_meters=req.accuracy_meters,
        checksum=req.checksum,
        reference_points=[ReferencePoint(**p) for p in req.reference_points],
        known_checksums=req.known_checksums,
    )


app = create_app(
    "fraud-score-python",
    "0.1.0",
    "Python baseline implementation of the fraud.score capability.",
)


@app.post("/fraud/score")
async def fraud_score(req: ScoreRequest):
    r = score(_to_input(req))
    return {
        "risk_score": r.risk_score,
        "fraud_detected": r.fraud_detected,
        "fraud_type": r.fraud_type,
        "confidence": r.confidence,
        "checks": [{"rule": c.rule, "risk": c.risk, "detail": c.detail} for c in r.checks],
    }


@app.get("/bench")
async def bench():
    """Real self-benchmark: score a fixed sample N times, measure p50 + throughput."""
    sample = ScoreInput(
        latitude=30.0444, longitude=31.2357, accuracy_meters=250.0,
        checksum="dup",
        reference_points=[ReferencePoint(latitude=30.0444, longitude=31.2357)],
        known_checksums=["dup"],
    )
    samples = 5000
    for _ in range(200):  # warm-up
        score(sample)
    latencies: list[float] = []
    start = time.perf_counter()
    for _ in range(samples):
        t0 = time.perf_counter()
        score(sample)
        latencies.append((time.perf_counter() - t0) * 1000.0)
    elapsed = time.perf_counter() - start
    latencies.sort()
    p50 = latencies[samples // 2]
    return {
        "capability": "fraud.score",
        "language": "python",
        "version": "1",
        "p50_ms": p50,
        "throughput_rps": samples / elapsed,
        "samples": samples,
    }
