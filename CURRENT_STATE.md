# MASAREEN Platform, Current State Report

**Last updated**: 2026-07-26  
**Backup**: `/tmp/masaren_backup_20260725_073126.tar.gz` (250 MB)

---

## Status: All gap-fix tasks completed + full-stack E2E verified

17 spec-discrepancy fixes, 7 backend import fixes, comprehensive web frontend overhaul, 6/6 Flutter E2E tests passing.

---

## 1. Platform Overview

| Layer | Status | Notes |
|---|---|---|
| **Flutter Mobile** | ✅ | 30+ screens, MD3 theme, RTL, animations, offline sync, secure storage, 6/6 E2E tests |
| **React Web** | ✅ | React 18 + Vite 5 + TypeScript + Tailwind, i18n (EN/AR), JWT refresh, production deployed |
| **Combined Backend** | ✅ | **36/36 services loaded**, async FastAPI, SQLAlchemy, Kafka |
| **Shared Kernel** | ✅ | constants, dtos, types, middleware, utils, RBAC, health checks |
| **Infrastructure** | ✅ | Alembic migrations, K8s manifests, health endpoints |
| **E2E Tests** | ✅ | 6/6 passing via Maestro |
| **Walkthrough Video** | ✅ | 47.6s at `/home/sms/masarenfinal/walkthrough_v4.mp4` |

---

## 2. Specification Compliance

### Doc 1, Technical Architecture v2.0.0
| Requirement | Status | Implementation |
|---|---|---|
| 7-layer architecture | ✅ | Shared kernel implements all layers |
| Kafka event bus + outbox | ✅ | `shared/utils/outbox.py`, `OutboxMessage` + `OutboxEntry` SQLAlchemy models |
| Async JWT authentication | ✅ | `shared/middleware/__init__.py`, HS256 + RS256 |
| RBAC middleware | ✅ | `shared/middleware/rbac.py` with role hierarchy |
| JWT TokenManager (RS256) | ✅ | `shared/utils/token_manager.py` |
| Redis cache + rate limiter | ✅ | `shared/utils/redis.py` |
| Health check system | ✅ | `shared/utils/health.py` with `HealthChecker` class (Postgres, Redis, Kafka) |
| CQRS pattern | ✅ | `shared/utils/cqrs.py` |
| Offline evidence sync | ✅ | `shared/utils/offline_sync.py` + `EvidenceDraft` model |
| Alembic migrations | ✅ | `backend/migrations/` with `001_initial.py` |
| Kubernetes manifests | ✅ | `k8s/backend.yaml` |
| flutter_secure_storage | ✅ | JWT stored via `FlutterSecureStorage` with legacy migration |
| Global error handling | ✅ | `shared/utils/app_factory.py` catches non-DomainException → JSON response |

### Doc 2, Media Institutions Blueprint
| Requirement | Status | Implementation |
|---|---|---|
| Credibility confidence scoring | ✅ | `shared/utils/confidence.py` |
| Feed ranking | ✅ | `shared/utils/feed_ranking.py` |
| Confidence badge in feed UI | ✅ | `_PostCard` in `feed_screen.dart` + web `PostCard.tsx` |

### Doc 3, Sports Profiling Blueprint
| Requirement | Status | Implementation |
|---|---|---|
| Canonical athlete passport (5 domains) | ✅ | `shared/utils/athlete_passport.py` |
| No single-score policy | ✅ | Explained dimensions, not collapsed score |

---

## 3. Backend Fixes (Latest Session)

| Fix | Files | Impact |
|---|---|---|
| `HealthChecker` class added | `backend/shared/utils/health.py` | Fixed 7 services failing to import: coin, ads, platform, notification, fraud, auth, impact_score |
| `OutboxEntry` dataclass added | `backend/shared/base_entity/__init__.py` | Fixed verification service import failure |
| Backend now loads **36/36** services | Was **1/36** due to import chain failures | All microservices functional |
| Global exception handler | `backend/shared/utils/app_factory.py` | All unhandled errors return JSON `{"success":false,"error":"INTERNAL_ERROR"}` instead of raw HTML 500 |
| UserRole `_missing_()` | identity/auth services + shared DTOs | Accepts DB role strings ("Media", "Sports Club", etc.) |

---

## 4. Web Frontend Fixes (Latest Session)

All fixes complete, TypeScript compiles clean, production build matches live site.

