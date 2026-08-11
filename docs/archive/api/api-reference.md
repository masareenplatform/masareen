# 📚 MASAREN Comprehensive Technical Reference (API & Architecture)

This document serves as the definitive source of truth for the MASAREN platform's technical implementation.

## 1. High-Efficiency Communication Layer (gRPC & Protobuf)

To reduce latency and payload size, MASAREN uses **gRPC** for inter-service communication, replacing traditional REST for internal calls.

### Protobuf Definition
The core contracts are defined in `shared/protos/masaren_v1.proto`.
- **`Entity`**: The universal identity used across all services.
- **`UserProfile`**: A condensed, high-performance profile object for rapid UI rendering.
- **`VerificationRequest`**: Optimized binary transfer of media content for AI agents.

### Internal Flow
`Service A` $\rightarrow$ `gRPC Client` $\rightarrow$ `Protobuf` $\rightarrow$ `Service B`

---

## 2. Real-Time Architecture (WebSockets)

MASAREN uses a **Reactive Event-Driven UI**. No page refreshes are required.

### The WebSocket Gateway
The `websocket-gateway` acts as a bridge between the **Kafka Event Bus** and the **Client**.
1. **Event Occurrence**: An action (e.g., Evidence Verified) happens in a backend service.
2. **Event Publication**: The service publishes a message to a Kafka topic (e.g., `masaren.execution.evidence_verified`).
3. **Gateway Consumption**: The WebSocket Gateway consumes the event.
4. **Targeted Push**: The Gateway identifies the active connection for `user_id` and pushes a JSON update via WebSocket.
5. **UI Update**: The React/Flutter frontend receives the event and updates the specific state slice without reloading.

---

## 3. The "Universal Entity" Model

To support complex collaborations, we moved from "Users" and "Organizations" to a unified **Entity** system.

### Entity Hierarchy
- **Individual**: A single person.
- **Organization**: A formal body (NGO, Company).
- **Group**: A temporary or permanent collaboration of Individuals.
- **Consortium**: A strategic partnership of Organizations.

### Relational Modeling
Entities are linked via `EntityRelationship` objects:
- **MemberOf**: `User` $\rightarrow$ `Group`
- **PartnerOf**: `Org A` $\rightarrow$ `Org B`
- **Sponsors**: `Corp` $\rightarrow$ `Program`

### Graph Integration (Neo4j)
These relationships are mirrored in Neo4j as edges:
`(Entity {id: 'A'}) -[:MEMBER_OF {role: 'Lead'}]-> (Entity {id: 'B'})`
This allows for complex queries like: *"Find all individuals who have collaborated with Org X on SDG 5 projects."*

---

## 4. API Gateway (Kraken-Style)

The Gateway handles:
- **Routing**: Maps `/api/identity/*` $\rightarrow$ `identity-service`.
- **Auth**: Validates JWTs before requests hit the backend.
- **Rate Limiting**: Prevents DDoS and API abuse.
- **Aggregation**: Can combine multiple gRPC calls into a single JSON response for the frontend.

---

## 5. Efficiency & Performance Summary
| Feature | Old Way | MASAREN Way | Benefit |
| :--- | :--- | :--- | :--- |
| Communication | REST / JSON | gRPC / Protobuf | $\sim 5x$ faster, smaller payloads |
| UI Updates | Page Refresh | WebSocket / Kafka | Instant, seamless experience |
| Identity | User vs Org | Universal Entity | Infinite relational flexibility |
| Gateway | Simple Proxy | Kraken-Style Gateway | Centralized security & orchestration |
