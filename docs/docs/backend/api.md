---
id: api
title: REST API Reference
sidebar_position: 5
---

# REST API Reference

Base URL (public): `https://masareen.mediahubnetwork.net`, all routes are under `/api/v1`.
The full machine-readable spec is at `/openapi.json`.

## Quick index (most-used)

### Auth
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/users/register` | Create account |
| POST | `/api/v1/auth/login` | Password login → JWT |
| POST | `/api/v1/auth/refresh` | Refresh JWT |
| POST | `/api/v1/auth/logout` | Invalidate session |
| POST | `/api/v1/auth/google` | Google OAuth exchange |
| POST | `/api/v1/authz/check` | Permission check |

### Users & Orgs
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/users/me` | Current profile |
| PATCH | `/api/v1/users/me/profile` | Update profile |
| POST | `/api/v1/users/me/skills` | Add skills |
| GET | `/api/v1/users/{id}` | Public profile |
| POST | `/api/v1/organizations/` | Create org |
| GET | `/api/v1/organizations/{id}` | Org profile |
| POST | `/api/v1/organizations/{id}/verify` | Verify org |

### Marketplace & Execution
| Method | Path | Purpose |
|--------|------|---------|
| POST, GET | `/api/v1/opportunities/` | List/create opportunities |
| POST | `/api/v1/opportunities/{id}/apply` | Apply |
| POST, GET | `/api/v1/tasks/` | List/create tasks |
| POST | `/api/v1/tasks/{id}/verify` | Verify task |
| POST, GET | `/api/v1/programs/` | Programs |
| POST | `/api/v1/workflows/templates` | Workflow templates |

### Verification
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/submissions` | Create submission |
| POST | `/submissions/{id}/pipeline` | Start pipeline |
| POST | `/api/v1/verification/pipelines/{id}/ai-review` | AI stage |
| POST | `/api/v1/verification/pipelines/{id}/human-verdict` | Human verdict |
| GET | `/api/v1/verification/queue` | Review queue |
| POST | `/evidence/` | Record evidence |
| POST | `/gps/capture` | Capture GPS |

### Reputation & Social
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/v1/portfolio/{user_id}` | Portfolio |
| GET | `/api/v1/users/{id}/impact-passport` | Portable passport |
| GET | `/api/v1/oii/{org_id}` | Org impact index |
| GET, POST | `/api/v1/posts` | Feed |
| GET, POST | `/api/v1/chat/conversations` | Messaging |
| GET | `/api/v1/matching/recommendations/{user_id}` | Matches |

### Admin
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/admin/pending` | Moderation queue |
| POST | `/admin/approve` | Approve/moderate |

## Example: full verified loop (curl)

```bash
BASE=https://masareen.mediahubnetwork.net

# 1. login
TOKEN=$(curl -s -X POST $BASE/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@masareen.mediahubnetwork.net","password":"Demo@12345"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")

# 2. browse opportunities
curl -s $BASE/api/v1/opportunities/ -H "Authorization: Bearer $TOKEN" | head -c 400

# 3. capture evidence + submit (pseudo)
#    - POST /evidence/  with media from /api/v1/media/upload-slot
#    - POST /submissions with task + evidence
#    - POST /submissions/{id}/pipeline  -> starts verification

# 4. inspect the pipeline
curl -s $BASE/api/v1/verification/queue -H "Authorization: Bearer $TOKEN"
```

## Errors

Non-2xx responses carry `message`/`errors`:

```json
{ "success": false, "data": null, "message": "Invalid credentials", "errors": null }
```

Common codes: `401` unauthenticated, `403` forbidden (authz), `404` not found,
`409` conflict (duplicate), `422` validation.
