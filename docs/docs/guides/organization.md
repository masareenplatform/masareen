---
id: organization
title: "Guide: Organizations"
sidebar_position: 3
---

# Guide: Organizations (NGO / Government / Company)

How an organization uses MASAREEN to source trusted help and prove outcomes.

## Create & verify your organization

1. Register a user, then create an organization: `POST /api/v1/organizations/`.
2. Set type flags — NGO / GOV / COMPANY / PARTNER (you can be more than one).
3. Complete the profile (`PATCH /api/v1/organizations/{id}/profile`).
4. **Verify** the organization (`POST /api/v1/organizations/{id}/verify`) so opportunities
   you post carry weight.

## Post opportunities

```bash
POST /api/v1/opportunities/
{
  "title": "Canal cleanup — Block 4",
  "description": "Remove solid waste along 500m of canal.",
  "skills": ["physical", "logistics"],
  "sdg": 6,
  "location": { "lat": 30.01, "lng": 31.02 },
  "min_pms": 40
}
```

`min_pms` gates who can apply — use it to require a baseline of trust.

## Run programs (multi-step work)

For larger initiatives, use **programs + workflows**:

- `POST /api/v1/programs/` then `enroll` participants.
- Define a **workflow template** (`POST /api/v1/workflows/templates`) with ordered steps.
- Instantiate (`POST /api/v1/workflows/templates/{id}/instantiate`) and `start`/`advance`
  the instance as work progresses.

## Manage tasks & members

- Add members (`POST /api/v1/organizations/{id}/members`).
- Review incoming applications; accept → a **task** is created.
- Monitor task lifecycle: `start → submit → verify → complete`.

## Prove outcomes

Every verified task produces **verified evidence** that rolls up into your **OII**
(Organization Impact Index): `GET /api/v1/oii/{org_id}`. Use analytics
(`/api/v1/analytics/organizations/{org_id}/stats`) and generate reports
(`POST /api/v1/reports/generate`) for funders.

## Partnerships

Collaborate via `POST /api/v1/partners/` — co-run opportunities and share verified impact.

## Why orgs love it

- Funders trust **verification pipelines**, not self-reports.
- Reputation (OII) is portable and compounding.
- Matching brings pre-vetted, reputation-gated talent to your opportunities.
