# MASAREN Platform - Complete Technical Knowledge Base

**Last Updated:** July 21, 2026  
**Version:** 2.0.0  
**Status:** Production-Ready

---

## Table of Contents

1. [Platform Overview](#1-platform-overview)
2. [Architecture Principles](#2-architecture-principles)
3. [Repository Structure](#3-repository-structure)
4. [Technology Stack](#4-technology-stack)
5. [Service Domain Architecture](#5-service-domain-architecture)
6. [Combined Backend System](#6-combined-backend-system)
7. [Frontend Architecture](#7-frontend-architecture)
8. [Event-Driven Architecture](#8-event-driven-architecture)
9. [Shared Kernel](#9-shared-kernel)
10. [Infrastructure & Deployment](#10-infrastructure--deployment)
11. [Security Architecture](#11-security-architecture)
12. [Testing Strategy](#12-testing-strategy)
13. [Development Workflow](#13-development-workflow)
14. [API Documentation](#14-api-documentation)
15. [Database Schema](#15-database-schema)
16. [Known Issues & Gaps](#16-known-issues--gaps)
17. [Future Roadmap](#17-future-roadmap)

---

## 1. Platform Overview

### 1.1 What is MASAREN?

**MASAREN (مسارين)** is the world's first **Impact Infrastructure as a Service (IIaaS)** platform. It converts verified real-world field actions into immutable, measurable, and economically valuable digital assets.

**Core Principle:** *If an action cannot be verified, it cannot become an economic asset.*

### 1.2 Key Differentiators

- **Verification-Centric:** Every asset creation requires multi-layered verification
- **Cross-Platform:** Web and mobile share identical feature sets
- **Event-Driven:** Kafka as single source of truth
- **Cloud-First AI:** Zero local LLM execution
- **Enterprise-Grade:** RBAC, GDPR compliance, audit trails

### 1.3 Platform Vision

MASAREN operates at the intersection of:
- **Intention and Execution** (planned objectives vs. field actions)
- **Field Work and Digital Assets** (physical actions → digital value)
- **Trust and Measurable Reputation** (verifiable trust through data)

---

## 2. Architecture Principles

### 2.1 Core Patterns

The platform implements these architectural patterns:

| Pattern | Purpose | Implementation |
|---------|---------|----------------|
| **Domain-Driven Design** | Complex business logic in bounded contexts | Aggregate patterns, ubiquitous language |
| **Clean/Hexagonal Architecture** | Separation of concerns | Core logic center, infrastructure adapters |
| **CQRS** | Command/Query separation | CommandBus + QueryBus |
| **Event Sourcing** | Immutable event logs | Transactional Outbox Pattern |
| **Microservices** | Independent deployability | 35+ services, Kafka communication |
| **Repository Pattern** | Abstract data access | Domain-specific repositories |
| **Specification Pattern** | Complex query building | Reusable query specifications |

### 2.2 Layered Architecture

```
Presentation Layer    →  React/Flutter frontends
Experience Layer      →  API Gateway (BFF) at :8080
Business Layer        →  35+ domain services
AI Layer             →  Cloud-based AI agents
Knowledge Layer      →  Neo4j knowledge graph
Data Layer           →  PostgreSQL + Redis + MinIO
Infrastructure Layer →  Docker/K8s + Kafka + Monitoring
```

---

## 3. Repository Structure

### 3.1 Top-Level Layout

```
MASAREN/
├── README.md                          # Human entry point
├── PLATFORM_GENOME.md                 # Agent blueprint (machine-readable)
├── PLATFORM_KNOWLEDGE.md              # THIS FILE - complete knowledge base
├── platform-genome.json               # JSON version of genome
├── .env.example                       # Environment template
├── docker-compose.yml                 # Full-stack deployment (30+ services)
├── docker-compose.override.yml        # Local overrides
│
├── apps/
│   ├── web/                          # React + TypeScript (port 3000)
│   ├── admin/                        # React + TypeScript admin (port 3001)
│   └── mobile/                       # Flutter (Android/iOS)
│
├── backend/
│   ├── shared/                       # Shared kernel (imported as shared.*)
│   ├── combined/main.py              # Combined backend (all services in one process)
│   ├── gateway/                      # API Gateway (BFF)
│   ├── identity/                     # Identity domain (3 services)
│   ├── execution/                    # Execution domain (4 services)
│   ├── verification/                 # Verification domain (6 services)
│   ├── ai/                          # AI agents + orchestrator
│   ├── graph/                       # Knowledge graph service
│   ├── reputation/                  # Reputation domain (3 services)
│   ├── marketplace/                 # Marketplace domain (2 services)
│   ├── reporting/                   # Reporting domain (3 services)
│   ├── notifications/               # Notification service
│   ├── billing/                     # Billing domain (3 services)
│   ├── chat-service/                # Chat + posts/feed
│   ├── partners/                    # Partner service
│   ├── coin/                        # MASAREN Coin (MRC)
│   ├── ads/                         # Ads service
│   └── platform/                    # Platform aggregation
│
├── infrastructure/
│   ├── databases/postgres/migrations/  # V001-V015 SQL migrations
│   ├── kafka/topics/                 # Event catalog (20+ topics)
│   ├── kubernetes/                   # K8s manifests
│   └── ci-cd/                        # GitHub Actions workflows
│
├── docs/                             # All documentation
│   ├── api/                         # API reference
│   ├── architecture/                # ADRs, event catalog
│   └── deployment/                  # Runbooks, checklists
│
├── testing/                          # E2E test harnesses
├── analytics/                        # R report scripts
└── logo/                            # Brand assets
```

---

## 4. Technology Stack

### 4.1 Backend Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.11+ | Runtime with type hints |
| **FastAPI** | Latest | Web framework, OpenAPI docs |
| **PostgreSQL + PostGIS** | 16 + 3.4 | Primary DB with spatial queries |
| **Neo4j + APOC** | 5 + GDS | Knowledge graph |
| **Redis** | 7 | Cache, sessions, rate limiting |
| **Apache Kafka** | 3.7.0 | Event bus (KRaft mode, no Zookeeper) |
| **NATS** | Latest | Real-time fan-out messaging |
| **MinIO / S3** | - | Blob storage for evidence |
| **OpenAI / Gemini** | - | Cloud AI inference |

### 4.2 Frontend Technologies

#### Web Application (apps/web)

| Technology | Version | Purpose |
|------------|---------|---------|
| **React** | 18.2 | UI framework |
| **TypeScript** | 5.3 | Static typing |
| **Vite** | 5.1 | Build tool with HMR |
| **React Router** | v6 | Client-side routing |
| **TanStack Query** | Latest | Server state management |
| **Tailwind CSS** | 3.4 | Utility-first CSS |
| **Axios** | Latest | HTTP client with interceptors |
| **i18n** | Latest | English/Arabic support |

#### Admin Panel (apps/admin)

- Same as web but uses **Mantine UI** component library
- Built and served via nginx

#### Mobile Application (apps/mobile)

| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | 3.22+ | Cross-platform framework |
| **Dart** | 3 | Programming language |
| **Provider** | Latest | State management |
| **http** | Latest | Pure Dart HTTP client |

### 4.3 DevOps & Infrastructure

| Tool | Purpose |
|------|---------|
| **Docker** | Containerization |
| **Docker Compose** | Local development (30+ services) |
| **Kubernetes** | Production deployment |
| **Prometheus + Grafana** | Monitoring and observability |
| **OpenTelemetry** | Distributed tracing |
| **GitHub Actions** | CI/CD pipelines |
| **Terraform** | Infrastructure as Code |

---

## 5. Service Domain Architecture

### 5.1 Service Topology (35+ Services)

#### Identity Domain (Authentication & Authorization)

| Service | Port | Responsibility | Key Tables |
|---------|------|----------------|------------|
| **identity-service** | 8001 | User profiles, email verification | users, user_profiles |
| **authentication-service** | 8002 | JWT issuance, OAuth2, sessions | oauth_sessions, tokens |
| **authorization-service** | 8003 | RBAC, permissions | roles, permissions, role_permissions |

#### Execution Domain (Core Operations)

| Service | Port | Responsibility | Key Tables |
|---------|------|----------------|------------|
| **organization-service** | 8004 | Organizations, hierarchy, memberships | organizations, affiliations |
| **program-service** | 8005 | Programs, lifecycle, SDG mapping | programs, program_enrollments |
| **task-service** | 8006 | Tasks, assignments, state machine | tasks, task_assignments |
| **workflow-service** | 8007 | Workflow orchestration | workflows, workflow_tasks |

#### Verification Domain (Core Differentiator)

| Service | Port | Responsibility | Integration |
|---------|------|----------------|-------------|
| **verification-service** | 8008 | Core verification logic, scoring | evidence, gps, audit |
| **evidence-service** | 8009 | Evidence capture, storage, versioning | media service |
| **gps-service** | - | Geolocation proof, timestamp | verification, audit |
| **audit-service** | - | Audit trails, compliance | verification, submission |
| **media-service** | - | Media processing, OCR | evidence service |
| **submission-service** | - | Submission intake, validation | verification, AI orchestrator |

#### AI Domain (Cloud-Only Inference)

| Service | Port | Responsibility | Cloud Model |
|---------|------|----------------|-------------|
| **vision-ai-service** | - | Evidence visual verification, OCR | GPT-4o Vision / Gemini Pro |
| **fraud-service** | 8090 | Fraud detection patterns | GPT-4o / Gemini Flash |
| **economist-agent** | - | Impact value calculation | GPT-4o / Gemini Pro |
| **graph-synthesis** | - | Neo4j knowledge graph updates | GPT-4o / Gemini Pro |
| **orchestrator** | 8070 | POAI crew coordination | All AI agents |

#### Reputation Domain

| Service | Port | Responsibility | Data Source |
|---------|------|----------------|-------------|
| **portfolio-service** | - | Impact portfolios, asset tracking | Neo4j |
| **impact-score-service** | 8094 | Individual PMS scoring | PostgreSQL |
| **org-score-service** | - | Organization reputation | Neo4j |

#### Marketplace Domain

| Service | Port | Responsibility |
|---------|------|----------------|
| **opportunity-service** | 8013 | Opportunity lifecycle |
| **matching-service** | 8014 | Talent/posting matching |

#### Economic Domain

| Service | Port | Responsibility |
|---------|------|----------------|
| **billing-service** | 8050 | Invoicing |
| **payment-service** | 8090 | Stripe / Paymob (Vodafone Cash) |
| **subscription-service** | - | Subscriptions |
| **coin-service** | - | MASAREN Coin (MRC) |

#### Additional Services

- **notification-service** (8060): FCM / in-app alerts
- **chat-service**: Chat + posts/feed (NATS fan-out)
- **report-service**: Report generation
- **analytics-service**: Live SQL analytics
- **forecast-service**: Forecasting
- **partner-service**: Partner organizations
- **ads-service**: Ads / brokerage
- **platform-service**: Platform revenue/aggregation

### 5.2 Service Communication

#### Synchronous (REST)

- All service-to-service and client-to-service communication
- FastAPI with OpenAPI 3.1 auto-documentation
- API Gateway at port 8080 (BFF pattern)

#### Asynchronous (Kafka + NATS)

- **Kafka:** Domain events (20+ topics), source of truth
- **NATS:** Real-time fan-out for social features
- **Transactional Outbox Pattern:** Atomic DB + event publishing

### 5.3 Event Catalog

| Event | Domain | Description |
|-------|--------|-------------|
| `organization_created` | Execution | New organization registered |
| `program_created` | Execution | New program launched |
| `task_created` | Execution | New task defined |
| `task_assigned` | Execution | Task assigned to volunteer |
| `location_reached` | Verification | GPS confirms arrival |
| `evidence_uploaded` | Verification | Media evidence uploaded |
| `evidence_verified` | AI/Vision | AI verification complete |
| `fraud_detected` | AI/Fraud | Suspicious pattern found |
| `impact_asset_created` | AI/Economist | New impact asset minted |
| `impact_score_updated` | Reputation | PMS recalculated |

---

## 6. Combined Backend System

### 6.1 Purpose

The **Combined Backend** (`backend/combined/main.py`) merges all 35+ microservices into a single FastAPI process for local development efficiency.

**Benefits:**
- Run on laptop/small droplet without 30+ Docker containers
- Single process eliminates network overhead
- Simplified debugging and testing

### 6.2 Implementation Details

#### Service Registration

Each service is registered as a uniquely-named package:

```python
SERVICES = [
    ("ms_identity", "identity/identity-service"),
    ("ms_auth", "identity/authentication-service"),
    # ... 30+ more services
]
```

#### Package Registration Function

```python
def _register_service_package(alias: str, rel: str) -> None:
    """Register backend/<rel> as top-level package named alias."""
    svc_root = os.path.join(BACKEND, rel)
    pkg = types.ModuleType(alias)
    pkg.__path__ = [svc_root]
    pkg.__package__ = alias
    sys.modules[alias] = pkg
```

#### Duplicate Table Resolution

SQLAlchemy Table.__new__ patching to handle duplicate table definitions:

```python
_orig_table_new = _Table.__new__

def _patched_table_new(cls, *args, **kwargs):
    metadata = kwargs.get("metadata") or (args[1] if len(args) >= 2 else None)
    name = kwargs.get("name") or (args[0] if args else None)
    
    if metadata is not None and name is not None:
        key = (schema, name) if schema else name
        if key in metadata.tables:
            return metadata.tables[key]  # Return first definition
    
    return _orig_table_new(cls, *args, **kwargs)

_Table.__new__ = staticmethod(_patched_table_new)
```

#### Route Merging

```python
for alias, rel in SERVICES:
    _register_service_package(alias, rel)
    mod = importlib.import_module(f"{alias}.src.main")
    svc = getattr(mod, "app", None)
    
    # Skip gateway and already included routes
    for r in list(svc.routes):
        if getattr(r, "path", None) in SKIP:
            svc.routes.remove(r)
    
    app.include_router(svc.router)
    
    # Copy exception handlers
    for exc_type, handler in svc.exception_handlers.items():
        if exc_type not in app.exception_handlers:
            app.add_exception_handler(exc_type, handler)
```

### 6.3 Static File Serving

The combined backend serves static files at `/static`:

```python
_static_dir = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(_static_dir, exist_ok=True)
for _sub in ("avatars", "uploads"):
    os.makedirs(os.path.join(_static_dir, _sub), exist_ok=True)
app.mount("/static", StaticFiles(directory=_static_dir), name="static")
```

---

## 7. Frontend Architecture

### 7.1 Web Application (apps/web)

#### Component Structure

```
apps/web/src/
├── components/
│   ├── layout/           # TopNav, Sidebar, Header, RightRail
│   └── common/           # Branding, ErrorBoundary, Icons
├── pages/                # 30+ page components
├── services/             # API client layer
├── store/                # React Context providers
├── hooks/                # Custom React hooks
├── types/                # TypeScript type definitions
└── i18n.tsx              # Internationalization
```

#### Page Structure (30+ Pages)

| Page | Route | Description |
|------|-------|-------------|
| LandingPage | /, /landing | Public landing |
| LoginPage | /login | Authentication |
| RegisterPage | /register | User registration |
| DashboardPage | /dashboard | Personal dashboard |
| ProgramsPage | /programs | Program discovery |
| TasksPage | /tasks | Task management |
| EvidencePage | /evidence | Evidence submission |
| PassportPage | /passport | Digital impact passport |
| OpportunitiesPage | /opportunities | Marketplace |
| PortfolioPage | /portfolio | Impact assets |
| AdminPage | /admin | Admin console (RBAC protected) |
| ChatPage | /chat | Real-time messaging |
| WalletPage | /wallet | MRC wallet |

#### Routing with Role-Based Access

```typescript
function RequireRole({ roles, children }: { roles: string[]; children: ReactElement }) {
  const { user, isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (user && !roles.includes(user.role)) return <Navigate to="/dashboard" replace />;
  return children;
}

// Usage
<Route path="/admin" element={
  <RequireRole roles={["ADMIN", "SUPER_ADMIN"]}>
    <AdminPage />
  </RequireRole>
} />
```

#### State Management

- **React Context:** Client state (auth, theme, UI)
- **TanStack Query:** Server state with caching and mutations

#### Authentication Flow

1. User logs in via email/password or Google OAuth
2. Backend issues JWT access token + refresh token
3. Axios interceptor attaches JWT to all requests
4. On 401, interceptor attempts token refresh
5. On refresh failure, redirect to login

### 7.2 Mobile Application (apps/mobile)

#### Architecture Pattern

**MVVM (Model-View-ViewModel)** with Provider for state management.

#### Directory Structure

```
apps/mobile/lib/
├── features/         # Feature-specific modules
├── providers/        # ChangeNotifier providers
├── services/         # API client and services
├── widgets/          # Reusable UI components
├── models/           # Data models and DTOs
└── screens/          # Full-page screens
```

#### Key Screens

- Login/Register with Google OAuth
- Dashboard with activity summary
- Program discovery and enrollment
- Task list and detail with mobile forms
- Evidence capture with camera + GPS
- Digital passport visualization
- Marketplace with search/filters
- Real-time chat
- Wallet for MRC balance

#### Mobile-Specific Features

- **Camera Integration:** Direct evidence capture
- **GPS Location Binding:** Automatic coordinates
- **Offline Mode:** Queue submissions when offline
- **Push Notifications:** FCM-based alerts
- **Biometric Auth:** Fingerprint/Face ID

---

## 8. Event-Driven Architecture

### 8.1 Kafka Event Bus

Apache Kafka 3.7 with **KRaft mode** (no Zookeeper):

- **20+ event topics** defined in `infrastructure/kafka/topics/event_catalog.yaml`
- **At-least-once delivery** guarantees
- **Idempotent consumers** with event_id deduplication

### 8.2 Transactional Outbox Pattern

Ensures atomicity between DB operations and event publishing:

```python
class OutboxMessage(Base):
    __tablename__ = "outbox_messages"
    
    id = Column(String, primary_key=True, default=uuid4)
    event_type = Column(String, nullable=False)
    aggregate_id = Column(String, nullable=False)
    aggregate_type = Column(String, nullable=False)
    payload = Column(JSON, nullable=False)
    status = Column(Enum("PENDING", "PUBLISHED", "FAILED"), default="PENDING")
    created_at = Column(DateTime, default=datetime.utcnow)
    published_at = Column(DateTime, nullable=True)

def publish_event(event: DomainEvent) -> None:
    session = Session()
    outbox = OutboxMessage(
        event_type=event.event_type,
        aggregate_id=event.aggregate_id,
        aggregate_type=event.aggregate_type,
        payload=event.dict()
    )
    session.add(outbox)
    session.commit()
    # Outbox processor picks up PENDING messages
```

### 8.3 Event Processing Pipeline

1. Domain action triggers `publish_event()` within DB transaction
2. Event saved to `outbox_messages` table
3. Background processor polls for PENDING messages
4. Each message published to appropriate Kafka topic
5. On success, status updated to PUBLISHED
6. Downstream services consume with at-least-once guarantees
7. Idempotent consumers deduplicate via `event_id`

### 8.4 Consumer Implementation

```python
class VerificationEventConsumer(KafkaConsumer):
    async def process(self, event: DomainEvent) -> None:
        # Idempotency check
        if await self._is_duplicate(event.event_id):
            return
        
        if event.data.get("status") == "APPROVED":
            await self._trigger_economist_agent(event)
        
        await self._mark_processed(event.event_id)
```

---

## 9. Shared Kernel

Location: `backend/shared/` (imported as `shared.*`)

### 9.1 Kernel Modules

| Module | Purpose |
|--------|---------|
| `events/` | Domain event base + 20+ event contracts |
| `utils/cqrs.py` | CommandBus + QueryBus |
| `utils/kafka_producer.py` | Idempotent Kafka publisher |
| `utils/kafka_consumer.py` | At-least-once consumer base |
| `utils/outbox.py` | Transactional Outbox Pattern |
| `utils/cloud_llm_client.py` | OpenAI + Google AI abstraction |
| `utils/app_factory.py` | Shared FastAPI factory |
| `utils/health.py` | Composable health checks |
| `utils/logging.py` | Structured JSON logging |
| `middleware/` | JWT, RBAC, bcrypt |
| `base_entity.py` | Abstract base for domain entities |
| `base_repository.py` | Generic CRUD repository |
| `exceptions.py` | Standardized exception hierarchy |

### 9.2 CQRS Implementation

```python
class CommandBus:
    def __init__(self):
        self._handlers = {}
    
    async def dispatch(self, command: Command):
        handler = self._handlers.get(type(command))
        if not handler:
            raise ValueError(f"No handler for {type(command).__name__}")
        return await handler.handle(command)

class QueryBus:
    async def ask(self, query: Query):
        handler = self._handlers.get(type(query))
        if not handler:
            raise ValueError(f"No handler for {type(query).__name__}")
        return await handler.handle(query)
```

---

## 10. Infrastructure & Deployment

### 10.1 Docker Compose Stack

30+ services defined in `docker-compose.yml`:

| Component | Image | Port | Purpose |
|-----------|-------|------|---------|
| Gateway | backend/Dockerfile.service | 8080 | BFF API Gateway |
| Web Frontend | apps/web/Dockerfile | 3000 | React app |
| Admin Frontend | apps/admin/Dockerfile | 3001 | Admin panel |
| PostgreSQL | postgis/postgis:16-3.4 | 5432 | Primary DB |
| Neo4j | neo4j:5-community | 7687 | Knowledge graph |
| Redis | redis:7-alpine | 6379 | Cache |
| Kafka | apache/kafka:3.7.0 | 9092 | Event bus |
| MinIO | minio/minio | 9000 | Blob storage |

### 10.2 Database Migrations

Located at `infrastructure/databases/postgres/migrations/`:

- **V001__initial.sql** through **V015__*.sql**
- Applied in order on first init
- Flyway-style versioning

### 10.3 Kubernetes Deployment

Manifests in `infrastructure/kubernetes/`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: identity-service
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: identity
        image: masaren/identity-service:latest
        ports:
        - containerPort: 8000
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
```

### 10.4 CI/CD Pipeline

GitHub Actions (`.github/workflows/`):

1. **test-shared:** Run shared kernel tests
2. **test-services:** Matrix test all services
3. **build-docker:** Build and push images
4. **deploy:** Deploy to production (main branch only)

---

## 11. Security Architecture

### 11.1 Authentication & Authorization

**Defense-in-depth security model:**

| Feature | Implementation |
|---------|---------------|
| **JWT Authentication** | RS256 signed, 15min access + 7day refresh |
| **RBAC** | 4 roles: VOLUNTEER < ORG_ADMIN < ADMIN < SUPER_ADMIN |
| **Google OAuth** | Popup-based with PKCE flow |
| **Rate Limiting** | Redis-backed per IP/user |
| **CORS** | Strict origin validation |
| **Input Validation** | Pydantic models on all APIs |

### 11.2 Token Management

```python
class TokenManager:
    def create_access_token(self, user_id: str, roles: list[str]) -> str:
        payload = {
            "sub": user_id,
            "roles": roles,
            "type": "access",
            "exp": datetime.utcnow() + timedelta(minutes=15)
        }
        return jwt.encode(payload, self.secret, algorithm="HS256")
```

### 11.3 Data Privacy

- **GDPR Compliance:** Data export, deletion, consent APIs
- **Encryption:** At rest and in transit (TLS 1.3)
- **PII Handling:** Separate storage with restricted access
- **Audit Trails:** All sensitive data access logged

---

## 12. Testing Strategy

### 12.1 Testing Pyramid

| Level | Tool | Coverage Target |
|-------|------|----------------|
| **Unit Tests** | pytest | Domain logic, commands, queries |
| **Integration Tests** | pytest + real DB | Service interactions |
| **Contract Tests** | OpenAPI validation | API schema compliance |
| **Event Tests** | pytest + Kafka | Consumer idempotency |
| **E2E Tests (Web)** | Playwright | Critical user journeys |
| **E2E Tests (Mobile)** | Maestro | Mobile flows |

**Target:** 90%+ code coverage across all services.

### 12.2 Test Configuration

```python
@pytest.fixture
async def db():
    async with DatabaseFixture() as fixture:
        await fixture.create_tables()
        yield fixture
        await fixture.drop_tables()

@pytest.fixture
def auth_token():
    return AuthFixture().generate_token(
        user_id="test-user",
        roles=["VOLUNTEER"]
    )
```

### 12.3 Example Unit Test

```python
class TestTaskService:
    async def test_create_task_success(self, db, auth_token):
        service = TaskService(db.session)
        command = CreateTaskCommand(
            program_id=str(uuid4()),
            title="Plant 50 trees",
            deadline=datetime(2026, 12, 31)
        )
        result = await service.create_task(command, auth_token)
        assert result.status == "CREATED"
        assert result.title == "Plant 50 trees"
```

---

## 13. Development Workflow

### 13.1 Local Development Setup

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env with your secrets

# 2. Start infrastructure
docker compose up -d postgres neo4j redis kafka minio

# 3. Run combined backend (all services in one process)
cd backend/combined
python main.py
# Available at http://localhost:8080

# 4. Run web frontend
cd apps/web
npm install
npm run dev
# Available at http://localhost:3000

# 5. Run mobile app
cd apps/mobile
flutter pub get
flutter run
```

### 13.2 Native Development Ports

| Service | Port |
|---------|------|
| Gateway | 8080 |
| Identity | 8001 |
| Auth | 8002 |
| Organization | 8004 |
| Program | 8005 |
| Task | 8006 |
| Verification | 8008 |
| Evidence | 8009 |
| Orchestrator | 8070 |
| Impact Score | 8094 |

### 13.3 Engineering Rules (Hard Constraints)

**Never:**
- Bypass domain events (always use Transactional Outbox)
- Couple services to another service's DB
- Call another service's DB directly
- Run AI inference locally (cloud only)
- Put business logic in controllers
- Bypass CommandBus/QueryBus
- Publish Kafka without Outbox
- Create circular dependencies

**Always:**
- Use Repository pattern
- Validate DTOs with Pydantic
- Publish domain events for state changes
- Write unit + integration + contract tests
- Maintain independent deployability
- Use structured JSON logging
- Expose health check endpoints
- Implement idempotent consumers

---

## 14. API Documentation

### 14.1 API Gateway Endpoints

Base URL: `http://localhost:8080/api/v1`

#### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Login with email/password |
| POST | `/auth/refresh` | Refresh access token |
| POST | `/auth/password/reset-request` | Request password reset |
| POST | `/users/register` | Register new user |

#### Core Resource Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Get current user |
| GET | `/organizations` | List organizations |
| POST | `/organizations` | Create organization |
| GET | `/programs` | List programs |
| POST | `/programs` | Create program |
| GET | `/tasks` | List tasks |
| POST | `/tasks` | Create task |
| GET | `/opportunities` | List opportunities |
| GET | `/pms/{user_id}` | Get impact score |

### 14.2 BFF Endpoints (Aggregation)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/bff/dashboard` | Aggregated dashboard data |
| GET | `/bff/leaderboard` | Top contributors by PMS |

### 14.3 API Documentation Access

- **Swagger UI:** `http://localhost:8080/docs`
- **ReDoc:** `http://localhost:8080/redoc`
- **OpenAPI Spec:** `http://localhost:8080/openapi.json`

---

## 15. Database Schema

### 15.1 PostgreSQL (Primary)

Key tables across services:

```sql
-- Identity domain
users, user_profiles, oauth_sessions, tokens
roles, permissions, role_permissions

-- Execution domain
organizations, affiliations, programs, program_enrollments
tasks, task_assignments, workflows, workflow_tasks

-- Verification domain
outbox_messages, evidence, submissions, audit_logs

-- Reputation domain
impact_scores, organization_scores, portfolios

-- Marketplace domain
opportunities, applications, matches
```

### 15.2 Neo4j (Knowledge Graph)

Node labels:
- `User`, `Organization`, `Program`, `Task`
- `ImpactAsset`, `Evidence`
- `SDG` (Sustainable Development Goals)

Relationship types:
- `PARTICIPATES_IN`, `CREATED`, `VERIFIED`
- `HAS_IMPACT`, `RELATED_TO`

### 15.3 Redis (Cache)

Keyspaces:
- `session:<user_id>` - User sessions
- `rate_limit:<ip>` - Rate limiting counters
- `processed_events` - Idempotent event tracking

---

## 16. Known Issues & Gaps

### 16.1 Current Gaps

1. **Per-function dead-code analysis** needed across 30+ services
2. **Several AI agents** implemented but not in docker-compose.yml
3. **OpenSearch** search layer planned but not implemented
4. **Go/Rust targets** aspirational only (current implementation is Python)
5. **gRPC** remains aspirational (REST + Kafka is real transport)

### 16.2 Technical Debt

- Some services have inconsistent error handling
- Event schema versioning not yet implemented
- Saga pattern for distributed transactions not complete
- API versioning strategy not formalized

---

## 17. Future Roadmap

### 17.1 Short-Term (Next 3 Months)

1. **OpenSearch Integration** - Full-text search
2. **Complete AI Agent Wiring** - Add all agents to docker-compose
3. **Event Sourcing** - Complete implementation for core aggregates
4. **Saga Orchestration** - Distributed transaction management
5. **Performance Optimization** - Query optimization, caching

### 17.2 Medium-Term (3-6 Months)

1. **Mobile Offline Mode** - Enhanced offline support
2. **Advanced Analytics** - Real-time dashboards
3. **Multi-Tenancy** - Tenant isolation for enterprise
4. **API Versioning** - Formal versioning strategy
5. **GraphQL API** - Alternative to REST

### 17.3 Long-Term (6+ Months)

1. **Federated Deployment** - Multi-region support
2. **Blockchain Integration** - Immutable asset tracking
3. **ML Pipeline** - Custom model training
4. **Mobile Native Modules** - Performance-critical features
5. **White-Label Solution** - Customizable deployments

---

## Appendices

### Appendix A: Environment Variables

Required in `.env`:

```bash
# Core
JWT_SECRET=your-256-bit-secret
DATABASE_URL=postgresql://masaren:password@localhost:5432/masaren
REDIS_URL=redis://localhost:6379/0
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
NEO4J_URL=bolt://neo4j:password@localhost:7687

# AI
OPENAI_API_KEY=sk-your-openai-key
CREWAI_BROKER_URL=

# Payments (Optional)
STRIPE_SECRET_KEY=
PAYMOB_API_KEY=

# Notifications (Optional)
FCM_SERVICE_ACCOUNT_JSON=
```

### Appendix B: Quick Reference Commands

```bash
# Start full stack
docker compose up -d

# View logs
docker compose logs -f <service-name>

# Run tests
cd backend && pytest

# Web dev mode
cd apps/web && npm run dev

# Mobile dev mode
cd apps/mobile && flutter run

# Build mobile APK
cd apps/mobile && flutter build apk

# Combined backend
cd backend/combined && python main.py
```

### Appendix C: Service Port Map

| Service | Port | Docker Compose Key |
|---------|------|-------------------|
| API Gateway | 8080 | gateway |
| Identity | 8001 | identity |
| Auth | 8002 | auth |
| Organization | 8004 | organization |
| Program | 8005 | program |
| Task | 8006 | task |
| Verification | 8008 | verification |
| Evidence | 8009 | evidence |
| Impact Score | 8094 | impact-score-python |
| Web Frontend | 3000 | web |
| Admin Frontend | 3001 | admin |

---

**End of Knowledge Base**

*This document is the single source of truth for the MASAREN platform. Update it whenever architectural changes are made.*
