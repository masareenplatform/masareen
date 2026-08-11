# EfficiencySelector — Design & Contract

## Purpose
Let production choose, per workload, the best engine implementation among available
language variants (Python / Go / Rust). Each variant implements the **same** HTTP+JSON
contract for a given *capability*. The selector tracks measured performance and lets
an operator (or autoscheduler) pick the variant to route to.

## Concepts
- **Capability**: a logical function, e.g. `auth.verify`, `fraud.score`,
  `reputation.pms`, `reputation.oii`. Identified by a stable string.
- **Variant**: a concrete implementation of a capability in a language.
  Identified by `(capability, language, version)`, e.g.
  `fraud.score/rust/1`. Each variant exposes:
  - `GET  /health` → `{status, capability, language, version}`
  - `GET  /bench`  → runs a small real self-benchmark, returns
    `{capability, language, version, p50_ms, throughput_rps, samples}`
    (measured, not hardcoded).
  - The capability's business endpoint(s) (identical path/shape across languages).
- **Selector**: the control plane. Holds a registry of variants per capability and
  a *policy* (`latency` | `throughput` | `explicit`). Returns the chosen
  `(language, version)` for a capability, or the full ranked list.

## Selection policy
- `latency`    → lowest `p50_ms` wins.
- `throughput` → highest `throughput_rps` wins.
- `explicit`   → operator-pinned `(language, version)` per capability.

When no measurements exist yet, the selector returns the baseline Python variant
(always present) — never a fabricated winner.

## HTTP contract (selector service)
- `GET  /selector/capabilities` → list capabilities + registered variants
- `GET  /selector/capabilities/{capability}` → variants + current choice
- `POST /selector/capabilities/{capability}/bench` → trigger `/bench` on each
  variant, store measured results (real calls, real numbers)
- `POST /selector/capabilities/{capability}/policy` body `{policy, pinned?}`
- `GET  /selector/route/{capability}` → `{capability, language, version, url}`
  used by the gateway to forward traffic.

## Variant registration
Variants self-register on startup by `POST /selector/register` with
`{capability, language, version, health_url, bench_url, business_url}`.
The selector periodically calls each `health_url`; unhealthy variants are
excluded from selection (honest degradation, no fake fallback).

## Honesty guarantees
- Benchmarks measure real work (the actual scoring/verify function on sample input).
- No hardcoded performance numbers.
- If a capability has only the Python variant, selector returns Python — it does
  not invent a faster one.
- Gateway only routes to a variant whose `health` is green.
