# Third-Party Open Source Software Licenses — MASAREN Platform

> **Legal Template Notice:** This document is a template and must be reviewed, updated with accurate version numbers, and verified by qualified legal counsel. Version numbers marked `[x.x.x]` must be replaced with the actual pinned versions in use at each release.

---

## Introduction

The MASAREN Platform incorporates third-party open source software components. This document lists those components, their applicable licenses, and their use within the Platform. MASAREN acknowledges and thanks the open source communities that have made these components available.

Each section covers one category of dependencies. For the full license text of each component, refer to the URL provided or to the component's source repository.

---

## 1. Python Backend Dependencies

These components are used in MASAREN's backend microservices built with Python/FastAPI.

---

### 1.1 FastAPI
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/tiangolo/fastapi/blob/master/LICENSE
- **Copyright:** Copyright © 2018 Sebastián Ramírez
- **Use in MASAREN:** Core ASGI web framework for all backend microservices (identity, verification, AI, reputation, marketplace, reporting, graph, gateway, and others).

### 1.2 Starlette
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/encode/starlette/blob/master/LICENSE.md
- **Copyright:** Copyright © 2018 Encode OSS Ltd.
- **Use in MASAREN:** ASGI toolkit underlying FastAPI; provides routing, middleware, WebSocket support, and background tasks.

### 1.3 Uvicorn
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/encode/uvicorn/blob/master/LICENSE.md
- **Copyright:** Copyright © 2017 Encode OSS Ltd.
- **Use in MASAREN:** ASGI server for running all FastAPI microservices in production and development.

### 1.4 Pydantic
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/pydantic/pydantic/blob/main/LICENSE
- **Copyright:** Copyright © 2017 Samuel Colvin
- **Use in MASAREN:** Data validation and serialization across all services; used in DTOs, request/response models, and configuration management.

### 1.5 SQLAlchemy
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/sqlalchemy/sqlalchemy/blob/main/LICENSE
- **Copyright:** Copyright © 2005–2026 SQLAlchemy authors and contributors
- **Use in MASAREN:** ORM and database abstraction layer for PostgreSQL interactions in all services that persist data.

### 1.6 Alembic
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/sqlalchemy/alembic/blob/main/LICENSE
- **Copyright:** Copyright © 2009–2026 Mike Bayer
- **Use in MASAREN:** Database schema migration tool for PostgreSQL. Manages schema versioning across deployment environments.

### 1.7 python-jose
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/mpdavis/python-jose/blob/master/LICENSE
- **Copyright:** Copyright © 2015 Michael Davis
- **Use in MASAREN:** JSON Web Token (JWT) creation, signing, and verification in authentication and authorization services.

### 1.8 passlib
- **Version:** `[x.x.x]`
- **License:** BSD 2-Clause License
- **License URL:** https://foss.heptapod.net/python-libs/passlib/-/blob/stable/LICENSE
- **Copyright:** Copyright © 2008–2020 Eli Collins
- **Use in MASAREN:** Password hashing (bcrypt) in the authentication service. Used for secure storage of user credentials.

### 1.9 bcrypt
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/pyca/bcrypt/blob/main/LICENSE
- **Copyright:** Copyright © The Individual Contributors
- **Use in MASAREN:** Bcrypt hashing algorithm for password security; invoked through passlib.

### 1.10 httpx
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/encode/httpx/blob/master/LICENSE.md
- **Copyright:** Copyright © 2019 Encode OSS Ltd.
- **Use in MASAREN:** Async HTTP client for inter-service communication, OpenAI API calls, Google Generative AI API calls, and external webhook delivery.

### 1.11 python-multipart
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/andrew-d/python-multipart/blob/master/LICENSE.txt
- **Copyright:** Copyright © 2012 Andrew Dunham
- **Use in MASAREN:** Multipart form data parsing for media/evidence file uploads in the verification domain.

### 1.12 psycopg2 / psycopg2-binary
- **Version:** `[x.x.x]`
- **License:** GNU LGPL v3 (with special exception permitting use without LGPL obligations when linked as a library)
- **License URL:** https://www.psycopg.org/license/
- **Copyright:** Copyright © 2001–2021 Federico Di Gregorio, Daniele Varrazzo, and contributors
- **Use in MASAREN:** PostgreSQL database adapter. Used through SQLAlchemy for all relational data access.
- **Note:** The psycopg2 license exception means that use of the compiled binary does not trigger LGPL copyleft obligations. This must be confirmed with legal counsel for the specific use case.

