# audit-service

**Domain**: Verification  
**Description**: Immutable audit trail and compliance logs

## Structure

```
audit-service/
├── src/
│   ├── api/            # FastAPI routers, request/response schemas
│   ├── domain/         # Entities, value objects, domain events
│   ├── application/    # Use cases, command/query handlers
│   ├── infrastructure/ # DB repos, Kafka producers, external clients
│   └── events/         # Outbound event publishers
├── tests/
│   ├── unit/
│   └── integration/
└── config/
    └── settings.py
```

## Events Emitted

See `src/events/` for full list.

## API

See `src/api/` and OpenAPI spec at `/docs` when running.

## Running

```bash
cd audit-service
pip install -r requirements.txt
uvicorn src.main:app --reload
```
