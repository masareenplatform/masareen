---
id: services
title: Services Catalog
sidebar_position: 2
---

# Services Catalog

The combined backend hosts **37 service routers**. Below is the catalog grouped by domain,
with the primary routes each exposes. (Full OpenAPI is served at `/openapi.json`.)

## Identity & Access
| Service | Key routes |
|--------|-----------|
| `ms_identity` | `/api/v1/users/*`, `/api/v1/users/me`, profiles, skills, follow |
| `ms_auth` | `/api/v1/auth/login`, `/logout`, `/refresh`, `/password/change`, `/password/reset-request` |
| `ms_authz` | `/api/v1/authz/check`, `/api/v1/authz/roles` |
| `ms_organization` | `/api/v1/organizations/*`, members, OII, verify |

## Execution (work gets done)
| Service | Key routes |
|--------|-----------|
| `ms_program` | `/api/v1/programs/*`, enroll, publish |
| `ms_task` | `/api/v1/tasks/*`, assign/start/submit/verify/complete |
| `ms_workflow` | `/api/v1/workflows/templates`, instances, advance/pause/cancel |

## Verification (trust is built)
| Service | Key routes |
|--------|-----------|
| `ms_verification` | `/api/v1/verification/pipelines/*`, `/verification/queue` |
| `ms_evidence` | `/evidence/*`, `/evidence/task/{id}`, verify |
| `ms_gps` | `/gps/capture`, `/gps/verify`, `/gps/task/{id}` |
| `ms_audit` | `/api/v1/audit/events`, review routing, aggregate |
| `ms_media` | `/api/v1/media/upload-slot`, `/api/v1/media/{asset_id}` |
| `ms_submission` | `/submissions`, pipeline/validate/reject |

## Reputation & Graphs
| Service | Key routes |
|--------|-----------|
| `ms_reputation` (portfolio) | `/api/v1/portfolio/{user_id}`, assets, certificates, impact-passport |
| `ms_impact_score` | PMS scoring, `/api/v1/reputation/score` |
| `ms_org_score` | OII, `/api/v1/oii/{org_id}` |
| `ms_graph` | `/api/v1/graph/*` — networks, talent match, SDG contributors |

## Marketplace & Social
| Service | Key routes |
|--------|-----------|
| `ms_marketplace` | `/api/v1/opportunities/*`, apply, publish |
| `ms_matching` | `/api/v1/matching/*` — recommendations, feed |
| `ms_posts` | `/api/v1/posts`, like/comment/save |
| `ms_chat` | `/api/v1/chat/conversations`, messages |
| `ms_partner` | `/api/v1/partners/*` — collaborations |

## Reporting, Analytics & Forecast
| Service | Key routes |
|--------|-----------|
| `ms_report` | `/api/v1/reports/generate`, purchase |
| `ms_analytics` | `/api/v1/analytics/*` — platform/program/user/org/SDG stats |
| `ms_forecast` | `/api/v1/forecast/impact` |

## Economy (coins, billing, ads)
| Service | Key routes |
|--------|-----------|
| `ms_coin` | `/api/v1/coin/wallets`, transactions, exchange |
| `ms_billing` | `/api/v1/billing/invoices/*` |
| `ms_subscription` | `/api/v1/subscriptions/*`, plans, upgrade |
| `ms_payment` | `/api/v1/payments/*`, Paymob PSP intents/webhooks |
| `ms_ads` | `/api/v1/ads/campaigns/*` |

## Notifications
| Service | Key routes |
|--------|-----------|
| (notifications) | `/api/v1/notifications/{user_id}`, device-tokens, preferences, read |

## Admin
| Service | Key routes |
|--------|-----------|
| (admin) | `/admin/pending`, `/admin/approve` — moderation queue |

## Response envelope

Almost every route returns the shared envelope:

```json
{
  "success": true,
  "data": { "access_token": "..." },
  "message": null,
  "errors": null,
  "meta": null
}
```

Successful responses are unwrapped to `data` by clients; non-2xx throws with `message`.
