# MASAREN — Agent Pretest Scheme (pre-alpha, before human testing)

Purpose: a reproducible, structured pretest where one or more AI agents adopt a
persona (account type), exercise the monetisation + core features against a running
backend (Docker gateway, or the offline mocks), and emit a machine-readable report.
This is the automated gate that runs **before** human alpha testing.

## 1. Personas / account types
| Persona | Role | Goal in pretest |
|---------|------|-----------------|
| `volunteer` | USER | Earn/spend MRC, view wallet, browse opportunities, no admin powers. |
| `organisation` | ORG | Fund ads, pay via Paymob, view payment history, see own campaigns. |
| `advertiser` | USER (or ORG) | Create ad campaigns (sees brokerage fee deducted), record impressions/clicks. |
| `admin` | ADMIN | Read platform profit & fees, **change** the brokerage rate, verify revenue ledger. |
| `field_agent` | FIELD_AGENT | Submit evidence, view passport; sanity-check it still works alongside monetisation. |

## 2. Feature checklist (per persona)
Mark each: `pass` / `fail` / `blocked` / `na`, with a one-line note + screenshot ref.

- **Auth & profile**: register (persona), login, me() reflects role.
- **Wallet (coin)**: create wallet, get balance, `exchange/rate`, `exchange/convert`
  (deposit & withdraw) — assert `fee_mrc` > 0 at default 2.5%; `transfer` — assert
  recipient net = amount − fee; `earn`/`spend`; transaction history lists rows.
- **Ads**: create campaign with budget B — assert response `platform_fee_coins = B*0.025`
  and `budget_coins = B − fee`; list/status toggle; add creative; record impression/click;
  stats show spend.
- **Payments**: `psp/status` shows Paymob enabled; `psp/paymob/intent` returns
  `redirect_url`/`payment_key`; history lists entries.
- **Platform (admin only)**: `config/fee` GET = 0.025; admin POST `config/fee` with 0.05
  → subsequent ads/coin fees use 5%; `revenue/summary` totals increase after the above
  actions; `revenue/events` lists the recorded brokerage rows.
- **Cross-cutting**: every monetised action leaves a `platform_revenue` row; UI shows the
  fee/preview; no fabricated balances; 401/403 honoured for non-admins touching admin APIs.

## 3. Execution model
- One agent per persona (parallel). Each agent:
  1. Creates its account via `POST /api/v1/users/register` (or uses seeded creds).
  2. Obtains a JWT (`POST /api/v1/auth/login`) and sets it in the client/header.
  3. Walks its checklist using the real API (or the web/mobile UIs + the mock gateway).
  4. Saves evidence: `testing/agent-pretest/reports/<persona>.md` + referenced screenshots.
- The `admin` agent runs **last**, after the others have generated revenue, then asserts
  the profit ledger reflects their activity (closes the loop on brokerage correctness).

## 4. Report template (each agent writes this)
```markdown
# Pretest report — <persona>
- date: 2026-07-09
- backend: docker | mock
- account: <id/email>, role: <ROLE>

## Results
| Feature | Status | Note | Screenshot |
|---------|--------|------|------------|
| wallet.convert (deposit) | pass | fee_mrc=2.5 @2.5% | wallet.png |
| ads.create (budget 100) | pass | fee_coins=10, deliverable=90 | ads.png |
| ... | ... | ... | ... |

## Brokerage assertions
- coin fee observed: 0.025 (expected 0.025) ✅
- ads fee observed: 10.0 on budget 100 (expected 10.0) ✅
- platform revenue after run: MRC=<x> EGP=<y>

## Blockers / bugs
- <description, severity, repro steps>

## Verdict: GREEN | AMBER | RED
```

## 5. Aggregate
A meta-agent (or `testing/agent-pretest/aggregate.mjs`) merges the per-persona reports
into `testing/agent-pretest/SUMMARY.md` with an overall verdict:
`GREEN` (all pass) → safe for human alpha; `AMBER` (minor) → conditional; `RED` → block.

## 6. Running today (Docker blocked)
Until the container stack is up, agents run the **mock** variant:
- Web: `testing/web/smoke-test.mjs` (Puppeteer + in-process mock gateway) — already
  exercises Wallet/Ads/Payments/Revenue UI with realistic data and screenshots.
- Mobile: `testing/mobile/run_emulator.ps1 -MockAuth` — drives the four screens on an
  emulator; renders UI shells/offline states.
- Backend brokerage logic: `cd backend/<svc> && python -m pytest tests -q` (green) plus
  the dedicated fee assertions in `test_wallet.py` / `test_ads.py`.
The mock variant validates UI + logic wiring; the Docker variant re-runs the same
checklist against the real PostgreSQL-backed services for true end-to-end proof.