### 1.13 asyncpg
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/MagicStack/asyncpg/blob/master/LICENSE
- **Copyright:** Copyright © 2016 MagicStack Inc.
- **Use in MASAREN:** High-performance async PostgreSQL driver for services requiring non-blocking database I/O.

### 1.14 redis (redis-py)
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/redis/redis-py/blob/master/LICENSE
- **Copyright:** Copyright © 2022 Redis Inc.
- **Use in MASAREN:** Redis client for session caching, rate limiting, leaderboard operations, and transient state storage.

### 1.15 kafka-python
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/dpkp/kafka-python/blob/master/LICENSE
- **Copyright:** Copyright © 2015 Dana Powers, David Arthur, and contributors
- **Use in MASAREN:** Kafka producer and consumer in the shared kernel (`kafka_producer.py`, `kafka_consumer.py`) for event-driven communication between microservices.

### 1.16 neo4j (Python Driver)
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/neo4j/neo4j-python-driver/blob/5.0/LICENSE
- **Copyright:** Copyright © 2002–2026 Neo4j Sweden AB
- **Use in MASAREN:** Graph database client for the knowledge graph service; Cypher query execution against Neo4j.

### 1.17 opensearch-py
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/opensearch-project/opensearch-py/blob/main/LICENSE.txt
- **Copyright:** Copyright OpenSearch Contributors
- **Use in MASAREN:** Full-text search client for the reporting and discovery features of the platform.

### 1.18 python-dotenv
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/theskumar/python-dotenv/blob/main/LICENSE
- **Copyright:** Copyright © 2014 Saurabh Kumar
- **Use in MASAREN:** Environment variable loading from `.env` files across all microservices.

### 1.19 pytest
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/pytest-dev/pytest/blob/main/LICENSE
- **Copyright:** Copyright © 2004 Holger Krekel and others
- **Use in MASAREN:** Test framework for all backend service unit and integration tests. Used in development/CI only; not distributed in production.

### 1.20 pytest-asyncio
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/pytest-dev/pytest-asyncio/blob/master/LICENSE
- **Copyright:** Copyright © 2015–2020 Tin Tvrtković
- **Use in MASAREN:** Async test runner plugin for pytest; required for testing async FastAPI endpoints. Development/CI only.

### 1.21 cryptography
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0 / BSD License (dual-licensed)
- **License URL:** https://github.com/pyca/cryptography/blob/main/LICENSE
- **Copyright:** Copyright © 2013–2026 The Python Cryptographic Authority and individual contributors
- **Use in MASAREN:** Cryptographic primitives for TLS, JWT signing, and secure data handling.

### 1.22 Pillow
- **Version:** `[x.x.x]`
- **License:** HPND (Historical Permission Notice and Disclaimer)
- **License URL:** https://github.com/python-pillow/Pillow/blob/main/LICENSE
- **Copyright:** Copyright © 1997–2011 by Secret Labs AB / Copyright © 1995–2011 by Fredrik Lundh
- **Use in MASAREN:** Image processing in the media and vision-AI services.

### 1.23 structlog / loguru
- **Version:** `[x.x.x]`
- **License:** MIT License / MIT License
- **License URL:** https://github.com/hynek/structlog/blob/main/LICENSE / https://github.com/Delgan/loguru/blob/master/LICENSE
- **Copyright:** Copyright © 2013 Hynek Schlawack / Copyright © 2019 Delgan
- **Use in MASAREN:** Structured JSON logging across all backend services (`shared/utils/logging.py`).

### 1.24 openai (Python SDK)
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/openai/openai-python/blob/main/LICENSE
- **Copyright:** Copyright © 2023 OpenAI
- **Use in MASAREN:** Cloud AI inference client for Vision AI, Fraud Detection, Impact Economist, and Graph Synthesis agents when `AI_PROVIDER=openai`.

### 1.25 google-generativeai
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/google/generative-ai-python/blob/main/LICENSE
- **Copyright:** Copyright © 2023 Google LLC
- **Use in MASAREN:** Cloud AI inference client for all AI agents when `AI_PROVIDER=google`.

---

## 2. JavaScript / TypeScript Frontend Dependencies

These components are used in MASAREN's React web application (`apps/web`) and admin panel (`apps/admin`).

---

### 2.1 React
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/facebook/react/blob/main/LICENSE
- **Copyright:** Copyright © Meta Platforms, Inc. and affiliates
- **Use in MASAREN:** Core UI library for the MASAREN web application and admin panel.

