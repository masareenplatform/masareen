"""Python reputation.score capability service (baseline for the EfficiencySelector).

Exposes the same HTTP+JSON contract as the Go variant of `reputation.score`.
Real weighted PMS computation, plus a measured /bench endpoint.
"""
from __future__ import annotations

import time

from fastapi import FastAPI
from pydantic import BaseModel
from shared.utils.app_factory import create_app

from .domain.pms import DIMENSION_KEYS, compute


class ScoreRequest(BaseModel):
    user_id: str
    dimensions: dict
    weights: dict = {}
    version: int = 0


BENCH_DIMS = {k: v for k, v in zip(
    DIMENSION_KEYS,
    [0.9, 0.8, 0.7, 0.6, 0.85, 0.5, 0.75, 0.4, 0.8, 0.6],
)}


app = create_app(
    "reputation-score-python",
    "0.1.0",
    "Python baseline implementation of the reputation.score capability.",
)


@app.post("/reputation/score")
async def reputation_score(req: ScoreRequest):
    snap = compute(req.user_id, req.dimensions, req.weights or None, req.version)
    return {
        "user_id": snap.user_id,
        "composite_score": snap.composite_score,
        "tier": snap.tier,
        "dimensions": snap.dimensions,
        "version": snap.version,
    }


@app.get("/bench")
async def bench():
    samples = 5000
    for _ in range(200):
        compute("bench", BENCH_DIMS)
    latencies: list[float] = []
    start = time.perf_counter()
    for _ in range(samples):
        t0 = time.perf_counter()
        compute("bench", BENCH_DIMS)
        latencies.append((time.perf_counter() - t0) * 1000.0)
    elapsed = time.perf_counter() - start
    latencies.sort()
    return {
        "capability": "reputation.score",
        "language": "python",
        "version": "1",
        "p50_ms": latencies[samples // 2],
        "throughput_rps": samples / elapsed,
        "samples": samples,
    }
