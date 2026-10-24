# MASAREN, Agent Handoff (continuation, session 2026-07-13, part 2)

Continuation of `AGENT_HANDOFF_2026-07-13.md`. This session focused on making
**alpha registration actually work end-to-end** (the prior blocker: new accounts were
`PENDING_VERIFICATION` and could not log in) and confirming **Flutter + web both
run against the combined backend**.

Env unchanged from prior handoff. Backend venv `backend\.venv`, Flutter
`C:\flutter\flutter\bin`, adb `C:\platform-tools\adb.exe` (fallback
`C:\Users\sherifrashwan\scoop\apps\scrcpy\4.0\adb.exe`), Node v26.

---

## 1. Root-cause of "registration doesn't let people in (alpha)"

`backend/identity/identity-service/src/domain/user.py` `User.register()` creates the
user with `status=PENDING_VERIFICATION`. Login (`authentication-service`) rejects any
non-`ACTIVE` user (`LoginHandler.handle` → `if not user.is_active`). So a freshly
registered person could never sign in. Prior sessions worked around it by manually
flipping `admin@masaren.org` to `ACTIVE` in Postgres.

## 2. Fixes applied this session

### A. Alpha auto-verify on registration  (the core fix)
- `backend/identity/identity-service/config/settings.py`, added
  `auto_verify_on_register: bool = False`.
- `backend/identity/identity-service/src/application/handlers.py`
  `RegisterUserHandler.handle()`, when `settings.auto_verify_on_register` is true,
  calls `user.verify_email()` (sets `email_verified=True`, `status=ACTIVE`) and
  returns `auto_verified: true` + a message telling the user they can sign in now.
- `backend/identity/identity-service/src/api/schemas.py`
  `RegisterUserResponse`, added `auto_verified: bool`.
- Gated by env so production keeps the email-verification flow.
  - `backend/run_combined.ps1`, sets `$env:AUTO_VERIFY_ON_REGISTER = "true"`.
  - `docker-compose.yml`, added `AUTO_VERIFY_ON_REGISTER: "true"` to `x-common-env`.

### B. Registration now captures ALL needed info  (page was collecting fields it never sent)
- `backend/identity/identity-service/src/api/schemas.py` `RegisterUserRequest` -
  added optional `national_id`, `university_id`, and `audience`
  (validated against the 5 known audiences).
- `backend/identity/identity-service/src/application/commands.py`
  `RegisterUserCommand`, added the same three fields.
- `backend/identity/identity-service/src/api/users.py` `register_user()`, forwards
  them to the command.
- `backend/identity/identity-service/src/application/handlers.py`, forwards them to
  `User.register(...)` so they are persisted (national_id, university_id on the
  user record; audience on the profile).

### C. Web `RegisterPage.tsx`
- Sends **all** fields (full_name, email, password, phone, national_id,
  university_id, role, audience), previously only 5 were sent.
- Password field shows a live hint and blocks submit until it meets the backend regex
  (8+ chars, upper/lower/digit/special).
- Added a required Terms/consent checkbox.
- On success with `auto_verified`, it auto-logs the user in (calls `authService.login`
  then `useAuth().login`) and routes to `/dashboard`, no dead-end "verify your
  email" message.

### D. Mobile `lib/features/auth/screens/register_screen.dart`
- Sends all fields incl. `role`, `audience`, `national_id`, `university_id`
  (student-only), `phone`.
- Password validator matches the backend regex; consent checkbox required.
- On `auto_verified`, auto-logs in and routes to `/dashboard`.
- `flutter analyze` on the file: **No issues**. Full-project `flutter analyze`: 155
  items, all `info`/`warning` (deprecations, lint hints), **zero errors**.

### E. Gradle build fix (environmental)
`apps/mobile/android/gradle.properties` `org.gradle.jvmargs` was `-Xmx1024m`,
which OOM-crashed the daemon on this 16 GB box. Bumped to `-Xmx1700m` and
added `-XX:HeapBaseMinAddress=0x100000000` (fixes the Windows G1/CompressedOops
native-memory crash). The debug APK now builds.

## 3. Verification done (all GREEN)

- **Combined backend health**: `GET /health` → `status:"healthy"`,
  `services_included` = 36 (ms_bff absent is expected).
- **Full register → login → /users/me e2e against :8080** (live, via the same
  API the apps call):
  - register → `status:"ACTIVE"`, `auto_verified:true`.
  - login → valid `access_token` (279 chars), `user_id`, `role`.
  - `/users/me` (with that token) → returns the user incl. persisted `phone`.
- **Web**: `apps/web> tsc --noEmit` → exit 0; `vitest run` → **9/9 pass**.
  Dev server restarted on **:3000** (a stale vite held :3000; killed it, restarted).
  `GET /` → 200; `/api/v1/...` proxy to :8080 confirmed (401 w/o token as expected).
- **Flutter**: `flutter analyze` → **0 errors**. `flutter build apk --debug`
  succeeds → `apps/mobile/android/build/app/outputs/flutter-apk/app-debug.apk`
  (122 MB). NOTE: Flutter's CLI prints *"Gradle build failed to produce an .apk
  file"*, this is a **false negative**; Gradle actually emits the APK under
  `android/build/...` and Flutter's path check misses it. The APK exists and installs.
- **On-device**: emulator launched with AVD **`masaren_test`** (the prior
  `pixel_6` AVD would not boot; `masaren_test` does). Uninstalled the old
  release-signed `com.masaren.app` (signature mismatch) then
  `adb install -r app-debug.apk` → **Success**. Launched the app via monkey:
  logcat shows `com.masaren.app/.MainActivity RESUMED` with the Flutter engine
  active and **no FATAL/AndroidRuntime crash**. (curl isn't on the emulator, so
  reachability was proven from the host e2e instead.)

## 4. How to (re)start everything

```powershell
# Backend (combined monolith, :8080, alpha auto-verify ON)
cd backend; powershell -NoProfile -ExecutionPolicy Bypass -File run_combined.ps1
# expect: health: healthy  services_included=36

# Realtime WS hub (:8787), if you need live feed
node ws-server.mjs

# Web dev server (:3000)
cd apps/web; npm run dev

# Emulator (use the working AVD name)
C:\Android\Sdk\emulator\emulator.exe -avd masaren_test

# Mobile APK (already built); install + run
adb -s emulator-5554 install -r apps\mobile\build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell monkey -p com.masaren.app -c android.intent.category.LAUNCHER 1
```
E2E login creds still valid: `admin@masaren.org` / `Masaren@1234` (ACTIVE,
email_verified). New alpha registrations now self-verify and can log in immediately.

## 5. Pending / next steps
1. **On-device UI registration test** via Maestro (maestro at
   `C:\Users\sherifrashwan\AppData\Local\maestro-cli\maestro\bin`, not on PATH).
   NOTE: the registration UI changed (added consent checkbox + role/audience
   dropdowns), so existing `testing/mobile/maestro/*register*.yaml` flows will need
   updating to tick the consent box / pick the dropdowns before they pass.
2. **Visual confirm** of the new registration screens on web + emulator (model
   can't see rendered UI; logic + boot verified only).
3. **Audit finding D** (client/server post-id desync) still open.
4. **Stage 5** remainder: RTL (Arabic) QA, a11y, mobile empty/loading states.
5. The old `pixel_6` AVD no longer boots here, `masaren_test` is the working one.
6. Consider wiring a real email-verification path for post-alpha; the
   `auto_verify_on_register` flag is the single switch to flip off.

(End of file)
