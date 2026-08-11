# ADR-001: Event-Driven Architecture as Core Paradigm

**Status**: Accepted  
**Date**: 2024-01  
**Deciders**: Core Architecture Team

## Context

MASAREN must track real-world human impact with complete auditability, support millions of concurrent users across multiple stakeholder types, and enable AI agents to react to field events in real-time.

## Decision

All state changes in MASAREN are represented as **immutable domain events** stored in an append-only event store (Event Sourcing). Services communicate asynchronously via **Apache Kafka**. No service modifies another service's data directly.

## Consequences

- ✅ Full audit trail of every action
- ✅ AI agents can consume event streams without coupling to business logic
- ✅ Time-travel debugging and event replay
- ✅ Independent service scalability
- ⚠️ Eventual consistency must be designed for in UX
- ⚠️ Higher operational complexity requires strong DevOps practices
