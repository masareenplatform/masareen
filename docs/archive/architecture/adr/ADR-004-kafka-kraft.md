# ADR-004: Kafka KRaft Mode (No Zookeeper)

**Status**: Accepted
**Date**: 2026-07-01
**Deciders**: Architecture Team + Gemini Brief Review

## Context
Original scaffold used Confluent Kafka + Zookeeper. Gemini brief correctly identified
that Zookeeper is deprecated in Kafka 3.x and adds operational complexity.

## Decision
Switch to `apache/kafka:3.7.0` in KRaft (combined broker+controller) mode.
Single-node for dev; 3-node KRaft cluster for production.

## Consequences
- ✅ Removes Zookeeper dependency entirely
- ✅ Simpler deployment (one container vs two)
- ✅ Better performance for small clusters
- ✅ Apache-maintained image (vs Confluent licensing concerns)
- ⚠️ KRaft is production-ready since Kafka 3.3 — no stability concerns
