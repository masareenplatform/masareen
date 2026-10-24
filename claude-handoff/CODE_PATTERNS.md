# MASAREN, Code Patterns (trimmed exemplars)

> Read this AFTER `PLATFORM_GENOME.md`. These are real, trimmed snippets so you can
> match conventions when extending a service. The full source is NOT in this package
> (token budget); pull the specific service from the real repo as needed.

## 1. Service entrypoint (FastAPI, via shared factory)

Every service's `src/main.py` is identical in shape, only the name/description change:

```python
from shared.utils.app_factory import create_app
from .api import router

app = create_app(
    "verification-service", "0.1.0",
    "Multi-stage evidence verification pipeline with AI review, fraud detection, human review."
)
app.include_router(router, prefix="/api/v1")
```

## 2. Shared kernel API surface (`backend/shared/utils/`)

### app_factory.py
```python
def create_app(name, version, description) -> FastAPI
```

### cloud_llm_client.py
```python
class LLMProvider(str, Enum)
class LLMMessage
class LLMResponse
class CloudLLMClient(ABC)
class OpenAIClient(CloudLLMClient)
class GoogleAIClient(CloudLLMClient)
def build_llm_client(provider: str, api_key: str) -> CloudLLMClient
```

### config_loader.py
```python
def get_database_url() -> str
def get_kafka_bootstrap() -> str
def get_redis_url() -> str
def get_neo4j_url() -> str
def get_neo4j_auth() -> tuple[str, str]
def get_ai_provider() -> str
def get_cloud_api_key() -> str
def get_openai_api_key() -> str
def get_google_api_key() -> str
```

### cqrs.py
```python
class Command
class Query(Generic[TResult])
class CommandHandler(ABC, Generic[TResult])
class QueryHandler(ABC, Generic[TResult])
class CommandBus   # register(command_type, handler)
class QueryBus     # register(query_type, handler)
```

### health.py
```python
class HealthStatus(str, Enum)
class ComponentHealth
class HealthReport
class HealthChecker   # register(name, check_fn)
```

### kafka_consumer.py
```python
class EventConsumer(ABC)   # at-least-once base; implement handle()
```

### kafka_producer.py
```python
class EventPublisher   # idempotent Kafka publisher
```

### logging.py
```python
def configure_logging(service_name, log_level="INFO")
def get_logger(name)
def bind_request_context(...)
def clear_request_context()
```

### outbox.py
```python
class OutboxWriter      # write event rows in same DB transaction
class OutboxRelay       # relay outbox rows -> Kafka (Transactional Outbox)
```

## 3. CQRS / handler shape (per service)

Services follow:
`api/router.py` (FastAPI routes) → `application/handlers/*.py` (command/query handlers)
→ `domain/` (entities, value objects) → `infrastructure/` (repositories, DB, kafka).

Commands/Queries are dispatched via `shared.utils.cqrs.CommandBus / QueryBus`.
Domain events are published **only** through `shared.utils.outbox` (Transactional Outbox).

## 4. AI agent pattern (`backend/ai/verification_orchestrator_service`)

POAI deliberative crew. Structure:
- `src/agents/*.py`, agent definitions
- `src/tasks/*.py`, task definitions
- `src/tools/*.py`, kafka / blackboard tools
- `src/utils/*.py`, helpers

Cloud LLM calls go through `shared.utils.cloud_llm_client`. Other AI modules
(`auditor-agent`, `economist-agent`, `fraud-service/python`, `vision-ai-service`, …)
are consumed by this orchestrator. These AI modules are implemented but are **not**
wired into `docker-compose.yml` yet.
