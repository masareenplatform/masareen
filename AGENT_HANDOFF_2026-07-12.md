# MASAREN — Agent Handoff (this session: 2026-07-12)

Continuation of `agenthandoff.txt`. This session focused on **Stage 4 (real-time)** completion,
a **full audit**, standing up the **combined monolith** as the test backend, and a first pass at
the **onboarding image bug**. Environment: Windows, Flutter at `C:\flutter`, Maestro at
`C:\Users\sherifrashwan\AppData\Local\maestro-cli\maestro\bin`, emulator `emulator-5554` (device
name `pixel_6`), Postgres + Redis running locally.

---

## 1. What is RUNNING / how to (re)start

### Combined monolith backend — `http://0.0.0.0:8080`
**This is the backend under test (the user chose the monolith over the per-service gateway).**
Single command to (re)start cleanly with logs:

```
cd backend
powershell -NoProfile -ExecutionPolicy Bypass -File run_combined.ps1
```

- Kills any existing `combined.main` processes, then starts ONE instance via the venv.
- **Critical env:** `DATABASE_URL=postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren`.
  Do NOT omit it — without Postgres, services using Postgres-only `ARRAY` columns (e.g.
  `organizations.member_ids`) crash SQLAlchemy's `create_all` on SQLite and **startup aborts**
  (`CompileError: can't render element of type ARRAY`). Postgres is up locally, so use it.
- Logs: `backend/combined_run.log` (and `combined_run.err`). Tail with
  `Get-Content backend\combined_run.log -Wait`. Health: `GET /health` → `status:"healthy"`,
  `services_included` = 36/37 (only `ms_bff` fails — no `ms_bff.src` module; harmless).
- Verified live: `GET /api/v1/posts` returns seeded posts; `POST /api/v1/auth/login` works.

### Realtime WebSocket hub — `ws-server.mjs` (Stage 4)
Zero-dependency Node broadcast hub. Run with `node ws-server.mjs` (port 8787). Relays
`{topic,payload}` to all *other* clients; `POST /publish {topic,payload}` injects from backend;
`/health` for monitoring. The social-service now pushes `post:new`/`post:react`/`post:comment`/
`post:saved` to it via `REALTIME_HUB_URL` (default `http://localhost:8787`). Set
`REALTIME_HUB_URL` in the combined env if you want live fan-out end-to-end.

---

## 2. E2E credentials (IMPORTANT — was a blocker)

The mobile Maestro flows (`testing/mobile/maestro/login.yaml`) log in as `admin@masaren.org`.
That user did **not** exist and the current auth policy rejects the old password:
- Password must be ≥8 chars with upper+lower+digit+special.
- New accounts are `PENDING_VERIFICATION` and cannot log in until verified.

Fixes applied this session:
- Registered `admin@masaren.org` / **`Masaren@1234`** and set its row
  `status='ACTIVE', email_verified=true` in Postgres (`users` table).
- Updated `testing/mobile/maestro/login.yaml` password to `Masaren@1234`.
Login now returns a valid JWT. (If the DB is ever wiped, re-run the register + DB status flip.)

---

## 3. Stage 4 — Real-time (DONE)
- `ws-server.mjs` implemented + verified (broadcast-to-others, no echo, REST inject, health, ping/pong).
- Web `VITE_WS_URL` wired (`.env.example`, web `Dockerfile`, compose `realtime` service).
- Web `postService.applyRemote` merges remote `POST_NEW/REACT/COMMENT` into the store (id-deduped).
- Backend `social/posts-service/src/service.py` + `api/__init__.py`: `publish_event()` + `asyncio.create_task`
  in create/like/comment/save handlers → server-side fan-out (so mobile/API-created posts go live too).
- `tsc` clean; 9/9 web vitest pass.
- Integration test `hub_integration.mjs` proves the chain (social POST → hub → WS client receives
  `post:new`/`post:react`/`post:comment`). NOTE: the venv path in that test was wrong
  (`backend/.venv`, not repo-root `.venv`) — fix before relying on it.

---

## 4. Onboarding first-screen image bug (PARTIAL — code fixed, NOT yet verified on device)
**Symptom reported:** the 1st onboarding screen images "are not shown correctly."
**Diagnosis:** asset files exist (`assets/images/avatars/p1..p10.jpg`, `masaren_logo_white_256.png`)
and are declared in `pubspec.yaml` (`assets/images/`). `adb logcat` while on the onboarding screen
showed **no asset-load errors**, so the images load — the issue is layout/robustness in
`_HeroVisual` (raw `GridView.count` in a `SizedBox`, no `shrinkWrap`/`childAspectRatio`/`errorBuilder`).
**Fix applied** in `apps/mobile/lib/features/onboarding/screens/onboarding_screen.dart`:
square `childAspectRatio:1`, `shrinkWrap:true`, `primary:false`, and `errorBuilder` placeholders on
both images (so a missing asset shows a person/eco icon instead of blank).
**Still needed:** `flutter build apk` + `adb install` (or `flutter run`) to put the fix on the
emulator and confirm visually. The model here cannot read images, so visual confirmation is pending.

---

## 5. Audit (full) — see `AUDIT_REPORT.md`
Stages 1–3 verified working end-to-end (live TestClient on social-service + combined; web tsc + 9/9
vitest; mobile wiring contract-consistent). Findings A–E documented (handoff import path broken,
`create_post` email-None crash, stale comments, client/server id desync). `github-gateway-sync` MCP
is unauthenticated here, so issues weren't auto-filed.

---

## 6. Pending / next steps for the next agent
1. **Verify onboarding fix on emulator:** `cd apps/mobile; flutter build apk; adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk`, then re-run `audit_splash_onboarding.yaml` (or screenshot).
2. **Run the full e2e audit:** `powershell -NoProfile -ExecutionPolicy Bypass -File run_e2e_audit.ps1` (ensure combined monolith + emulator up; ~15–30 min for 14 flows). NOTE: the script buffers output until done — run it with `*> e2e_run.log` and read the log, or run single flows directly via `maestro test testing/mobile/maestro/<flow>.yaml --device emulator-5554`.
3. **Stage 5 polish:** empty/loading states, RTL QA (Arabic ل مسارين), a11y, e2e.
4. **Mobile WS consumption:** `bookmark_store`/`api_service` are local-only; optionally subscribe the app to the hub for cross-user live updates.
5. **Live fan-out E2E:** start `ws-server.mjs` and set `REALTIME_HUB_URL` on the combined process, then confirm a post created via one client appears on another.

## 7. Quick command reference (user's "working cmd")
```
# backend (combined monolith) restart + watch
cd backend; powershell -NoProfile -ExecutionPolicy Bypass -File run_combined.ps1
Get-Content backend\combined_run.log -Wait

# realtime hub
node ws-server.mjs        # :8787

# mobile e2e single flow
$env:JAVA_HOME="C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
$env:PATH="C:\Users\sherifrashwan\AppData\Local\maestro-cli\maestro\bin;$env:PATH"
maestro test testing/mobile/maestro/audit_feed_reactions.yaml --device emulator-5554

# rebuild + install mobile to verify onboarding fix
cd apps/mobile; flutter build apk; adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
```
