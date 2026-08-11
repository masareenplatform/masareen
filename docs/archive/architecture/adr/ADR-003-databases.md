# ADR-003: Polyglot Persistence Strategy

**Status**: Accepted

## Decisions

| Database | Purpose |
|----------|---------|
| PostgreSQL + PostGIS | Primary transactional store, geospatial queries |
| Neo4j | Knowledge graph: relationships between people, orgs, skills, tasks |
| Redis | Caching, sessions, rate limiting, pub/sub |
| OpenSearch | Full-text search across programs, opportunities, people |
| Vector DB (pgvector) | Semantic search, AI embeddings, similarity matching |
| Object Storage (S3-compatible) | Media files, evidence photos/videos |
| Data Warehouse | Analytics, aggregated reporting (read-optimized) |
| Immutable Event Store | Append-only source of truth for all events |

## Rule

Each service owns its own database schema. No cross-service direct DB access.
