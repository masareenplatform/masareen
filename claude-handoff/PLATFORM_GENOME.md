# MASAREN Platform Genome (v2.0, Cleaned & Verified)

> **Single source of truth for any agent working on MASAREN.**
> Read this file first. It is the machine-friendly blueprint of the platform after the
> cleanup audit of 2026-07-12 (dead code, duplicate implementations, build artifacts and
> session/transcript clutter removed, see "Cleanup Audit" at the bottom).

---

## 0. One-line identity

**MASAREN (مسارين)**, *Impact Infrastructure as a Service (IIaaS)*. Converts verified
real-world field actions into immutable, measurable, economically valuable digital assets.
Core principle: **if an action cannot be verified, it cannot become an economic asset.**

---

## 1. Repository layout (post-cleanup)

```
MASAREN/
├── README.md                      # Human entry point
├── PLATFORM_GENOME.md             # THIS FILE, agent blueprint
├── platform-genome.json           # Machine-readable copy of this file
├── .env.example                   # Env template (copy to .env, fill secrets)
├── .gitignore
├── docker-compose.yml             # Canonical full-stack deployment (30+ services)
├── docker-compose.override.yml    # Local overrides
├── bringup.ps1 / run_e2e_audit.ps1# Helper scripts
├── Masaren-Presentation-1.pdf     # Pitch deck asset
├── apps/
│   ├── web/                       # React + TypeScript (VOLUNTEER/ORG app)  :3000
│   ├── admin/                     # React + TypeScript (HITL review)        :3001
│   └── mobile/                    # Flutter (Android/iOS) app
├── backend/                       # All microservices (Python / FastAPI)
│   ├── shared/                    # Shared kernel package (imported as `shared.*`)
│   ├── run_native.ps1             # Native dev launcher (symlinks + uvicorn)
│   ├── combined/main.py           # Loads all ORM models (used by tooling)
│   ├── <domain>/<service>/        # Services (see topology below)
│   └── ai/                        # AI agents + verification orchestrator
├── docs/                          # ALL documentation (moved here from root)
│   ├── api/                       #   api-reference.md, contracts.md
│   ├── architecture/              #   ADRs 001-007, event-catalog, service-contracts, saga
│   ├── deployment/runbooks/       #   local-dev-setup, production-checklist, k8s template
│   ├── monitoring.md, nginx-proxy.md, setup-guide.md, user-guide.md,
│   │   algorithm-guide.md, efficiency-selector.md, verification-domain-validation.md
├── infrastructure/                # DB migrations, Kafka topics, K8s, Helm, Terraform, CI
├── testing/                       # Maestro/E2E mobile + web harnesses
├── MASAREN-DEMO/                  # Standalone demo proxying the real backend
├── analytics/                     # Offline R report scripts (BYO data)
├── crewai_verification_testing/   # REMOVED (duplicate of backend/ai/verification_orchestrator_service)
├── logo/                          # Brand assets (AI-scratch .html/.js removed)
└── shared/ (top-level)            # REMOVED (unused gRPC/proto stubs; REST+Kafka is real)
```

---

## 2. Architecture

- **Style:** Domain-Driven Design · Clean/Hexagonal Architecture · CQRS · Event Sourcing ·
  Transactional Outbox · Event-Driven · Microservices · Knowledge Graph.
- **Layers:** Presentation → Experience → Business → AI → Knowledge → Data → Infrastructure.
- **Sync transport:** REST (FastAPI) behind a single API Gateway (BFF) on `:8080`.
- **Async transport:** **Kafka** (event bus, source of truth for domain events) **+ NATS**
  (real-time fan-out for social/posts/feed). NOTE: README mentions KRaft; the deployed
  `docker-compose.yml` uses Confluent Kafka **with Zookeeper**. OpenSearch is planned (search)
  but is **NOT** in the current compose stack.
- **Database strategy:** PostgreSQL+PostGIS (transactional) · Neo4j+APOC (knowledge graph) ·
  Redis (cache/sessions/rate-limit) · MinIO/S3 (evidence blobs).
