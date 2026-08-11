"""Python auth.verify capability service (baseline for the EfficiencySelector).

Exposes the same HTTP+JSON contract as the Go variant of `auth.verify`. Real JWT
verification + bcrypt password checking, plus a measured /bench endpoint.
"""
from __future__ import annotations

import os
import time

from fastapi import FastAPI
from pydantic import BaseModel
from shared.utils.app_factory import create_app

from .domain.auth import check_password, hash_password, mint_token, verify_token

JWT_SECRET = os.environ.get("JWT_SECRET", "masaren-dev-secret-change-me")
BENCH_TOKEN = mint_token("bench-user", "field_agent", JWT_SECRET, ttl_seconds=3600)


class VerifyRequest(BaseModel):
    token: str


class HashRequest(BaseModel):
    password: str
    cost: int = 0  # ignored by passlib default; accepted for contract parity


class CheckRequest(BaseModel):
    password: str
    hash: str


app = create_app(
    "auth-verify-python",
    "0.1.0",
    "Python baseline implementation of the auth.verify capability.",
)


@app.post("/auth/verify")
async def auth_verify(req: VerifyRequest):
    try:
        claims = verify_token(req.token, JWT_SECRET)
    except ValueError as exc:
        return {"valid": False, "error": str(exc)}
    return {
        "valid": True,
        "claims": {
            "user_id": claims.user_id,
            "role": claims.role,
            "sub": claims.sub,
            "expiry": claims.expiry,
        },
    }


@app.post("/auth/hash")
async def auth_hash(req: HashRequest):
    return {"hash": hash_password(req.password)}


@app.post("/auth/check")
async def auth_check(req: CheckRequest):
    return {"match": check_password(req.password, req.hash)}


@app.get("/bench")
async def bench():
    samples = 5000
    for _ in range(200):
        verify_token(BENCH_TOKEN, JWT_SECRET)
    latencies: list[float] = []
    start = time.perf_counter()
    for _ in range(samples):
        t0 = time.perf_counter()
        verify_token(BENCH_TOKEN, JWT_SECRET)
        latencies.append((time.perf_counter() - t0) * 1000.0)
    elapsed = time.perf_counter() - start
    latencies.sort()
    return {
        "capability": "auth.verify",
        "language": "python",
        "version": "1",
        "p50_ms": latencies[samples // 2],
        "throughput_rps": samples / elapsed,
        "samples": samples,
    }
