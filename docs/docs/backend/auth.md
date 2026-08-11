---
id: auth
title: Authentication & Authorization
sidebar_position: 3
---

# Authentication & Authorization

## Sign-up

```bash
curl -X POST https://masareen.mediahubnetwork.net/api/v1/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "you@example.com",
    "full_name": "Your Name",
    "password": "StrongPass@123",
    "phone": "+201000000000",
    "role": "INDIVIDUAL",
    "audience": "PROFESSIONAL"
  }'
```

With `AUTO_VERIFY_ON_REGISTER=true` (the demo config), the account is auto-verified and you
can sign in immediately. The response includes `auto_verified: true` and a friendly message.

## Password login

```bash
curl -X POST https://masareen.mediahubnetwork.net/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"StrongPass@123"}'
```

Returns:

```json
{ "success": true, "data": { "access_token": "<JWT>", "token_type": "bearer" } }
```

The JWT is signed with `JWT_SECRET`. Send it on every authed request:

```bash
Authorization: Bearer <JWT>
```

Other auth routes: `/api/v1/auth/refresh`, `/api/v1/auth/logout`,
`/api/v1/auth/password/change`, `/api/v1/auth/password/reset-request`.

## Google OAuth

The backend exposes `POST /api/v1/auth/google`. The web app implements the full OAuth
flow: it opens Google consent, exchanges the `id_token` (verified via Google's tokeninfo),
finds-or-creates the user, and issues a MASAREEN JWT. The mobile app delegates to the web
app via `url_launcher` (opens `https://masareen.mediahubnetwork.net/login?google=1`).

> **Action required (your side):** register the redirect URI
> `https://masareen.mediahubnetwork.net/oauth/google/callback` in the Google Cloud Console
> for the OAuth client. Until then, Google sign-in will not complete.

## Authorization & roles

Roles (e.g. `SUPER_ADMIN`, org roles) gate sensitive actions. Clients ask the authz service:

```bash
curl -X POST https://masareen.mediahubnetwork.net/api/v1/authz/check \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"permission":"organization:verify"}'
```

Role permissions are introspectable at `/api/v1/authz/roles/{role_name}/permissions`.

## Demo accounts

| Role | Email | Password |
|------|-------|----------|
| SUPER_ADMIN | `admin@masareen.mediahubnetwork.net` | `Masareen@Admin2026` |
| Demo individual | `demo@masareen.mediahubnetwork.net` | `Demo@12345` |

> Change the admin password and `JWT_SECRET` before any production use.
