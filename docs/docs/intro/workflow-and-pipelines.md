---
id: workflow-and-pipelines
title: Workflow & Verification Pipelines
sidebar_position: 3
---

# Workflow & Verification Pipelines

This is the heart of MASAREEN. If you read one page, read this one. It explains how an
intention becomes verified impact, and exactly what a "pipeline" is under the hood.

## The end-to-end workflow

```text
ORGANIZATION                INDIVIDUAL / MEMBER                PLATFORM
    |                              |                              |
    |  posts Opportunity           |                              |
    |----------------------------->|                              |
    |                              |  applies / is matched        |
    |<-----------------------------|                              |
    |  accepts -> creates Task     |                              |
    |----------------------------->|                              |
    |                              |  does field work             |
    |                              |  captures Evidence (photo/   |
    |                              |  GPS/doc/audio) via mobile   |
    |                              |----------------------------->|
    |                              |                              | Submission -> Pipeline
    |                              |                              |   AI review
    |                              |                              |   Human review (if needed)
    |                              |                              |   Verdict (approve/reject)
    |                              |<-----------------------------|
    |  Task verified               |  Reputation (PMS) updated    |
    |  OII updated                 |  Impact passport updated     |
    |                              |                              |
    |  new Opportunities unlocked  |  portfolio grows             |
```

## Step by step

### 1. Opportunity creation (Intention)
An organization posts an **opportunity** (`POST /api/v1/opportunities/`) with a title,
description, required skills, an SDG tag, a location, and often a **minimum PMS score**
gate. Opportunities are the units of "someone needs help / wants work done."

### 2. Matching & application
The **matching service** (`/api/v1/matching/*`) ranks candidates by reputation, skill, and
proximity. The candidate applies (`POST /api/v1/opportunities/{id}/apply`) or is invited.
Acceptance instantiates a **task** (`POST /api/v1/tasks/`).

### 3. Execution & evidence capture
The assignee performs the work and captures **evidence** from the mobile app, a photo,
GPS coordinate, document, or audio note. Evidence is uploaded to a media slot
(`POST /api/v1/media/upload-slot`) and recorded (`POST /evidence/`).

### 4. Submission → Pipeline
A **submission** (`POST /submissions`) bundles evidence against a task. Creating a
submission starts a **verification pipeline** (`POST /api/v1/submissions/{id}/pipeline`).
This is where "pipeline" becomes concrete.

## What is a verification pipeline?

A **pipeline** is a stateful, multi-stage verification run for one submission. It is the
auditable record of *how* a piece of evidence became "verified." You can inspect any
pipeline at `GET /api/v1/verification/pipelines/{pipeline_id}` or look up the pipeline for
a specific evidence item at `GET /api/v1/verification/pipelines/evidence/{evidence_id}`.

The canonical stages:

| Stage | Endpoint | What happens |
|-------|----------|--------------|
| Ingest | `POST /submissions` | Evidence + task + actor captured as a submission. |
| Pipeline start | `POST /submissions/{id}/pipeline` | A pipeline entity is created in `PENDING`. |
| AI review | `POST /api/v1/verification/pipelines/{id}/ai-review` | AI agents score authenticity, detect tampering, cross-check GPS vs. claimed location, read documents. Produces a confidence score + flags. |
| Human review | `POST /api/v1/verification/pipelines/{id}/human-review` | If AI confidence is below threshold (or fraud flags trip), a human reviewer is assigned from the audit queue. |
| Human verdict | `POST /api/v1/verification/pipelines/{id}/human-verdict` | Reviewer approves or rejects with a reason. |
| Validate / Reject | `POST /submissions/{id}/validate`, `.../reject` | Final state written; task marked verified. |

### Pipeline state machine

```text
PENDING
   │  start pipeline
   ▼
AI_REVIEW        ──(confidence high & no flags)──► VALIDATED
   │  (confidence low / flags)
   ▼
HUMAN_REVIEW     ──(approve)──► VALIDATED
   │  (reject)
   ▼
REJECTED
```

### Why a pipeline (not a boolean)?

Because trust is earned in stages. A pipeline lets you:

- **Explain** a verdict ("approved after AI 0.91 + human review by auditor #42").
- **Audit** who verified what, and when, critical for donors and regulators.
- **Tune** thresholds per organization or opportunity type.
- **Re-open** if new evidence arrives (a new submission can spawn a new pipeline).

## From verified evidence to reputation

When a pipeline reaches `VALIDATED`:

- The **task** is marked complete/verified (`POST /api/v1/tasks/{id}/verify`).
- The individual's **PMS** (Personal Merit Score) and **OII** components update via the
  impact-score service.
- The individual's **portfolio** gains an asset and an **impact passport** entry.
- The organization's **OII** (Organization Impact Index) increases.
- The **graph service** writes a relationship (person → contributed_to → program/SDG).
- New, higher-tier **opportunities** become reachable (the loop closes).

## Workflow engine (programs & multi-step work)

For larger programs, MASAREEN has a dedicated **workflow engine**
(`/api/v1/workflows/*`): templates define ordered steps; instantiating a template creates
a workflow **instance** that can be `start`ed, `advance`d, `pause`d, or `cancel`ed. Programs
(`/api/v1/programs/`) use this to orchestrate multi-organization, multi-task initiatives -
e.g., a reforestation program = enroll → assign plots → capture per-plot evidence →
aggregate → publish impact report.

> **In short:** an *opportunity* is the ask, a *task* is the assigned work, *evidence* is the
> proof, a *pipeline* is the verification of that proof, and *reputation* is what you earn
> when the pipeline passes. The workflow engine stitches many tasks into programs.
