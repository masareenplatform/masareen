# MASAREN — Agent Handoff (session 2026-07-13)

Continuation of `AGENT_HANDOFF_2026-07-12.md` / `agenthandoff.txt`. This session:
(1) created & fixed `statusreportprealpha.tex`, (2) fixed audit findings **B** and **C**,
(3) added **Stage 5** web feed polish (loading/empty states), (4) implemented **mobile
WebSocket consumption** (live feed), and (5) brought up the WS hub + web dev server and
**verified the full realtime chain end-to-end**.

Env: Windows, repo at `C:\Users\sherifrashwan\Downloads\MASAREN-FINAL\MASAREN`.
Backend venv `backend\.venv`, Flutter `C:\flutter\flutter\bin`, adb `C:\platform-tools\adb.exe`,
Node v26, emulator `emulator-5554`.

---

## 0. ⚠️ FIRST THING ON RESUME — verify the backend is up

I ran `backend\run_combined.ps1` at the very end to load the finding-B fix. It **kills the old
monolith and starts a fresh one**; the built-in 6 s health check reported "Unable to connect"
(monolith needs longer to import 36 services + Postgres). **I did not get to confirm it came
back up.** Check immediately:

```powershell
Invoke-WebRequest http://localhost:8080/health -UseBasicParsing | Select -Expand Content
# expect status:"healthy", 36 services (ms_bff absent is normal)
Get-Content backend\combined_run.log -Tail 30      # if down, read this + combined_run.err
```

If down, restart: `powershell -NoProfile -ExecutionPolicy Bypass -File backend\run_combined.ps1`
then wait ~20–30 s and re-check `/health`. Required env is set inside that script
(DATABASE_URL=Postgres, JWT_SECRET=`masaren-alpha-change-me`). Docker (postgres/redis/kafka/
zookeeper) was already up this session.

---

## 1. What is RUNNING (started this session)

| Service | Port | How started | Notes |
|---|---|---|---|
| Combined monolith | 8080 | `backend\run_combined.ps1` | **VERIFY (see §0).** JWT_SECRET=`masaren-alpha-change-me` |
| Realtime WS hub | 8787 | `node ws-server.mjs` (bg, cwd=repo root) | healthy; logs `%TEMP%\opencode\ws.log`/`ws.err` |
| Web dev server | 3000 | `npm run dev` in `apps\web` (bg) | HTTP 200; `/api`→8080 proxy; logs `%TEMP%\opencode\web.log` |
| Emulator | — | already running | `emulator-5554` |
| Docker infra | — | already up | postgres, redis, kafka, zookeeper |

Restart the hub / web if the machine rebooted:
```powershell
Start-Process node -ArgumentList "ws-server.mjs" -WorkingDirectory <repo> -WindowStyle Hidden
Start-Process npm.cmd -ArgumentList "run","dev" -WorkingDirectory <repo>\apps\web -WindowStyle Hidden
```
E2E login creds (unchanged, still valid this session): `admin@masaren.org` / `Masaren@1234`.

---

## 2. Code changes this session (all verified — see §3)

### A. Audit finding B — `create_post` crash on missing JWT email  (FIXED)
`backend/social/posts-service/src/service.py` `create_post()`: replaced
`token.email.split(...)` with an `identity = token.email or token.sub or "user"` guard so a JWT
without an `email` claim no longer raises AttributeError/500.

### B. Audit finding C — stale "no backend /posts" comments  (FIXED)
- `apps/web/src/services/postService.ts` — rewrote the file header + bookmarks comment to
  describe the live social-service (was "backend does not yet expose /posts").
- `apps/mobile/lib/features/feed/bookmark_store.dart` — removed the **duplicated** stale
  doc-comment block; now describes the server-synced bookmark.

### C. Stage 5 polish — web feed loading & empty states  (DONE)
- `apps/web/src/pages/FeedPage.tsx` — `posts` state is now `Post[] | null`: `null` shows a
  3-card `PostSkeleton` shimmer (new component in same file, `aria-busy`+sr-only label);
  `[]` shows a **filter-specific** empty message (Saved vs general).
- `apps/web/src/i18n.tsx` — added `feed.emptySaved` in EN + AR.

### D. Mobile WebSocket consumption — live feed  (DONE, the main new feature)
- **NEW** `apps/mobile/lib/services/realtime_service.dart` — zero-dependency WS client using
  `dart:io` `WebSocket` (no new pubspec dep). Connects to `WS_URL`
  (default `ws://10.0.2.2:8787` = emulator→host hub), parses `{topic,payload}`, exposes a
  broadcast `Stream<RealtimeEvent>`, auto-reconnects (2.5 s), best-effort (never throws).
  Exports `RealtimeTopics` (`post:new/react/comment/saved`) + singleton `realtimeService`.
