# MASAREN (مسارين)
### Impact Infrastructure as a Service, IIaaS

> **"Two Paths"**, The intersection of Intention and Execution, Field Work and Digital Assets, Trust and Measurable Reputation.

**MASAREN** is the world's first **Impact Infrastructure Platform**, converting every verified real-world field action into immutable, measurable, and economically valuable digital assets.

> **Core Principle:** *If an action cannot be verified, it cannot become an economic asset.*

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Repository Structure](#repository-structure)
4. [Quick Start](#quick-start)
5. [Infrastructure Stack](#infrastructure-stack)
6. [Domains & Services](#domains--services)
7. [AI Architecture](#ai-architecture--hybrid-cloud-only-inference)
8. [Shared Kernel](#shared-kernel-modules)
9. [Mobile App](#mobile-app-flutter)
10. [Web Dashboard](#web-dashboard-reacttypescript)
11. [Combined Backend](#combined-backend)
12. [Video Processing](#video-processing--hls-transcoding)
13. [IP Legal Portfolio](#ip-legal-portfolio)
14. [E2E Testing](#e2e-testing)
15. [Deployment](#deployment)
16. [Development Stages](#development-stages)
17. [API Reference](#api-reference)
18. [Configuration](#configuration)
19. [License](#license)

---

## Overview

MASAREN bridges the gap between real-world impact actions and digital economic value through a proprietary pipeline of **AI-powered verification**, **blockchain-backed asset creation**, and **knowledge graph-powered trust propagation**.

The platform operates through 12 development stages, each delivering a core capability:

| Stage | Domain | Key Deliverables |
|-------|--------|-----------------|
| 0 | Specification | Platform genome, architecture decisions |
| 1 | Monorepo | 423 directories, 24+ services, unified codebase |
| 2 | Shared Kernel | 22 reusable modules (events, CQRS, Kafka, outbox, AI client) |
| 3 | Identity | Authentication, authorization, RBAC, JWT |
| 4 | Execution | Organization, program, task, workflow management |
| 5 | Verification | Submission, media, evidence, GPS, audit, verification |
| 6 | AI | Vision AI, fraud detection, impact economist, graph synthesis |
| 7 | Reputation | Impact score, organization score, personal impact portfolio |
| 8 | Marketplace | Matching engine, opportunity marketplace |
| 9 | Reporting | Analytics, forecasting, statistical reports |
| 10 | Knowledge Graph | Neo4j integration, Cypher queries, graph synthesis |
| 11 | Frontend | Flutter mobile app + React web dashboard |
| 12 | Production | Infrastructure, CI/CD, monitoring, E2E testing |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                               │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │ Flutter Mobile  │    │ React Web       │    │ Admin Panel     │  │
│  │ (com.masaren.app)│    │ (Port :9000)    │    │ (React)         │  │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘  │
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                     EXPERIENCE LAYER                                 │
│  REST API Gateway · GraphQL · Real-time WebSocket · Push Notifications│
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                      BUSINESS LAYER                                  │
│                    35+ Microservices (FastAPI)                        │
│  ┌─────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │IDEN│ │AUTH  │ │ORG   │ │PROG  │ │TASK │ │VERIF│ │AI  │ │MKT  │ │...│ │
│  └─────┘ └──────┘ └──────┘ └──────┘ └──────┘ └─────┘ └─────┘ └─────┘ │
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                        AI LAYER                                      │
│  GPT-4o Vision · Gemini Pro · GPT-4o · Gemini Flash (Cloud APIs)    │
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                     KNOWLEDGE LAYER                                    │
│                  Neo4j Knowledge Graph + GDS                           │
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                       DATA LAYER                                     │
│  PostgreSQL+PostGIS  │ Redis  │ Kafka (KRaft)  │ OpenSearch         │
└──────────┬────────────────────────┬────────────────────────┬────────┘
           │                        │                        │
┌──────────▼────────────────────────▼────────────────────────▼────────┐
│                  INFRASTRUCTURE LAYER                                  │
│  Docker · Kubernetes · Nginx Proxy Manager · Tailscale               │
└──────────────────────────────────────────────────────────────────────┘
```

**Patterns:** Domain-Driven Design · Clean/Hexagonal Architecture · CQRS · Event Sourcing · Event-Driven Architecture · Microservices · Knowledge Graph

---

## Repository Structure

```
masareen/
├── apps/
│   ├── mobile/                      # Flutter mobile app
│   │   ├── android/                 # Android native config, splash, icons
│   │   ├── ios/                     # iOS native config
│   │   ├── lib/
│   │   │   ├── api_client.dart      # AuthApi with uploadVideo()
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart  # Logo + spinner + startup audio
│   │   │   │   ├── login_screen.dart    # API URL: http://41.33.197.134:8088
│   │   │   └── ...
│   │   ├── assets/
│   │   │   ├── sounds/              # app_startup.wav
│   │   │   └── images/              # logos, splash graphics
│   │   ├── pubspec.yaml             # Flutter deps (audioplayers ^6.1.0)
│   │   └── build/                   # APK output: app-release.apk
│   ├── web/                         # React + TypeScript web dashboard
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── social/PostCard.tsx  # HlsVideo component (hls.js)
│   │   │   │   └── social/Composer.tsx   # File upload to backend
│   │   ├── package.json             # Vite + React, hls.js dependency
│   │   ├── vite.config.ts           # Proxy: /api → localhost:8088
│   │   ├── public/                  # Static assets
│   │   ├── dist/                    # Production build
│   │   └── index.html
│   └── admin/                       # Admin panel (separate app)
├── backend/
│   ├── combined/                    # Combined FastAPI backend (port 8080)
│   │   ├── main.py                  # Application entry point
│   │   ├── extra_routers.py         # Additional route registrations
│   │   ├── video_endpoints.py       # Video upload, transcode, HLS serving
│   │   ├── google_oauth.py          # OAuth 2.0 authentication
│   │   ├── admin_panel.py           # Admin management endpoints
│   │   ├── statistical_reports.py   # Analytics and reporting
│   │   ├── seed_platform.py         # Platform initialization
│   │   ├── seed_profiles.py         # Profile and demo data seeding
│   │   ├── static/                  # Static assets (HLS, images)
│   │   ├── __pycache__/
│   │   ├── combined_run.log         # Runtime logs
│   │   └── combined_run.err          # Error logs
│   ├── shared/                      # Shared kernel modules
│   ├── identity/                    # Identity domain
│   ├── execution/                   # Execution domain
│   ├── verification/                # Verification domain
│   ├── ai/                          # AI agents
│   ├── reputation/                  # Reputation services
│   ├── marketplace/                 # Marketplace services
│   ├── reporting/                   # Reporting & analytics
│   ├── graph/                       # Knowledge graph service
│   ├── notifications/               # Push notifications
│   ├── billing/                     # Billing & subscriptions
│   ├── gateway/                     # API Gateway
│   ├── .venv/                       # Python venv with all deps
│   └── .venv_linux/                 # Linux-specific venv
├── infrastructure/
│   ├── databases/
│   │   └── postgres/
│   │       └── migrations/          # V001–V004 SQL migrations
│   ├── kafka/
│   │   └── topics/                  # Event catalog (20 topics)
│   ├── kubernetes/                  # K8s manifests (base)
│   └── ci-cd/
│       └── github-actions/          # CI/CD workflows
├── ip-legal/
│   ├── README.md                    # Directory overview
│   ├── INDEX.md                     # Master index & status tracker
│   ├── copyright/                   # Registrations & source headers
│   ├── patents/                     # IDFs, claims, prior art, provisionals
│   ├── trademarks/                  # Trademark registrations
│   ├── trade-secrets/               # Policies, NDAs, inventories
│   ├── notices/                     # Legal notices & templates
│   └── governance/                  # IP policies & procedures
├── testing/
│   ├── e2e/                         # Maestro E2E test suite (19 YAML files)
│   │   ├── 00_setup.yaml
│   │   ├── 01_login.yaml
│   │   ├── 02_register.yaml
│   │   ├── ...
│   │   ├── 18_simulation_post_interactions.yaml
│   │   ├── _login_admin.yaml
│   │   ├── run_all_tests.sh
│   │   ├── screenshots/
│   │   └── scripts/
│   └── integration/                  # Integration tests
├── docs/
│   ├── architecture/
│   │   ├── adr/                     # Architecture Decision Records (ADR-001 to ADR-003)
│   │   └── decisions/               # Gemini review analysis
│   ├── techdocs.tex                 # Technical documentation (LaTeX)
│   ├── techdocs*.tex                # Detailed technical docs (5 volumes)
│   ├── PLATFORM_GENOME.md           # Platform specification
│   ├── PLATFORM_KNOWLEDGE.md        # Technical knowledge base
│   ├── CURRENT_STATE.md             # Current development status
│   └── walkthrough_v4.mp4           # Platform walkthrough video
├── transcode-farm/                  # HLS transcoding infrastructure
├── docker-compose.yml               # Full local dev stack
├── .env.example                     # Environment variables template
├── AGENT_HANDOFF_2026-07-12.md      # Agent handoff notes (Day 1)
├── AGENT_HANDOFF_2026-07-13.md      # Agent handoff notes (Day 2)
├── AGENT_HANDOFF_2026-07-13-continuation.md
├── AUDIT_REPORT.md                  # Platform audit report
├── E2E_AUDIT.md                     # E2E testing audit
├── CURRENT_STATE.md                 # Current state summary
├── platform-genome.json             # Platform specification (JSON)
├── PLATFORM_GENOME.md               # Platform specification
├── PLATFORM_KNOWLEDGE.md            # Technical knowledge
├── statusreporterrors.txt           # Error log
├── statusreportprealpha.tex         # Pre-alpha status report (LaTeX)
├── uvicorn.log                      # Backend runtime log
├── bringup.ps1                      # Windows bringup script
├── run_e2e_audit.ps1                # E2E audit script (Windows)
├── MASAREN-DEMO/                    # Demo materials
├── masaren-web-mobile-p0/           # P0 specifications
├── k8s/                             # Kubernetes configs
├── logo/                            # Logo assets
├── .git/                            # Git repository
└── .gitignore                       # Git ignore rules
```

---

## Quick Start

### Prerequisites

- Python 3.11+ (backend)
- Flutter 3.22+ (mobile)
- Node.js 20+ (web)
- PostgreSQL 16 + PostGIS 3.4
- Redis 7
- Apache Kafka 3.7+ (KRaft mode)
- Neo4j 5 Community
- OpenSearch 2
- Docker + Docker Compose (recommended for local dev)

### 1. Clone and Configure

```bash
git clone https://github.com/SRashwan/masareen.git
cd masareen

# Environment setup (for combined backend)
cp .env.example .env
# Edit .env, set POSTGRES_PASSWORD, NEO4J_PASSWORD, CLOUD_API_KEY

# For combined backend (single FastAPI app)
export PYTHONPATH="/home/sms/masarenfinal/backend"
export DATABASE_URL="postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
export JWT_SECRET="masaren-alpha-change-me"
export REDIS_URL="redis://localhost:6379"
```

### 2. Start Infrastructure

```bash
# Option A: Full Docker stack (includes all services)
docker compose up -d

# Option B: Combined backend only (single process on port 8080)
cd backend
screen -dmS backend bash -c 'cd combined && .venv_linux/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8088 --log-level info'
curl -s http://localhost:8088/health
```

### 3. Run Services Directly (without Docker)

```bash
# Combined backend
cd backend/combined
source ../.venv_linux/bin/activate
python -m uvicorn main:app --host 0.0.0.0 --port 8088 --reload

# Web frontend (development)
cd apps/web
npm install
npm run dev   # Vite dev server on port 3000

# Web frontend (production)
npx vite build
npx vite preview --port 9000 --host 0.0.0.0

# Mobile app
cd apps/mobile
flutter pub get
flutter run
```

### 4. API Documentation

- Combined backend: `http://localhost:8088/docs`
- Web API: `http://localhost:8088/api/v1/`
- Video API: `http://localhost:8088/api/v1/videos/`
- Health: `http://localhost:8088/health`

---

## Infrastructure Stack

| Component | Image | Purpose | Default Port |
|-----------|-------|---------|-------------|
| PostgreSQL + PostGIS | `postgis/postgis:16-3.4` | Primary transactional store | 5432 |
| Neo4j + APOC + GDS | `neo4j:5-community` | Knowledge graph | 7474, 7687 |
| Redis | `redis:7-alpine` | Sessions, cache, rate limiting | 6379 |
| Apache Kafka (KRaft) | `apache/kafka:3.7.0` | Event bus, no Zookeeper | 9092 |
| OpenSearch | `opensearchproject/opensearch:2` | Full-text search | 9200 |
| Nginx Proxy Manager | `jc21/nginx-proxy-manager` | Reverse proxy, SSL | 80, 443, 81 |
| Tailscale | `tailscale/tailscale` | VPN, secure remote access | - |
| Filebrowser | Self-hosted | File management | 8080 |

### Combined Backend Services

The `backend/combined/` directory contains a unified FastAPI application that merges all 35+ microservices into a single process. This is used for:

- Production deployment (single container)
- Local development (single process)
- Testing (E2E, integration)
- Video processing (upload, transcode, HLS serving)

**Key files:**
- `main.py`, Application entry point, router registration
- `extra_routers.py`, Additional API route registrations
- `video_endpoints.py`, Video upload, transcoding, HLS streaming
- `google_oauth.py`, OAuth 2.0 authentication
- `admin_panel.py`, Admin management endpoints
- `statistical_reports.py`, Analytics and reporting
- `seed_platform.py`, Platform initialization and database seeding
- `seed_profiles.py`, Profile and demo data seeding

---

## Domains & Services

| Domain | Services | Stage | Key Files |
|--------|----------|-------|-----------|
| **Identity** | identity-service, authentication-service, authorization-service | ✅ Stage 3 | `backend/identity/` |
| **Execution** | organization-service, program-service, task-service, workflow-service | ✅ Stage 4 | `backend/execution/` |
| **Verification** | submission-service, media-service, evidence-service, gps-service, audit-service, verification-service | ✅ Stage 5 | `backend/verification/` |
| **AI** | vision-ai, fraud-detection, impact-economist, graph-synthesis | ✅ Stage 6 | `backend/ai/` + `combined/` |
| **Reputation** | impact-score, organization-score, portfolio (PMS), market-score | ✅ Stage 7 | `backend/reputation/` |
| **Marketplace** | matching-service, opportunity-marketplace | ✅ Stage 8 | `backend/marketplace/` |
| **Reporting** | report-service, analytics-service, forecast-service | ✅ Stage 9 | `backend/reporting/` |
| **Graph** | graph-service (Neo4j) | ✅ Stage 10 | `backend/graph/` |
| **Notifications** | push-service, email-service, webhook-service | ✅ | `backend/notifications/` |
| **Billing** | subscription-service, payment-service, coin-service | ✅ | `backend/billing/` |

---

## AI Architecture, Hybrid (Cloud-Only Inference)

**Deployment hardware:** HPE ProLiant DL360 Gen10 · 32GB RAM · **0GB VRAM**

All AI inference routes to cloud APIs. No local LLM execution.

| Agent | Consumes | Cloud Model | Emits |
|-------|---------|-------------|-------|
| Vision AI | `evidence_uploaded` | GPT-4o Vision / Gemini Pro | `evidence_verified` |
| Fraud Detection | `location_reached`, `evidence_uploaded` | GPT-4o / Gemini Flash | `fraud_detected` |
| Impact Economist | `evidence_verified` (APPROVED) | GPT-4o / Gemini Pro | `impact_asset_created` |
| Graph Synthesis | `impact_asset_created` | GPT-4o / Gemini Pro | `pms_updated` + Neo4j Cypher |

Set `AI_PROVIDER=google` or `AI_PROVIDER=openai` in `.env`.

### Required API Keys

```env
OPENAI_API_KEY=your-openai-key-here
GOOGLE_API_KEY=your-google-gemini-key-here
```

---

## Shared Kernel Modules

| Module | Purpose | Location |
|--------|---------|----------|
| `events/` | Domain event base + 20 event contracts | `backend/shared/events/` |
| `utils/cqrs.py` | CommandBus + QueryBus | `backend/shared/utils/cqrs.py` |
| `utils/kafka_producer.py` | Idempotent Kafka publisher | `backend/shared/utils/kafka_producer.py` |
| `utils/kafka_consumer.py` | At-least-once consumer base | `backend/shared/utils/kafka_consumer.py` |
| `utils/outbox.py` | Transactional Outbox Pattern | `backend/shared/utils/outbox.py` |
| `utils/cloud_llm_client.py` | OpenAI + Google AI client abstraction | `backend/shared/utils/cloud_llm_client.py` |
| `middleware/` | JWT, RBAC, bcrypt | `backend/shared/middleware/` |
| `utils/app_factory.py` | Shared FastAPI factory | `backend/shared/utils/app_factory.py` |
| `utils/health.py` | Composable health checks | `backend/shared/utils/health.py` |
| `utils/logging.py` | Structured JSON logging | `backend/shared/utils/logging.py` |

### Dependencies

```
FastAPI                    # Web framework
PostgreSQL + asyncpg       # Database
Redis (aioredis)           # Cache/sessions
Kafka-Python / AIOKafka    # Event streaming
Neo4j (neo4j Python driver) # Knowledge graph
OpenSearch (opensearch-py) # Search
OpenAI SDK                 # AI inference
Google Generative AI SDK   # AI inference
Bcrypt / PyJWT             # Auth
Pydantic v2                # Validation
SQLAlchemy 2.0             # ORM
Alembic                    # Migrations
Gunicorn + Uvicorn         # ASGI server
```

---

## Building the Android APK (clean clone)

`apps/mobile/android/` is git-ignored, so a fresh clone has no Android project. CI (and you, locally) regenerate it and re-apply the MASAREEN config (package `com.masaren.app`, permissions, cleartext HTTP, desugaring, launcher icon):

```bash
cd apps/mobile
flutter create --platforms=android --org com.masaren --project-name masaren .   # Flutter 3.24.x
pip install pillow && python3 tool/patch_android.py
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://your.backend   # define is optional
```

GitHub Actions does this automatically (`.github/workflows/android-apk.yml`) and publishes `masareen.apk` to the `latest-apk` release, which the landing page (`landing/`) links to. The APK is signed with the debug key (installable, not Play-Store-ready).

## Cloudflare backend (`cloudflare/`)

Free-tier Worker + D1 database: Google sign-up, registrations, login tracking, contact messages and the CEO dashboard (`/admin.html`). Setup: `cloudflare/README.md`.

## Landing page (`landing/`)

Static bilingual (EN/AR) site for Cloudflare R2 / `masareen.com`; see `landing/README.md`.

---

## Mobile App (Flutter)

**Package:** `com.masaren.app`
**Version:** 0.2.0+2
**Platform:** Android (arm64-v8a only)
**Size:** 22.8 MB

### Features

- **Splash Screen:** MASAREN logo + loading spinner with startup chime audio
- **Authentication:** Email/password login + Google OAuth
- **Home Feed:** Scrollable feed of impact actions and posts
- **Create Post:** Create posts with text, images, and video
- **Video Upload:** Record or pick video → upload → HLS transcoding → playback
- **Personal Impact Portfolio (PMS):** View verified impact assets
- **Wallet:** View and manage MASAREN coin balance
- **Notifications:** Push notifications for verification status
- **Bottom Navigation:** Feed, Create, Portfolio, Profile, Settings
- **Drawer Menu:** Navigation to all sections

### Key Dependencies

```yaml
dependencies:
  flutter: ^3.22.0
  cupertino_icons: ^1.0.8
  http: ^1.2.5
  provider: ^6.1.4
  video_player: ^2.9.1
  file_picker: ^9.0.0
  image_picker: ^1.1.2
  audioplayers: ^6.1.0        # Startup sound
  google_sign_in: ^6.3.1
  flutter_secure_storage: ^9.2.4
  path_provider: ^2.1.3
  connectivity_plus: ^5.0.2
  device_info_plus: ^11.2.0
  intl: ^0.19.0
```

### Build & Deploy

```bash
cd apps/mobile

# Install dependencies
flutter pub get

# Run on device (debug)
flutter run

# Build release APK (arm64-v8a)
flutter build apk --release --target-platform android-arm64

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

**APK Location:** `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

### Device Testing

```bash
# Connect via SSH tunnel (wireless debugging)
# SSH tunnel command (port changes on each restart):
ssh -N -R 15561:192.168.100.3:<PORT> sms@100.123.2.61

# ADB connect
adb connect 127.0.0.1:15561

# Install APK
adb -s 127.0.0.1:15561 install -r build/app/outputs/flutter-apk/app-release.apk

# Run E2E tests
maestro --udid 127.0.0.1:15561 test testing/e2e/01_login.yaml
```

### Mobile API Configuration

The mobile app connects to the backend via:
- **Base URL:** `https://masareen.mediahubnetwork.net` (via Nginx Proxy Manager reverse proxy)
- **API Client:** Configured in `apps/mobile/lib/api_client.dart`

The API client base URL:
```dart
ApiClient({String baseUrl = 'https://masareen.mediahubnetwork.net'})
```

Google OAuth URL in `login_screen.dart`:
```dart
Uri.parse('https://masareen.mediahubnetwork.net/login?google=1')
```

Video HLS URLs in `create_post_screen.dart`:
```dart
hlsUrl.startsWith('http') ? hlsUrl : 'https://masareen.mediahubnetwork.net$hlsUrl'
```

### Mobile-Specific Features

- **Splash Screen:** Uses `launch_background.xml` with solid `#111111` background and MASAREN logo
- **Startup Sound:** 2.5s ascending chime played via `audioplayers` package in splash screen
- **Video Picker:** Video chip in Create Post screen, uses `file_picker` package
- **Video Playback:** ExoPlayer (native Android) handles HLS `.m3u8` via `VideoPlayerController.networkUrl`
- **App Icon:** Black/dark navy logo on white background across all mipmap densities

---

## Web Dashboard (React + TypeScript)

**Port:** 9000 (production) / 3000 (development)

### Features

- **Login/Register:** Email + Google OAuth
- **Feed:** Home feed with posts from organizations and programs
- **Create Post:** Post creation with media upload (image + video)
- **Video Playback:** HLS adaptive streaming via `hls.js`
- **Personal Impact Portfolio:** View verified impact assets
- **Wallet:** Coin balance, transaction history
- **Admin Panel:** User management, organization management, analytics

### Key Dependencies

```json
{
  "react": "^18",
  "react-router-dom": "^6",
  "typescript": "^5",
  "vite": "^5",
  "hls.js": "^1.5.13",
  "axios": "^1.7.9",
  "@tanstack/react-query": "^5",
  "lucide-react": "^0.441.0",
  "tailwindcss": "^3.4.0"
}
```

### Development

```bash
cd apps/web

# Install dependencies
npm install

# Development server (port 3000)
npm run dev

# Production build
npm run build

# Serve production build (port 9000)
npx vite preview --port 9000 --host 0.0.0.0
```

### Vite Configuration

```typescript
// vite.config.ts
server: {
  port: 3000,
  host: true,
  strictPort: true,
  proxy: { "/api": "http://localhost:8080" },
  allowedHosts: ["masareen.mediahubnetwork.net", "localhost"]
}
```

### Web-Specific Features

- **HlsVideo Component:** Custom React component using `hls.js` for adaptive bitrate HLS playback
- **Composer File Upload:** Direct upload to backend (`/api/v1/videos/upload` for videos, `/api/v1/users/me/avatar` for images)
- **PostCard:** Renders posts with embedded video players for video content

---

## Combined Backend

The combined backend is a unified FastAPI application that merges all 35+ microservices into a single process. Located at `backend/combined/`.

### Entry Point: `main.py`

```python
# Application startup
from fastapi import FastAPI
app = FastAPI(title="MASAREEN Combined Platform")

# Router registration
app.include_router(video_endpoints.router, prefix="/api/v1/videos")
app.include_router(extra_routers.router, prefix="/api/v1")
# ... 35+ service routers
```

### Video Endpoints (`video_endpoints.py`)

Three endpoints for the video upload → transcode → HLS pipeline:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/videos/upload` | Upload video file, start transcode job |
| `GET` | `/api/v1/videos/status/{job_id}` | Poll transcoding status |
| `GET` | `/api/v1/videos/hls/{job_id}/{path}` | Serve HLS segments (.m3u8, .ts) |

### Video Processing Pipeline

```
User uploads video (mobile app)
  → POST /api/v1/videos/upload
  → Save temp file to /tmp/
  → Try transcode farm: http://100.123.2.61:9100
  → Fallback: Local FFmpeg ABR transcoding
  → HLS output: /home/sms/masarenfinal/backend/combined/static/hls/
  → Return: {job_id, hls_url} (202 Accepted)
```

**Key backend endpoints:**

| Service | Endpoints |
|---------|-----------|
| Identity | `/api/v1/auth/*` |
| Organization | `/api/v1/organizations/*` |
| Programs | `/api/v1/programs/*` |
| Tasks | `/api/v1/tasks/*` |
| Posts | `/api/v1/posts/*` |
| Users | `/api/v1/users/*` |
| Media | `/api/v1/media/*` |
| Evidence | `/api/v1/evidence/*` |
| Verification | `/api/v1/verification/*` |
| Impact | `/api/v1/impact/*` |
| Portfolio | `/api/v1/portfolio/*` |
| Admin | `/api/v1/admin/*` |
| Analytics | `/api/v1/analytics/*` |
| Chat | `/api/v1/chat/*` |
| Payments | `/api/v1/payments/*` |

### Health Check

```bash
curl http://localhost:8088/health
```

Response:
```json
{
  "status": "healthy",
  "service": "masaren-combined",
  "services_included": [
    "ms_identity", "ms_auth", "ms_authz", "ms_organization",
    "ms_program", "ms_task", "ms_workflow", "ms_verification",
    "ms_evidence", "ms_gps", "ms_audit", "ms_media",
    "ms_submission", "ms_graph", "ms_reputation",
    "ms_impact_score", "ms_org_score", "ms_marketplace",
    "ms_matching", "ms_posts", "ms_report", "ms_analytics",
    "ms_forecast", "ms_chat", "ms_billing", "ms_subscription",
    "ms_payment", "ms_partner", "ms_coin", "ms_ads",
    "ms_platform", "ms_notification", "ms_orchestrator",
    "ms_fraud_python", "ms_auth_python", "ms_impact_score_python"
  ]
}
```

### Running the Combined Backend

```bash
# Production (port 8088, avoids filebrowser on 8080)
cd /home/sms/masarenfinal/backend
export DATABASE_URL="postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
export JWT_SECRET="masaren-alpha-change-me"
export REDIS_URL="redis://localhost:6379"
screen -dmS backend bash -c 'cd combined && .venv_linux/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8088 --log-level info'

# Development (with auto-reload)
cd combined
source ../.venv_linux/bin/activate
python -m uvicorn main:app --host 0.0.0.0 --port 8088 --reload
```

**Start Script:** `backend/run_combined_linux.sh`

---

## Video Processing & HLS Transcoding

### Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────┐     ┌────────────┐
│  Mobile App │────►│ Upload Endpoint  │────►│ Transcode    │────►│ HLS Output │
│  (ExoPlayer │     │ /videos/upload   │     │  Farm OR      │     │ .m3u8/.ts  │
│   reads     │     │ (async, 202)     │     │  Local FFmpeg │     │ /hls/      │
│   .m3u8)    │     │                  │     │  ABR fallback │     │            │
└─────────────┘     └────────┬─────────┘     └──────┬───────┘     └─────┬──────┘
                             │                       │                    │
                             │          ┌────────────▼────────────┐      │
                             │          │ Transcode Farm          │      │
                             │          │ http://100.123.2.61:9100  │      │
                             │          │ (Windows workers)       │      │
                             │          └────────────┬────────────┘      │
                             │                       │                    │
                             │          ┌────────────▼────────────┐      │
                             │          │ Local FFmpeg Fallback   │      │
                             │          │ 5 ABR profiles:         │      │
                             │          │ 1080p → 240p            │      │
                             │          │ libx264, aac, 6s segs   │      │
                             │          └────────────┬────────────┘      │
                             │                       │                    │
                             │    ┌──────────────────▼────────────┐     │
                             └───►│ Serve: /videos/hls/{job_id}/   │◄────┘
                                  │ Output: static/hls/{job_id}/  │
                                  └───────────────────────────────┘
```

### Transcode Farm

The transcode farm (`/home/sms/transcode-farm/`) provides distributed transcoding via:

- **API:** Port 9100 on server (100.123.2.61)
- **Workers:** Windows binaries (currently offline)
- **Fallback:** Local FFmpeg on Linux server

When a video upload is received:

1. Temp file saved to `/tmp/`
2. API call to transcode farm (`POST /transcode`)
3. If farm workers unavailable → local FFmpeg fallback
4. HLS segments written to `backend/combined/static/hls/{job_id}/`
5. Client polls `/videos/status/{job_id}` for completion
6. Client plays HLS via `hls_url` (ExoPlayer on Android, hls.js on web)

### ABR Profiles Generated

| Resolution | Codec | Bitrate | Profile |
|-----------|-------|---------|---------|
| 1080p | H.264 | 4500 kbps | high |
| 720p | H.264 | 2500 kbps | main |
| 480p | H.264 | 1000 kbps | main |
| 360p | H.264 | 500 kbps | baseline |
| 240p | H.264 | 200 kbps | baseline |

All profiles: 48kHz AAC audio, 6-second segments, `#EXT-X-VERSION:3`

### HLS File Structure

```
static/hls/
└── {job_id}/
    ├── master.m3u8          # Master playlist (variant list)
    ├── stream_0.m3u8        # 1080p playlist
    ├── stream_0_0.ts        # Segments
    ├── stream_0_1.ts
    ├── stream_1.m3u8        # 720p playlist
    ├── stream_1_0.ts
    ├── ...
    ├── stream_4.m3u8        # 240p playlist
    └── stream_4_0.ts
```

---

## IP Legal Portfolio

The `ip-legal/` directory is the **single authoritative source** for all MASAREN intellectual property documentation.

### Patent Portfolio

```
ip-legal/patents/
├── disclosures/             # 5 Invention Disclosure Forms (IDFs)
│   ├── IDF-001: Verification-to-Asset Pipeline
│   ├── IDF-002: Impact Score Algorithm (ISA)
│   ├── IDF-003: Geo-Fenced Field Verification
│   ├── IDF-004: AI Multi-Modal Evidence Verification
│   └── IDF-005: Knowledge Graph Synthesis Engine
├── claims/                  # 2 claim sets (pre-attorney)
│   ├── CLM-001: Verification Pipeline claims (8 claims)
│   └── CLM-002: Impact Score Algorithm claims (8 claims)
├── prior-art/               # 2 prior art search reports
│   ├── PAR-001: Verification technology landscape
│   └── PAR-002: Impact measurement prior art
├── provisional/             # 2 provisional applications (drafted)
│   ├── PROV-001: Verification-to-Asset Pipeline
│   └── PROV-002: Impact Score Algorithm
└── pct/                     # 1 PCT application (drafting)
    └── PCT-001: Combined Verification + Scoring pipeline
```

### Copyright Portfolio

```
ip-legal/copyright/
├── registrations/
│   ├── COPYRIGHT-APPLICATION-001.md (platform software)
│   └── WORKS-REGISTER.md (master catalog)
├── source-headers/
│   ├── STANDARD-HEADER-PYTHON.txt
│   ├── STANDARD-HEADER-DART.txt
│   ├── STANDARD-HEADER-TYPESCRIPT.txt
│   ├── STANDARD-HEADER-SQL.txt
│   └── STANDARD-HEADER-YAML.txt
└── notices/
    └── COPYRIGHT-POLICY.md
```

### Trademark Portfolio

```
ip-legal/trademarks/
├── registrations/
│   ├── TM-001: MASAREN (word mark)
│   ├── TM-002: مسارين (Arabic word mark)
│   └── TM-003: IIaaS logo/device mark
├── usage-evidence/
└── brand-standards/
```

### Trade Secrets

```
ip-legal/trade-secrets/
├── policies/
│   ├── TS-POLICY-001: Trade Secret Identification
│   └── TS-POLICY-002: Employee Handling & Protection
├── nda-templates/
│   ├── NDA-EMPLOYEE.md
│   ├── NDA-CONTRACTOR.md
│   ├── NDA-PARTNER.md
│   └── NDA-MUTUAL.md
└── inventories/
    ├── TS-INV-001: Algorithms & Models
    ├── TS-INV-002: Data Schemas & Structures
    └── TS-INV-003: AI Configs & Prompts
```

### Governance

```
ip-legal/governance/
├── policies/
│   ├── GOV-POL-001: IP Ownership & Assignment
│   ├── GOV-POL-002: Open Source Usage
│   ├── GOV-POL-003: Third-Party Software
│   └── GOV-POL-004: Invention Disclosure Review
├── procedures/
│   ├── PROC-001: New Invention Disclosure
│   ├── PROC-002: Patent Filing Workflow
│   ├── PROC-003: Copyright Registration
│   ├── PROC-004: Trademark Monitoring
│   └── PROC-005: IP Incident Response
└── training/
    ├── TRAIN-001: IP Basics for Employees
    ├── TRAIN-002: Trade Secret Handling
    └── TRAIN-003: Open Source Compliance
```

**Legal Contacts:**
- General Counsel: legal@masaren.com
- Patent Attorney: [To be assigned]
- Trademark Counsel: [To be assigned]

---

## E2E Testing

### Test Suite

The Maestro E2E test suite contains 19 test files covering all major user journeys:

| File | Description | Duration |
|------|-------------|----------|
| `00_setup.yaml` | App setup and permissions | ~5s |
| `01_login.yaml` | Login with valid credentials | ~10s |
| `02_register.yaml` | Register new account | ~10s |
| `03_bottom_nav.yaml` | Bottom navigation interaction | ~8s |
| `04_drawer_logout.yaml` | Drawer menu and logout | ~8s |
| `05_feed_tabs.yaml` | Feed tab navigation | ~5s |
| `06_create_post.yaml` | Create post with text + image | ~8s |
| `07_feed_scroll.yaml` | Scroll feed interaction | ~5s |
| `08_login_invalid.yaml` | Login with invalid credentials | ~8s |
| `09_simulation_individual.yaml` | Individual user simulation | ~30s |
| `10_simulation_content_creator.yaml` | Content creator workflow | ~30s |
| `11_simulation_program_journey.yaml` | Program journey simulation | ~30s |
| `12_simulation_wallet_economy.yaml` | Wallet and coin economy | ~25s |
| `13_simulation_opportunities_apply.yaml` | Apply to opportunities | ~25s |
| `14_simulation_notifications_flow.yaml` | Notification flow | ~20s |
| `15_simulation_admin_panel.yaml` | Admin panel access | ~20s |
| `16_simulation_theme_language.yaml` | Theme & Language settings | ~15s |
| `17_simulation_full_user_journey.yaml` | Full user journey end-to-end | ~60s |
| `18_simulation_post_interactions.yaml` | Post interactions (like, comment) | ~25s |
| `_login_admin.yaml` | Admin login helper | ~5s |

### Running Tests

```bash
# Install Maestro
curl -Ls "https://get.maestro.dev" | bash

# Ensure device is connected via ADB
adb devices

# Run a single test
maestro --udid 127.0.0.1:15561 test testing/e2e/01_login.yaml

# Run all tests
./testing/e2e/run_all_tests.sh

# Run on physical device via SSH tunnel
ssh -N -R 15561:192.168.100.3:<PORT> sms@100.123.2.61
adb connect 127.0.0.1:15561
maestro --udid 127.0.0.1:15561 test testing/e2e/
```

### Test Coordinates

Tests use screen coordinates for the Oppo Reno 6 4G (1080×2400 screen):

- Email field: `(540, 1157)`
- Password field: `(540, 1325)`
- Navigation bar: varies by screen

### Test Scripts

- `run_all_tests.sh`, Runs all 19 tests sequentially
- `scripts/`, Helper scripts for setup, teardown, and reporting
- `screenshots/`, Captured screenshots from test runs

---

## Deployment

### Docker Compose (Local Development)

```bash
docker compose up -d
```

Services include: PostgreSQL, Redis, Kafka, Neo4j, OpenSearch, Nginx Proxy Manager, Filebrowser, and all 35+ microservices.

### Kubernetes (Production)

```bash
cd infrastructure/kubernetes
kubectl apply -f base/
kubectl apply -f overlays/production/
```

### Nginx Proxy Manager Configuration

- **Proxy Host:** `masareen.mediahubnetwork.net`
- **Upstream:** `http://100.123.2.61:8088` (backend)
- **Admin Panel:** `http://10.78.51.217:81`
- **SSL:** Let's Encrypt certificates managed via NPM UI

### Backend Startup

```bash
# Screen session (persistent)
export DATABASE_URL="postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
export JWT_SECRET="masaren-alpha-change-me"
export REDIS_URL="redis://localhost:6379"
screen -dmS backend bash -c 'cd combined && .venv_linux/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8088 --log-level info'

# Web frontend
screen -dmS frontend bash -c 'cd apps/web && npx vite preview --port 9000 --host 0.0.0.0'
```

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren

# Authentication
JWT_SECRET=masaren-alpha-change-me
JWT_ALGORITHM=HS256

# Cache & Messaging
REDIS_URL=redis://localhost:6379
KAFKA_BOOTSTRAP_SERVERS=10.78.51.217:9092

# AI
OPENAI_API_KEY=your-key-here
GOOGLE_API_KEY=your-key-here
AI_PROVIDER=openai|google

# CORS
CORS_ORIGINS=*

# Other
AUTO_VERIFY_ON_REGISTER=true
```

---

## Development Stages

- [x] **Stage 0**, Project specification
- [x] **Stage 1**, Monorepo structure (423 dirs, 24+ services)
- [x] **Stage 2**, Shared kernel (22 modules)
- [x] **Stage 3**, Identity domain (54 files, 30 tests)
- [x] **Stage 4**, Execution domain (organization, program, task, workflow)
- [x] **Stage 5**, Verification domain
- [x] **Stage 6**, AI agents (full implementation)
- [x] **Stage 7**, Reputation (PMS, OII, portfolio)
- [x] **Stage 8**, Marketplace
- [x] **Stage 9**, Reporting & analytics
- [x] **Stage 10**, Knowledge graph
- [x] **Stage 11**, Frontend (Flutter + React)
- [x] **Stage 12**, Production infrastructure

---

## API Reference

### Authentication

```bash
# Login
POST /api/v1/auth/login
Content-Type: application/json
{ "email": "user@example.com", "password": "password" }

# Google OAuth
GET /login?google=1

# Register
POST /api/v1/auth/register
{ "email": "user@example.com", "password": "password", "name": "User" }
```

### Posts

```bash
# Create post
POST /api/v1/posts/
Authorization: Bearer <jwt_token>
{ "content": "My impact action", "media_urls": ["/static/images/example.jpg"] }

# Get feed
GET /api/v1/posts/feed
Authorization: Bearer <jwt_token>
```

### Videos

```bash
# Upload video
POST /api/v1/videos/upload
Content-Type: multipart/form-data
file: <video_file>
Authorization: Bearer <jwt_token>

# Response (202 Accepted)
{
  "job_id": "uuid-here",
  "hls_url": "/api/v1/videos/hls/uuid-here/master.m3u8"
}

# Check status
GET /api/v1/videos/status/{job_id}
Authorization: Bearer <jwt_token>

# Response
{ "status": "processing|completed|failed", "progress": 65 }

# Serve HLS
GET /api/v1/videos/hls/{job_id}/{segment_path}
```

### Organizations

```bash
# Create organization
POST /api/v1/organizations/
Authorization: Bearer <jwt_token>
{ "name": "Green Earth", "description": "Environmental NGO" }
```

---

## Configuration

### Server Information

| Service | Host | Port | Notes |
|---------|------|------|-------|
| Backend (FastAPI) | 10.10.8.230 | 8088 | Primary API |
| Frontend (Vite) | 10.10.8.230 | 9000 | Web dashboard |
| Nginx Proxy Manager | 10.78.51.217 | 81 | NPM admin panel |
| PostgreSQL | localhost | 5432 | Primary database |
| Redis | localhost | 6379 | Cache & sessions |
| Kafka | 10.78.51.217 | 9092 | Event bus |
| Neo4j | localhost | 7474, 7687 | Knowledge graph |
| Filebrowser | 10.78.51.217 | 8080 | File management |
| Tailscale | 100.123.2.61 | - | VPN access |

### Admin Credentials

- **Email:** `admin@masaren.org`
- **Password:** `Masaren@1234`

### SSH Access

```bash
# Server access via Tailscale
ssh sms@100.123.2.61
```

### Mobile Device Testing

```bash
# Physical device: Oppo Reno 6 4G (1080×2400)
# SSH tunnel for wireless debugging:
ssh -N -R 15561:192.168.100.3:<PORT> sms@100.123.2.61

# Install APK on device
adb -s 127.0.0.1:15561 install -r apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## License

**Proprietary, MASAREN Project · All rights reserved.**

See `ip-legal/notices/LICENSE-PROPRIETARY.md` for the full proprietary license agreement.

Unauthorized reproduction, distribution, or modification of any portion of this software, including but not limited to source code, compiled binaries, documentation, and design assets, is strictly prohibited without the prior written consent of MASAREN.

---

## Quick Links

- **Documentation:** `docs/PLATFORM_GENOME.md`, `docs/PLATFORM_KNOWLEDGE.md`, `CURRENT_STATE.md`
- **Video Walkthrough:** `docs/walkthrough_v4.mp4`
- **Handoff Notes:** `AGENT_HANDOFF_2026-07-12.md`, `AGENT_HANDOFF_2026-07-13.md`, `AGENT_HANDOFF_2026-07-13-continuation.md`
- **Audit Reports:** `AUDIT_REPORT.md`, `E2E_AUDIT.md`
- **IP Legal:** `ip-legal/README.md`, `ip-legal/INDEX.md`
- **API Docs:** `http://localhost:8088/docs`

---

*Document Owner: MASAREN Legal Team*
*Last Updated: August 11, 2026*
*Classification: CONFIDENTIAL, PROPRIETARY*