---
id: admin
title: "Guide: Administrators"
sidebar_position: 5
---

# Guide: Administrators

The SUPER_ADMIN perspective: keep the network trustworthy and healthy.

## Sign in as admin

Use the admin account (`admin@masareen.mediahubnetwork.net` / `Masareen@Admin2026`), or any
user granted `SUPER_ADMIN`. The web **Admin dashboard** (`/admin`) shows KPI count-ups and
charts via Recharts.

## Moderation queue

Some submissions/accounts are flagged by fraud scoring and routed to human review.

- `GET /admin/pending`, list items awaiting moderation.
- `POST /admin/approve`, approve/moderate an item.

You can also work the verification queue directly:
`GET /api/v1/verification/queue`, then `human-review` / `human-verdict` on a pipeline.

## Audit & oversight

- `POST /api/v1/audit/events`, record an audit event.
- `GET /api/v1/audit/review/pending`, items needing review.
- `POST /api/v1/audit/review/route`, assign a reviewer.
- `PATCH /api/v1/audit/review/{id}/resolve`, close a review.
- `GET /api/v1/audit/aggregate/{id}`, aggregated audit trail for an entity.

## Platform analytics

- `GET /api/v1/analytics/platform/summary`, top-line health.
- `GET /api/v1/analytics/sdg/progress`, SDG coverage.
- `GET /api/v1/analytics/organizations/{id}/stats`, per-org.
- `GET /api/v1/analytics/users/{id}/stats`, per-user.

## Economy oversight

- `GET /api/v1/platform/revenue/summary`, `/platform/revenue/events`, revenue.
- `GET /api/v1/billing/invoices/organization/{id}`, invoices.
- `GET /api/v1/subscriptions/{org_id}`, plan state.

## Health & operations

- `/health`, `/health/live`, `/health/ready`, process health.
- `/evidence/health`, `/api/v1/graph/health/neo4j`, dependency health.
- Check the backend logs (`combined_run*.log`) for errors.

## Security checklist (pre-production)

- [ ] Change `JWT_SECRET` to a strong random value.
- [ ] Rotate the admin password; disable `AUTO_VERIFY_ON_REGISTER` if you want manual review.
- [ ] Register the Google OAuth redirect URI in Google Cloud.
- [ ] Restrict `/admin/*` and `/api/v1/authz/*` to trusted roles.
- [ ] Enable TLS + rate limiting at the proxy in front of `:9000`/`:8080`.