- **AI deployment:** Cloud-only inference (OpenAI / Google Gemini). No local LLMs.
  Configured via `OPENAI_API_KEY` and `CREWAI_BROKER_URL` in `.env` (SETUP_GUIDE referenced
  `AI_PROVIDER`/`CLOUD_API_KEY`, those are doc aliases; `.env.example` is authoritative).

---

## 3. Service topology (authoritative, from docker-compose.yml)

Every service is built from `backend/Dockerfile.service` (`SERVICE_PATH: <path>`), runs
internally on `:8000`, and derives JWT from `JWT_SECRET`. Only the gateway and frontends are
published to the host.

| Domain | Compose key | Source path | Responsibility |
| --- | --- | --- | --- |
| Gateway | `gateway` | `backend/gateway` | BFF, routing, JWT auth, rate-limit, aggregation, published `:8080` |
| Identity | `identity` | `backend/identity/identity-service` | Users, profiles, RBAC |
| Identity | `auth` | `backend/identity/authentication-service` | Login / token issuance |
| Identity | `authz` | `backend/identity/authorization-service` | Authorization checks |
| Execution | `organization` | `backend/execution/organization-service` | Orgs, affiliations |
| Execution | `program` | `backend/execution/program-service` | Program lifecycle, SDG mapping |
| Execution | `task` | `backend/execution/task-service` | Task FSM, assignments |
| Execution | `workflow` | `backend/execution/workflow-service` | Process orchestration |
| Verification | `verification` | `backend/verification/verification-service` | Verification logic & verdicts |
| Verification | `evidence` | `backend/verification/evidence-service` | Evidence persistence/storage |
| Verification | `gps` | `backend/verification/gps-service` | Geo proof |
| Verification | `audit` | `backend/verification/audit-service` | Audit trail |
| Verification | `media` | `backend/verification/media-service` | Media handling |
| Verification | `submission` | `backend/verification/submission-service` | Submission intake |
| Graph | `graph` | `backend/graph/graph-service` | Neo4j knowledge graph |
| Reputation | `reputation` | `backend/reputation/portfolio-service` | Impact portfolios |
| Reputation | `impact-score` | `backend/reputation/impact-score-service` | Individual PMS / impact score |
| Reputation | `org-score` | `backend/reputation/organization-score-service` | Org reputation |
| Marketplace | `marketplace` | `backend/marketplace/opportunity-service` | Opportunity lifecycle |
| Marketplace | `matching` | `backend/marketplace/matching-service` | Talent/posting matching |
| Reporting | `report` | `backend/reporting/report-service` | Report generation |
| Reporting | `analytics` | `backend/reporting/analytics-service` | Live SQL analytics |
| Reporting | `forecast` | `backend/reporting/forecast-service` | Forecasting |
| Notifications | `notification` | `backend/notifications/notification-service` | FCM / in-app alerts |
| Social | `chat` | `backend/chat-service` | Chat + posts/feed (NATS fan-out) |
| Billing | `billing` | `backend/billing/billing-service` | Invoicing |
| Billing | `payment` | `backend/billing/payment-service` | Stripe / Paymob (Vodafone Cash) |
| Billing | `subscription` | `backend/billing/subscription-service` | Subscriptions |
| Partners | `partner` | `backend/partners/partner-service` | Partner orgs |
| Coin | `coin` | `backend/coin/coin-service` | MASAREN Coin (MRC) |
| Ads | `ads` | `backend/ads/ads-service` | Ads / brokerage |
| Platform | `platform` | `backend/platform/platform-service` | Platform revenue/aggregation |

### AI / verification services (implemented, orchestrated separately)
- `backend/ai/verification_orchestrator_service`, POAI deliberative crew (native `:8070`).
- `backend/ai/fraud-service/python`, fraud scoring (native `:8090`).
- Other AI modules consumed by the orchestrator: `auditor-agent`, `economist-agent`,
  `broker-agent`, `planner-agent`, `recommendation-agent`, `vision-ai-service`,
  `speech-ai-service`, `compliance-service`, `media-distribution-service`.
  These are **not** in `docker-compose.yml`; they are invoked by the orchestrator / run natively.

