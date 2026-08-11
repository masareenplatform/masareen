# MASAREN — Live Client Demo

## What This Demo Shows
A fully functional MASAREN BFF (API gateway + SPA) that runs standalone with a
persistent local SQLite store (`masaren_demo.db`), and **best-effort proxies
every domain operation to the real backend microservices** when they are
reachable.

Design principles (per platform-genome "never" rules):
- **NO in-memory mock data.** All domain state is persisted in SQLite.
- **NO simulated/random values.** AI confidence, impact value, GPS, and fraud
  risk are REAL (computed from actual evidence) or explicitly marked
  `IN_REVIEW` / `PENDING` — never faked.
- Every write also attempts a real call to the corresponding backend service
  (org / program / task / gps / evidence / submission / verification / audit).
  If a backend service is unreachable, the operation still succeeds locally but
  is **never** replaced by fabricated data.

The demo walks through the complete IIaaS pipeline:

```
Register User → Create Organization → Create Program → Create Task
→ Assign Task → Start Task → Submit GPS-tagged Evidence
→ Backend Verification Pipeline (real) → Impact Asset Created → PMS Score Updated
→ View Impact Passport
```

## Run in 30 Seconds

```bash
pip install fastapi uvicorn[standard] python-jose[cryptography] passlib[bcrypt] pydantic httpx
uvicorn demo:app --reload --port 8000
```

Then open **http://localhost:8000** in your browser.

## Connecting to the Real Backend

The demo proxies to the backend microservices via environment variables.
When a service is reachable, the demo performs the real operation there; when
it is not, it falls back to local persistence **without fabricating data**.

```bash
# Defaults shown; override to point at your running services
export BACKEND_ORG_URL=http://localhost:8011
export BACKEND_PROGRAM_URL=http://localhost:8012
export BACKEND_TASK_URL=http://localhost:8013
export BACKEND_GPS_URL=http://localhost:8004
export BACKEND_AUDIT_URL=http://localhost:8003
export BACKEND_EVIDENCE_URL=http://localhost:8006
export BACKEND_SUBMISSION_URL=http://localhost:8001
export BACKEND_VERIFICATION_URL=http://localhost:8005
```

Bring up the full backend stack (Postgres + Kafka + Redis + Neo4j + services)
with `docker-compose up` from the repository root, then start the demo.

### Evidence verification flow (real, async)
1. `POST /api/evidence` creates the evidence and starts a real verification pipeline
   in the verification-service. The evidence is stored as `IN_REVIEW` (no fabricated
   confidence) until the backend's vision/fraud agents complete.
2. `POST /api/evidence/{evidence_id}/sync` polls the verification-service for the
   pipeline verdict. When the backend reports `APPROVED`, the demo creates the impact
   asset locally with a **transparent value** = `MEDIA_BASE_VALUE[media_type] × ai_confidence`
   (using the real `ai_confidence_score` from the pipeline — never random). If the
   backend is unreachable the endpoint returns HTTP 503.
3. The frontend should call `sync` after a short delay (or on a timer) to reflect the
   real verification outcome.

## Demo Accounts (auto-seeded on first login)

| Email | Password | Role |
|-------|----------|------|
| sara@masaren.io | demo1234 | Field Worker (INDIVIDUAL) |
| khalid@masaren.io | demo1234 | Field Worker (INDIVIDUAL) |
| admin@masaren.io | demo1234 | Platform Admin |

Or register a new account from the UI.

## Platform Sections

| Section | What to show |
|---------|-------------|
| 📊 Dashboard | Live stats — users, programs, tasks, evidence, impact value, events emitted |
| 📋 Programs | Create organizations and programs with SDG goal tagging |
| ✅ Tasks | Full task lifecycle: PENDING → ASSIGNED → IN_PROGRESS → SUBMITTED → COMPLETED |
| 📸 Evidence | GPS-tagged evidence submission with instant AI verification simulation |
| 🪪 Impact Passport | PMS score, tier (Bronze/Silver/Gold/Platinum), 10 dimension radar |
| ⚡ Event Stream | Live immutable audit log of all domain events |

## Demo Flow for Client Presentation (10 minutes)

### 1. The Problem (1 min)
> "Billions are spent on social programs every year — with no way to verify what actually happened in the field."

### 2. Show the Dashboard (1 min)
- Point to "Events Emitted" — every action is immutable
- Point to "Impact Value $" — real economic value from field work

### 3. Create a Program (2 min)
- Click Programs → create an org → create a program with SDGs 3, 6, 10
- Explain: "This is the Clean Water Initiative. Every task generates verifiable evidence."

### 4. Assign and Execute a Task (2 min)
- Click Tasks → create a task → assign it → click Start
- Explain the state machine: PENDING → ASSIGNED → IN_PROGRESS

### 5. Submit Evidence + AI Verification (2 min)
- Click Evidence → select task → submit GPS-tagged evidence
- Watch the pipeline: Captured → AI Verified → Impact Asset Created
- Show AI confidence score and green APPROVED badge
- Explain: "In production, this calls GPT-4o Vision or Gemini Pro"

### 6. Impact Passport (2 min)
- Click Impact Passport
- Show the 10-dimension PMS radar chart updating in real time
- Show the tier badge (Bronze → Silver → Gold → Platinum)
- Show passport ID: MP-XXXXXXXX-GOLD-L2
- Explain: "This is a portable, verifiable digital identity for every field worker"

## Architecture Behind This Demo

```
Field Worker → GPS Capture → Evidence Upload
                                  ↓
                           AI Vision Agent (GPT-4o)
                                  ↓
                         Fraud Detection Agent
                                  ↓
                          [AUTO-APPROVE if confidence > 80%]
                                  ↓
                         Impact Economist Agent
                                  ↓
                         Impact Asset Created ($value)
                                  ↓
                       Graph Synthesis Engine (Neo4j)
                                  ↓
                          PMS Score Updated
                                  ↓
                          Opportunity Matching
```

## Full Platform (Production)
- 24 microservices across 11 domains
- Apache Kafka (KRaft) event bus
- PostgreSQL + PostGIS
- Neo4j knowledge graph + APOC + GDS
- 9 specialized AI agents (cloud-only inference)
- Flutter mobile app + React web app
- Kubernetes + Helm deployment
