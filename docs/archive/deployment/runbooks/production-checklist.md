# Production Deployment Checklist

## Pre-deployment
- [x] **Zero-Mock Audit**: Comprehensive codebase audit performed; zero production-level mocks, stubs, or simulated data layers remaining.
- [x] **Code Quality Audit**: System-wide check for `print` statements and `NotImplementedError` in core business logic completed.
- [ ] All secrets rotated and stored in K8s secrets (not ConfigMaps)
- [ ] `.env` never committed — verify with `git log --all -- .env`
- [ ] Neo4j constraints migration applied on production cluster
- [ ] SDG seed nodes loaded
- [ ] Kafka topics pre-created (run `kafka/topics/event_catalog.yaml`)
- [ ] PostgreSQL migrations applied (Alembic or flyway)
- [ ] Cloud API keys validated (test call to OpenAI/Google)

## K8s deployment
```bash
kubectl apply -f infrastructure/kubernetes/base/namespace.yaml
kubectl apply -f infrastructure/kubernetes/base/configmap.yaml
kubectl create secret generic masaren-secrets --from-env-file=.env -n masaren

# Deploy all services
kubectl apply -k infrastructure/kubernetes/overlays/prod
```

## Post-deployment verification
- [ ] All 24 service pods Running: `kubectl get pods -n masaren`
- [ ] Gateway health: `curl https://api.masaren.io/health/upstream`
- [ ] Neo4j reachable from graph-service pod
- [ ] Kafka consumer groups active: check Kafka UI
- [ ] Outbox relay running (check logs for OutboxRelay)
- [ ] Prometheus scraping all targets
- [ ] Grafana dashboard loading
- [ ] Alert rules loaded in Alertmanager

## Rollback
```bash
kubectl rollout undo deployment/<service-name> -n masaren
```

## K8s deployment
```bash
kubectl apply -f infrastructure/kubernetes/base/namespace.yaml
kubectl apply -f infrastructure/kubernetes/base/configmap.yaml
kubectl create secret generic masaren-secrets --from-env-file=.env -n masaren

# Deploy all services
kubectl apply -k infrastructure/kubernetes/overlays/prod
```

## Post-deployment verification
- [ ] All 24 service pods Running: `kubectl get pods -n masaren`
- [ ] Gateway health: `curl https://api.masaren.io/health/upstream`
- [ ] Neo4j reachable from graph-service pod
- [ ] Kafka consumer groups active: check Kafka UI
- [ ] Outbox relay running (check logs for OutboxRelay)
- [ ] Prometheus scraping all targets
- [ ] Grafana dashboard loading
- [ ] Alert rules loaded in Alertmanager

## Rollback
```bash
kubectl rollout undo deployment/<service-name> -n masaren
```
