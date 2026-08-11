---
id: individual-user
title: "Guide: Individual Users"
sidebar_position: 2
---

# Guide: Individual Users

This is the day-to-day playbook for a person using MASAREEN to prove and grow their impact.

## Your identities

You are one login, but several **identities** (see
[Profiles & Identities](/docs/concepts/profiles-and-identities)): volunteer, professional,
supporter, member. You don't manage them separately — they emerge from your activity. Each
carries its own proof and feeds the same **PMS** (Personal Merit Score).

## Daily flow

1. **Sign in** (web or app).
2. **Check the feed** (`/api/v1/posts`) — see what your network is verifying.
3. **Open Opportunities** — browse the marketplace or your personalized recommendations
   (`GET /api/v1/matching/recommendations/{user_id}`).
4. **Apply** to a task you're matched for (`POST /api/v1/opportunities/{id}/apply`).
5. **Execute** — start the task, do the work.
6. **Capture evidence** from the mobile app (photo + automatic GPS).
7. **Submit** → pipeline runs → **verified**.
8. **Watch reputation** — PMS up, portfolio entry added, impact passport updated.

## Building reputation (PMS)

Your PMS rises when pipelines **validate** your evidence. Levers:

- **Consistency** — regular verified tasks beat one big one.
- **Relevance** — evidence that clearly matches the task scores higher.
- **Location integrity** — GPS that matches the opportunity location avoids fraud flags.
- **Skill alignment** — working in your stated skill areas compounds.

## Your portable proof

- **Portfolio** (`GET /api/v1/portfolio/{user_id}`) — assets + certificates.
- **Impact passport** (`GET /api/v1/users/{user_id}/impact-passport`) — a portable,
  verifiable record you can show any donor or employer.
- **Graph** (`GET /api/v1/graph/person/{user_id}/network`) — who you've impacted with.

## Following & social

Follow other users (`POST /api/v1/users/{user_id}/follow`), message via chat
(`/api/v1/chat/conversations`), and engage on posts (like/comment/save).

## Tip: unlock better opportunities

Opportunities carry a **minimum PMS gate**. As your score climbs, opportunities that were
greyed out become available — that's the marketplace loop rewarding verified work.
