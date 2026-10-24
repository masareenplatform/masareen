---
id: verification-engine
title: The Verification Engine
sidebar_position: 4
---

# The Verification Engine

This page zooms into the services that turn captured artifacts into **verified evidence**.

## Components

```text
            ┌──────────────┐
evidence ──►│  Submission  │──start──►┌──────────────────────┐
            └──────────────┘          │  Verification Pipeline│
                                      └──────────┬───────────┘
                                                 │
                          ┌──────────────────────┼──────────────────────┐
                          ▼                      ▼                      ▼
                   ┌────────────┐         ┌────────────┐         ┌────────────┐
                   │  AI review │         │ GPS service│         │ Media svc  │
                   │ (vision)   │         │ (location) │         │ (assets)   │
                   └─────┬──────┘         └─────┬──────┘         └─────┬──────┘
                         │                      │                      │
                         └──────────► human review (audit queue) ◄─────┘
                                      │
                                      ▼
                                 verdict (validate / reject)
```

## AI review

`POST /api/v1/verification/pipelines/{pipeline_id}/ai-review`

AI agents analyze the evidence:

- **Media authenticity**, edit detection, duplicate/stock detection, EXIF consistency.
- **Relevance**, does the artifact depict the claimed work?
- **GPS cross-check**, claimed location vs. captured GPS (`/gps/verify`).
- **Document understanding**, reads uploaded docs for consistency.

Output: a **confidence score** plus structured flags.

## Human review

When AI confidence is below threshold or fraud flags trip, the pipeline routes to the
**audit queue** (`GET /api/v1/verification/queue`). A reviewer picks it up:

- `POST /api/v1/verification/pipelines/{id}/human-review`, claim the review.
- `POST /api/v1/verification/pipelines/{id}/human-verdict`, `approve` / `reject` with reason.

Audit events are recorded (`POST /api/v1/audit/events`) for the tamper-evident trail.

## Fraud scoring

`POST /fraud/score` provides an independent risk signal consumed by the pipeline and the
admin moderation queue (`/admin/pending`, `/admin/approve`).

## Finalizing

- `POST /submissions/{id}/validate`, mark submission validated → task verified.
- `POST /submissions/{id}/reject`, reject with reason; pipeline → `REJECTED`.

## Inspecting a pipeline

```bash
# full pipeline
GET /api/v1/verification/pipelines/{pipeline_id}

# pipeline for a specific evidence item
GET /api/v1/verification/pipelines/evidence/{evidence_id}
```

Both return the stage history, AI confidence, reviewer, and final verdict, the auditable
proof behind every reputation point.

## Design rationale

Splitting verification into **AI → human → verdict** stages (rather than a single boolean)
is what makes MASAREEN trustworthy: every approved claim can be explained and audited, and
thresholds can be tuned per organization or opportunity type without code changes.
