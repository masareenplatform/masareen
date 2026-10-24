"""MASAREN combined backend, one process hosting every microservice's HTTP routes.

Why: running 35+ uvicorn processes is heavy and fragile on a laptop / small droplet.
Each service already constructs a complete FastAPI `app` (shared `create_app` + routers),
so we import each service as a uniquely-named package and merge its routes here.
The result is a single `uvicorn combined.main:app` (port 8080) that serves every
`/api/v1/...` route the mobile + web apps expect, no per-service gateway fan-out needed.

Infra (postgres/neo4j/redis/kafka) still runs separately (Docker containers locally).

Implementation note (no mklink / junctions):
  Each service directory (e.g. backend/identity/identity-service) is registered as a
  top-level, uniquely-named package (e.g. `ms_identity`) whose __path__ points at the
  service directory. That lets the service's relative imports (`from ..config import
  settings`, `from ..infrastructure...`) resolve exactly as they do when the service is
  run standalone, while keeping every service isolated under its own package name so
  module names never collide. This is cross-platform (works in Linux containers too).
"""
import os
import sys
import types
import importlib

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(BACKEND, "shared")
for p in (BACKEND, SHARED):
    if p not in sys.path:
        sys.path.insert(0, p)

# alias -> service directory (relative to backend/). gateway is intentionally excluded.
SERVICES = [
    ("ms_identity",      "identity/identity-service"),
    ("ms_auth",          "identity/authentication-service"),
    ("ms_authz",         "identity/authorization-service"),
    ("ms_organization",  "execution/organization-service"),
    ("ms_program",       "execution/program-service"),
    ("ms_task",          "execution/task-service"),
    ("ms_workflow",      "execution/workflow-service"),
    ("ms_verification",  "verification/verification-service"),
    ("ms_evidence",      "verification/evidence-service"),
    ("ms_gps",           "verification/gps-service"),
    ("ms_audit",         "verification/audit-service"),
    ("ms_media",         "verification/media-service"),
    ("ms_submission",    "verification/submission-service"),
    ("ms_graph",         "graph/graph-service"),
    ("ms_reputation",    "reputation/portfolio-service"),
    ("ms_impact_score",  "reputation/impact-score-service"),
    ("ms_org_score",     "reputation/organization-score-service"),
    ("ms_marketplace",  "marketplace/opportunity-service"),
    ("ms_matching",     "marketplace/matching-service"),
    ("ms_posts",        "social/posts-service"),
    ("ms_report",        "reporting/report-service"),
    ("ms_analytics",     "reporting/analytics-service"),
    ("ms_forecast",      "reporting/forecast-service"),
    ("ms_chat",          "chat-service"),
    ("ms_billing",       "billing/billing-service"),
    ("ms_subscription",  "billing/subscription-service"),
    ("ms_payment",       "billing/payment-service"),
    ("ms_partner",       "partners/partner-service"),
    ("ms_coin",          "coin/coin-service"),
    ("ms_ads",           "ads/ads-service"),
    ("ms_platform",     "platform/platform-service"),
    ("ms_notification", "notifications/notification-service"),
    ("ms_bff",          "bff/dashboard-service"),
    ("ms_orchestrator",  "ai/verification_orchestrator_service"),
    ("ms_fraud_python",  "ai/fraud-service/python"),
    ("ms_auth_python",   "identity/authentication-service/python"),
    ("ms_impact_score_python", "reputation/impact-score-service/python"),
]


def _register_service_package(alias: str, rel: str) -> None:
    """Register <backend>/<rel> as a top-level package named `alias`."""
    svc_root = os.path.join(BACKEND, rel)
    pkg = types.ModuleType(alias)
    pkg.__path__ = [svc_root]          # makes `alias` a package rooted at the service dir
    pkg.__package__ = alias
    sys.modules[alias] = pkg


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import create_async_engine

from shared.base_repository.db import Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Single-process combined backend: make sure every ORM-defined table exists
    # in the (dev) database. `create_all` is idempotent, it only creates tables
    # that are missing, so it coexists with the SQL migration files and is safe
    # to run on every startup. This keeps the combined backend self-contained
    # for local E2E without needing the full per-service migration pipeline.
    url = os.environ.get("DATABASE_URL")
    if url:
        try:
            engine = create_async_engine(url)
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            await engine.dispose()
            print("[combined] schema synced (create_all)", flush=True)
        except Exception as e:  # noqa: BLE001 - don't hard-fail startup on DB issues
            print(f"[combined] schema sync skipped: {e!r}", flush=True)
    yield


app = FastAPI(title="MASAREN Combined Backend", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

SKIP = {"/health", "/docs", "/openapi.json", "/redoc"}  # combined app owns these

# Multiple services define the same tables (e.g. `users`) on the SINGLE shared
# `Base.metadata` (see shared/base_repository/db.py). In separate processes that's
# fine; merged into one process the duplicate check in `Table.__new__` raises
# "Table 'X' is already defined". Reuse the first definition for subsequent services.
import sqlalchemy as _sa
from sqlalchemy import Table as _Table
_orig_table_new = _Table.__new__
def _patched_table_new(cls, *args, **kwargs):
    metadata = kwargs.get("metadata")
    if metadata is None and len(args) >= 2:
        metadata = args[1]
    name = kwargs.get("name") or (args[0] if args else None)
    schema = kwargs.get("schema")
    if metadata is not None and name is not None:
        key = (schema, name) if schema else name
        if key in metadata.tables:
            return metadata.tables[key]
    return _orig_table_new(cls, *args, **kwargs)
_Table.__new__ = staticmethod(_patched_table_new)


_included = []
for alias, rel in SERVICES:
    try:
        _register_service_package(alias, rel)
        mod = importlib.import_module(f"{alias}.src.main")
        svc = getattr(mod, "app", None)
        if svc is None:
            print(f"[combined] WARN {alias}: no app object", flush=True)
            continue
        for r in list(svc.routes):
            if getattr(r, "path", None) in SKIP:
                svc.routes.remove(r)
        app.include_router(svc.router)
        # Each service registers its own exception handlers (e.g. DomainException
        # -> 401/404/409). include_router does NOT copy them, so copy them here so
        # domain errors map to proper HTTP status codes instead of 500 in the
        # combined app. First registration wins (they are all the same handler).
        for exc_type, handler in svc.exception_handlers.items():
            if exc_type not in app.exception_handlers:
                app.add_exception_handler(exc_type, handler)
        _included.append(alias)
        print(f"[combined] OK   included {alias}", flush=True)
    except Exception as e:  # noqa: BLE001 - keep the combined app alive even if one service fails
        print(f"[combined] FAIL {alias}: {e!r}", flush=True)

print(f"[combined] merged {len(_included)}/{len(SERVICES)} services", flush=True)


@app.get("/health")
async def health():
    return {"status": "healthy", "service": "masaren-combined",
            "services_included": _included}