- `apps/mobile/lib/features/feed/feed_store.dart` — extracted `_mapPost()` (shared by initial
  load + live merge), added `_ensureRealtime()` (subscribes on `load()`), `applyRemote()`
  (id-deduped merge of post:new/react/comment), and now **publishes** react/new to the hub from
  `toggleLike`/`addPost`. Added `dispose()`. Mapping also sets `timestamp` from `createdAt`.

> Not done yet: mobile does not yet consume `post:saved`, messages, or notifications over WS —
> only the feed. That's the obvious next extension of `realtime_service.dart`.

### E. `statusreportprealpha.tex` (repo root) — created + made compile-clean
Matches the format of the (git-history) `statusreport*.tex`. Fixed the errors captured in
`statusreporterrors.txt` (unescaped `_` in a tabularx cell → `\_`; `~`→`\textasciitilde{}`).
Validated: 4/4 tabularx rows have 3 cols, braces 217/217, envs balanced. **No local TeX engine**
(no pdflatex/tectonic) so it was not actually compiled here — compile on a TeX box to confirm.

---

## 3. Verification done this session (all GREEN)

- **Finding B**: in-process test (import via importlib, in-mem SQLite) — no-email + with-email
  cases both create OK (`name='User'`/`'Alice'`). PASS.
- **Web**: `apps\web> node_modules\.bin\tsc.cmd --noEmit` → exit 0; `vitest run` → **9/9 pass**.
- **Mobile**: `flutter analyze` on the two changed files → **No issues**. Full-project analyze:
  only pre-existing `info` hints + **one pre-existing `warning`** (`feed_screen.dart:505`
  `_CommentSheet` unused `key` — NOT mine, from prior session's uncommitted work). My two files
  are clean.
- **Live realtime E2E** (`%TEMP%\opencode\rt_e2e.mjs`, re-runnable with `node`): WS client +
  login + create/like/comment via the live :8080 API → hub relays `post:new`, `post:react`,
  `post:comment` — **RESULT: PASS**. This validates the exact wire protocol the new Dart client
  parses, and the web app (now on :3000 with `VITE_WS_URL`) receives live updates.

Helper scripts live in `%TEMP%\opencode\` (`test_finding_b.py`, `rt_e2e.mjs`) — outside the
repo, safe to delete/re-run.

---

## 4. Pending / next steps (priority order)

1. **CONFIRM BACKEND HEALTHY** (§0). If it didn't come back, restart + tail the log.
2. **Rebuild + install the mobile APK** to get the WS feed + finding-C/onboarding fixes on the
   emulator, then watch it live:
   ```powershell
   cd apps\mobile; flutter build apk   # STOP emulator first if Gradle OOMs (16 GB box)
   adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-release.apk
   ```
   Then verify: open the feed on the emulator and run `node %TEMP%\opencode\rt_e2e.mjs` (or
   create a post from the web at :3000) → the new post/like should appear on the phone live.
3. **Verify onboarding image fix on device** (carried over from prior session — code fixed, not
   yet visually confirmed).
4. **Full mobile e2e audit**: `run_e2e_audit.ps1` (needs `maestro` — it's at
   `C:\Users\sherifrashwan\AppData\Local\maestro-cli\maestro\bin`, NOT on PATH). Run single
   flows via `maestro test testing/mobile/maestro/<flow>.yaml --device emulator-5554`.
5. **Stage 5 remainder**: RTL (Arabic) QA, accessibility pass, mobile empty/loading states
   (web done this session).
6. **Audit finding D** (client/server post-id desync) still open — reconcile local `p_…`/`local_…`
   ids with server ids after sync. Findings A (doc) & E (unauth github MCP) are env/doc only.
7. Extend mobile WS to `post:saved`, messages, notifications (see §2D note).
8. Compile `statusreportprealpha.tex` on a TeX box to confirm it's clean.

---

## 5. Uncommitted tree note

Branch `master`; the working tree already had ~hundreds of uncommitted changes from prior
sessions (mobile glass redesign, etc.) BEFORE this session. My edits above are on top of that.
Nothing committed this session. Recommend reviewing `git status` / committing a clean baseline
before large new work. Do NOT rename `social/posts-service` (hyphen) — the combined monolith
expects that path for `ms_posts`.
