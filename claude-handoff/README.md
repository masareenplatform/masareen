# MASAREN, Claude Handoff Package

This directory is a **self-contained project brief** for the web Claude (claude.ai) to audit,
debug, build, and continue the MASAREN platform. The full source is included (minus vendored
and build artifacts) so Claude can read, edit, and run it inside a Claude Project.

## How to use this package
1. **Upload the whole `claude-handoff/` folder** as a Claude Project (files load on demand,
   so the ~20 MB does not all hit context at once).
2. **Start with `PLATFORM_GENOME.md`**, the single source of truth (architecture, full
   service topology, ports, env vars, events, engineering rules, and the cleanup audit).
   `platform-genome.json` is the machine-readable twin.
3. **`CODE_PATTERNS.md`**, trimmed exemplars (service entrypoint, shared-kernel API surface,
   CQRS shape, AI agent pattern) so edits match conventions.
4. **`STRUCTURE.txt`**, compact map of what's in this package.
5. **Run it:** copy `.env.example` → `.env`, set `JWT_SECRET` + `OPENAI_API_KEY`, then
   `docker compose up -d` (gateway `:8080`, web `:3000`, admin `:3001`). For native dev run
   `backend/run_native.ps1`.

## What's included
- `backend/`, all 30+ Python/FastAPI microservices (real source, buildable). Excludes
  `.venv`, `build`, `target`, `__pycache__`, `_run`, `node_modules`, **`tests/`**, and `k8s/`
  to stay compact. Tests + k8s live in the full repo if needed.
- `apps/web/`, React + TypeScript app (excludes `node_modules`/`build`/`dist`).
- `apps/mobile/`, Flutter app `lib/`, `assets/`, `test/`, `pubspec.yaml`
  (excludes generated `android/`, `build/`, `.dart_tool`; regenerate via `flutter create`).
- `infrastructure/`, DB migrations, Kafka topics, K8s, Helm, Terraform, CI, monitoring.
- `docker-compose.yml` + `docker-compose.override.yml`, full-stack deployment.
- `.env.example`, env template.

## What's NOT here (by design)
- No `node_modules/`, `.venv/`, `android/build/`, `target/` (vendored/build artifacts).
- No `backend/tests/` or `k8s/` (regenerate/run from full repo).
- `apps/admin/` and `MASAREN-DEMO/` are not included, ask if you need them.
- `docs/` tree is summarized inside the genome (not copied).

## Continuation checklist
- [ ] Pick the service/domain to change (genome §3 topology).
- [ ] Follow engineering rules (genome §9): Repository pattern, DTO validation, events via
      Outbox, no local AI, framework-independent domain models.
- [ ] Run unit + integration + contract + event tests (≥90% target) in the full repo.
- [ ] Update `PLATFORM_GENOME.md` / `platform-genome.json` if topology or contracts change.

## Known gaps (from audit)
- Per-function dead-code pass (`ruff`/`vulture`) across 30+ services not yet done.
- Several `backend/ai/*` agents implemented but not wired into `docker-compose.yml`.
- OpenSearch search layer planned but absent.
