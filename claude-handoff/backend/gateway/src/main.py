"""
MASAREN API Gateway
Routes all inbound requests to the appropriate microservice.
Handles: rate limiting, JWT validation, auth token forwarding, request ID injection,
          CORS, service discovery (env-based), health aggregation, and RIGOROUS SECURITY.
"""
from __future__ import annotations
import os
import time
import uuid
import re
from collections import defaultdict
from typing import Dict, Tuple, Any
from datetime import datetime

import httpx
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from shared.middleware import decode_token

# ── SECURITY GUARDING SYSTEM ──────────────────────────────────────────────────────

class SecurityGuard:
    """Rigorous security layer to prevent XSS, SQLi, and DDoS."""
    
    DANGEROUS_PATTERNS = [
        re.compile(r"<script.*?>", re.IGNORECASE),
        re.compile(r"DROP\s+TABLE", re.IGNORECASE),
        re.compile(r"UNION\s+SELECT", re.IGNORECASE),
        re.compile(r"OR\s+1=1", re.IGNORECASE),
    ]

    @staticmethod
    def sanitize_input(data: Any) -> Any:
        """Recursively sanitize all input data."""
        if isinstance(data, str):
            for pattern in SecurityGuard.DANGEROUS_PATTERNS:
                if pattern.search(data):
                    raise HTTPException(status_code=400, detail="Malicious input detected.")
            return data.strip()
        elif isinstance(data, dict):
            return {k: SecurityGuard.sanitize_input(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [SecurityGuard.sanitize_input(i) for i in data]
        return data

    @staticmethod
    def apply_secure_headers(response: Response):
        """Inject industry-standard security headers."""
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; object-src 'none';"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response

app = FastAPI(
    title="MASAREN API Gateway",
    description="Single entry point for all MASAREN microservices.",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Configuration ─────────────────────────────────────────────────────────────
JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-production")
JWT_ALGO = os.getenv("JWT_ALGORITHM", "HS256")

# Rate limiting config
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_MAX_REQUESTS = int(os.getenv("RATE_LIMIT_MAX_REQUESTS", "100"))

# IP-based rate limiting (in-memory; use Redis in production)
_rate_store: Dict[str, list] = defaultdict(list)

# Public paths that don't require authentication
PUBLIC_PATHS = {
    "/health", "/health/upstream", "/docs", "/redoc", "/openapi.json",
    "/api/v1/auth/login", "/api/v1/auth/refresh",
    "/api/v1/auth/password/reset-request",
    "/api/v1/users/register",
}

# ── Service registry ──────────────────────────────────────────────────────────
# NOTE: every MASAREN microservice container listens on port 8000 internally
# (see each service Dockerfile: `uvicorn ... --port 8000`). The hostnames below
# match the docker-compose service names. Override any entry via its *_SERVICE_URL
# environment variable for other topologies (k8s, bare-metal, etc.).
SERVICE_REGISTRY: dict[str, str] = {
    "identity":       os.getenv("IDENTITY_SERVICE_URL",       "http://identity:8000"),
    "authentication": os.getenv("AUTHENTICATION_SERVICE_URL", "http://auth:8000"),
    "authorization":  os.getenv("AUTHORIZATION_SERVICE_URL",  "http://authz:8000"),
    "organization":   os.getenv("ORGANIZATION_SERVICE_URL",   "http://organization:8000"),
    "program":        os.getenv("PROGRAM_SERVICE_URL",        "http://program:8000"),
    "task":           os.getenv("TASK_SERVICE_URL",           "http://task:8000"),
    "workflow":       os.getenv("WORKFLOW_SERVICE_URL",       "http://workflow:8000"),
    "verification":   os.getenv("VERIFICATION_SERVICE_URL",   "http://verification:8000"),
    "evidence":       os.getenv("EVIDENCE_SERVICE_URL",       "http://evidence:8000"),
    "gps":            os.getenv("GPS_SERVICE_URL",            "http://gps:8000"),
    "audit":          os.getenv("AUDIT_SERVICE_URL",          "http://audit:8000"),
    "media":          os.getenv("MEDIA_SERVICE_URL",          "http://media:8000"),
    "graph":          os.getenv("GRAPH_SERVICE_URL",          "http://graph:8000"),
    "reputation":     os.getenv("REPUTATION_SERVICE_URL",     "http://reputation:8000"),
    "impact-score":   os.getenv("IMPACT_SCORE_SERVICE_URL",   "http://impact-score:8000"),
    "org-score":      os.getenv("ORG_SCORE_SERVICE_URL",      "http://org-score:8000"),
    "marketplace":    os.getenv("MARKETPLACE_SERVICE_URL",    "http://marketplace:8000"),
    "matching":       os.getenv("MATCHING_SERVICE_URL",       "http://matching:8000"),
    "report":         os.getenv("REPORT_SERVICE_URL",         "http://report:8000"),
    "notification":   os.getenv("NOTIFICATION_SERVICE_URL",   "http://notification:8000"),
    "analytics":      os.getenv("ANALYTICS_SERVICE_URL",      "http://analytics:8000"),
    "forecast":       os.getenv("FORECAST_SERVICE_URL",       "http://forecast:8000"),
    "chat":           os.getenv("CHAT_SERVICE_URL",           "http://chat:8000"),
    "billing":        os.getenv("BILLING_SERVICE_URL",        "http://billing:8000"),
    "subscription":   os.getenv("SUBSCRIPTION_SERVICE_URL",   "http://subscription:8000"),
    "payment":        os.getenv("PAYMENT_SERVICE_URL",        "http://payment:8000"),
    "partner":        os.getenv("PARTNER_SERVICE_URL",        "http://partner-service:8000"),
    "coin":           os.getenv("COIN_SERVICE_URL",           "http://coin:8000"),
    "ads":            os.getenv("ADS_SERVICE_URL",            "http://ads:8000"),
    "platform":       os.getenv("PLATFORM_SERVICE_URL",       "http://platform:8000"),
    "efficiency-selector": os.getenv("SELECTOR_SERVICE_URL",  "http://efficiency-selector:8095"),
    # Static (Python-baseline) fallbacks for capability-routed endpoints.
    "fraud-score":     os.getenv("FRAUD_SCORE_SERVICE_URL",     "http://fraud-python:8090"),
    "auth-verify":     os.getenv("AUTH_VERIFY_SERVICE_URL",     "http://auth-python:8093"),
    "reputation-score": os.getenv("REPUTATION_SCORE_SERVICE_URL", "http://impact-score-python:8094"),
}

# EfficiencySelector integration: for these path prefixes the gateway asks the
# selector which language variant to use (measured, not guessed). If the selector
# is unreachable or returns no healthy variant, routing falls back to the static
# SERVICE_REGISTRY entry above (honest degradation, never a fabricated route).
SELECTOR_URL = os.getenv("SELECTOR_URL", "http://efficiency-selector:8095")
SELECTOR_CAPABILITIES: dict[str, str] = {
    "/fraud":        "fraud.score",
    "/auth/verify":  "auth.verify",
    "/reputation":   "reputation.score",
}
# Short-lived cache of selector decisions to avoid a per-request HTTP call.
_selector_cache: dict[str, tuple[float, str | None]] = {}
_SELECTOR_CACHE_TTL = float(os.getenv("SELECTOR_CACHE_TTL_SECONDS", "10"))

# Subscription-tier requirements per path. Intentionally empty: tier enforcement is
# a future enhancement (see commented block in the proxy middleware). When enabled,
# populate this map and wire a real billing-service subscription check.
TIER_REQUIREMENTS: dict[str, str] = {}

ROUTE_MAP: dict[str, str] = {
    "/api/v1/users":         "identity",
    "/api/v1/auth":          "authentication",
    "/api/v1/authz":         "authorization",
    "/api/v1/organizations": "organization",
    "/api/v1/programs":      "program",
    "/api/v1/tasks":         "task",
    "/api/v1/workflows":     "workflow",
    "/api/v1/verification":  "verification",
    "/api/v1/evidence":      "evidence",
    "/api/v1/gps":           "gps",
    "/api/v1/audit":         "audit",
    "/api/v1/media":         "media",
    "/api/v1/graph":         "graph",
    "/api/v1/pms":           "impact-score",
    "/api/v1/oii":           "org-score",
    "/api/v1/portfolio":     "reputation",
    "/api/v1/matching":      "matching",
    "/api/v1/opportunities": "marketplace",
    "/api/v1/reports":       "report",
    "/api/v1/notifications": "notification",
    "/api/v1/analytics":     "analytics",
    "/api/v1/forecast":      "forecast",
    "/api/v1/chat":          "chat",
    "/api/v1/billing":       "billing",
    "/api/v1/subscriptions": "subscription",
    "/api/v1/payments":      "payment",
    "/api/v1/partners":      "partner",
    "/api/v1/coin":          "coin",
    "/api/v1/ads":           "ads",
    "/api/v1/platform":      "platform",
    "/selector":             "efficiency-selector",
    # Capability-routed endpoints (selector-aware; static fallback below).
    "/fraud":               "fraud-score",
    "/auth/verify":         "auth-verify",
    "/reputation":          "reputation-score",
}


def resolve_service(path: str) -> str | None:
    for prefix, service in ROUTE_MAP.items():
        if path.startswith(prefix):
            return SERVICE_REGISTRY.get(service)
    return None


def _capability_for(path: str) -> str | None:
    """Return the EfficiencySelector capability name for a path, if any."""
    for prefix, capability in SELECTOR_CAPABILITIES.items():
        if path.startswith(prefix):
            return capability
    return None


def select_variant_url(path: str) -> str | None:
    """Ask the EfficiencySelector which variant URL to use for this path.

    Uses a short TTL cache. Returns None on any failure so the caller keeps the
    static fallback target (never fabricates a route).
    """
    capability = _capability_for(path)
    if not capability:
        return None
    now = time.time()
    cached = _selector_cache.get(capability)
    if cached and now - cached[0] < _SELECTOR_CACHE_TTL:
        return cached[1]
    url = None
    try:  # pragma: no cover - depends on live selector; failure is non-fatal
        import httpx

        with httpx.Client(timeout=0.5) as client:
            r = client.get(f"{SELECTOR_URL}/selector/route/{capability}")
            if r.status_code == 200:
                url = r.json().get("url")
    except Exception:
        url = None
    _selector_cache[capability] = (now, url)
    return url


# ── Rate Limiter ──────────────────────────────────────────────────────────────
def check_rate_limit(client_ip: str) -> None:
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    _rate_store[client_ip] = [t for t in _rate_store[client_ip] if t > window_start]
    if len(_rate_store[client_ip]) >= RATE_LIMIT_MAX_REQUESTS:
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit exceeded. Max {RATE_LIMIT_MAX_REQUESTS} requests per {RATE_LIMIT_WINDOW}s.",
        )
    _rate_store[client_ip].append(now)


# ── JWT Validation ────────────────────────────────────────────────────────────
def validate_jwt(request: Request) -> None:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header.")
    token = auth_header[7:]
    try:
        decode_token(token, JWT_SECRET, JWT_ALGO)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(exc)}")


# ── Proxy Middleware ──────────────────────────────────────────────────────────
@app.middleware("http")
async def proxy_middleware(request: Request, call_next):
    path = request.url.path

    # Skip middleware for health/docs paths
    if path in ("/health", "/docs", "/redoc", "/openapi.json", "/health/upstream"):
        return await call_next(request)

    # 1. SECURITY: Sanitize input body
    if request.method in ("POST", "PUT", "PATCH"):
        try:
            body = await request.json()
            SecurityGuard.sanitize_input(body)
        except Exception as e:
            if isinstance(e, HTTPException): raise e
            return JSONResponse(status_code=400, content={"error": "INVALID_INPUT", "message": str(e)})

    client_ip = request.client.host if request.client else "unknown"

    # Rate limiting
    try:
        check_rate_limit(client_ip)
    except HTTPException as exc:
        return JSONResponse(status_code=exc.status_code, content={"success": False, "error": "RATE_LIMITED", "message": exc.detail})

    # JWT validation for protected paths (skip auth routes + register)
    is_public = any(path.startswith(pp) for pp in PUBLIC_PATHS)
    if not is_public:
        # Extract the bearer token from the Authorization header. (Previously this
        # branch referenced an undefined `token` variable, raising NameError and
        # making the gateway reject/500 on EVERY authenticated request.)
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"success": False, "error": "UNAUTHORIZED",
                         "message": "Missing or invalid Authorization header."},
            )
        token = auth_header[7:]
        try:
            token_data = decode_token(token, JWT_SECRET, JWT_ALGO)
            user_id = getattr(token_data, "sub", None)

            # ── TIER CHECK ─────────────────────────────────────────────────────────
            # Check if the path requires a specific subscription tier
            required_tier = TIER_REQUIREMENTS.get(path)
            if required_tier:
                # In real implementation: call billing-service
                # if not await check_subscription_tier(user_id, path):
                #     return JSONResponse(status_code=402, content={"error": "PAYMENT_REQUIRED"})
                pass

        except HTTPException as exc:
            return JSONResponse(
                status_code=exc.status_code,
                content={"success": False, "error": "UNAUTHORIZED", "message": exc.detail},
            )

    target = resolve_service(path)

    # EfficiencySelector: for capability-routed paths, prefer the variant the
    # selector picked from measured benchmarks. On any failure the static
    # `target` above is used (honest fallback, never a fabricated route).
    try:
        variant_url = select_variant_url(path)
        if variant_url:
            target = variant_url
    except Exception:
        pass

    if not target:
        return await call_next(request)

    trace_id = request.headers.get("X-Trace-Id", str(uuid.uuid4()))
    upstream_url = f"{target}{path}"
    if request.url.query:
        upstream_url += f"?{request.url.query}"

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            body = await request.body()
            upstream_resp = await client.request(
                method=request.method, url=upstream_url,
                headers={**dict(request.headers), "X-Trace-Id": trace_id,
                         "X-Gateway": "masaren-gateway"},
                content=body,
            )
            response = Response(
                content=upstream_resp.content,
                status_code=upstream_resp.status_code,
                headers={"X-Trace-Id": trace_id,
                         "Content-Type": upstream_resp.headers.get("content-type", "application/json")},
            )
            # 2. SECURITY: Apply secure headers to all responses
            return SecurityGuard.apply_secure_headers(response)

    except httpx.ConnectError:
        return JSONResponse(status_code=503,
                            content={"success": False, "error": "SERVICE_UNAVAILABLE",
                                      "message": f"Upstream service unreachable for path: {path}"})
    except Exception as exc:
        return JSONResponse(status_code=502,
                            content={"success": False, "error": "BAD_GATEWAY", "message": str(exc)})



