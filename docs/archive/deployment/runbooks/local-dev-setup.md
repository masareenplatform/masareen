# Local Development Setup Runbook

## Prerequisites
- Docker Desktop ≥ 4.28
- Python 3.12+
- Node.js 20+ (for web app)
- Flutter 3.16+ (for mobile app)

## 1. Clone and configure
```bash
git clone https://github.com/YOUR_ORG/masaren.git
cd masaren
cp .env.example .env
# Edit .env, set passwords and CLOUD_API_KEY
```

## 2. Start infrastructure
```bash
docker compose up -d
# Wait ~30s for all services to be healthy
docker compose ps
```

## 3. Run Neo4j migrations
```bash
docker exec masaren-neo4j cypher-shell -u neo4j -p $NEO4J_PASSWORD   < infrastructure/databases/neo4j/migrations/001_constraints.cypher
docker exec masaren-neo4j cypher-shell -u neo4j -p $NEO4J_PASSWORD   < infrastructure/databases/neo4j/migrations/002_sdg_nodes.cypher
```

## 4. Start services (example: identity domain)
```bash
# Terminal 1, identity-service
cd backend/identity/identity-service
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8001

# Terminal 2, authentication-service
cd backend/identity/authentication-service
uvicorn src.main:app --reload --port 8002

# Terminal 3, gateway
cd backend/gateway
pip install fastapi uvicorn httpx
uvicorn src.main:app --reload --port 8000
```

## 5. Test the platform
```bash
# Register a user
curl -X POST http://localhost:8001/api/v1/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@masaren.io","full_name":"Test User","password":"secure123"}'

# Health check all services
curl http://localhost:8000/health/upstream
```

## 6. Run unit tests
```bash
cd backend/identity/identity-service
pytest tests/unit/ -v --cov=src

cd backend/execution/task-service
pytest tests/unit/ -v

cd backend/verification/evidence-service
pytest tests/unit/ -v
```

## Service Port Map
| Service | Port |
|---------|------|
| API Gateway | 8000 |
| identity-service | 8001 |
| authentication-service | 8002 |
| authorization-service | 8003 |
| organization-service | 8004 |
| program-service | 8005 |
| task-service | 8006 |
| workflow-service | 8007 |
| verification-service | 8008 |
| evidence-service | 8009 |
| gps-service | 8010 |
| PostgreSQL | 5432 |
| Neo4j Browser | 7474 |
| Neo4j Bolt | 7687 |
| Redis | 6379 |
| Kafka | 9092 |
| OpenSearch | 9200 |
