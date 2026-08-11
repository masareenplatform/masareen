# MASAREEN Verification Orchestrator - Architecture Report (Production Version)

## 1. Core Philosophy: Procedural Objective AI (POAI)
This service implements the **Procedural Objective AI** framework coined by Sherif Rashwan. The fundamental principle is that AI-generated verdicts on high-stakes evidence are **never accepted on the first pass**. Instead, the truth emerges through a structured process of **deliberation**.

### The POAI Pipeline:
1. **Diverse Inference**: Specialized agents (Fraud and Visual) provide initial, independent assessments.
2. **Critical Deliberation**: A `DeliberationAgent` cross-examines these results, identifying contradictions and challenging over-confident assertions.
3. **Objective Synthesis**: A final `ReporterAgent` synthesizes the deliberated findings into a robust, auditable verdict.

## 2. System Architecture

### 2.1 Service Design
The `verification-orchestrator-service` is a FastAPI-based microservice integrated into the `backend/ai/` domain. It operates in two modes:
- **REST API**: Synchronous triggers for manual verification requests.
- **Kafka Bridge**: An asynchronous `EventConsumer` that integrates the CrewAI pipeline directly into the MASAREEN event-driven architecture.

### 2.2 Component Mapping

| Component | Implementation | Role |
| :--- | :--- | :--- |
| **LLM Engine** | Google Gemma 4 31B IT | High-reasoning model for complex deliberation and synthesis. |
| **Orchestration** | CrewAI Framework | Manages agent roles, task dependencies, and sequential processing. |
| **Data Source** | MASAREEN-DEMO BFF | Zero-mock interaction with real platform data via REST. |
| **Audit Trail** | Shared Blackboard | Real-time logging of agent "thoughts" for full transparency. |
| **Human-in-the-Loop** | Admin Approval Tool | Mandatory human confirmation for high-risk / ambiguous verdicts. |

## 3. Production-Ready Constraints

### 3.1 Zero-Mock Policy
The service is strictly forbidden from using simulated data. It interacts with:
- **Real Database**: Via the BFF, which queries the production-ready PostgreSQL and Neo4j instances.
- **Real Events**: Consuming and producing genuine Kafka messages.
- **Real Identities**: Using actual `user_id` and `evidence_id` from the system.

### 3.2 Verification & Validation
The service is designed for production deployment:
- **Async Execution**: Long-running CrewAI processes are handled via FastAPI `BackgroundTasks` to avoid blocking the API.
- **Error Transparency**: Honest HTTP 503/500 errors are returned when infrastructure is unreachable, rather than falling back to mocks.
- **Auditability**: The `blackboard.log` ensures that every "AI thought" is recorded for human review.

---
*Architecture version 3.0 - Integrated POAI & HITL Framework.*