### 2.2 React DOM
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/facebook/react/blob/main/LICENSE
- **Copyright:** Copyright © Meta Platforms, Inc. and affiliates
- **Use in MASAREN:** DOM rendering engine for React components in the web application.

### 2.3 React Router
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/remix-run/react-router/blob/main/LICENSE.md
- **Copyright:** Copyright © React Training LLC 2015–2019 / Remix Software Inc. 2020–2023
- **Use in MASAREN:** Client-side routing for the web application's single-page application navigation.

### 2.4 TypeScript
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/microsoft/TypeScript/blob/main/LICENSE.txt
- **Copyright:** Copyright © Microsoft Corporation
- **Use in MASAREN:** Static type system for all frontend JavaScript code. Development dependency; compiled to plain JS for production.

### 2.5 Vite
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/vitejs/vite/blob/main/LICENSE
- **Copyright:** Copyright © 2019-present, Yuxi (Evan) You and Vite contributors
- **Use in MASAREN:** Build tool and development server for the React web application.

### 2.6 Tailwind CSS
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/tailwindlabs/tailwindcss/blob/master/LICENSE
- **Copyright:** Copyright © Tailwind Labs, Inc.
- **Use in MASAREN:** Utility-first CSS framework for styling the MASAREN web application.

### 2.7 Axios
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/axios/axios/blob/v1.x/LICENSE
- **Copyright:** Copyright © 2014-present Matt Zabriskie & Collaborators
- **Use in MASAREN:** HTTP client for API requests from the web frontend to the MASAREN backend gateway.

### 2.8 Zustand
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/pmndrs/zustand/blob/main/LICENSE
- **Copyright:** Copyright © 2019 Paul Henschel
- **Use in MASAREN:** Lightweight state management library for global application state in the web frontend.

### 2.9 Lucide React
- **Version:** `[x.x.x]`
- **License:** ISC License
- **License URL:** https://github.com/lucide-icons/lucide/blob/main/LICENSE
- **Copyright:** Copyright © 2020 Lucide Contributors
- **Use in MASAREN:** Icon library used throughout the MASAREN web application UI.

### 2.10 React Query / TanStack Query
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/TanStack/query/blob/main/LICENSE
- **Copyright:** Copyright © 2021-present Tanner Linsley
- **Use in MASAREN:** Server-state management and API data caching in the React web application.

### 2.11 date-fns
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/date-fns/date-fns/blob/main/LICENSE.md
- **Copyright:** Copyright © 2021 Sasha Koss and Lesha Koss
- **Use in MASAREN:** Date manipulation and formatting utilities in the web frontend.

### 2.12 Recharts
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/recharts/recharts/blob/master/LICENSE
- **Copyright:** Copyright © 2015-2022 recharts group
- **Use in MASAREN:** Charting and data visualization components for impact metrics and analytics dashboards.

### 2.13 PostCSS
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/postcss/postcss/blob/main/LICENSE
- **Copyright:** Copyright © 2013 Andrey Sitnik
- **Use in MASAREN:** CSS post-processing tool used in the Vite/Tailwind build pipeline.

### 2.14 ESLint
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/eslint/eslint/blob/main/LICENSE
- **Copyright:** Copyright © OpenJS Foundation and other contributors
- **Use in MASAREN:** JavaScript/TypeScript linting. Development dependency only.

### 2.15 Playwright
- **Version:** `[x.x.x]`
- **License:** Apache License 2.0
- **License URL:** https://github.com/microsoft/playwright/blob/main/LICENSE
- **Copyright:** Copyright © Microsoft Corporation
- **Use in MASAREN:** End-to-end browser testing framework. Used in CI/CD pipeline for automated web E2E tests. Development/CI dependency only.

---

## 3. Flutter / Dart Mobile Dependencies

These components are used in MASAREN's Flutter mobile application (`apps/mobile`).

---

### 3.1 Flutter SDK
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/flutter/flutter/blob/master/LICENSE
- **Copyright:** Copyright © 2014 The Flutter Authors
- **Use in MASAREN:** Cross-platform UI framework for the MASAREN iOS and Android mobile application.

### 3.2 Dart SDK
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/dart-lang/sdk/blob/main/LICENSE
- **Copyright:** Copyright © 2012 The Dart Authors
- **Use in MASAREN:** Programming language and runtime for the Flutter mobile application.