| File | Fix |
|---|---|
| `App.tsx` | `RequireAuth` wrapper for protected routes, 404 `NotFoundPage`, removed duplicate routes |
| `authStore.tsx` | `try-catch` on `JSON.parse(localStorage)`, `isTokenExpired()` check, `useMemo` for context |
| `LoginPage.tsx` | Fixed double-unwrap, loading/disabled state, `type="email"`, password toggle, form validation |
| `RegisterPage.tsx` | Fixed double-unwrap auto-login, `type="email"`, `inputMode`, `autoComplete`, `required` |
| `NotificationsPage.tsx` | Complete rewrite, fixed dark-theme (white on light bg), i18n, timeAgo, unread count, mark all read |
| `DashboardPage.tsx` | Removed ALL hardcoded fake data, wired real API (`bffService.dashboard()`, `coinService.getWallet()`) |
| `PostCard.tsx` | Null guard on `badge`/`post.media`, confidence badge (Verified/Partial/Unverified), i18n |
| `Composer.tsx` | Fixed blob URL memory leak, loading state on submit, i18n |
| `ProfilePage.tsx` | Working Edit Profile button with save, bio editing, i18n |
| `FeedPage.tsx` | Filter labels use i18n, "POAI · Verified" chip i18n'd |
| `Branding.tsx` | MenuSheet/ComposeModal labels i18n'd |
| `i18n.tsx` | Added 25+ new EN/AR translation keys |
| `api.ts` | Fixed login double-unwrap in `authService.login()` |

**Production verification**: `https://masareen.mediahubnetwork.net` serves `index-BPoswbeD.js` (matches our fresh build exactly). Confirmed strings: "Mark all as read", "Page not found", "Invalid email or password", "Sign In".

---

## 5. New Files Created (All Gap Fixes)

```
backend/shared/constants/__init__.py, platform-wide constants and enums
backend/shared/types/__init__.py, shared value objects (EntityId, Money, GeoPoint, etc.)
backend/shared/utils/athlete_passport.py, Doc 3 canonical athlete passport model
backend/shared/utils/offline_sync.py, Doc 1 offline evidence capture + draft queue
backend/shared/utils/health.py, health check system with HealthChecker class
backend/shared/utils/token_manager.py, JWT TokenManager with RS256 + HS256 fallback
backend/shared/middleware/rbac.py, RBAC with role hierarchy + permissions
backend/alembic.ini, Alembic configuration
backend/migrations/env.py, async Alembic environment
backend/migrations/versions/001_initial.py, initial schema (outbox_events, evidence_drafts)
k8s/backend.yaml, Deployment, Service, Ingress, Redis, Secret
```

---

## 6. Key Architecture Notes

- **API base URL**: `https://masareen.mediahubnetwork.net`
- **`api.post()` signature**: positional body `post(path, [body])`, NOT named
- **Feed API envelope**: `{"success": true, "data": [...]}`
- **NavigationBar tabs** (0-based): Home, Explore, Create(+), Courses/Profile, More
- **Coin API path**: `/api/v1/coin/` (singular)
- **Backend port**: `:8080`
- **Backend startup**: `screen -dmS backend bash /tmp/start_backend.sh`
- **DB roles**: Media, Sports Club, Sports Federation, Athlete, Government, NGO, Company, INDIVIDUAL
- **App icon**: White logo on `#FFFFFF` adaptive background
- **Admin**: `admin@masaren.org` / `Masaren@1234`
- **Emulator**: `localhost:15555` (pixel_6, android-33, SDK 34)
- **ADB**: `/tmp/platform-tools/adb`
- **Maestro**: `$HOME/.maestro/bin/maestro` v2.7.0, flags `--udid localhost:15555 --no-reinstall-driver`
- **Flutter SDK**: `/opt/flutter/bin/flutter` (3.32.0, Dart 3.8.0)
- **Public IP**: `41.33.197.134` via OpenResty/nginx proxy manager → same server
- **Web build**: `/home/sms/masarenfinal/apps/web/dist/` (React 18 + Vite 5 + TypeScript + Tailwind)

---

## 7. No remaining gaps

All identified discrepancies between frontend, backend, and the 3 specification PDFs have been implemented and verified. Flutter E2E tests pass 6/6. Web frontend compiles and deploys cleanly. Backend loads all 36 services.
