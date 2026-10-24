---
id: profiles-and-identities
title: Profiles & Multiple Identities
sidebar_position: 2
---

# Profiles & Multiple Identities

One of MASAREEN's most important design decisions is that **identity is plural by default**.
A human being is never just one thing, and an organization is never just one type. The
platform is built to model that reality instead of forcing everyone into a single box.

## Individuals are not monoliths

When you register (`POST /api/v1/users/register`) you pick a base audience -
`PROFESSIONAL` or `VOLUNTEER`, and a role such as `INDIVIDUAL`. But that is only your
starting identity. Over time you accumulate **multiple profile identities**, each with its
own context:

- **Volunteer identity**, skills, causes (SDGs), hours, verified tasks.
- **Professional / employee identity**, linked to an organization, with role and
  responsibilities.
- **Donor / supporter identity**, contributions and the impact they unlocked.
- **Member identity**, belonging to programs, clubs, or communities.

These are not separate accounts. They are **facets of one verified person**, stitched
together by your user record (`GET /api/v1/users/me`) and your reputation. You switch
context the way you switch hats, and each hat carries its own proof.

## Organizations are not monoliths either

An entity that registers as an organization (`POST /api/v1/organizations/`) may simultaneously
be:

- An **NGO** running field programs.
- A **Government agency** publishing public mandates.
- A **Company** executing CSR/ESG commitments.
- A **Partner** in collaborations (`/api/v1/partners/`).

The organization profile (`PATCH /api/v1/organizations/{id}/profile`) and its **OII**
(Organization Impact Index) reflect all of these facets. Verification
(`POST /api/v1/organizations/{id}/verify`) attests the legal/organizational identity so
that opportunities it posts carry weight.

## Why multiple identities matter

- **Context-appropriate trust.** A government reviewer and a volunteer teammate see the
  facets relevant to them, not your entire life.
- **No lost reputation.** Switching from "volunteer at NGO A" to "employee at Company B"
  doesn't erase your PMS; it enriches it.
- **Cleaner matching.** The matching service can match *the right identity* to *the right
  opportunity* (e.g., your "trainer" skills to a training task).

## Identity data model (simplified)

```text
User (one login, one JWT subject)
 ├─ Identity: INDIVIDUAL / PROFESSIONAL / VOLUNTEER ...
 ├─ Profile  (name, nationality, avatar, bio)
 ├─ Skills   (POST /api/v1/users/me/skills)
 ├─ Causes   (SDG tags)
 ├─ Memberships (orgs, programs)
 ├─ Reputation (PMS, OII components)
 └─ Impact passport (portable verified record)
        │
Organization (legal entity)
 ├─ Type flags (NGO / GOV / COMPANY / PARTNER)
 ├─ Profile & verification
 ├─ Members (POST /api/v1/organizations/{id}/members)
 └─ OII (Organization Impact Index)
```

## Privacy & control

Identities are scoped. You control what each facet exposes, and the authorization service
(`/api/v1/authz/check`) enforces who can see what. A follower sees a public profile
(`GET /api/v1/users/{id}`); an auditor sees verification context; a stranger sees a
portfolio summary.

> The takeaway: **MASAREEN does not ask "who are you?" once. It asks "which of your
> verified selves is relevant here?"**, and that is what makes trust both granular and
> durable.