### 3.3 http (Dart package)
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/dart-lang/http/blob/master/LICENSE
- **Copyright:** Copyright © 2012 The Dart Authors
- **Use in MASAREN:** HTTP client package for API communication from the mobile application.

### 3.4 dio
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/cfug/dio/blob/main/LICENSE
- **Copyright:** Copyright © 2018 wendux
- **Use in MASAREN:** Advanced HTTP client with interceptors, used for authenticated API calls and file uploads.

### 3.5 provider / riverpod
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/rrousselGit/riverpod/blob/master/LICENSE
- **Copyright:** Copyright © 2020 Remi Rousselet
- **Use in MASAREN:** State management framework for the Flutter mobile application.

### 3.6 shared_preferences
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences/LICENSE
- **Copyright:** Copyright © 2013 The Flutter Authors
- **Use in MASAREN:** Persistent key-value storage for user preferences and local session tokens.

### 3.7 flutter_secure_storage
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/mogol/flutter_secure_storage/blob/develop/LICENSE
- **Copyright:** Copyright © 2020 German Saprykin
- **Use in MASAREN:** Secure storage of authentication tokens using platform keychain/keystore.

### 3.8 geolocator
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/Baseflow/flutter-geolocator/blob/master/LICENSE
- **Copyright:** Copyright © 2018 Baseflow
- **Use in MASAREN:** GPS location access for field worker location verification and task check-in features.

### 3.9 image_picker
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/flutter/packages/blob/main/packages/image_picker/image_picker/LICENSE
- **Copyright:** Copyright © 2013 The Flutter Authors
- **Use in MASAREN:** Camera and photo library access for evidence capture and upload in the verification workflow.

### 3.10 camera
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/flutter/packages/blob/main/packages/camera/camera/LICENSE
- **Copyright:** Copyright © 2013 The Flutter Authors
- **Use in MASAREN:** Direct camera access for real-time evidence capture with metadata.

### 3.11 flutter_map
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/fleaflet/flutter_map/blob/master/LICENSE
- **Copyright:** Copyright © 2018 John Ryan
- **Use in MASAREN:** Interactive map display for location-based field task views.

### 3.12 intl
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/dart-lang/i18n/blob/main/pkgs/intl/LICENSE
- **Copyright:** Copyright © 2013 The Dart Authors
- **Use in MASAREN:** Internationalization and localization support; Arabic (RTL) and English (LTR) interface languages.

### 3.13 cached_network_image
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/Baseflow/flutter_cached_network_image/blob/develop/LICENSE
- **Copyright:** Copyright © 2019 Baseflow
- **Use in MASAREN:** Caching of remote images (avatars, evidence thumbnails, organization logos).

### 3.14 flutter_svg
- **Version:** `[x.x.x]`
- **License:** MIT License
- **License URL:** https://github.com/dnfield/flutter_svg/blob/master/LICENSE
- **Copyright:** Copyright © 2018 Dan Field
- **Use in MASAREN:** SVG asset rendering for MASAREN logos and iconography in the mobile application.

### 3.15 go_router
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/flutter/packages/blob/main/packages/go_router/LICENSE
- **Copyright:** Copyright © 2013 The Flutter Authors
- **Use in MASAREN:** Declarative routing and deep linking in the Flutter application.

### 3.16 firebase_messaging (if used)
- **Version:** `[x.x.x]`
- **License:** BSD 3-Clause License
- **License URL:** https://github.com/firebase/flutterfire/blob/master/LICENSE
- **Copyright:** Copyright © 2017 The Chromium Authors
- **Use in MASAREN:** Push notification delivery to mobile clients via Firebase Cloud Messaging (FCM).

---

## 4. Infrastructure Components

These components are deployed as services in MASAREN's infrastructure stack.

---

