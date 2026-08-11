# impact-score-service

**Domain**: Reputation  
**Description**: Proof of Mission Score (PMS) calculation engine

## Structure

```
impact-score-service/
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
cd impact-score-service
pip install -r requirements.txt
uvicorn src.main:app --reload
```
