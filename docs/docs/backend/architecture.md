---
id: architecture
title: Backend Architecture
sidebar_position: 1
---

# Backend Architecture

The MASAREEN backend is a **microservice system collapsed into a single process** for
deployment simplicity, while keeping each service's code and routers isolated.

## Topology

```text
                        ┌─────────────────────────────────────┐
   Web (React)  ───────► │   uvicorn combined.main:app  :8080  │
   Mobile (Flutter) ───► │                                       │
                        │  37 FastAPI routers merged here       │
                        │  /api/v1/auth/* /opportunities/* ...   │
                        └───────────┬──────────────┬────────────┘
                                    │              │
                          ┌─────────▼───┐    ┌─────▼──────┐
                          │ PostgreSQL  │    │  Neo4j     │  (graph)
                          │   16        │    │  Redis     │  (cache/queue)
                          └─────────────┘    └────────────┘
```

## Why "combined"?

Running 37 separate `uvicorn` processes is heavy and fragile on a small host. Each service
already builds a complete FastAPI app with its own routers, so `combined/main.py` imports
every service as a **uniquely-named package** (e.g. `ms_identity`, `ms_evidence`) and merges
their routers under one app. Result: a single process on `:8080` serving every `/api/v1/*`
route the web and mobile apps expect, no API gateway fan-out needed.

> Infra (Postgres / Neo4j / Redis) still runs separately as containers. The "combined"
> part is only the HTTP layer.

## How services are mounted

`combined/main.py` keeps a `SERVICES` list of `(package_alias, service_directory)` pairs and
registers each as a top-level importable package whose `__path__` points at the service
dir. Relative imports inside each service resolve exactly as they would standalone, while
module names never collide. Google OAuth is mounted separately
(`POST /api/v1/auth/google`).

## Identity & trust boundaries

- **Authentication** (`ms_auth`), JWT issuance/refresh, password change/reset, Google.
- **Authorization** (`ms_authz`), role/permission checks (`POST /api/v1/authz/check`).
- **Identity** (`ms_identity`), users, profiles, multiple identities.
- **Organization** (`ms_organization`), orgs, members, OII.

## Infra dependencies

| Dependency | Used for |
|-----------|----------|
| PostgreSQL 16 | Relational core: users, orgs, tasks, evidence, submissions. |
| Neo4j | Graph: person→program→SDG networks, talent matching. |
| Redis | Cache + lightweight queues (notifications, media jobs). |
| Object storage / media slots | Evidence artifacts (photos, docs, audio). |

## Health & observability

- `/health`, `/health/live`, `/health/ready`, liveness/readiness.
- `/evidence/health`, `/evidence/health/ready`, `/api/v1/graph/health/neo4j`, per-dependency.
- `/bench`, quick benchmark. Prometheus instrumentation is wired via the shared layer.

## Running it

```bash
# venv
source backend/.venv_linux/bin/activate

# env (example)
export DATABASE_URL="postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
export JWT_SECRET="masaren-alpha-change-me"
export AUTO_VERIFY_ON_REGISTER=true

# start the combined process
uvicorn combined.main:app --host 0.0.0.0 --port 8080
```

The web app calls this backend through the public domain, which proxies `/api/v1/*` to
`:8080`. The Flutter app uses `https://masareen.mediahubnetwork.net` as its base URL.