### 4.1 PostgreSQL with PostGIS
- **Version:** `16-3.4` (PostGIS extension)
- **License:** PostgreSQL License (BSD-like) / GNU GPL v2 (PostGIS)
- **License URL:** https://www.postgresql.org/about/licence/ / https://postgis.net/docs/manual-3.4/
- **Copyright:** Copyright © 1996–2026 The PostgreSQL Global Development Group / © 2001–2026 PostGIS Project Steering Committee
- **Use in MASAREN:** Primary transactional relational database. PostGIS extension used for geospatial data (GPS coordinates, field locations).
- **Note:** PostGIS is licensed under GPL v2. As MASAREN runs PostGIS as a separate server process (not linked into MASAREN's binary), this does not trigger GPL copyleft obligations on MASAREN's proprietary code. Consult legal counsel to confirm.

### 4.2 Neo4j Community Edition
- **Version:** `5.x`
- **License:** GNU GPL v3 (Community Edition)
- **License URL:** https://github.com/neo4j/neo4j/blob/4.4/LICENSE.txt
- **Copyright:** Copyright © 2002–2026 Neo4j Sweden AB
- **Use in MASAREN:** Knowledge graph database for the graph-service domain (relationships between users, organizations, impacts, and assets).
- **Note:** Neo4j Community Edition is licensed under GPL v3. MASAREN accesses Neo4j exclusively as a separate network service (client-server model via the Bolt protocol). This network separation means Neo4j's GPL obligations do not extend to MASAREN's proprietary code. However, if production deployment requires the Enterprise Edition, a separate commercial license from Neo4j must be obtained. Consult legal counsel.

### 4.3 Apache Kafka (KRaft mode)
- **Version:** `3.7.0`
- **License:** Apache License 2.0
- **License URL:** https://github.com/apache/kafka/blob/trunk/LICENSE
- **Copyright:** Copyright © The Apache Software Foundation
- **Use in MASAREN:** Distributed event streaming platform for the event-driven architecture; carries all 20 defined domain event types between microservices.

### 4.4 Redis
- **Version:** `7-alpine`
- **License:** BSD 3-Clause License (versions < 7.4) / RSALv2 or SSPLv1 (versions ≥ 7.4)
- **License URL:** https://github.com/redis/redis/blob/unstable/COPYING
- **Copyright:** Copyright © 2006-2026 Salvatore Sanfilippo
- **Use in MASAREN:** In-memory data store for session management, API rate limiting, leaderboard/reputation scoring caches, and pub/sub messaging.
- **Note:** Redis 7.x series introduced a license change to RSALv2/SSPLv1. This licensing change should be assessed by legal counsel. Depending on the version pinned and MASAREN's deployment model, alternative Redis-compatible solutions (Valkey, KeyDB) may need to be evaluated.

### 4.5 OpenSearch
- **Version:** `2.x`
- **License:** Apache License 2.0
- **License URL:** https://github.com/opensearch-project/OpenSearch/blob/main/LICENSE.txt
- **Copyright:** Copyright © OpenSearch Contributors
- **Use in MASAREN:** Distributed full-text and vector search engine for discovery, filtering, and analytics reporting features.

### 4.6 Docker
- **Version:** As deployed
- **License:** Apache License 2.0 (Docker Engine open source) / Proprietary (Docker Desktop — not used in production)
- **License URL:** https://github.com/moby/moby/blob/master/LICENSE
- **Copyright:** Copyright © 2013–2026 Docker, Inc.
- **Use in MASAREN:** Container runtime for packaging and deploying all MASAREN microservices.

### 4.7 Kubernetes
- **Version:** As deployed
- **License:** Apache License 2.0
- **License URL:** https://github.com/kubernetes/kubernetes/blob/master/LICENSE
- **Copyright:** Copyright © The Kubernetes Authors
- **Use in MASAREN:** Container orchestration platform for production deployment of the microservices architecture.

---

## 5. Additional Notices

### 5.1 OpenAI API
MASAREN's AI agents may call the OpenAI API (GPT-4o, GPT-4o-mini). Use of the OpenAI API is governed by OpenAI's Terms of Service and Usage Policies. OpenAI is not an open source component; it is a third-party service. No OpenAI source code is distributed with MASAREN.

### 5.2 Google Generative AI API (Gemini)
MASAREN's AI agents may call the Google Generative AI API (Gemini Pro, Gemini Flash). Use of this API is governed by Google's Terms of Service and Generative AI Prohibited Use Policy. No Google proprietary code is distributed with MASAREN.

### 5.3 Mapbox / OpenStreetMap (if applicable)
Map tiles, if used, may be sourced from Mapbox (proprietary, requires API key and Mapbox ToS compliance) or OpenStreetMap (ODbL license). The applicable terms depend on which tile provider is configured in the deployment.

---

*Document Version: 1.0*
*Last Updated: August 11, 2026*
*Classification: Internal / Compliance Reference*

> **Action Required:** Before each production release, update all version placeholder fields (`[x.x.x]`) with the actual pinned versions from `requirements.txt`, `pubspec.lock`, and `package-lock.json`. Have qualified legal counsel review any license changes introduced by dependency version bumps.
