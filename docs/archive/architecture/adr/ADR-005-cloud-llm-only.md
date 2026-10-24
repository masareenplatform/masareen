# ADR-005: Cloud-Only LLM Inference

**Status**: Accepted
**Date**: 2026-07-01
**Hardware Constraint**: HPE ProLiant DL360 Gen10, 0GB VRAM

## Context
Deployment server has no GPU. Local inference of models ≥7B parameters is impossible.

## Decision
All AI agent inference routes to cloud APIs via `CloudLLMClient` abstraction.
Supported providers: OpenAI (GPT-4o), Google AI Studio (Gemini 1.5 Pro/Flash).

## Architecture
```
AI Agent → CloudLLMClient (port) → OpenAIClient / GoogleAIClient (adapter)
                                  → External Cloud API
```

## Consequences
- ✅ No GPU hardware required on-premises
- ✅ Access to frontier models (GPT-4o Vision for evidence analysis)
- ✅ Provider-agnostic via factory pattern
- ⚠️ Ongoing API costs, mitigated by batching and caching
- ⚠️ Network dependency, mitigated by retry/fallback logic
- ✅ Swappable: adding AWS Bedrock requires one new adapter class
