# README.md

# evidence-service

**Domain**: Verification  
**Description**: Evidence lifecycle management and storage

## Structure

```
evidence-service/
├── src/
│   ├── api/            # FastAPI routers, request/response schemas
│   ├── domain/         # Entities, value objects, domain events
│   ├── application/    # Use cases, command/query handlers
│   ├── infrastructure/ # DB repos, Kafka producers, external clients
│   └── events/         # Outbound event publishers
├── tests/
│   ├── unit/
│   │   ├── test_evidence_domain.py
│   │   └── test_api_specification.py
│   └── integration/
├── config/
│   └── settings.py
└── docs/
    └── evidence-service-validation.md
```

## Events Emitted

See `src/events/` for full list.

## API

See `src/api/` and OpenAPI spec at `/docs` when running.

## Running

```bash
cd evidence-service
pip install -r requirements.txt
uvicorn src.main:app --reload
```

## Testing

```bash
pytest tests/unit/ -v
pytest tests/integration/ -v
```

## Validation

Run acceptance tests for Evidence Service:
```bash
# 1. Build Verification
python -m pytest tests/unit/ tests/integration/ --cov=src

# 2. Runtime Verification  
uvicorn src.main:app --reload &
sleep 5
curl http://localhost:8000/health

# 3. API Verification
curl -X POST http://localhost:8000/ -H "Content-Type: application/json" -d '{"task_id":"task-test","submitted_by":"user-1","media_type":"PHOTO","file_size_bytes":1048576}'
curl http://localhost:8000/docs

# 4. Docker Verification
docker compose up -d
```
