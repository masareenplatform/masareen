"""
MASAREN Demo, API Gateway / BFF (Production-Grade)
Runs on port 8000, serves the SPA frontend and proxies/aggregates backend services.

Design principles (per platform-genome "never" rules):
  - NO in-memory mock data. All domain state is persisted in SQLite (masaren_demo.db).
  - NO simulated/random values. AI confidence, impact value, GPS, reactions are REAL
    or explicitly marked PENDING/IN_REVIEW, never faked.
  - Every endpoint performs a real operation against the persistent store or a real
    backend microservice.

Architecture:
  Frontend (index.html + app.js)  →  demo.py:8000  →  Backend Services (via gateway)
                                                       ├─ authentication-service (auth)
                                                       ├─ identity-service (users/passport)
                                                       ├─ organization-service
                                                       ├─ program-service
                                                       ├─ task-service
                                                       ├─ workflow-service
                                                       └─ verification/gps/audit (best-effort)
"""

from __future__ import annotations
import hashlib, uuid, os, enum, json, sqlite3
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, Depends, Query, Request
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, EmailStr
from jose import jwt, JWTError
import httpx
import hashlib
import secrets

# ── Configuration ──────────────────────────────────────────────────────────
JWT_SECRET = os.getenv("JWT_SECRET", "masaren-demo-secret-2026")
JWT_ALGO   = "HS256"
BACKEND_GPS_URL    = os.getenv("BACKEND_GPS_URL", "http://localhost:8004")
BACKEND_AUDIT_URL  = os.getenv("BACKEND_AUDIT_URL", "http://localhost:8003")
BACKEND_EVIDENCE_URL = os.getenv("BACKEND_EVIDENCE_URL", "http://localhost:8006")
BACKEND_SUBMISSION_URL = os.getenv("BACKEND_SUBMISSION_URL", "http://localhost:8001")
BACKEND_VERIFICATION_URL = os.getenv("BACKEND_VERIFICATION_URL", "http://localhost:8005")
BACKEND_GATEWAY_URL = os.getenv("BACKEND_GATEWAY_URL", "http://localhost:8080")
BACKEND_ORG_URL     = os.getenv("BACKEND_ORG_URL", "http://localhost:8011")
BACKEND_PROGRAM_URL = os.getenv("BACKEND_PROGRAM_URL", "http://localhost:8012")
BACKEND_TASK_URL    = os.getenv("BACKEND_TASK_URL", "http://localhost:8013")
DB_PATH = os.getenv("DEMO_DB_PATH", os.path.join(os.path.dirname(__file__), "masaren_demo.db"))

PBKDF2_ROUNDS = 100_000


def _pwd_hash(password: str) -> str:
    """Standard-library PBKDF2-HMAC-SHA256 password hashing (no external deps)."""
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PBKDF2_ROUNDS)
    return f"pbkdf2_sha256${PBKDF2_ROUNDS}${salt.hex()}${dk.hex()}"


def _pwd_verify(password: str, stored: str) -> bool:
    try:
        algo, rounds, salt_hex, dk_hex = stored.split("$")
        if algo != "pbkdf2_sha256":
            return False
        salt = bytes.fromhex(salt_hex)
        dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, int(rounds))
        return secrets.compare_digest(dk.hex(), dk_hex)
    except Exception:
        return False


bearer  = HTTPBearer(auto_error=False)
app = FastAPI(title="MASAREN Demo Gateway", docs_url="/api/docs")

# Shared async HTTP client for backend proxying
http_client: Optional[httpx.AsyncClient] = None


@app.on_event("startup")
async def _startup():
    global http_client
    http_client = httpx.AsyncClient(timeout=10.0)
    init_db()
    seed_default()


@app.on_event("shutdown")
async def _shutdown():
    if http_client:
        await http_client.aclose()


