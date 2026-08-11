# gps-service

**Domain**: Verification  
**Description**: GPS tracking, geofencing, location verification

## Structure

```
gps-service/
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
cd gps-service
pip install -r requirements.txt
uvicorn src.main:app --reload
```
