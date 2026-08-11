---
id: opportunities
title: Opportunities, Tasks & the Marketplace
sidebar_position: 3
---

# Opportunities, Tasks & the Marketplace

The **marketplace** is where intention lives. It is the mechanism that turns "I need help"
into "work got done and verified."

## Opportunity

An **opportunity** is a unit of demand: a task, role, program slot, or call for
participation. Created by an organization via `POST /api/v1/opportunities/`.

Key fields:

- `title`, `description` — what needs doing.
- `skills[]` — required/desired capabilities.
- `sdg` — the Sustainable Development Goal it advances.
- `location` — where the work happens (used for GPS verification + proximity matching).
- `min_pms` — a **minimum PMS score gate** (reputation as access control).
- `type` — task / program / volunteer-call / paid-role.

Opportunities are listed (`GET /api/v1/opportunities/`), fetched individually
(`GET /api/v1/opportunities/{id}`), and published (`POST /api/v1/opportunities/{id}/publish`).

There is also **platform content** (`/api/v1/opportunities/platform-content`) — curated,
network-wide opportunities surfaced to everyone.

## From opportunity → task

When a candidate applies (`POST /api/v1/opportunities/{id}/apply`) and is accepted, the
opportunity spawns a **task** (`POST /api/v1/tasks/`). The task is the *assigned, executable*
unit:

- `assign` (`POST /api/v1/tasks/{id}/assign`) — assign to a user.
- `start` (`POST /api/v1/tasks/{id}/start`) — work begins.
- `submit` (`POST /api/v1/tasks/{id}/submit`) — evidence submitted.
- `verify` (`POST /api/v1/tasks/{id}/verify`) — verified after pipeline passes.
- `complete` / `cancel` — terminal states.

Tasks carry a history (`GET /api/v1/tasks/{id}/history`) so the lifecycle is auditable.

## Matching & recommendation

The **matching service** connects supply and demand intelligently:

- `POST /api/v1/matching/opportunities-for-user` — opportunities suited to a user.
- `POST /api/v1/matching/users-for-opportunity` — candidates for an opportunity.
- `GET /api/v1/matching/recommendations/{user_id}` — personalized feed.
- `POST /api/v1/matching/feed` — the general discovery feed.

Ranking uses **PMS score, skills, SDG alignment, and graph proximity** (who you and your
network have worked with). This is how reputation *unlocks* opportunity: higher PMS →
better-matched, higher-tier opportunities become reachable.

## Programs & workflows (bigger than one task)

A **program** (`/api/v1/programs/`) is a coordinated initiative made of many tasks, often
across multiple organizations. Programs use the **workflow engine** (see
[Workflow & Pipelines](/docs/intro/workflow-and-pipelines)) to define ordered steps, enroll
participants (`POST /api/v1/programs/{id}/enroll`), and publish an impact report at the end.

## The marketplace loop

```text
Org posts Opportunity (with min_pms gate)
        │
        ▼
Matching ranks candidates by reputation + skill
        │
        ▼
Candidate applies → accepted → Task created
        │
        ▼
Execution + Evidence → Verification Pipeline → VALIDATED
        │
        ▼
PMS up → candidate now qualifies for higher min_pms opportunities
```

This is the compounding loop that makes MASAREEN a network, not a job board.
