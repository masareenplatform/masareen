# MASAREN (مسارين)
### Impact Infrastructure as a Service — IIaaS

> **"Two Paths"** — The intersection of Intention and Execution, Field Work and Digital Assets, Trust and Measurable Reputation.

MASAREN is the world's first **Impact Infrastructure Platform**, converting every verified real-world field action into immutable, measurable, and economically valuable digital assets.

---

## Core Principle

> **If an action cannot be verified, it cannot become an economic asset.**

---

## Architecture

```
Presentation Layer  →  Experience Layer  →  Business Layer
→  AI Layer  →  Knowledge Layer  →  Data Layer  →  Infrastructure Layer
```

**Patterns:** Domain-Driven Design · Clean/Hexagonal Architecture · CQRS · Event Sourcing · Event-Driven Architecture · Microservices · Knowledge Graph

---

## Repository Structure

```
MASAREN/
├── apps/                        # Frontend (Flutter mobile, React web, admin)
├── backend/
│   ├── shared/                  # Shared kernel — Stage 2
│   ├── identity/                # Identity domain — Stage 3
│   │   ├── identity-service
│   │   ├── authentication-service
│   │   └── authorization-service
│   ├── execution/               # Execution domain — Stage 4
│   │   ├── organization-service
│   │   ├── program-service
│   │   ├── task-service
│   │   └── workflow-service
│   ├── verification/            # Stage 5
│   ├── ai/                      # AI agents
│   ├── reputation/              # Stage 7
│   ├── marketplace/             # Stage 8
│   ├── reporting/               # Stage 9
│   ├── graph/                   # Stage 10
│   ├── notifications/
│   ├── billing/
│   └── gateway/                 # API Gateway
├── infrastructure/
│   ├── databases/postgres/migrations/   # V001–V004 SQL
│   ├── kafka/topics/                    # Event catalog (20 topics)
│   ├── kubernetes/                      # K8s base manifests
│   └── ci-cd/github-actions/            # CI pipeline
├── docs/
│   ├── architecture/adr/               # ADR-001 to ADR-003
│   └── architecture/decisions/         # Gemini review analysis
├── docker-compose.yml                  # Full local dev stack
└── .env.example                        # Environment variables template
```

---

## Quick Start

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env — set POSTGRES_PASSWORD, NEO4J_PASSWORD, CLOUD_API_KEY

# 2. Start infrastructure
docker compose up -d

# 3. Run a service (example: identity-service)
cd backend/identity/identity-service
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8001

# 4. API docs
open http://localhost:8001/docs
```

---

## Infrastructure Stack

| Component | Image | Purpose |
|-----------|-------|---------|
| PostgreSQL + PostGIS | `postgis/postgis:16-3.4` | Primary transactional store |
| Neo4j + APOC + GDS | `neo4j:5-community` | Knowledge graph |
| Redis | `redis:7-alpine` | Sessions, cache, rate limiting |
| Apache Kafka (KRaft) | `apache/kafka:3.7.0` | Event bus — no Zookeeper |
| OpenSearch | `opensearchproject/opensearch:2` | Full-text search |

---

## Domains & Services

| Domain | Services | Stage |
|--------|----------|-------|
| **Identity** | identity, authentication, authorization | ✅ 3 |
| **Execution** | organization, program, task, workflow | ✅ 4 |
| **Verification** | submission, media, evidence, gps, audit, verification | ✅ 5 |
| **AI** | vision-ai, fraud, economist, graph-synthesis | ✅ 6 |
| **Reputation** | impact-score, organization-score, portfolio | ✅ 7 |
| **Marketplace** | matching, opportunity | ✅ 8 |
| **Reporting** | report, analytics, forecast | ✅ 9 |
| **Graph** | graph-service | ✅ 10 |

---

## AI Architecture — Hybrid (Cloud-Only Inference)

**Deployment hardware:** HPE ProLiant DL360 Gen10 · 32GB RAM · **0GB VRAM**

All AI inference routes to cloud APIs. No local LLM execution.

| Agent | Consumes | Cloud Model | Emits |
|-------|---------|-------------|-------|
| Vision AI | `evidence_uploaded` | GPT-4o Vision / Gemini Pro | `evidence_verified` |
| Fraud Detection | `location_reached`, `evidence_uploaded` | GPT-4o / Gemini Flash | `fraud_detected` |
| Impact Economist | `evidence_verified` (APPROVED) | GPT-4o / Gemini Pro | `impact_asset_created` |
| Graph Synthesis | `impact_asset_created` | GPT-4o / Gemini Pro | `pms_updated` + Neo4j Cypher |

Set `AI_PROVIDER=google` or `AI_PROVIDER=openai` in `.env`.

---

## Shared Kernel Modules

| Module | Purpose |
|--------|---------|
| `events/` | Domain event base + 20 event contracts |
| `utils/cqrs.py` | CommandBus + QueryBus |
| `utils/kafka_producer.py` | Idempotent Kafka publisher |
| `utils/kafka_consumer.py` | At-least-once consumer base |
| `utils/outbox.py` | Transactional Outbox Pattern |
| `utils/cloud_llm_client.py` | OpenAI + Google AI client abstraction |
| `middleware/` | JWT, RBAC, bcrypt |
| `utils/app_factory.py` | Shared FastAPI factory |
| `utils/health.py` | Composable health checks |
| `utils/logging.py` | Structured JSON logging |

---

## Development Stages

- [x] **Stage 0** — Project specification
- [x] **Stage 1** — Monorepo structure (423 dirs, 24+ services)
- [x] **Stage 2** — Shared kernel (22 modules)
- [x] **Stage 3** — Identity domain (54 files, 30 tests)
- [x] **Stage 4** — Execution domain (organization, program, task, workflow)
- [x] **Stage 5** — Verification domain
- [x] **Stage 6** — AI agents (full implementation)
- [x] **Stage 7** — Reputation (PMS, OII, portfolio)
- [x] **Stage 8** — Marketplace
- [x] **Stage 9** — Reporting & analytics
- [x] **Stage 10** — Knowledge graph
- [x] **Stage 11** — Frontend (Flutter + React)
- [x] **Stage 12** — Production infrastructure

---

## License

Proprietary — MASAREN Project · All rights reserved.
