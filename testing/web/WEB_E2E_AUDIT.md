# MASAREN Web — Full E2E Audit & UI Unification

**Date:** 2026-07-12
**Scope:** Complete web E2E audit of all authenticated routes + visual unification of the
web app with the Flutter mobile app (one cohesive, Material-3-light brand platform).

## 1. E2E results

### 1a. Real user-flow E2E (`testing/web/real-e2e.mjs`)
Drives a real register → DB-verify → login → dashboard → feed flow against the **live
combined backend** (no mocks). Result: **6/6 PASS, 0 console errors.**

| Check | Result |
|---|---|
| register_ui | PASS |
| db_verify | PASS |
| login_ui | PASS (redirects to dashboard, token present) |
| dashboard_render | PASS |
| feed_render | PASS |
| no_console_errors | PASS (0) |

### 1b. Full route-load audit (`testing/web/audit-routes.mjs`)
Authenticates a real user, then loads **every** authenticated route on desktop, plus a
375px mobile pass for the bottom-nav / compose-FAB / responsive sidebar. Result:
**23/23 PASS, 0 console errors.**

Routes verified: dashboard, programs, tasks, evidence, passport, opportunities,
portfolio, profile, admin, notifications, reports, billing, **chat (fixed)**, feed,
collaborate, wallet, ads, payments, revenue — and mobile bottom-nav + compose-FAB +
sidebar-hidden checks.

### 1c. Fixes found during audit
- **`/chat` crashed** with `t.map is not a function`. Root cause: `chatService` returns
  the API envelope `{ data: [...] }`, but `ChatPage` treated the envelope object as the
  array. Fixed `ChatPage.tsx` to read `res?.data` for conversations/messages and
  `res?.data?.id` / `res?.data?.assistant_reply` for create/send. Also restyled Chat to
  the light M3 system.

## 2. Web ↔ Flutter UI unification

Goal: make the web app feel like the **same platform** as the Flutter mobile app, while
staying web-appropriate and responsive.

### Shared design language (now identical on both platforms)
- **Palette** — already matched: brand `#0250A3`, azure `#0077C8`, green `#2A9D45`,
  canvas `#F0F4FF`, ink `#0D1425`, muted `#3D4F6B`, line `#DCE6F5`.
- **Font** — web now uses **Cairo** globally (was Inter/Sora), matching Flutter's
  `GoogleFonts.cairoTextTheme`.
- **Material 3 light surfaces** — 16–20px radius cards, hairline borders, soft shadows,
  filled brand buttons (rounded 12px), rounded-full chips, 12px filled inputs with brand
  focus ring. All defined in `apps/web/src/index.css` + `tailwind.config.js`.
- **Brand identity** — `BrandMark` (gradient M tile) + `BrandWordmark` (brand→azure
  gradient text) mirror Flutter's `ShaderMask` wordmark and logo mark, used in the
  TopNav, Sidebar, Landing, Login and Register.
- **Avatars** — brand-family gradient avatars across web, matching the MASAREN brand
  (palette retuned in `postService.avatarColors`).

### Navigation parity (web mirrors the Flutter shell)
- `components/common/Branding.tsx` defines one `PRIMARY_NAV` + `TOOLS_NAV` model.
- **Desktop:** left `Sidebar` = Primary tabs (Home/Explore/Tasks/Alerts/Profile) + Tools
  group — exactly the Flutter bottom bar + app-menu-sheet, expanded.
- **Mobile:** `BottomNav` (5-tab Material-style bar) + gradient **compose FAB** mirrors
  Flutter's `NavigationBar` + `FloatingActionButton`. A `MenuSheet` ("More") mirrors
  `AppMenuSheet`. The sidebar hides on mobile; the FAB opens a `ComposeModal`
  (`ComposeSheet` equivalent).
- `TopNav` now mirrors Flutter's `SocialAppBar` (gradient wordmark, search, menu, avatar
  menu).

### Pages restyled
- `LoginPage` / `RegisterPage` — centered card, gradient wordmark, "Continue with Google"
  button, brand inputs; **E2E placeholders preserved exactly**
  (`Full Name`, `Email`, `Strong Password (8+ chars, mixed case)`, `Phone Number`, … and
  `button[type=submit"]`).
- `DashboardPage` — converted from dark tokens to clean light M3 cards.
- `ChatPage` — fixed + restyled to light theme.
- `LandingPage` — Cairo font, light `bg-aurora-light` hero, unified brand mark.
- Legacy dark-theme utilities (`text-white`, `text-gold`, `from-gold-light/to-gold`,
  `shadow-glow-gold`) are normalized to light/brand in `index.css` so the remaining 20
  feature pages stay readable and on-brand without per-file rewrites.

## 3. How to run
```powershell
# build the web app
cd apps/web; npm run build
# full route audit (needs combined backend on :8080 + postgres)
cd testing/web; node audit-routes.mjs
# real register->login->navigate flow
cd testing/web; node real-e2e.mjs
```
