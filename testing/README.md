# MASAREN, Simulation & Pretest Scheme

Offline, reproducible verification of the Web + Mobile clients and the brokerage
monetisation logic, independent of the (currently broken) Docker runtime. Three layers:

```
testing/
├── README.md                      # this file
├── web/                           # Layer 1, Web UI smoke + screenshots + perf
│   ├── package.json
│   ├── smoke-test.mjs             # Puppeteer + in-process mock gateway
│   ├── screenshots/               # generated PNGs
│   └── report.json                # per-route load/DOM metrics
├── mobile/                        # Layer 2, Emulator integration test
│   ├── README.md
│   ├── integration_test/app_test.dart
│   ├── testing_driver.dart        # screenshot harness for flutter drive
│   └── run_emulator.ps1           # boot AVD + run tests + screenshots
└── agent-pretest/                 # Layer 3, AI-agent pre-alpha pass
    └── ACCOUNT_MATRIX.md          # personas, checklist, report template, aggregate
```

## Layer 1, Web (Puppeteer + mock gateway)
Renders the real built web app (`apps/web/dist`) against an in-process **mock gateway**
so every new page shows realistic data with no backend. Captures screenshots and
records per-route performance (load ms, DOM nodes, layout/style recalcs, JS heap).

```powershell
cd apps/web && npm run build          # ensure dist/ exists
cd testing/web && npm install && node smoke-test.mjs
```
Outputs: `testing/web/screenshots/{dashboard,wallet,ads,payments,revenue}.png`
and `testing/web/report.json`.

## Layer 2, Mobile (emulator)
Drives the four new screens on an Android emulator; asserts they render and captures
PNGs. Offline mode (`-MockAuth`) seeds a session so the drawer + screens are reachable
without a backend.

```powershell
cd testing/mobile && .\run_emulator.ps1 -MockAuth
```

## Layer 3, Agent pretest (pre-alpha gate)
Different AI-agent personas (volunteer / organisation / advertiser / admin / field
agent) create accounts, walk a feature checklist, and assert the brokerage fee is
correctly applied at every monetised action. See `agent-pretest/ACCOUNT_MATRIX.md`
for the matrix, report template, and aggregate verdict (GREEN/AMBER/RED).

## When Docker is fixed
Re-run Layer 1 with `VITE_API_BASE` / proxy pointed at the live gateway, and Layer 2/3
without `-MockAuth`, to convert the mock validation into true end-to-end proof against
PostgreSQL-backed services. The checklists are identical, only the data source changes.