### Native dev ports (via `backend/run_native.ps1`)
gateway 8080 · identity 8001 · auth 8002 · organization 8004 · program 8005 · task 8006 ·
workflow 8007 · verification 8008 · evidence 8009 · graph 8011 · opportunity 8013 ·
matching 8014 · billing 8050 · notification 8060 · orchestrator 8070 · fraud-python 8090 ·
auth-python 8093 · impact-score-python 8094.

---

## 4. Data & events

- **Migrations:** `infrastructure/databases/postgres/migrations/V001__…V015__*.sql`
  (applied in order on first init; currently V001–V015, not V001–V004 as older docs state).
- **Kafka topics:** defined in `infrastructure/kafka/topics/event_catalog.yaml`; human docs at
  `docs/architecture/event-catalog.md` and `docs/api/events/event_catalog.md`.
- **Canonical events:** `organization_created`, `program_created`, `task_created/assigned/
  started/completed`, `location_reached`, `submission_uploaded`, `evidence_uploaded`,
  `evidence_verified`, `fraud_detected`, `impact_asset_created`, `impact_score_updated`,
  `organization_score_updated`, `portfolio_updated`, `graph_updated`.
- **Event rule:** never publish Kafka events without the Transactional Outbox pattern.

---

## 5. Shared kernel (`backend/shared`, imported as `shared.*`)

`base_entity` · `base_repository` · `constants` · `dtos` · `events` · `exceptions` ·
`infrastructure` · `middleware` (JWT/RBAC/bcrypt) · `testing` · `types` · `utils`
(app_factory, health, logging, kafka_producer/consumer, cqrs, cloud_llm_client, outbox).
This is the real shared package. (The old top-level `shared/` with protobuf/avro stubs was
removed, it was referenced by no code.)

---

## 6. Environment variables (`.env.example`, authoritative)

`JWT_SECRET` (required, shared by all services + gateway) · `STRIPE_SECRET_KEY` /
`STRIPE_WEBHOOK_SECRET` (optional; 501 local-ledger mode without) · `PAYMOB_*` (Egypt card +
Vodafone Cash via Paymob Accept) · `MRC_PER_EGP` (MASAREN Coin rate) ·
`FCM_SERVICE_ACCOUNT_JSON` (optional push) · `OPENAI_API_KEY` · `CREWAI_BROKER_URL` ·
`PUBLIC_GATEWAY_URL` (default `http://localhost:8080/api/v1`).
Infra connection strings are templated in compose: `DATABASE_URL`, `REDIS_URL`,
`KAFKA_BOOTSTRAP_SERVERS`, `NEO4J_URL`.

---

## 7. How to run

```bash
cp .env.example .env            # set JWT_SECRET + OPENAI_API_KEY
docker compose up -d            # full stack; gateway :8080, web :3000, admin :3001
# Native dev (per-service ports):  cd backend && ./run_native.ps1
# DB + Kafka auto-init from infrastructure/ migrations + event_catalog.yaml
```
Frontends: `apps/web` (Vite+React+TS), `apps/admin` (Vite+React+TS, Mantine),
`apps/mobile` (Flutter). `apps/web/src` is TypeScript, the old compiled `.js` duplicates
were deleted; do not reintroduce them.

---

## 8. Frontend apps

- **apps/web**, React + TypeScript (Vite). Authored in `.tsx`/`.ts`; the stale compiled `.js`
  siblings were removed during cleanup.
- **apps/admin**, React + TypeScript admin console (Mantine), built and served via nginx.
- **apps/mobile**, Flutter app (lib/ feature structure; bilingual EN/AR).
- Top-level `frontend/` (vanilla-JS prototype) was **removed**, redundant with `apps/admin`.

---

## 9. Engineering rules (hard constraints)

**Never:** bypass domain events · couple services to another service's DB · call another DB
directly · run AI inference locally · put business logic in controllers · bypass CommandBus/
QueryBus · publish Kafka without Outbox · create circular deps · expose internal entities via
API · duplicate domain logic.
**Always:** Repository pattern · validate DTOs · publish domain events · unit + integration +
contract + event tests · independent deployability · structured JSON logging · health
endpoints · idempotent consumers · framework-independent domain models.
Target: ≥90% coverage. Languages: services are **Python/FastAPI** (the Go/Rust experiments in
`authentication-service/go`, `impact-score-service/go`, `fraud-service/rust` were abandoned and
removed). Some services list Go/Rust as future targets in older docs, aspirational only.