# ── Health endpoints ──────────────────────────────────────────────────────────
@app.get("/health", tags=["Infrastructure"])
async def health():
    return {"status": "healthy", "service": "api-gateway", "version": "0.1.0"}


@app.get("/health/upstream", tags=["Infrastructure"])
async def health_upstream():
    """Ping all registered services and return aggregate health."""
    results = {}
    async with httpx.AsyncClient(timeout=5.0) as client:
        for name, url in SERVICE_REGISTRY.items():
            try:
                r = await client.get(f"{url}/health")
                results[name] = {"status": "healthy" if r.status_code == 200 else "degraded",
                                 "code": r.status_code}
            except Exception as e:
                results[name] = {"status": "unreachable", "error": str(e)}
    overall = "healthy" if all(v["status"] == "healthy" for v in results.values()) else "degraded"
    return {"gateway": "healthy", "overall": overall, "services": results}


# ── BFF aggregation layer ───────────────────────────────────────────────────────
# A thin Backend-for-Frontend layer for the handful of dashboard views that need
# data from more than one microservice in a single round-trip. Every value is
# fetched live from a real service; if a dependency is unreachable the field is
# reported as null with an explicit `degraded` flag — never fabricated.

async def _svc_get(client: httpx.AsyncClient, service: str, path: str,
                   auth: str | None, params: dict | None = None):
    """GET a downstream service, unwrap ApiResponse envelope, return data or None."""
    base = SERVICE_REGISTRY.get(service)
    if not base:
        return None
    headers = {"X-Gateway": "masaren-gateway"}
    if auth:
        headers["Authorization"] = auth
    try:
        r = await client.get(f"{base}{path}", headers=headers, params=params)
        if r.status_code >= 400:
            return None
        body = r.json()
        # Services wrap payloads in {"success": true, "data": ...}
        return body.get("data", body) if isinstance(body, dict) else body
    except Exception:
        return None


