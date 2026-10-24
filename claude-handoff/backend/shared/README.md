# MASAREN Shared Kernel, Stage 2

The Shared Kernel is the cross-cutting foundation imported by every microservice.
It contains zero business logic. It defines contracts, not implementations.

## Contents

| Module | Purpose |
|--------|---------|
| `events/` | Immutable `DomainEvent` base + all domain event contracts |
| `base_entity/` | `AggregateRoot` base class |
| `base_repository/` | `Repository` port interface + async SQLAlchemy session |
| `dtos/` | Shared Pydantic schemas, enums, paginated responses |
| `exceptions/` | Domain exception hierarchy |
| `middleware/` | JWT auth, password hashing, RBAC dependency factories |
| `utils/cqrs.py` | `CommandBus` + `QueryBus` (dispatcher pattern) |
| `utils/kafka_producer.py` | `EventPublisher`, async Kafka wrapper |
| `utils/kafka_consumer.py` | `EventConsumer`, abstract base consumer |
| `utils/outbox.py` | `OutboxWriter` + `OutboxRelay` (transactional outbox) |
| `utils/logging.py` | Structured JSON logging via structlog |
| `utils/health.py` | `HealthChecker`, composable health report builder |
| `utils/app_factory.py` | `create_app()`, FastAPI factory with all standard middleware |
| `testing/` | Shared pytest fixtures (in-memory DB, mock publisher, helpers) |

## Usage in a Service

```python
# service/src/main.py
from masaren_shared.utils.app_factory import create_app
from masaren_shared.utils.health import HealthChecker

health = HealthChecker("identity-service")
health.register("postgres", check_postgres)
health.register("kafka", check_kafka)

app = create_app(
    service_name="identity-service",
    health_checker=health,
    on_startup=[publisher.start, consumer.start],
    on_shutdown=[publisher.stop, consumer.stop],
)
app.include_router(router, prefix="/api/v1")
```

## Architecture Rules

1. **No business logic** in the shared kernel
2. **No imports** from specific services (no circular dependencies)
3. **Every service** uses `create_app()`, never builds FastAPI from scratch
4. **All DB sessions** go through `base_repository/db.py`, no raw connections
5. **All events** transit through `OutboxWriter` inside transactions
6. **All Kafka publishing** goes through `EventPublisher`, no direct aiokafka

---

## Hybrid Architecture Addendum (from hardware constraint review)

**Deployment server**: HPE ProLiant DL360 Gen10 · 32GB RAM · **0GB VRAM**

This constraint has one architectural consequence:
**No local LLM inference.** All AI agent computation routes to cloud APIs.

### `utils/cloud_llm_client.py`

Providers implemented:
- `OpenAIClient`, GPT-4o (text + vision), text-embedding-3-small
- `GoogleAIClient`, Gemini 1.5 Flash/Pro (text + vision), text-embedding-004

Factory: `build_llm_client(provider, api_key)`, reads from `AI_PROVIDER` and `CLOUD_API_KEY` env vars.

### Kafka Broker (KRaft Mode)

Switched from Confluent Kafka + Zookeeper → `apache/kafka:3.7.0` in KRaft mode.
Zookeeper dependency removed. Same topic catalog, same producer/consumer code.

### Infrastructure service names

All internal hostnames updated to match `container_name` values in docker-compose:
- `masaren-postgres`, `masaren-neo4j`, `masaren-redis`, `masaren-kafka`, `masaren-opensearch`