---

## 10. Documentation index (everything lives in `docs/`)

- Architecture: `docs/architecture/adr/ADR-001..007`, `service-contracts.md`, `event-catalog.md`,
  `saga-design.md`, `verification-sequence.md`, `database-ownership.md`.
- API/human: `docs/api/api-reference.md` (gRPC is aspirational, REST/Kafka is real),
  `docs/api/contracts.md` (BFF request/response schemas).
- Runbooks: `docs/deployment/runbooks/local-dev-setup.md`, `production-checklist.md`,
  `k8s-service-template.yaml`.
- Guides: `docs/setup-guide.md`, `docs/user-guide.md`, `docs/algorithm-guide.md`,
  `docs/monitoring.md`, `docs/nginx-proxy.md`, `docs/efficiency-selector.md`,
  `docs/verification-domain-validation.md`.

---

## 11. Cleanup audit (2026-07-12), what was removed

**Removed (root clutter, all untracked or unused):** `prompt1-30.txt`, `promptres*.txt`,
`prompte2e*.txt`, `promptlog.txt`, `promptrn*.txt`, `statusreport1-5.tex`, `workstream2.tex`,
`statusreporterrors.txt`, `latexfix.txt`, `lastprompt.txt`, `output.txt`, `present.md`,
`_dbg.py`, `_net.py`, `_smoke_all.py`, `validate_evidence.*`, `audit_verification_service.py`,
`build_log.txt`, `app-arm64-v8a-release.apk`, `audit_run.*`, `_audit_run.log`, `_apk_build.*`,
`e2e_audit.json`, `report.xml`, `prune_log.txt`, `landing.png`, `on_login.png`, `.pytest_cache`,
`logs/`.

**Removed (transient session/process docs):** `AGENT_HANDOFF.md`, `CONTINUITY.md`,
`CONTINUITY_BACKEND.md`, `CONTINUITY_E2E.md`, `CONTINUITY_MOBILE_BUILD.md`,
`SESSION_CONTINUITY.md`, `SESSION_STATUS_NO_MOCK_BACKEND.md`, `SYSTEM_STATE.md`,
`PROJECT_STATE.md`, `PROJECT_REGISTRY.md`, `BASELINE.md`, `IMMEDIATE_EXECUTION_COMMAND.md`,
`IMMEDIATE_EXECUTION_PLAN.md`, `IMPLEMENTATION_PRIORITY.md`, `MAESTRO_E2E_HANDOFF.md`,
`FLUTTER_MAESTRO_E2E_HANDOFF.md`, `E2E_AUDIT.md`. Their useful content is folded into this genome.
(Kept reference docs were moved into `docs/`.)

**Removed (dead / duplicate code):** `backend/ai/fraud-service/rust` + its compiled `target/`,
`backend/identity/authentication-service/go` (+ `.exe`), `backend/reputation/impact-score-service/go`
(+ `.exe`), `backend/chat/chat-service` (duplicate of `backend/chat-service`),
`backend/social/posts-service`, `backend/bff/dashboard-service`, `maestro/` (stray `.class`),
top-level `shared/` (unused proto/avro stubs), `crewai_verification_testing/` (duplicate of the
orchestrator), `frontend/` (vanilla prototype), `backend/_repro*.py`, `backend/_fix_columns.py`,
`backend/_apply_columns.py`, `backend/selector_state.json`, `apps/web/public/*.apk`,
`MASAREN-DEMO/promptfix.txt`, logo AI-scratch `.html`/`.js`.

**Kept (live, verified):** all `docker-compose.yml` services, `backend/shared`, `docs/`,
`infrastructure/`, `apps/{web,admin,mobile}`, `testing/`, `MASAREN-DEMO/`, `analytics/`,
`logo/` assets, reference docs now under `docs/`.

**Known gaps (recommended follow-ups, not yet done):** per-function dead-code pass
(e.g. `ruff`/`vulture`) across the 30+ services; several `backend/ai/*` agents are implemented
but not yet wired into `docker-compose.yml`; OpenSearch search layer is planned but absent.
