# ADR-002: Clean + Hexagonal Architecture per Service

**Status**: Accepted  
**Date**: 2024-01

## Decision

Every microservice follows Clean Architecture with these mandatory layers:

```
api/            ← FastAPI routers, request/response models (Adapters)
application/    ← Use cases, commands, queries, handlers (Application)
domain/         ← Entities, value objects, domain events, repositories (Domain)
infrastructure/ ← DB, Kafka, external APIs, repositories impl (Infrastructure)
events/         ← Outbound event publishers
```

## Rule

Business logic NEVER exists in `api/` or `infrastructure/`. Domain entities NEVER import from infrastructure.