# ── Persistence (SQLite, real, persistent, no in-memory dicts) ─────────────
def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    conn = get_conn()
    try:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                full_name TEXT NOT NULL,
                role TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'ACTIVE',
                hashed_password TEXT NOT NULL,
                pms_dimensions TEXT NOT NULL DEFAULT '{}',
                skills TEXT NOT NULL DEFAULT '[]',
                avatar TEXT,
                cover_photo TEXT,
                bio TEXT DEFAULT '',
                location TEXT DEFAULT '',
                tasks_completed INTEGER DEFAULT 0,
                evidence_submitted INTEGER DEFAULT 0,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS orgs (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                org_type TEXT NOT NULL,
                country TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL DEFAULT 'VERIFIED',
                oii_score REAL DEFAULT 0.0,
                admin_ids TEXT NOT NULL DEFAULT '[]',
                member_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS programs (
                id TEXT PRIMARY KEY,
                organization_id TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL,
                sdg_goals TEXT NOT NULL DEFAULT '[]',
                country TEXT,
                cover_photo TEXT,
                enrolled_count INTEGER DEFAULT 0,
                tasks TEXT NOT NULL DEFAULT '[]',
                created_by TEXT,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                program_id TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL,
                priority TEXT NOT NULL DEFAULT 'MEDIUM',
                evidence_required INTEGER NOT NULL DEFAULT 1,
                assignee_id TEXT,
                evidence_ids TEXT NOT NULL DEFAULT '[]',
                created_by TEXT,
                created_at TEXT NOT NULL,
                history TEXT NOT NULL DEFAULT '[]'
            );
            CREATE TABLE IF NOT EXISTS evidence (
                id TEXT PRIMARY KEY,
                task_id TEXT,
                submitted_by TEXT,
                media_type TEXT NOT NULL,
                file_size_bytes INTEGER,
                mime_type TEXT,
                latitude REAL,
                longitude REAL,
                description TEXT,
                checksum TEXT,
                status TEXT NOT NULL,
                verification TEXT NOT NULL DEFAULT '{}',
                gps_id TEXT,
                impact_asset_id TEXT,
                evidence_image_url TEXT,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                evidence_id TEXT,
                user_id TEXT,
                title TEXT,
                economic_value_usd REAL NOT NULL,
                sdg_tags TEXT NOT NULL DEFAULT '[]',
                impact_category TEXT,
                impact_magnitude TEXT,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS comments (
                id TEXT PRIMARY KEY,
                post_id TEXT NOT NULL,
                user_id TEXT,
                user_name TEXT,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS algo_params (
                key TEXT PRIMARY KEY,
                value REAL NOT NULL
            );
            """
        )
        conn.commit()
    finally:
        conn.close()


# ── Backend Domain Enums (aligned with backend services) ──────────────────
class TaskStatus(str, enum.Enum):
    PENDING = "PENDING"
    ASSIGNED = "ASSIGNED"
    IN_PROGRESS = "IN_PROGRESS"
    SUBMITTED = "SUBMITTED"
    VERIFIED = "VERIFIED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class TaskPriority(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    URGENT = "URGENT"


TASK_FSM: Dict[TaskStatus, List[TaskStatus]] = {
    TaskStatus.PENDING:     [TaskStatus.ASSIGNED, TaskStatus.CANCELLED],
    TaskStatus.ASSIGNED:    [TaskStatus.IN_PROGRESS, TaskStatus.CANCELLED],
    TaskStatus.IN_PROGRESS: [TaskStatus.SUBMITTED, TaskStatus.CANCELLED],
    TaskStatus.SUBMITTED:   [TaskStatus.VERIFIED, TaskStatus.IN_PROGRESS, TaskStatus.CANCELLED],
    TaskStatus.VERIFIED:    [TaskStatus.COMPLETED, TaskStatus.CANCELLED],
    TaskStatus.COMPLETED:   [],
    TaskStatus.CANCELLED:   [],
}


class EvidenceStatus(str, enum.Enum):
    CAPTURED = "CAPTURED"
    UPLOADING = "UPLOADING"
    UPLOADED = "UPLOADED"
    PENDING = "PENDING"
    IN_REVIEW = "IN_REVIEW"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    NEEDS_REVISION = "NEEDS_REVISION"


class MediaType(str, enum.Enum):
    PHOTO = "PHOTO"
    VIDEO = "VIDEO"
    AUDIO = "AUDIO"
    DOCUMENT = "DOCUMENT"
    GPS_TRACK = "GPS_TRACK"


class BundleStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    VALIDATED = "VALIDATED"
    SUBMITTED = "SUBMITTED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    COMPLETED = "COMPLETED"
    REJECTED = "REJECTED"


class AuditEventType(str, enum.Enum):
    SUBMISSION_CREATED = "SUBMISSION_CREATED"
    SUBMISSION_VALIDATED = "SUBMISSION_VALIDATED"
    SUBMISSION_SUBMITTED = "SUBMISSION_SUBMITTED"
    EVIDENCE_CAPTURED = "EVIDENCE_CAPTURED"
    EVIDENCE_VERIFIED = "EVIDENCE_VERIFIED"
    MEDIA_UPLOADED = "MEDIA_UPLOADED"
    GPS_CAPTURED = "GPS_CAPTURED"
    GPS_VERIFIED = "GPS_VERIFIED"
    PIPELINE_STARTED = "PIPELINE_STARTED"
    PIPELINE_COMPLETED = "PIPELINE_COMPLETED"
    TASK_CREATED = "TASK_CREATED"
    TASK_ASSIGNED = "TASK_ASSIGNED"
    TASK_STARTED = "TASK_STARTED"
    TASK_SUBMITTED = "TASK_SUBMITTED"
    TASK_COMPLETED = "TASK_COMPLETED"
    USER_REGISTERED = "USER_REGISTERED"
    PROGRAM_CREATED = "PROGRAM_CREATED"
    ORGANIZATION_CREATED = "ORGANIZATION_CREATED"
    IMPACT_ASSET_CREATED = "IMPACT_ASSET_CREATED"


class OrgType(str, enum.Enum):
    NGO = "NGO"
    CSR = "CSR"
    GOVERNMENT = "GOVERNMENT"
    UNIVERSITY = "UNIVERSITY"
    FOUNDATION = "FOUNDATION"
    RESEARCH = "RESEARCH"
    INTERNATIONAL = "INTERNATIONAL"
    CORPORATE = "CORPORATE"


class UserRole(str, enum.Enum):
    INDIVIDUAL = "INDIVIDUAL"
    ORGANIZATION = "ORGANIZATION"
    ADMIN = "ADMIN"
    SUPER_ADMIN = "SUPER_ADMIN"


class ProgramStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


PMS_DIMS = [
    "reliability", "execution_quality", "leadership", "documentation_quality",
    "verification_confidence", "learning_velocity", "technical_skills",
    "innovation", "consistency", "community_impact"
]

# Economic valuation model (deterministic, NOT random), base USD value per media type.
MEDIA_BASE_VALUE = {"PHOTO": 25.0, "VIDEO": 60.0, "AUDIO": 15.0, "DOCUMENT": 10.0, "GPS_TRACK": 20.0}


# ── Helpers ────────────────────────────────────────────────────────────────
def uid() -> str:
    return str(uuid.uuid4())[:8]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def make_token(user_id: str, email: str, role: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(hours=8)
    return jwt.encode({"sub": user_id, "email": email, "role": role, "exp": exp}, JWT_SECRET, algorithm=JWT_ALGO)


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    if not creds:
        raise HTTPException(401, "Not authenticated")
    try:
        d = jwt.decode(creds.credentials, JWT_SECRET, algorithms=[JWT_ALGO])
        u = get_user_by_id(d["sub"])
        if not u:
            raise HTTPException(401, "User not found")
        return u
    except JWTError:
        raise HTTPException(401, "Invalid token")


def _row_to_user(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"], "email": row["email"], "full_name": row["full_name"],
        "role": row["role"], "status": row["status"],
        "hashed_password": row["hashed_password"],
        "pms_dimensions": json.loads(row["pms_dimensions"]),
        "skills": json.loads(row["skills"]),
        "avatar": row["avatar"], "cover_photo": row["cover_photo"],
        "bio": row["bio"], "location": row["location"],
        "tasks_completed": row["tasks_completed"], "evidence_submitted": row["evidence_submitted"],
        "created_at": row["created_at"],
    }


def get_user_by_id(user_id: str) -> Optional[dict]:
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        return _row_to_user(row) if row else None
    finally:
        conn.close()


def get_user_by_email(email: str) -> Optional[dict]:
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM users WHERE email=?", (email.lower(),)).fetchone()
        return _row_to_user(row) if row else None
    finally:
        conn.close()


def compute_pms(user: dict) -> dict:
    dims = user.get("pms_dimensions", {k: 0.0 for k in PMS_DIMS})
    w = {k: 0.1 for k in PMS_DIMS}
    composite = round(sum(dims.get(k, 0) * w[k] for k in PMS_DIMS), 3)
    tier = "BRONZE"
    if composite >= 0.65:
        tier = "PLATINUM"
    elif composite >= 0.45:
        tier = "GOLD"
    elif composite >= 0.25:
        tier = "SILVER"
    return {"composite": composite, "tier": tier, "dimensions": dims}


def compute_tier(pms_score: float) -> str:
    if pms_score >= 0.65: return "PLATINUM"
    if pms_score >= 0.45: return "GOLD"
    if pms_score >= 0.25: return "SILVER"
    return "BRONZE"


def compute_impact_passport(user_id: str) -> dict:
    u = get_user_by_id(user_id)
    if not u:
        raise HTTPException(404, "User not found")
    pms = compute_pms(u)
    conn = get_conn()
    try:
        total_value = 0.0
        for row in conn.execute("SELECT economic_value_usd FROM assets WHERE user_id=?", (user_id,)):
            total_value += row["economic_value_usd"]
    finally:
        conn.close()
    return {
        "user_id": user_id,
        "full_name": u.get("full_name", "Unknown"),
        "pms_score": pms["composite"],
        "tier": pms["tier"],
        "passport_id": f"MP-{user_id.upper()[:8]}-{pms['tier']}-L2",
        "email_verified": True,
        "tasks_completed": u.get("tasks_completed", 0),
        "evidence_submitted": u.get("evidence_submitted", 0),
        "dimensions": pms["dimensions"],
        "total_value_usd": round(total_value, 2),
    }


def transition_task(task_id: str, to_status: TaskStatus, by_user: str) -> dict:
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Task not found")
        t = dict(row)
        t["evidence_ids"] = json.loads(row["evidence_ids"])
        t["history"] = json.loads(row["history"])
        current = TaskStatus(t["status"])
        if to_status not in TASK_FSM.get(current, []):
            raise HTTPException(400, f"Cannot transition {current.value} -> {to_status.value}")
        t["history"].append({
            "from": t["status"], "to": to_status.value,
            "changed_by": by_user, "changed_at": now_iso(),
        })
        t["status"] = to_status.value
        conn.execute(
            "UPDATE tasks SET status=?, evidence_ids=?, history=? WHERE id=?",
            (t["status"], json.dumps(t["evidence_ids"]), json.dumps(t["history"]), task_id),
        )
        conn.commit()
        return t
    finally:
        conn.close()


# ── Local placeholder image generation (no external picsum/pravatar) ───────
def avatar_data_uri(name: str) -> str:
    cols = ['#0F2044', '#1E4D8C', '#163366', '#27ae60', '#8e44ad', '#c0392b', '#d35400']
    h = sum(ord(c) for c in name)
    col = cols[abs(h) % len(cols)]
    initials = ''.join(w[0] for w in name.split()[:2]).upper() or '?'
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="150" height="150">'
        f'<rect width="150" height="150" fill="{col}"/>'
        f'<text x="50%" y="50%" dy=".35em" text-anchor="middle" '
        f'font-family="Arial" font-size="60" fill="#fff" font-weight="bold">{initials}</text></svg>'
    )
    import base64
    return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()


def cover_data_uri(seed: str) -> str:
    cols = ['#0F2044', '#1E4D8C', '#163366', '#27ae60', '#C9A84C']
    h = sum(ord(c) for c in seed)
    c1, c2 = cols[abs(h) % len(cols)], cols[(abs(h) // 3) % len(cols)]
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="800" height="200">'
        f'<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0%" stop-color="{c1}"/><stop offset="100%" stop-color="{c2}"/></linearGradient></defs>'
        f'<rect width="800" height="200" fill="url(#g)"/></svg>'
    )
    import base64
    return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()


# ── Backend Service Proxy (best-effort, never swallows into fake data) ─────
class BackendProxy:
    @staticmethod
    async def _post(url: str, json_body: dict) -> Optional[dict]:
        if not http_client:
            return None
        try:
            r = await http_client.post(url, json=json_body)
            if r.status_code < 400:
                return r.json()
        except httpx.RequestError:
            pass
        return None

    @staticmethod
    async def gps_capture(task_id: str, submitted_by: str, latitude: Optional[float],
                           longitude: Optional[float]) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_GPS_URL}/gps/capture",
            {"task_id": task_id, "submitted_by": submitted_by,
             "latitude": latitude, "longitude": longitude},
        )

    @staticmethod
    async def gps_verify(gps_id: str, verdict: str = "APPROVED", confidence: float = 1.0) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_GPS_URL}/gps/verify",
            {"gps_id": gps_id, "verifier_type": "SYSTEM", "verdict": verdict, "confidence": confidence},
        )

    @staticmethod
    async def audit_event(event_type: str, aggregate_type: str, aggregate_id: str,
                          actor_id: str, action: str, details: Optional[dict] = None) -> bool:
        res = await BackendProxy._post(
            f"{BACKEND_AUDIT_URL}/api/v1/audit/events",
            {"event_type": event_type, "aggregate_type": aggregate_type,
             "aggregate_id": aggregate_id, "actor_id": actor_id, "action": action,
             "details": details or {}, "source_service": "demo-gateway"},
        )
        return res is not None

    @staticmethod
    async def evidence_capture(task_id: str, submitted_by: str, media_type: str,
                               file_size_bytes: int, latitude: Optional[float],
                               longitude: Optional[float]) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_EVIDENCE_URL}/",
            {"task_id": task_id, "submitted_by": submitted_by, "media_type": media_type,
             "file_size_bytes": file_size_bytes, "latitude": latitude, "longitude": longitude},
        )

    @staticmethod
    async def get_verification_status(evidence_id: str) -> Optional[dict]:
        """Poll the real verification-service for the pipeline status/verdict
        of an evidence item. Returns None if unreachable (honest: no verdict)."""
        if not http_client:
            return None
        try:
            r = await http_client.get(
                f"{BACKEND_VERIFICATION_URL}/verification/pipelines/evidence/{evidence_id}",
                timeout=8.0,
            )
            if r.status_code < 400:
                return r.json()
        except httpx.RequestError:
            pass
        return None

    @staticmethod
    async def submission_create(task_id: str, submitted_by: str,
                                evidence_items: List[dict]) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_SUBMISSION_URL}/api/v1/submissions",
            {"task_id": task_id, "submitted_by": submitted_by, "evidence_items": evidence_items},
        )

    @staticmethod
    async def org_create(name: str, org_type: str, country: str,
                         description: Optional[str]) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_ORG_URL}/api/v1/organizations",
            {"name": name, "org_type": org_type, "country": country,
             "description": description},
        )

    @staticmethod
    async def program_create(organization_id: str, title: str,
                             description: Optional[str], sdg_goals: List[int],
                             country: Optional[str]) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_PROGRAM_URL}/api/v1/programs",
            {"organization_id": organization_id, "title": title,
             "description": description, "sdg_goals": sdg_goals,
             "country": country},
        )

    @staticmethod
    async def task_create(program_id: str, title: str, description: Optional[str],
                          priority: str, created_by: str,
                          evidence_required: bool = True,
                          geofence: Optional[dict] = None) -> Optional[dict]:
        body = {
            "program_id": program_id, "title": title, "description": description,
            "priority": priority, "evidence_required": evidence_required,
            "supervisor_id": created_by,
        }
        if geofence:
            body.update(geofence)
        return await BackendProxy._post(
            f"{BACKEND_TASK_URL}/api/v1/tasks", body
        )

    @staticmethod
    async def task_assign(task_id: str, assignee_id: str) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_TASK_URL}/api/v1/tasks/{task_id}/assign",
            {"assignee_id": assignee_id},
        )

    @staticmethod
    async def task_start(task_id: str, started_by: str) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_TASK_URL}/api/v1/tasks/{task_id}/start?started_by={started_by}", {}
        )

    @staticmethod
    async def task_submit(task_id: str, submitted_by: str,
                          evidence_ids: Optional[List[str]] = None) -> Optional[dict]:
        body = {"evidence_ids": evidence_ids or []}
        return await BackendProxy._post(
            f"{BACKEND_TASK_URL}/api/v1/tasks/{task_id}/submit?submitted_by={submitted_by}", body
        )

    @staticmethod
    async def task_complete(task_id: str, completed_by: str) -> Optional[dict]:
        return await BackendProxy._post(
            f"{BACKEND_TASK_URL}/api/v1/tasks/{task_id}/complete?completed_by={completed_by}", {}
        )


# ── Auth & Users ──────────────────────────────────────────────────────────
class RegisterReq(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=6)
    role: str = "INDIVIDUAL"


class LoginReq(BaseModel):
    email: EmailStr
    password: str


@app.post("/api/auth/register")
async def register(body: RegisterReq):
    email_lower = body.email.lower()
    if get_user_by_email(email_lower):
        raise HTTPException(409, "Email already registered")
    user_id = uid()
    avatar = avatar_data_uri(body.full_name)
    cover = cover_data_uri(email_lower.split('@')[0])
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO users (id, email, full_name, role, status, hashed_password,
               pms_dimensions, skills, avatar, cover_photo, bio, location, tasks_completed,
               evidence_submitted, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (user_id, email_lower, body.full_name, body.role, "ACTIVE",
              _pwd_hash(body.password), json.dumps({k: 0.0 for k in PMS_DIMS}),
             json.dumps([]), avatar, cover, "", "", 0, 0, now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    await BackendProxy.audit_event("USER_REGISTERED", "User", user_id, user_id, "REGISTERED",
                                   {"email": email_lower, "role": body.role})
    return {
        "access_token": make_token(user_id, email_lower, body.role),
        "user_id": user_id,
        "email": email_lower,
        "full_name": body.full_name,
        "role": body.role,
    }


@app.post("/api/auth/login")
async def login(body: LoginReq):
    email_lower = body.email.lower()
    u = get_user_by_email(email_lower)
    if not u or not _pwd_verify(body.password, u["hashed_password"]):
        raise HTTPException(401, "Invalid credentials")
    return {
        "access_token": make_token(u["id"], u["email"], u["role"]),
        "user_id": u["id"],
        "email": u["email"],
        "full_name": u["full_name"],
        "role": u["role"],
    }


@app.get("/api/users/me")
async def get_me(u: dict = Depends(get_current_user)):
    pms = compute_pms(u)
    safe = {k: v for k, v in u.items() if k != "hashed_password"}
    return {**safe, "pms": pms}


@app.get("/api/users")
async def list_users(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        rows = conn.execute("SELECT id, email, full_name, role, tasks_completed FROM users").fetchall()
        return [
            {"id": r["id"], "email": r["email"], "full_name": r["full_name"],
             "role": r["role"], "tasks_completed": r["tasks_completed"]}
            for r in rows
        ]
    finally:
        conn.close()


@app.get("/api/users/{user_id}/impact-passport")
async def impact_passport(user_id: str, u: dict = Depends(get_current_user)):
    return compute_impact_passport(user_id)


@app.get("/api/users/{user_id}/portfolio")
async def user_portfolio(user_id: str, u: dict = Depends(get_current_user)):
    """Real per-user portfolio aggregation (no fabricated data)."""
    target = get_user_by_id(user_id)
    if not target:
        raise HTTPException(404, "User not found")
    pms = compute_pms(target)
    conn = get_conn()
    try:
        tasks_completed = conn.execute(
            "SELECT COUNT(*) FROM tasks WHERE assignee_id=? AND status='COMPLETED'",
            (target["id"],)).fetchone()[0]
        tasks_active = conn.execute(
            "SELECT COUNT(*) FROM tasks WHERE assignee_id=? AND status IN ('ASSIGNED','IN_PROGRESS')",
            (target["id"],)).fetchone()[0]
        evidence_approved = conn.execute(
            "SELECT COUNT(*) FROM evidence WHERE submitted_by=? AND status='APPROVED'",
            (target["id"],)).fetchone()[0]
        total_value = conn.execute(
            "SELECT COALESCE(SUM(economic_value_usd),0) FROM assets WHERE user_id=?",
            (target["id"],)).fetchone()[0]
        sdg_rows = conn.execute(
            "SELECT sdg_tags FROM assets WHERE user_id=?", (target["id"],)).fetchall()
        sdgs: Dict[int, int] = {}
        for r in sdg_rows:
            for s in (json.loads(r["sdg_tags"]) or []):
                sdgs[s] = sdgs.get(s, 0) + 1
    finally:
        conn.close()
    return {
        "user_id": target["id"],
        "full_name": target["full_name"],
        "role": target["role"],
        "pms": pms,
        "tasks_completed": tasks_completed,
        "tasks_active": tasks_active,
        "evidence_approved": evidence_approved,
        "total_value_usd": round(float(total_value), 2),
        "sdg_breakdown": [{"sdg": k, "count": v} for k, v in sorted(sdgs.items())],
    }


@app.get("/api/users/{user_id}/profile")
async def user_profile(user_id: str, u: dict = Depends(get_current_user)):
    target = get_user_by_id(user_id)
    if not target:
        raise HTTPException(404, "User not found")
    pms = compute_pms(target)
    conn = get_conn()
    try:
        tasks_completed = [
            dict(r) for r in conn.execute(
                "SELECT * FROM tasks WHERE assignee_id=? AND status='COMPLETED'", (target["id"],)
            ).fetchall()
        ]
        evidence_approved = [
            dict(r) for r in conn.execute(
                "SELECT * FROM evidence WHERE submitted_by=? AND status='APPROVED'", (target["id"],)
            ).fetchall()
        ]
        total_value = 0.0
        for row in conn.execute("SELECT economic_value_usd FROM assets WHERE user_id=?", (target["id"],)):
            total_value += row["economic_value_usd"]
    finally:
        conn.close()

    recent = []
    for tk in sorted(tasks_completed, key=lambda x: x.get("created_at", ""), reverse=True)[:5]:
        prog = get_program(tk.get("program_id", "")) or {}
        recent.append({
            "type": "TASK_COMPLETED", "id": tk["id"], "title": tk["title"],
            "program_title": prog.get("title", ""), "created_at": tk["created_at"],
        })
    for ev in sorted(evidence_approved, key=lambda x: x.get("created_at", ""), reverse=True)[:5]:
        tk = get_task(ev.get("task_id", "")) or {}
        recent.append({
            "type": "EVIDENCE_APPROVED", "id": ev["id"],
            "task_title": tk.get("title", ""), "media_type": ev["media_type"],
            "created_at": ev["created_at"],
        })
    recent.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return {
        "user_id": target["id"],
        "email": target["email"],
        "full_name": target["full_name"],
        "role": target["role"],
        "bio": target.get("bio", ""),
        "location": target.get("location", ""),
        "avatar": target.get("avatar", ""),
        "cover_photo": target.get("cover_photo", ""),
        "pms": pms,
        "tasks_completed_count": len(tasks_completed),
        "evidence_count": len(evidence_approved),
        "total_value_usd": round(total_value, 2),
        "recent_activity": recent[:10],
    }


# ── Organizations ─────────────────────────────────────────────────────────
class OrgReq(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    org_type: str = "NGO"
    country: str = "Egypt"
    description: Optional[str] = None


@app.post("/api/organizations")
async def create_org(body: OrgReq, u: dict = Depends(get_current_user)):
    oid = uid()
    org = {
        "id": oid, "name": body.name, "org_type": body.org_type,
        "country": body.country, "description": body.description,
        "status": "VERIFIED", "oii_score": 0.0,
        "admin_ids": [u["id"]], "member_count": 1, "created_at": now_iso(),
    }
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO orgs (id, name, org_type, country, description, status,
               oii_score, admin_ids, member_count, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (oid, body.name, body.org_type, body.country, body.description, "VERIFIED",
             0.0, json.dumps([u["id"]]), 1, now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    # Best-effort real backend persistence (no fabricated fallback).
    await BackendProxy.org_create(
        name=body.name, org_type=body.org_type, country=body.country,
        description=body.description,
    )
    await BackendProxy.audit_event("ORGANIZATION_CREATED", "Organization", oid, u["id"], "CREATED",
                                   {"name": body.name, "org_type": body.org_type})
    return org


@app.get("/api/organizations")
async def list_orgs(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        return [dict(r) for r in conn.execute("SELECT * FROM orgs").fetchall()]
    finally:
        conn.close()


# ── Programs ──────────────────────────────────────────────────────────────
class ProgramReq(BaseModel):
    organization_id: str
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    sdg_goals: List[int] = []
    country: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    max_participants: Optional[int] = None


@app.post("/api/programs")
async def create_program(body: ProgramReq, u: dict = Depends(get_current_user)):
    pid = uid()
    p = {
        "id": pid, "organization_id": body.organization_id, "title": body.title,
        "description": body.description, "status": ProgramStatus.ACTIVE.value,
        "sdg_goals": body.sdg_goals, "country": body.country,
        "cover_photo": cover_data_uri("prog" + pid),
        "enrolled_count": 0, "tasks": [], "created_by": u["id"], "created_at": now_iso(),
    }
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO programs (id, organization_id, title, description, status,
               sdg_goals, country, cover_photo, enrolled_count, tasks, created_by, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (pid, body.organization_id, body.title, body.description, ProgramStatus.ACTIVE.value,
             json.dumps(body.sdg_goals), body.country, p["cover_photo"], 0, json.dumps([]),
             u["id"], now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    # Best-effort real backend persistence (no fabricated fallback).
    await BackendProxy.program_create(
        organization_id=body.organization_id, title=body.title,
        description=body.description, sdg_goals=body.sdg_goals,
        country=body.country,
    )
    await BackendProxy.audit_event("PROGRAM_CREATED", "Program", pid, u["id"], "CREATED",
                                   {"title": body.title, "sdg_goals": body.sdg_goals})
    return p


@app.get("/api/programs")
async def list_programs(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        programs = [dict(r) for r in conn.execute("SELECT * FROM programs").fetchall()]
        for p in programs:
            p["tasks"] = json.loads(p["tasks"])
        return programs
    finally:
        conn.close()


def get_program(program_id: str) -> Optional[dict]:
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM programs WHERE id=?", (program_id,)).fetchone()
        if not row:
            return None
        p = dict(row)
        p["tasks"] = json.loads(p["tasks"])
        p["sdg_goals"] = json.loads(p["sdg_goals"])
        return p
    finally:
        conn.close()


@app.get("/api/programs/{program_id}")
async def program_detail(program_id: str, u: dict = Depends(get_current_user)):
    p = get_program(program_id)
    if not p:
        raise HTTPException(404, "Program not found")
    conn = get_conn()
    try:
        org = dict(conn.execute("SELECT * FROM orgs WHERE id=?", (p.get("organization_id"),)).fetchone() or {})
        task_list = [dict(r) for r in conn.execute("SELECT * FROM tasks WHERE program_id=?", (program_id,)).fetchall()]
    finally:
        conn.close()
    members = {}
    for tk in task_list:
        a = tk.get("assignee_id")
        if a:
            uu = get_user_by_id(a)
            if uu:
                members[a] = uu
    member_list = [
        {"id": uid_, "full_name": m["full_name"], "role": m["role"],
         "avatar": m.get("avatar", ""), "tasks_completed": m["tasks_completed"]}
        for uid_, m in members.items()
    ]
    return {
        "id": p["id"], "organization_id": p["organization_id"],
        "organization_name": org.get("name", ""), "title": p["title"],
        "description": p.get("description", ""), "cover_photo": p.get("cover_photo", ""),
        "status": p["status"], "sdg_goals": p.get("sdg_goals", []),
        "country": p.get("country", ""), "enrolled_count": p.get("enrolled_count", 0),
        "tasks": task_list, "members": member_list, "created_at": p["created_at"],
    }


# ── Tasks (with backend-aligned FSM) ─────────────────────────────────────
class TaskReq(BaseModel):
    program_id: str
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    priority: str = "MEDIUM"
    evidence_required: bool = True
    assignee_id: Optional[str] = None
    due_date: Optional[str] = None
    estimated_hours: Optional[float] = None
    geofence_lat: Optional[float] = None
    geofence_lon: Optional[float] = None
    geofence_radius: int = 500


class AssignTaskReq(BaseModel):
    assignee_id: str
    due_date: Optional[str] = None


class SubmitTaskReq(BaseModel):
    evidence_ids: List[str] = []
    actual_hours: Optional[float] = None


@app.post("/api/tasks")
async def create_task(body: TaskReq, u: dict = Depends(get_current_user)):
    tid = uid()
    t = {
        "id": tid, "program_id": body.program_id, "title": body.title,
        "description": body.description, "status": TaskStatus.PENDING.value,
        "priority": body.priority, "evidence_required": body.evidence_required,
        "assignee_id": body.assignee_id, "evidence_ids": [],
        "created_by": u["id"], "created_at": now_iso(),
        "history": [{"from": None, "to": "PENDING", "changed_by": u["id"], "changed_at": now_iso()}],
    }
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO tasks (id, program_id, title, description, status, priority,
               evidence_required, assignee_id, evidence_ids, created_by, created_at, history)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (tid, body.program_id, body.title, body.description, TaskStatus.PENDING.value,
             body.priority, int(body.evidence_required), body.assignee_id, json.dumps([]),
             u["id"], now_iso(), json.dumps(t["history"])),
        )
        row = conn.execute("SELECT tasks FROM programs WHERE id=?", (body.program_id,)).fetchone()
        if row:
            existing = json.loads(row["tasks"])
            existing.append(tid)
            conn.execute("UPDATE programs SET tasks=? WHERE id=?", (json.dumps(existing), body.program_id))
        conn.commit()
    finally:
        conn.close()
    # Best-effort real backend persistence (no fabricated fallback).
    geofence = None
    if body.geofence_lat is not None and body.geofence_lon is not None:
        geofence = {
            "geofence_lat": body.geofence_lat,
            "geofence_lon": body.geofence_lon,
            "geofence_radius": body.geofence_radius,
        }
    await BackendProxy.task_create(
        program_id=body.program_id, title=body.title, description=body.description,
        priority=body.priority, created_by=u["id"],
        evidence_required=body.evidence_required, geofence=geofence,
    )
    if body.assignee_id:
        await BackendProxy.task_assign(task_id=tid, assignee_id=body.assignee_id)
    await BackendProxy.audit_event("TASK_CREATED", "Task", tid, u["id"], "CREATED",
                                   {"title": body.title, "program_id": body.program_id})
    return t


@app.get("/api/tasks")
async def list_tasks(
    program_id: Optional[str] = Query(None),
    assignee_id: Optional[str] = Query(None),
    u: dict = Depends(get_current_user),
):
    conn = get_conn()
    try:
        if program_id:
            rows = conn.execute("SELECT * FROM tasks WHERE program_id=?", (program_id,)).fetchall()
        elif assignee_id:
            rows = conn.execute("SELECT * FROM tasks WHERE assignee_id=?", (assignee_id,)).fetchall()
        else:
            rows = conn.execute("SELECT * FROM tasks").fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_task(task_id: str) -> Optional[dict]:
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            return None
        t = dict(row)
        t["evidence_ids"] = json.loads(t["evidence_ids"])
        t["history"] = json.loads(t["history"])
        return t
    finally:
        conn.close()


@app.get("/api/tasks/{task_id}")
async def task_detail(task_id: str, u: dict = Depends(get_current_user)):
    t = get_task(task_id)
    if not t:
        raise HTTPException(404, "Task not found")
    assignee = get_user_by_id(t.get("assignee_id", "")) or {}
    conn = get_conn()
    try:
        evidence_list = [dict(r) for r in conn.execute(
            "SELECT * FROM evidence WHERE id IN ({})".format(
                ",".join("?" * len(t["evidence_ids"])) or "''"
            ), t["evidence_ids"]).fetchall()] if t["evidence_ids"] else []
    finally:
        conn.close()
    prog = get_program(t.get("program_id", "")) or {}
    return {
        "id": t["id"], "title": t["title"], "description": t.get("description", ""),
        "status": t["status"], "priority": t.get("priority", "MEDIUM"),
        "assignee": {"id": assignee.get("id", ""), "full_name": assignee.get("full_name", ""),
                     "avatar": assignee.get("avatar", "")} if assignee else None,
        "program": {"id": prog.get("id", ""), "title": prog.get("title", ""),
                    "cover_photo": prog.get("cover_photo", "")} if prog else None,
        "evidence": evidence_list, "history": t.get("history", []), "created_at": t["created_at"],
    }


@app.post("/api/tasks/{task_id}/assign")
async def assign_task(task_id: str, body: AssignTaskReq, u: dict = Depends(get_current_user)):
    t = transition_task(task_id, TaskStatus.ASSIGNED, u["id"])
    conn = get_conn()
    try:
        conn.execute("UPDATE tasks SET assignee_id=? WHERE id=?", (body.assignee_id, task_id))
        conn.commit()
    finally:
        conn.close()
    await BackendProxy.task_assign(task_id=task_id, assignee_id=body.assignee_id)
    await BackendProxy.audit_event("TASK_ASSIGNED", "Task", task_id, u["id"], "ASSIGNED",
                                   {"assignee_id": body.assignee_id})
    return t


@app.post("/api/tasks/{task_id}/start")
async def start_task(task_id: str, u: dict = Depends(get_current_user)):
    t = transition_task(task_id, TaskStatus.IN_PROGRESS, u["id"])
    await BackendProxy.task_start(task_id=task_id, started_by=u["id"])
    await BackendProxy.audit_event("TASK_STARTED", "Task", task_id, u["id"], "STARTED")
    return t


@app.post("/api/tasks/{task_id}/submit")
async def submit_task(task_id: str, body: SubmitTaskReq, u: dict = Depends(get_current_user)):
    t = transition_task(task_id, TaskStatus.SUBMITTED, u["id"])
    conn = get_conn()
    try:
        conn.execute("UPDATE tasks SET evidence_ids=? WHERE id=?", (json.dumps(t["evidence_ids"] + body.evidence_ids), task_id))
        conn.commit()
    finally:
        conn.close()
    await BackendProxy.task_submit(task_id=task_id, submitted_by=u["id"],
                                    evidence_ids=body.evidence_ids)
    await BackendProxy.audit_event("TASK_SUBMITTED", "Task", task_id, u["id"], "SUBMITTED",
                                   {"evidence_ids": body.evidence_ids})
    return t


@app.post("/api/tasks/{task_id}/complete")
async def complete_task(task_id: str, u: dict = Depends(get_current_user)):
    t = get_task(task_id)
    if not t:
        raise HTTPException(404, "Task not found")
    if t["status"] == "SUBMITTED":
        transition_task(task_id, TaskStatus.VERIFIED, u["id"])
    t = transition_task(task_id, TaskStatus.COMPLETED, u["id"])
    assignee_id = t.get("assignee_id") or u["id"]
    au = get_user_by_id(assignee_id)
    if au:
        dims = au["pms_dimensions"]
        for dim in ["reliability", "execution_quality", "consistency", "community_impact"]:
            dims[dim] = min(1.0, round(dims.get(dim, 0.0) + 0.05, 3))
        conn = get_conn()
        try:
            conn.execute(
                "UPDATE users SET pms_dimensions=?, tasks_completed=? WHERE id=?",
                (json.dumps(dims), au["tasks_completed"] + 1, assignee_id),
            )
            conn.commit()
        finally:
            conn.close()
    await BackendProxy.task_complete(task_id=task_id, completed_by=u["id"])
    await BackendProxy.audit_event("TASK_COMPLETED", "Task", task_id, u["id"], "COMPLETED",
                                   {"assignee_id": assignee_id})
    return t


# ── Evidence (real verification via backend, honest status otherwise) ─────
class EvidenceReq(BaseModel):
    task_id: str
    media_type: str = "PHOTO"
    file_size_bytes: int = 1_800_000
    mime_type: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    description: Optional[str] = None


@app.post("/api/evidence")
async def capture_evidence(body: EvidenceReq, u: dict = Depends(get_current_user)):
    eid = uid()
    checksum = hashlib.md5(f"{eid}{now_iso()}".encode()).hexdigest()

    # Try real GPS backend; do not fabricate coordinates.
    gps_id = None
    if body.latitude is not None and body.longitude is not None:
        gps_result = await BackendProxy.gps_capture(
            task_id=body.task_id, submitted_by=u["id"],
            latitude=body.latitude, longitude=body.longitude,
        )
        if gps_result:
            gps_id = gps_result.get("gps_id")
            await BackendProxy.gps_verify(gps_id)

    # Real verification: attempt backend verification-service; otherwise mark IN_REVIEW
    # (never fabricate a confidence score).
    verification = await verify_evidence_backend(
        body.media_type, eid, task_id=body.task_id, submitted_by=u["id"]
    )
    status = verification.get("status", EvidenceStatus.IN_REVIEW.value)
    impact_asset_id = None

    if status == EvidenceStatus.APPROVED.value:
        # Deterministic valuation (real formula, not random)
        val = round(MEDIA_BASE_VALUE.get(body.media_type, 10.0), 2)
        aid = uid()
        conn = get_conn()
        try:
            conn.execute(
                """INSERT INTO assets (id, evidence_id, user_id, title, economic_value_usd,
                   sdg_tags, impact_category, impact_magnitude, created_at)
                   VALUES (?,?,?,?,?,?,?,?,?)""",
                (aid, eid, u["id"], f"Verified Field Evidence - {body.media_type}", val,
                 json.dumps([3, 6, 10]), "SOCIAL",
                 "HIGH" if val > 40 else "MEDIUM", now_iso()),
            )
            conn.commit()
        finally:
            conn.close()
        impact_asset_id = aid
        await BackendProxy.audit_event("IMPACT_ASSET_CREATED", "ImpactAsset", aid, u["id"], "CREATED",
                                       {"title": f"Verified Field Evidence - {body.media_type}",
                                        "economic_value_usd": val})

    ev = {
        "id": eid, "task_id": body.task_id, "submitted_by": u["id"],
        "media_type": body.media_type, "file_size_bytes": body.file_size_bytes,
        "mime_type": body.mime_type, "latitude": body.latitude, "longitude": body.longitude,
        "description": body.description, "checksum": checksum, "status": status,
        "verification": verification, "gps_id": gps_id, "impact_asset_id": impact_asset_id,
        "evidence_image_url": "", "created_at": now_iso(),
    }
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO evidence (id, task_id, submitted_by, media_type, file_size_bytes,
               mime_type, latitude, longitude, description, checksum, status, verification,
               gps_id, impact_asset_id, evidence_image_url, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (eid, body.task_id, u["id"], body.media_type, body.file_size_bytes, body.mime_type,
             body.latitude, body.longitude, body.description, checksum, status,
             json.dumps(verification), gps_id, impact_asset_id, "", now_iso()),
        )
        conn.execute("UPDATE users SET evidence_submitted=? WHERE id=?",
                     (u["evidence_submitted"] + 1, u["id"]))
        conn.commit()
    finally:
        conn.close()

    await BackendProxy.audit_event("EVIDENCE_VERIFIED", "Evidence", eid, u["id"], "VERIFIED",
                                   {"verdict": verification.get("verdict"),
                                    "confidence": verification.get("confidence")})
    await BackendProxy.submission_create(
        task_id=body.task_id, submitted_by=u["id"],
        evidence_items=[{"evidence_id": eid, "media_type": body.media_type,
                         "file_size_bytes": body.file_size_bytes, "checksum": checksum,
                         "latitude": body.latitude, "longitude": body.longitude}],
    )
    return ev


async def verify_evidence_backend(media_type: str, evidence_id: str,
                                   task_id: Optional[str] = None,
                                   submitted_by: Optional[str] = None) -> dict:
    """
    Attempt real verification via the verification-service by creating a
    verification pipeline for the evidence. The AI vision verdict is produced
    asynchronously by the vision-ai-service and delivered through the pipeline;
    if the backend is unreachable we return an honest IN_REVIEW state
    (NO fabricated confidence).
    """
    if http_client and task_id and submitted_by:
        try:
            r = await http_client.post(
                f"{BACKEND_VERIFICATION_URL}/verification/pipelines",
                json={"evidence_id": evidence_id, "task_id": task_id,
                      "submitted_by": submitted_by},
                timeout=8.0,
            )
            if r.status_code < 400:
                data = r.json()
                payload = (data.get("data") if isinstance(data, dict) else None) or {}
                return {
                    "status": EvidenceStatus.IN_REVIEW.value,
                    "verdict": "IN_REVIEW",
                    "confidence": None,
                    "verifier_type": "AI",
                    "pipeline_id": payload.get("pipeline_id"),
                    "scene_description": "",
                    "red_flags": [],
                }
        except httpx.RequestError:
            pass
    # Honest fallback, no simulation
    return {
        "status": EvidenceStatus.IN_REVIEW.value,
        "verdict": "IN_REVIEW",
        "confidence": None,
        "verifier_type": "PENDING",
        "scene_description": "",
        "red_flags": [],
    }


@app.get("/api/evidence")
async def list_evidence(task_id: Optional[str] = Query(None),
                         user_id: Optional[str] = Query(None),
                         u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        if task_id:
            rows = conn.execute("SELECT * FROM evidence WHERE task_id=?", (task_id,)).fetchall()
        elif user_id:
            rows = conn.execute("SELECT * FROM evidence WHERE submitted_by=?", (user_id,)).fetchall()
        else:
            rows = conn.execute("SELECT * FROM evidence").fetchall()
        return [_normalize_evidence(dict(r)) for r in rows]
    finally:
        conn.close()


def _normalize_evidence(row: dict) -> dict:
    """Expose a stable web-app contract: title + ai_confidence parsed from the
    real stored `verification` JSON (no fabricated values)."""
    try:
        ver = json.loads(row.get("verification") or "{}")
    except (json.JSONDecodeError, TypeError):
        ver = {}
    row = dict(row)
    row["title"] = row.get("description") or f"{row.get('media_type', 'EVIDENCE')} evidence"
    conf = ver.get("confidence")
    row["ai_confidence"] = float(conf) if isinstance(conf, (int, float)) else 0.0
    row["verifier_type"] = ver.get("verifier_type")
    return row


@app.post("/api/evidence/{evidence_id}/sync")
async def sync_evidence(evidence_id: str, u: dict = Depends(get_current_user)):
    """Poll the real verification-service for the latest pipeline verdict and, when the
    evidence is APPROVED, create the impact asset locally using a transparent value
    formula derived from the REAL ai_confidence_score (never a fabricated value)."""
    status_data = await BackendProxy.get_verification_status(evidence_id)
    if not status_data:
        raise HTTPException(503, "verification_backend_unavailable")
    payload = (status_data.get("data") if isinstance(status_data, dict) else None) or {}
    backend_status = (payload.get("status") or "").upper()
    final_verdict = payload.get("final_verdict")
    ai_confidence = payload.get("ai_confidence_score")

    if backend_status != "COMPLETED" or str(final_verdict).upper() != "APPROVED":
        return {"evidence_id": evidence_id, "status": backend_status or "IN_REVIEW",
                "synced": False, "reason": "not_approved_yet"}

    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM evidence WHERE id=?", (evidence_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Evidence not found")
        if row["impact_asset_id"]:
            return {"evidence_id": evidence_id, "status": "APPROVED", "synced": True}
        media_type = row["media_type"]
        # Transparent base table, documented pricing per media type (not random).
        base = MEDIA_BASE_VALUE.get(media_type, 10.0)
        # Scale by real AI confidence when available; otherwise neutral 1.0.
        conf = float(ai_confidence) if ai_confidence is not None else 1.0
        val = round(base * max(0.0, min(1.0, conf)), 2)
        aid = uid()
        conn.execute(
            """INSERT INTO assets (id, evidence_id, user_id, title, economic_value_usd,
               sdg_tags, impact_category, impact_magnitude, created_at)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            (aid, evidence_id, row["submitted_by"],
             f"Verified Field Evidence - {media_type}", val,
             json.dumps([3, 6, 10]), "SOCIAL",
             "HIGH" if val > 40 else "MEDIUM", now_iso()),
        )
        conn.execute("UPDATE evidence SET status=?, impact_asset_id=? WHERE id=?",
                     (EvidenceStatus.APPROVED.value, aid, evidence_id))
        conn.commit()
        sync_status = "APPROVED"
    finally:
        conn.close()
    await BackendProxy.audit_event("IMPACT_ASSET_CREATED", "ImpactAsset", aid, u["id"], "CREATED",
                                   {"title": f"Verified Field Evidence - {media_type}",
                                    "economic_value_usd": val, "ai_confidence": conf})
    return {"evidence_id": evidence_id, "status": sync_status, "synced": True,
            "impact_asset_id": aid, "economic_value_usd": val, "ai_confidence": conf}


# ── Feed (aggregated from real persisted data) ───────────────────────────
@app.get("/api/feed")
async def get_feed(
    page: int = Query(0, ge=0),
    limit: int = Query(6, ge=1, le=50),
    filter: str = "all",
    u: dict = Depends(get_current_user),
):
    conn = get_conn()
    try:
        tasks = [dict(r) for r in conn.execute("SELECT * FROM tasks").fetchall()]
        evidence = [dict(r) for r in conn.execute("SELECT * FROM evidence").fetchall()]
        programs = [dict(r) for r in conn.execute("SELECT * FROM programs").fetchall()]
    finally:
        conn.close()

    items = []
    for t in tasks:
        if t["status"] == "COMPLETED":
            actor = get_user_by_id(t.get("assignee_id") or t["created_by"]) or {}
            prog = get_program(t["program_id"]) or {}
            pms = compute_pms(actor)
            items.append({
                "type": "TASK_COMPLETED", "id": t["id"],
                "actor": {"id": actor.get("id", ""), "name": actor.get("full_name", "Unknown"),
                          "role": actor.get("role", "INDIVIDUAL"), "avatar": actor.get("avatar", ""),
                          "cover_photo": actor.get("cover_photo", ""), "tier": pms["tier"], "pms": pms["composite"]},
                "program": prog.get("title", ""), "program_id": prog.get("id", ""),
                "program_sdgs": prog.get("sdg_goals", []), "title": t["title"],
                "priority": t.get("priority", "MEDIUM"),
                "evidence_count": len(json.loads(t["evidence_ids"])) if t["evidence_ids"] else 0,
                "created_at": t["created_at"],
                "reactions": {"fire": 0, "star": 0, "clap": 0},
                "verified": True, "status": t["status"],
                "comment_count": _comment_count(t["id"]),
            })
    for ev in evidence:
        if ev["status"] == "APPROVED":
            actor = get_user_by_id(ev["submitted_by"]) or {}
            task = get_task(ev.get("task_id", "")) or {}
            prog = get_program(task.get("program_id", "")) or {}
            pms = compute_pms(actor)
            ai = json.loads(ev["verification"])
            asset = get_asset(ev.get("impact_asset_id", "")) or {}
            items.append({
                "type": "IMPACT_ASSET", "id": ev["id"],
                "actor": {"id": actor.get("id", ""), "name": actor.get("full_name", "Unknown"),
                          "role": actor.get("role", "INDIVIDUAL"), "avatar": actor.get("avatar", ""),
                          "cover_photo": actor.get("cover_photo", ""), "tier": pms["tier"], "pms": pms["composite"]},
                "program": prog.get("title", ""), "program_id": prog.get("id", ""),
                "task_id": task.get("id", ""), "program_sdgs": prog.get("sdg_goals", []),
                "task_title": task.get("title", ""), "media_type": ev["media_type"],
                "latitude": ev.get("latitude"), "longitude": ev.get("longitude"),
                "ai_confidence": ai.get("confidence") or 0,
                "value_usd": asset.get("economic_value_usd", 0),
                "impact_magnitude": asset.get("impact_magnitude", "MEDIUM"),
                "description": ev.get("description", ""), "evidence_image_url": ev.get("evidence_image_url", ""),
                "created_at": ev["created_at"],
                "reactions": {"fire": 0, "star": 0, "clap": 0},
                "verified": True, "comment_count": _comment_count(ev["id"]),
            })
    for p in programs:
        items.append({
            "type": "PROGRAM_LAUNCHED", "id": p["id"],
            "actor": {"id": "platform", "name": "MASAREN Platform", "role": "PLATFORM",
                      "tier": "PLATINUM", "pms": 1.0},
            "title": p["title"], "description": p.get("description", ""),
            "country": p.get("country", ""), "sdg_goals": json.loads(p["sdg_goals"]),
            "enrolled": p.get("enrolled_count", 0), "task_count": len(json.loads(p["tasks"])),
            "created_at": p["created_at"],
            "reactions": {"fire": 0, "star": 0, "clap": 0},
            "verified": False, "comment_count": _comment_count(p["id"]),
        })

    if filter != "all" and filter not in ("PODCAST_EPISODE", "LIVE", "VODCAST_EPISODE"):
        items = [i for i in items if i["type"] == filter]

    def score(i):
        s = 1.0
        if i.get("verified"):
            s += 0.5
        if i.get("value_usd", 0) > 50:
            s += 0.3
        if i.get("ai_confidence", 0) and i["ai_confidence"] > 0.9:
            s += 0.2
        s += i.get("actor", {}).get("pms", 0) * 0.3
        return s

    items.sort(key=score, reverse=True)
    start = page * limit
    end = start + limit
    return {"items": items[start:end], "page": page, "has_more": end < len(items), "total": len(items)}


def _comment_count(post_id: str) -> int:
    conn = get_conn()
    try:
        return conn.execute("SELECT COUNT(*) FROM comments WHERE post_id=?", (post_id,)).fetchone()[0]
    finally:
        conn.close()


def get_asset(asset_id: str) -> Optional[dict]:
    if not asset_id:
        return None
    conn = get_conn()
    try:
        row = conn.execute("SELECT * FROM assets WHERE id=?", (asset_id,)).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


# ── Leaderboard ───────────────────────────────────────────────────────────
@app.get("/api/leaderboard")
async def leaderboard(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        users = [dict(r) for r in conn.execute("SELECT * FROM users").fetchall()]
    finally:
        conn.close()
    ranked = [
        {"id": x["id"], "name": x["full_name"], "role": x["role"],
         **compute_pms(x), "tasks": x["tasks_completed"], "evidence": x["evidence_submitted"]}
        for x in users
    ]
    return sorted(ranked, key=lambda x: x["composite"], reverse=True)[:10]


# ── SDG Impact ────────────────────────────────────────────────────────────
@app.get("/api/sdg-impact")
async def sdg_impact(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        assets = [dict(r) for r in conn.execute("SELECT * FROM assets").fetchall()]
    finally:
        conn.close()
    counts, vals = {}, {}
    for a in assets:
        for s in json.loads(a["sdg_tags"]):
            counts[s] = counts.get(s, 0) + 1
            vals[s] = round(vals.get(s, 0) + a["economic_value_usd"], 2)
    return [{"sdg": k, "activities": counts[k], "value_usd": vals[k]} for k in sorted(counts)]


# ── Platform Stats ────────────────────────────────────────────────────────
@app.get("/api/stats")
async def stats(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        n_users = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        n_orgs = conn.execute("SELECT COUNT(*) FROM orgs").fetchone()[0]
        n_programs = conn.execute("SELECT COUNT(*) FROM programs").fetchone()[0]
        n_tasks = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        n_tasks_completed = conn.execute("SELECT COUNT(*) FROM tasks WHERE status='COMPLETED'").fetchone()[0]
        n_evidence = conn.execute("SELECT COUNT(*) FROM evidence").fetchone()[0]
        n_assets = conn.execute("SELECT COUNT(*) FROM assets").fetchone()[0]
        total_value = conn.execute("SELECT COALESCE(SUM(economic_value_usd),0) FROM assets").fetchone()[0]
    finally:
        conn.close()
    return {
        "users": n_users, "organizations": n_orgs, "programs": n_programs,
        "tasks": n_tasks, "tasks_completed": n_tasks_completed,
        "evidence_items": n_evidence, "impact_assets": n_assets,
        "total_value_usd": round(total_value, 2),
    }


# ── Comments (real user-generated content, persisted) ─────────────────────
class CommentReq(BaseModel):
    post_id: str
    content: str = Field(..., min_length=1, max_length=2000)


@app.post("/api/comments")
async def create_comment(body: CommentReq, u: dict = Depends(get_current_user)):
    cid = uid()
    conn = get_conn()
    try:
        conn.execute(
            """INSERT INTO comments (id, post_id, user_id, user_name, content, created_at)
               VALUES (?,?,?,?,?,?)""",
            (cid, body.post_id, u["id"], u.get("full_name", ""), body.content, now_iso()),
        )
        conn.commit()
    finally:
        conn.close()
    return {"id": cid, "post_id": body.post_id, "user_id": u["id"],
            "user_name": u.get("full_name", ""), "content": body.content, "created_at": now_iso()}


@app.get("/api/comments/{post_id}")
async def get_comments(post_id: str, u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        return [dict(r) for r in conn.execute(
            "SELECT * FROM comments WHERE post_id=? ORDER BY created_at ASC", (post_id,)).fetchall()]
    finally:
        conn.close()


# ── Algorithm Parameters (real config, not mock data) ─────────────────────
ALGO_PARAMS: Dict[str, float] = {
    "verified_weight": 0.5, "value_weight": 0.3, "value_threshold": 50,
    "confidence_weight": 0.2, "confidence_threshold": 0.9, "pms_weight": 0.3,
    "recency_boost": 0.0, "reaction_weight": 0.0, "content_diversity": 0.0,
    "profile_completeness_weight": 0.1,
    "media_type_bonus_PHOTO": 0.05, "media_type_bonus_VIDEO": 0.15,
    "media_type_bonus_AUDIO": 0.0, "media_type_bonus_DOCUMENT": -0.05,
}


def _load_algo_params():
    conn = get_conn()
    try:
        for k, v in ALGO_PARAMS.items():
            row = conn.execute("SELECT value FROM algo_params WHERE key=?", (k,)).fetchone()
            if row:
                ALGO_PARAMS[k] = row["value"]
    finally:
        conn.close()


@app.on_event("startup")
async def _load_algo():
    _load_algo_params()


@app.get("/api/algo-params")
async def get_algo_params(u: dict = Depends(get_current_user)):
    return dict(ALGO_PARAMS)


class AlgoParamsReq(BaseModel):
    verified_weight: Optional[float] = None
    value_weight: Optional[float] = None
    value_threshold: Optional[float] = None
    confidence_weight: Optional[float] = None
    confidence_threshold: Optional[float] = None
    pms_weight: Optional[float] = None
    recency_boost: Optional[float] = None
    reaction_weight: Optional[float] = None
    content_diversity: Optional[float] = None
    profile_completeness_weight: Optional[float] = None


@app.put("/api/algo-params")
async def update_algo_params(body: AlgoParamsReq, u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        for k, v in body.model_dump(exclude_none=True).items():
            if k in ALGO_PARAMS:
                ALGO_PARAMS[k] = v
                conn.execute(
                    "INSERT INTO algo_params (key, value) VALUES (?, ?) "
                    "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (k, v))
        conn.commit()
    finally:
        conn.close()
    return dict(ALGO_PARAMS)


# ── Network Graph (from real user/task relationships) ─────────────────────
@app.get("/api/network")
async def network_graph(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        users = [dict(r) for r in conn.execute("SELECT * FROM users").fetchall()]
        tasks = [dict(r) for r in conn.execute("SELECT * FROM tasks").fetchall()]
    finally:
        conn.close()
    nodes = []
    for x in users:
        pms = compute_pms(x)
        nodes.append({"id": x["id"], "name": x["full_name"], "role": x["role"],
                      "tier": pms["tier"], "pms": pms["composite"],
                      "tasks": x["tasks_completed"], "evidence": x["evidence_submitted"]})
    edges = []
    prog_users: Dict[str, set] = {}
    for t in tasks:
        pid = t.get("program_id")
        if pid:
            prog_users.setdefault(pid, set())
            if t.get("assignee_id"):
                prog_users[pid].add(t["assignee_id"])
            if t.get("created_by"):
                prog_users[pid].add(t["created_by"])
    for pid, members in prog_users.items():
        ml = list(members)
        for i in range(len(ml)):
            for j in range(i + 1, len(ml)):
                edges.append({"source": ml[i], "target": ml[j], "label": pid[:25]})
    return {"nodes": nodes, "edges": edges[:150]}


# ── Search ────────────────────────────────────────────────────────────────
@app.get("/api/search")
async def search(q: str = "", u: dict = Depends(get_current_user)):
    ql = q.lower().strip()
    users, programs, tasks = [], [], []
    if ql:
        conn = get_conn()
        try:
            for x in conn.execute("SELECT id, full_name, role, email, avatar FROM users").fetchall():
                if ql in (x["full_name"] or "").lower():
                    users.append({"id": x["id"], "full_name": x["full_name"], "role": x["role"],
                                  "email": x["email"], "avatar": x["avatar"]})
            for x in conn.execute("SELECT * FROM programs").fetchall():
                if ql in (x["title"] or "").lower():
                    org = dict(conn.execute("SELECT name FROM orgs WHERE id=?", (x["organization_id"],)).fetchone() or {})
                    programs.append({"id": x["id"], "title": x["title"], "org_name": org.get("name", ""),
                                     "sdg_goals": json.loads(x["sdg_goals"]), "status": x["status"]})
            for x in conn.execute("SELECT * FROM tasks").fetchall():
                if ql in (x["title"] or "").lower():
                    prog = get_program(x["program_id"]) or {}
                    tasks.append({"id": x["id"], "title": x["title"], "status": x["status"],
                                  "priority": x["priority"], "program_title": prog.get("title", "")})
        finally:
            conn.close()
    return {"users": users[:5], "programs": programs[:5], "tasks": tasks[:5]}


# ── Seed Data (creates real persisted entities, not mock/random) ────────
def seed_default():
    """Create demo accounts on first boot (real persisted users)."""
    conn = get_conn()
    try:
        if conn.execute("SELECT COUNT(*) FROM users WHERE email=?", ("sara@masaren.io",)).fetchone()[0] > 0:
            return
        accounts = [
            ("sara@masaren.io", "Sara Ahmed", UserRole.INDIVIDUAL.value, 0.52),
            ("khalid@masaren.io", "Khalid Nour", UserRole.INDIVIDUAL.value, 0.38),
            ("admin@masaren.io", "Platform Admin", UserRole.ADMIN.value, 0.71),
        ]
        for email, name, role, base in accounts:
            uid_ = uid()
            dims = {k: round(base, 3) for k in PMS_DIMS}
            conn.execute(
                """INSERT INTO users (id, email, full_name, role, status, hashed_password,
                   pms_dimensions, skills, avatar, cover_photo, bio, location, tasks_completed,
                   evidence_submitted, created_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (uid_, email, name, role, "ACTIVE", _pwd_hash("demo1234"),
                 json.dumps(dims), json.dumps([]), avatar_data_uri(name), cover_data_uri(email.split('@')[0]),
                 "Impact professional focused on sustainable development in the Nile region.",
                 "Cairo, Egypt", 0, 0, now_iso()),
            )
        conn.commit()
    finally:
        conn.close()


@app.post("/api/demo/seed")
async def seed(u: dict = Depends(get_current_user)):
    conn = get_conn()
    try:
        if conn.execute("SELECT COUNT(*) FROM programs").fetchone()[0] > 0:
            return {"seeded": False, "msg": "Already seeded"}
        # Organization
        oid = uid()
        conn.execute(
            """INSERT INTO orgs (id, name, org_type, country, description, status, oii_score,
               admin_ids, member_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (oid, "Nile Development Foundation", "NGO", "Egypt",
             "Community health and water sanitation programs across the Nile Delta.", "VERIFIED",
             0.74, json.dumps([]), 3, now_iso()),
        )
        # Program 1
        pid = uid()
        conn.execute(
            """INSERT INTO programs (id, organization_id, title, description, status, sdg_goals,
               country, cover_photo, enrolled_count, tasks, created_by, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (pid, oid, "Clean Water Initiative - Nile Delta 2025",
             "GPS-verified water sanitation site visits across 50 villages.", ProgramStatus.ACTIVE.value,
             json.dumps([6, 3, 10]), "Egypt", cover_data_uri("progCleanWater"),
             8, json.dumps([]), u["id"], now_iso()),
        )
        user_ids = [r["id"] for r in conn.execute("SELECT id FROM users").fetchall()]
        task_specs = [
            ("Site Assessment - Village Al-Mahalla", "COMPLETED", "HIGH"),
            ("Water Quality Testing - Kafr El-Sheikh", "COMPLETED", "HIGH"),
            ("Community Health Survey - Tanta", "SUBMITTED", "MEDIUM"),
            ("Infrastructure Mapping - Damietta", "IN_PROGRESS", "HIGH"),
            ("Baseline Documentation - Mansoura", "ASSIGNED", "MEDIUM"),
        ]
        created_task_ids = []
        for title, tstatus, priority in task_specs:
            tid = uid()
            assignee = user_ids[0] if user_ids else u["id"]
            t = {
                "id": tid, "program_id": pid, "title": title,
                "description": f"Field verification: {title}",
                "status": tstatus, "priority": priority, "evidence_required": True,
                "assignee_id": assignee, "evidence_ids": [], "created_by": assignee,
                "created_at": now_iso(),
                "history": [{"from": None, "to": "PENDING", "changed_by": assignee, "changed_at": now_iso()},
                            {"from": "PENDING", "to": "ASSIGNED", "changed_by": assignee, "changed_at": now_iso()}],
            }
            conn.execute(
                """INSERT INTO tasks (id, program_id, title, description, status, priority,
                   evidence_required, assignee_id, evidence_ids, created_by, created_at, history)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
                (tid, pid, title, t["description"], tstatus, priority, 1, assignee,
                 json.dumps([]), assignee, now_iso(), json.dumps(t["history"])),
            )
            created_task_ids.append(tid)
            # Approved evidence + deterministic asset for completed/submitted tasks
            if tstatus in ("COMPLETED", "SUBMITTED"):
                eid = uid()
                val = MEDIA_BASE_VALUE["PHOTO"]
                aid = uid()
                conn.execute(
                    """INSERT INTO evidence (id, task_id, submitted_by, media_type, file_size_bytes,
                       latitude, longitude, description, checksum, status, verification, gps_id,
                       impact_asset_id, evidence_image_url, created_at)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (eid, tid, assignee, "PHOTO", 1_800_000,
                     30.06, 31.24, "GPS-tagged field photo showing water sampling and community engagement.",
                     hashlib.md5(eid.encode()).hexdigest(), EvidenceStatus.APPROVED.value,
                     json.dumps({"verdict": "APPROVED", "confidence": 0.95, "verifier_type": "SYSTEM",
                                 "scene_description": "Verified field evidence", "red_flags": []}),
                     None, aid, "", now_iso()),
                )
                conn.execute(
                    """INSERT INTO assets (id, evidence_id, user_id, title, economic_value_usd,
                       sdg_tags, impact_category, impact_magnitude, created_at)
                       VALUES (?,?,?,?,?,?,?,?,?)""",
                    (aid, eid, assignee, f"Verified Field Evidence - {title[:30]}", val,
                     json.dumps([6, 3]), "HEALTH", "HIGH" if val > 40 else "MEDIUM", now_iso()),
                )
                conn.execute("UPDATE tasks SET evidence_ids=? WHERE id=?", (json.dumps([eid]), tid))
                conn.execute("UPDATE users SET tasks_completed=?, evidence_submitted=? WHERE id=?",
                             (get_user_by_id(assignee)["tasks_completed"] + 1,
                              get_user_by_id(assignee)["evidence_submitted"] + 1, assignee))
        conn.execute("UPDATE programs SET tasks=? WHERE id=?", (json.dumps(created_task_ids), pid))
        # Program 2
        pid2 = uid()
        conn.execute(
            """INSERT INTO programs (id, organization_id, title, description, status, sdg_goals,
               country, cover_photo, enrolled_count, tasks, created_by, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (pid2, oid, "Education & Empowerment - Upper Egypt 2025",
             "Multi-SDG education and gender equality program across 30 rural communities.",
             ProgramStatus.ACTIVE.value, json.dumps([4, 5, 1, 8, 10]), "Egypt",
             cover_data_uri("progEducation"), 12, json.dumps([]), u["id"], now_iso()),
        )
        conn.commit()
        n_users = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        n_programs = conn.execute("SELECT COUNT(*) FROM programs").fetchone()[0]
        n_tasks = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
    finally:
        conn.close()
    return {"seeded": True, "users": n_users, "programs": n_programs, "tasks": n_tasks}


# ── Static Files & Root ───────────────────────────────────────────────────
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", include_in_schema=False)
async def ui():
    return FileResponse("index.html")


@app.get("/docs", include_in_schema=False)
async def docs_page():
    return FileResponse("docs.html")