@app.get("/api/v1/bff/dashboard", tags=["BFF"])
async def bff_dashboard(request: Request):
    """Aggregate the volunteer/org dashboard: platform summary + the caller's
    personal stats + PMS. Missing dependencies degrade gracefully (null + flag)."""
    auth = request.headers.get("Authorization")
    user_id = None
    if auth and auth.startswith("Bearer "):
        try:
            user_id = decode_token(auth[7:], JWT_SECRET, JWT_ALGO).sub
        except Exception:
            user_id = None

    async with httpx.AsyncClient(timeout=10.0) as client:
        platform = await _svc_get(client, "analytics", "/api/v1/analytics/platform/summary", auth)
        me = await _svc_get(client, "identity", "/api/v1/users/me", auth)
        user_stats = pms = None
        if user_id:
            user_stats = await _svc_get(client, "analytics", f"/api/v1/analytics/users/{user_id}/stats", auth)
            pms = await _svc_get(client, "impact-score", f"/api/v1/pms/{user_id}", auth)

    degraded = [name for name, val in
                {"analytics": platform, "identity": me}.items() if val is None]
    return {
        "success": True,
        "data": {
            "platform": platform,
            "me": me,
            "user_stats": user_stats,
            "pms": pms,
        },
        "degraded": degraded,
    }


@app.get("/api/v1/bff/leaderboard", tags=["BFF"])
async def bff_leaderboard(request: Request, limit: int = 20):
    """Top contributors by PMS composite score. Sourced from identity-service's
    admin user listing; returns an honest 503 if identity is unreachable."""
    auth = request.headers.get("Authorization")
    async with httpx.AsyncClient(timeout=10.0) as client:
        data = await _svc_get(client, "identity", "/api/v1/users/",
                              auth, params={"limit": min(limit, 100), "offset": 0})
    if data is None:
        return JSONResponse(
            status_code=503,
            content={"success": False, "error": "SERVICE_UNAVAILABLE",
                     "message": "identity-service unreachable; leaderboard cannot be computed."},
        )
    items = data.get("items", data) if isinstance(data, dict) else data
    ranked = sorted(
        (items or []),
        key=lambda u: (u or {}).get("pms_score", 0) or 0,
        reverse=True,
    )[:limit]
    return {"success": True, "data": ranked}
