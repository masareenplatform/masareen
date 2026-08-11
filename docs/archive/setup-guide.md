# 🚀 MASAREN Setup Guide (Developer & DevOps Edition)

Welcome to the MASAREN technical onboarding. This guide is designed for developers and DevOps engineers to get the platform running from zero to production.

## 1. 🛠 Prerequisites
Before starting, ensure you have the following installed:
- **Docker & Docker Compose**: For containerized infrastructure.
- **Python 3.11+**: For backend services.
- **Node.js 18+ & npm**: For the React web application.
- **Flutter SDK**: For the mobile application.
- **Git**: For version control.
- **PostgreSQL / PostGIS**: Primary database.
- **Apache Kafka**: The event-driven backbone.

---

## 2. 📦 Local Development Setup

### Step 1: Clone and Configure
```bash
# Clone the repository
git clone https://github.com/anomalyco/masaren.git
cd masaren

# Setup environment variables
cp .env.example .env
```
**Important `.env` settings:**
- `DATABASE_URL`: `postgresql+asyncpg://user:pass@localhost:5432/masaren`
- `KAFKA_BOOTSTRAP_SERVERS`: `localhost:9092`
- `AI_PROVIDER`: `google` or `openai`
- `CLOUD_API_KEY`: Your Gemini or OpenAI key.

### Step 2: Start Infrastructure
We use Docker Compose to spin up the complex stack (Postgres, Kafka, Redis, Neo4j, OpenSearch).
```bash
docker compose up -d
```

### Step 3: Database & Kafka Initialization
Run the provided SQL migrations in `infrastructure/databases/postgres/migrations/` and create the Kafka topics listed in `infrastructure/kafka/topics/event_catalog.yaml`.

### Step 4: Running Services
Each service is a standalone FastAPI application.
```bash
# Example: Running the Identity Service
cd backend/identity/identity-service
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8001
```

---

## 3. 🚀 CI/CD & Deployment Pipeline

MASAREN uses a **GitOps** approach for deployments.

### GitHub Workflow
1. **Feature Branch**: Create a branch `feature/your-feature-name`.
2. **Pull Request**: Submit a PR to `main`.
3. **Automated Testing**: GitHub Actions triggers unit tests and linting.
4. **Merge**: Once approved and tests pass, merge to `main`.

### Deployment Flow
`Main Branch` $\rightarrow$ `GitHub Actions` $\rightarrow$ `Docker Hub/GHCR` $\rightarrow$ `Kubernetes (K8s)`

**How to update the production environment:**
1. Update the image tag in `infrastructure/kubernetes/overlays/prod/kustomization.yaml`.
2. Apply the changes:
   ```bash
   kubectl apply -k infrastructure/kubernetes/overlays/prod
   ```

---

## 4. 🛠 Basic Troubleshooting
- **DB Connection Error**: Check if `docker compose ps` shows the postgres container as `healthy`.
- **Kafka Lag**: Use `kafka-consumer-groups` to check if events are being processed.
- **AI Errors**: Verify your `CLOUD_API_KEY` has sufficient credits and the `AI_PROVIDER` is set correctly.
