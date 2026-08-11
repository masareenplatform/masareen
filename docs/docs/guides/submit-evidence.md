---
id: submit-evidence
title: "Guide: Submitting Verified Evidence"
sidebar_position: 4
---

# Guide: Submitting Verified Evidence

The single most important action on MASAREEN. Do it well and trust compounds.

## From the mobile app (recommended)

1. Open the assigned **task** → tap **Start**.
2. Do the field work.
3. Tap **Capture** and take a **photo** of the result. The app auto-logs **GPS**.
4. (Optional) attach a **document** or **audio** note for context.
5. Tap **Submit**.

Under the hood the app:
- requests a media upload slot (`POST /api/v1/media/upload-slot`),
- uploads the artifact,
- records evidence (`POST /evidence/`) and captures GPS (`POST /gps/capture`),
- creates a **submission** (`POST /submissions`),
- starts a **pipeline** (`POST /submissions/{id}/pipeline`).

## From the API (advanced)

```bash
BASE=https://masareen.mediahubnetwork.net
AUTH="Authorization: Bearer $TOKEN"

# 1. get an upload slot
SLOT=$(curl -s -X POST $BASE/api/v1/media/upload-slot -H "$AUTH")
# 2. upload bytes to the slot URL, then mark complete
curl -s -X PATCH $BASE/api/v1/media/<asset_id>/upload-complete -H "$AUTH"
# 3. record evidence
curl -s -X POST $BASE/evidence/ -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"task_id":"<task>","asset_id":"<asset>","kind":"photo"}'
# 4. capture GPS
curl -s -X POST $BASE/gps/capture -H "$AUTH" \
  -d '{"task_id":"<task>","lat":30.01,"lng":31.02}'
# 5. submit + start pipeline
SUB=$(curl -s -X POST $BASE/submissions -H "$AUTH" -d '{"task_id":"<task>","evidence_ids":["<ev>"]}')
curl -s -X POST $BASE/submissions/<sub>/pipeline -H "$AUTH"
```

## What the pipeline checks

See [The Verification Engine](/docs/backend/verification-engine). In short: AI reviews
authenticity + relevance + GPS; if confidence is low or fraud flags trip, a human reviewer
picks it from the queue and issues a verdict.

## Making evidence pass

- **Be on-site.** Let GPS record; match the opportunity's location.
- **Show the work.** Photo should clearly depict the claimed outcome.
- **Stay in window.** Capture during the task's active period.
- **Add context.** A short note or doc helps relevance scoring.
- **Avoid duplicates/stock.** AI detects reused or stock media.

## After validation

- Task marked `verified`.
- Your **PMS** increases; portfolio + impact passport updated.
- An edge is written in the **graph** linking you to the program/SDG.
- The organization's **OII** increases.

## If rejected

Read the reason on the pipeline (`GET /api/v1/verification/pipelines/{id}`). Fix the issue
(e.g., add GPS, clearer photo) and submit a new submission — a new pipeline runs.
