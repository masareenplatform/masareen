# ADR-007: Hybrid Local+Cloud Infrastructure Pattern

**Status**: Accepted
**Date**: 2026-07-01

## Decision
**Local on-premises** (HPE ProLiant DL360 Gen10):
- Kafka (KRaft) — event bus
- PostgreSQL + PostGIS — primary data store
- Neo4j + APOC/GDS — knowledge graph
- Redis — cache/sessions
- OpenSearch — search index

**Cloud (remote)**:
- All LLM/VLM inference (OpenAI / Google AI Studio)
- Object storage for media (S3-compatible)
- Future: CDN for evidence media delivery

## Rationale
Server has 32GB RAM, 24 vCPUs — sufficient for all data infrastructure.
0GB VRAM makes local GPU inference impossible.
Cloud APIs provide frontier model access at fractional per-call cost.

## Network Security
All cloud API calls are outbound HTTPS only.
No inbound cloud access to on-premises data.
API keys stored in Kubernetes secrets / .env — never in code.
