# Gemini Brief — Architectural Review & Decision Log

**Reviewed by**: Lead Systems Architect  
**Date**: 2026-07-01  
**Verdict per claim**: ACCEPTED ✅ | REJECTED ❌ | ALREADY CORRECT ✓

---

## Claim 1 — Project Overview & Core Principle
> Clean/Hexagonal Architecture, DDD, Microservices, Event Sourcing, CQRS.
> Core principle: "If an action cannot be verified, it cannot become an economic asset."

**Verdict: ALREADY CORRECT ✓**  
This matches our Stage 1–3 architecture exactly. No change needed.

---

## Claim 2 — Hardware: HPE ProLiant DL360 Gen10, 32GB RAM, 0GB VRAM
> On-premises 1U rack server, no GPU, Xeon Gold 5118.

**Verdict: ACCEPTED ✅ — Architectural implication only**  
This is real deployment context Gemini had that we did not. It has one valid consequence:
heavy local LLM inference (e.g. Llama 70B) is impossible. Our AI agents must call
**external cloud APIs** (Google AI Studio, OpenAI, AWS Bedrock) — never run models locally.
This does NOT change domain code, shared kernel, or identity services.
It DOES mean: AI agent services get a `CloudLLMClient` abstraction, not a local model runner.

---

## Claim 3 — Hybrid Infrastructure: Local state + Remote cloud AI
> Local: Kafka, Postgres, Neo4j, Redis. Remote: cloud LLM webhooks for agent inference.

**Verdict: ACCEPTED ✅ — Already implied, now made explicit**  
Our architecture never assumed local GPU inference. This formalises it.
Action: add `CloudLLMClient` base + provider implementations (OpenAI, Google, Bedrock)
to the shared kernel `utils/` layer. AI agents inject this client.

---

## Claim 4 — Docker Compose revision
Gemini proposes:
- KRaft-mode Kafka (no Zookeeper): `apache/kafka:latest` with `KAFKA_PROCESS_ROLES: broker,controller`
- Postgres 15 (`postgis/postgis:15-3.3`)
- Neo4j 5.12 community (no APOC/GDS plugins mentioned)
- No Redis, no OpenSearch

**Verdict: PARTIALLY ACCEPTED — item by item:**

| Item | Decision | Reason |
|------|----------|---------|
| KRaft Kafka (no Zookeeper) | ✅ ACCEPT | Zookeeper is deprecated in Kafka 3.x+; KRaft is production-ready and simpler. Upgrade. |
| Postgres 15 vs our 16 | ❌ REJECT | We are on `postgis/postgis:16-3.4` which is newer and stable. No downgrade. |
| Neo4j 5.12 community, no plugins | ❌ REJECT | We keep APOC + GDS plugins. They are essential for graph algorithms (PMS scoring, pathfinding). Community edition is fine. |
| Remove Redis | ❌ REJECT | Redis is required: JWT session store, rate limiting, outbox relay signalling, caching. Cannot remove. |
| Remove OpenSearch | ❌ REJECT | OpenSearch is required: full-text search across programs, opportunities, people. Cannot remove. |
| Named network `masaren-network` | ✅ ACCEPT | Good practice. Add explicit bridge network. |
| Named containers | ✅ ACCEPT | Better observability. Add `container_name` to all services. |
| `restart: always` | ✅ ACCEPT | Production resilience. Add to all services. |

---

## Claim 5 — Four AI Agents to implement
> Vision AI Agent, Fraud Detection Agent, Impact Economist, Graph Synthesis Engine.

**Verdict: ACCEPTED ✅ — Correct subset, but scope is Stage 6**  
These four agents are a valid subset of our 9 AI services. They are the highest-priority ones.
Gemini correctly identifies their Kafka-consumer + cloud-API-call pattern.
Action: scaffold these four with the `CloudLLMClient` pattern in the AI domain.
Full implementation is Stage 6, but the base structure belongs in the codebase now.

---

## Summary of Changes to Apply

1. **Docker Compose**: Switch Kafka to KRaft mode; add named network; add container names; add restart policies. Keep Postgres 16, Redis, OpenSearch, Neo4j with plugins.
2. **Shared Kernel**: Add `CloudLLMClient` abstraction + provider stub (OpenAI/Google/Bedrock).
3. **AI Services**: Scaffold the four priority agents with Kafka consumer + cloud client injection.
4. **Config**: Add cloud API key env vars to config loader.
5. **No changes** to: domain models, shared kernel infrastructure, identity services, migrations, CQRS bus, outbox pattern, JWT middleware — all correct.
