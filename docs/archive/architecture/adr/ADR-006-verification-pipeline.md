# ADR-006: Multi-Stage Verification Pipeline

**Status**: Accepted
**Date**: 2026-07-01

## Context
Evidence verification requires: AI analysis, fraud detection, and optionally human review.
The routing logic must be event-driven and configurable without code changes.

## Decision
Three-stage pipeline with auto-routing:
1. **AI Stage** (Vision AI Agent) — confidence 0-1
2. **Fraud Stage** (Fraud Detection Agent) — risk score 0-100
3. **Human Stage** — triggered if: AI confidence < 0.80 OR fraud risk > 30

Auto-approval: AI confidence ≥ 0.80 AND fraud risk ≤ 30 AND AI verdict = APPROVED

## Thresholds
All thresholds are configurable via environment variables — not hardcoded.
```
AI_CONFIDENCE_THRESHOLD = 0.80   (env: VERIFICATION_AI_THRESHOLD)
FRAUD_RISK_THRESHOLD    = 30     (env: VERIFICATION_FRAUD_THRESHOLD)
```

## Consequences
- ✅ Fully automated for high-confidence, low-risk evidence
- ✅ Human reviewers only see ambiguous or flagged submissions
- ✅ Configurable without deployment
- ⚠️ Human review queue must be monitored and staffed
