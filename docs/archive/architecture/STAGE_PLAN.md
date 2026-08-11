# MASAREN Development Stage Plan

## Stage 1 — Project Structure & Architecture ✅
- Monorepo layout (423 directories)
- All 24 microservice scaffolds
- Shared kernel (events, base entity, exceptions)
- Domain event contracts
- PostgreSQL migrations (V001–V004)
- Neo4j graph schemas and Cypher queries
- Kafka topic catalog
- Architecture Decision Records (ADRs 001–003)
- Kubernetes base manifests
- CI/CD GitHub Actions pipeline
- Docker Compose for local dev

## Stage 2 — Shared Kernel (next)
- Base repository interface
- CQRS command/query bus
- Kafka producer/consumer base
- Outbox pattern implementation
- JWT middleware
- Structured logging
- Health check framework
- OpenAPI base schemas

## Stage 3 — Identity Domain
- identity-service (user CRUD, skills, impact passport)
- authentication-service (JWT, refresh tokens, OAuth2, MFA)
- authorization-service (RBAC, permissions, OPA policies)

## Stage 4 — Execution Domain
- organization-service (org CRUD, verification)
- program-service (program lifecycle, enrollment)
- task-service (task assignment, FSM state machine)
- workflow-service (multi-step orchestration)

## Stage 5 — Verification Domain
- gps-service (location capture, geofencing)
- media-service (upload, processing, CDN)
- evidence-service (evidence lifecycle)
- submission-service (intake validation)
- verification-service (AI+human pipeline)
- audit-service (immutable trail)

## Stage 6 — AI Agents
- vision-ai-service (photo/video evidence analysis)
- speech-ai-service (audio transcription, validation)
- fraud-service (anomaly detection)
- compliance-service (policy enforcement)
- planner-agent (program & task planning)
- recommendation-agent (skill/opportunity matching)
- economist-agent (impact value calculation)

## Stage 7 — Reputation
- impact-score-service (PMS computation engine)
- organization-score-service (OII computation engine)
- portfolio-service (digital asset registry)

## Stage 8 — Knowledge Graph
- graph-service (Neo4j CRUD, traversals, recommendations)
- Real-time graph updates from event streams

## Stage 9 — Marketplace
- opportunity-service (jobs, funding, scholarships)
- matching-service (AI-powered talent-opportunity matching)

## Stage 10 — Reporting & Analytics
- report-service (SDG-aligned auto-reports)
- analytics-service (real-time dashboards)
- forecast-service (predictive impact)

## Stage 11 — Frontend
- Flutter mobile app (Android + iOS)
- React web app (individual dashboard)
- React admin panel (org/admin)

## Stage 12 — Infrastructure & Deployment
- Kubernetes production configs
- Terraform cloud provisioning
- Helm charts
- Monitoring (Grafana + Prometheus)
- Secrets management
- Multi-region deployment
