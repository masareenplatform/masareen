---
id: overview
title: Frontend Overview
sidebar_position: 1
---

# Frontend Overview

MASAREEN ships two frontends that talk to the same backend:

- **Web app**, React 18 + TypeScript + Vite. The primary surface: landing, marketing,
  feed, admin dashboard, login, profiles.
- **Mobile app**, Flutter 3.32 / Dart 3.8. A focused, plugin-free Android client for
  capture-and-verify in the field.

Both share the **same brand identity** (brand `#0250A3`, azure `#0077C8`, accent `#2A9D45`,
canvas `#F0F4FF`) and the same backend contract.

## Brand identity

| Token | Value | Use |
|-------|-------|-----|
| `--brand` | `#0250A3` | Primary, links, buttons |
| `--azure` | `#0077C8` | Gradient partner, accents |
| `--accent` | `#2A9D45` | Success, verified, SDG |
| `--canvas` | `#F0F4FF` | Page background |
| `--ink` | `#0D1425` | Text |

The web app uses a dark cinematic landing (mesh/grid backgrounds, neon convergence, bento
features) and a light, material app shell for the authenticated experience.

## How they connect

```text
Web (React/Vite)  ─┐
                   ├─► https://masareen.mediahubnetwork.net ─► /api/v1/* ─► backend :8080
Mobile (Flutter) ─┘        (domain proxies API; serves web build on :9000)
```

The mobile app's base URL is `https://masareen.mediahubnetwork.net` (it previously defaulted
to the emulator-only `10.0.2.2:8080` and was fixed). Google sign-in on mobile delegates to
the web consent screen via `url_launcher`.

## What's next

- [Web app](/docs/frontend/web), pages, layout, theming, build/run.
- [Mobile app](/docs/frontend/mobile), setup, screens, APK, install.
