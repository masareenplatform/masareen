---
id: verified-evidence
title: Verified Evidence, What It Actually Is
sidebar_position: 4
---

# Verified Evidence, What It Actually Is

"Verified evidence" is the central noun of MASAREEN. This page defines it precisely,
because the whole reputation system rests on getting this right.

## Definition

**Verified evidence** = a captured artifact (photo, document, audio, GPS trace) that has
passed a **verification pipeline** and is therefore accepted as proof that a specific unit
of work happened, where and when it was claimed.

It is *not* "a photo you uploaded." It is "a photo that an AI and/or human reviewer confirmed
is authentic, on-site, and relevant to the task."

## The evidence lifecycle

```text
capture (mobile)  →  upload (media slot)  →  record (evidence entity)
        │
        ▼
attach to Submission  →  start Pipeline  →  AI review  →  (human review?)  →  Verdict
        │
        ▼
VALIDATED evidence  →  feeds Task.verify + PMS + Portfolio + Graph
```

### 1. Capture
The mobile app lets you capture: photo, document, audio, or GPS. GPS is captured
automatically on relevant actions (`POST /gps/capture`, uploaded via `/gps/uploaded`) so the
*place* is proven, not just the *thing*.

### 2. Upload & record
Media goes to a signed upload slot (`POST /api/v1/media/upload-slot`), then the asset is
recorded (`POST /api/v1/media/{asset_id}` completion, or `POST /evidence/`). The evidence
service owns the evidence entity (`GET /evidence/{evidence_id}`).

### 3. Submission
Evidence is bundled into a **submission** (`POST /submissions`) tied to a task and actor.

### 4. Pipeline (the verification)
As detailed in [Workflow & Pipelines](/docs/intro/workflow-and-pipelines), the pipeline runs
AI review then optional human review and lands on a verdict
(`POST /api/v1/submissions/{id}/validate` or `.../reject`).

### 5. Becoming "verified"
Once validated, the evidence is **verified evidence**. It is immutable proof: who, what,
where (GPS), when, and who verified it (AI confidence + reviewer id). You can always pull
the pipeline trail (`GET /api/v1/verification/pipelines/evidence/{evidence_id}`).

## What makes evidence trustworthy

| Signal | How it's checked |
|--------|------------------|
| **Authenticity** | AI media analysis detects edits, duplicates, stock photos, mismatched metadata. |
| **Location** | GPS vs. the opportunity/task's claimed location; proximity scored. |
| **Relevance** | AI reads the artifact against the task description (does this photo show the work?). |
| **Timeliness** | Capture timestamp vs. task window. |
| **Independence** | Where possible, corroborating evidence (e.g., a second witness, an audit event). |

## Fraud scoring

A dedicated fraud scorer (`POST /fraud/score`) and the audit service
(`/api/v1/audit/*`) provide independent risk signals. High fraud scores route evidence to
human review and can flag an account for the admin queue (`/admin/pending`).

## Why "verified" is durable

Verified evidence is the leaf node of trust in MASAREEN:

- It powers the **PMS** (your personal merit) and **OII** (org impact) scores.
- It becomes an **asset** in your portfolio (`GET /api/v1/portfolio/{user_id}/assets`).
- It produces a portable **impact passport** entry
  (`GET /api/v1/users/{user_id}/impact-passport`), proof you can take anywhere.
- It writes an edge in the **graph** (`POST /api/v1/graph/relationships`) linking you to the
  program/SDG you impacted.

> In one sentence: **verified evidence is the atomic unit of trust in MASAREEN, and
> reputation is just the sum of verified evidence you've produced.**
