"""EfficiencySelector HTTP API.

Routes:
- POST /selector/register                       register a variant
- GET  /selector/capabilities                  list all capabilities + variants
- GET  /selector/capabilities/{capability}      capability detail + current choice
- POST /selector/capabilities/{capability}/bench   run real benchmarks on variants
- POST /selector/capabilities/{capability}/policy   set selection policy
- GET  /selector/route/{capability}             resolve best variant (for gateway)
- POST /selector/capabilities/{capability}/health  refresh variant health
"""
from __future__ import annotations

import datetime as dt
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..domain.model import Language, Policy, Variant
from ..infrastructure.registry import Registry


def get_registry() -> Registry:
    from ..app import registry  # singleton wired at startup
    return registry


router = APIRouter(tags=["efficiency-selector"])


class RegisterRequest(BaseModel):
    capability: str
    language: str
    version: str
    health_url: str
    bench_url: str
    business_url: str


class PolicyRequest(BaseModel):
    policy: str  # latency | throughput | explicit
    pinned: Optional[str] = None


class BenchResult(BaseModel):
    capability: str
    results: list[dict]


@router.post("/selector/register")
async def register(req: RegisterRequest, reg: Registry = Depends(get_registry)):
    try:
        lang = Language(req.language.lower())
    except ValueError:
        raise HTTPException(status_code=400, detail=f"unknown language: {req.language}")
    v = Variant(
        capability=req.capability,
        language=lang,
        version=req.version,
        health_url=req.health_url,
        bench_url=req.bench_url,
        business_url=req.business_url,
    )
    reg.register_variant(v)
    return {"success": True, "variant": v.key}


@router.get("/selector/capabilities")
async def list_capabilities(reg: Registry = Depends(get_registry)):
    out = {}
    for name in reg.list_capabilities():
        cap = reg.get_capability(name)
        out[name] = {
            "policy": cap.policy.value,
            "pinned": cap.pinned,
            "variants": [v.to_dict() for v in cap.variants.values()],
        }
    return {"capabilities": out}


@router.get("/selector/capabilities/{capability}")
async def get_capability(capability: str, reg: Registry = Depends(get_registry)):
    cap = reg.get_capability(capability)
    if cap is None:
        raise HTTPException(status_code=404, detail="capability_not_found")
    chosen = cap.select()
    return {
        "capability": capability,
        "policy": cap.policy.value,
        "pinned": cap.pinned,
        "current_choice": chosen.to_dict() if chosen else None,
        "ranking": [v.to_dict() for v in cap.ranking()],
        "variants": [v.to_dict() for v in cap.variants.values()],
    }


@router.post("/selector/capabilities/{capability}/bench")
async def run_benchmarks(capability: str, reg: Registry = Depends(get_registry)):
    """Trigger a real self-benchmark on every variant via its /bench endpoint.

    Measurements are taken from the variant's own response (real work, real
    numbers), nothing is fabricated here.
    """
    import httpx

    cap = reg.get_capability(capability)
    if cap is None:
        raise HTTPException(status_code=404, detail="capability_not_found")

    results = []
    async with httpx.AsyncClient(timeout=30.0) as client:
        for v in list(cap.variants.values()):
            try:
                r = await client.get(v.bench_url)
                if r.status_code == 200:
                    body = r.json()
                    v.p50_ms = float(body.get("p50_ms"))
                    v.throughput_rps = float(body.get("throughput_rps"))
                    v.samples = int(body.get("samples", 0))
                    v.last_bench_at = dt.datetime.now(dt.timezone.utc).isoformat()
                    reg.update_variant(v)
                    results.append({"variant": v.key, "measured": True, "data": body})
                else:
                    results.append({"variant": v.key, "measured": False,
                                    "error": f"bench http {r.status_code}"})
            except Exception as exc:  # network/timeout, honest, not fabricated
                results.append({"variant": v.key, "measured": False, "error": str(exc)})
    return BenchResult(capability=capability, results=results)


@router.post("/selector/capabilities/{capability}/policy")
async def set_policy(capability: str, req: PolicyRequest,
                     reg: Registry = Depends(get_registry)):
    try:
        pol = Policy(req.policy.lower())
    except ValueError:
        raise HTTPException(status_code=400, detail=f"unknown policy: {req.policy}")
    reg.set_policy(capability, pol, req.pinned)
    return {"success": True, "policy": pol.value, "pinned": req.pinned}


@router.post("/selector/capabilities/{capability}/health")
async def refresh_health(capability: str, reg: Registry = Depends(get_registry)):
    import httpx

    cap = reg.get_capability(capability)
    if cap is None:
        raise HTTPException(status_code=404, detail="capability_not_found")
    async with httpx.AsyncClient(timeout=5.0) as client:
        for v in list(cap.variants.values()):
            try:
                r = await client.get(v.health_url)
                v.healthy = r.status_code == 200
            except Exception:
                v.healthy = False
            reg.update_variant(v)
    return {"capability": capability,
            "variants": {v.key: v.healthy for v in cap.variants.values()}}


@router.get("/selector/route/{capability}")
async def route(capability: str, reg: Registry = Depends(get_registry)):
    cap = reg.get_capability(capability)
    if cap is None:
        raise HTTPException(status_code=404, detail="capability_not_found")
    chosen = cap.select()
    if chosen is None:
        raise HTTPException(status_code=503,
                            detail="no_healthy_variant_available")
    return {
        "capability": capability,
        "language": chosen.language.value,
        "version": chosen.version,
        "url": chosen.business_url,
    }
