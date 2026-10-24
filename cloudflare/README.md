# MASAREEN on Cloudflare (free tier)

The **landing page lives in an R2 bucket** (custom domain, e.g. `masareen.com`) and the **API is this Worker** (`/api/*`) with **D1** (SQLite) as the database. Everything fits the Cloudflare free plan: R2 storage/egress, Workers 100k requests/day, D1 5M row reads/day.

| Piece | Where |
|---|---|
| API + auth | `cloudflare/src/index.js` |
| Database schema | `cloudflare/schema.sql` (tables: `users`, `login_events`, `contact_messages`) |
| Upgrade existing DB | `cloudflare/migrations/001-profile-fields.sql` |
| Landing page + sign-up | `landing/index.html` → uploaded to R2 |
| CEO dashboard | `landing/admin.html` → uploaded to R2 |
| Tests (11, run offline) | `cloudflare/test/worker.test.mjs` |

## 1. Put the landing page on R2

```bash
cd landing
./upload-to-r2.sh my-bucket          # macOS/Linux
```
On Windows use `.\upload-to-r2.ps1 my-bucket` instead. Both upload `index.html`, `admin.html`, `favicon.ico` and `assets/*.png`.

Then in **R2 > bucket > Settings > Custom Domains** add `masareen.com` (and `www`). If the root does not serve `index.html`, add a Cloudflare **Transform Rule** (Rewrite URL): when path equals `/`, rewrite to `/index.html`. Purge the cache after each upload.

## 2. Wire the API Worker to that domain

Two supported options. Pick one.

**A. Same domain (recommended, no CORS):** add a Worker route so only `/api/*` goes to the Worker while R2 serves the rest. Uncomment in `wrangler.toml`:

```toml
routes = [
  { pattern = "masareen.com/api/*", zone_name = "masareen.com" },
  { pattern = "www.masareen.com/api/*", zone_name = "masareen.com" },
]
```

Leave `window.MASAREEN_API_BASE` empty in `index.html` / `admin.html` (the default), so requests go to the same origin.

**B. Separate host:** give the Worker a free custom domain (`api.masareen.com`) and uncomment:

```toml
routes = [{ pattern = "api.masareen.com", custom_domain = true }]
```

Then set in **both** `landing/index.html` and `landing/admin.html`:

```html
<script>window.MASAREEN_API_BASE = "https://api.masareen.com";</script>
```

and in `wrangler.toml`:

```toml
ALLOWED_ORIGINS = "https://masareen.com,https://www.masareen.com"
COOKIE_DOMAIN = ".masareen.com"   # optional, shares the session across subdomains
```

The Worker sends CORS headers only to `ALLOWED_ORIGINS` (defaults: `masareen.com`, `www`, localhost), handles `OPTIONS` preflight, and switches the session cookie to `SameSite=None; Secure` for cross-origin calls.

## 3. One-time setup (about 10 minutes)

> **Windows shortcut:** run `.\setup.ps1` from this folder. It logs in, creates the D1 database, writes its id into `wrangler.toml`, applies the schema, generates `SESSION_SECRET`, deploys the Worker, and can create the R2 bucket and upload the landing page. The manual steps below are the same thing.
>
> **macOS/Linux shortcut:** run the equivalent commands below.

1. **Google client ID** — already configured in `wrangler.toml` from the `masareen` Google Cloud project (`336070303963-cksadpqp8d591afvir53vsb86fl41cqj.apps.googleusercontent.com`). Its Authorized JavaScript origin is `https://masareen.com`. If you test locally, add `http://localhost:8787` to *Authorized JavaScript origins* in Google Cloud Console. The OAuth **client secret is not used** by this Worker (Google ID tokens are verified with the public client ID), so it is not stored in the repo or in Wrangler.
2. **Install and log in**
   ```bash
   cd cloudflare && npm install && npx wrangler login
   ```
3. **Create the database**
   ```bash
   npx wrangler d1 create masareen    # copy the database_id into wrangler.toml
   npm run db:init                    # fresh database: creates all tables/columns
   ```
   Upgrading a database created before the role-aware sign-up? Run once:
   ```bash
   npm run db:migrate                 # ALTER TABLE ... (safe "duplicate column" errors mean it is already applied)
   ```
4. **Configure** `wrangler.toml`: set `ADMIN_EMAILS` to the Google accounts allowed into the dashboard. The Google client ID and the same-domain `/api/*` routes are already filled in. Then the signing secret:
   ```bash
   npx wrangler secret put SESSION_SECRET   # paste a long random string
   ```
5. **Deploy**: `npm run deploy`. Confirm `https://masareen.com/api/health` responds. The CEO opens `/admin.html` and signs in with an allowed Google account.

## Sign-up flow

The form adapts to **who the person is**:

| Role | Extra fields |
|---|---|
| Student | university, **university ID**, faculty/department, academic year, degree level |
| Academic / researcher | university, academic title, department (optional) |
| Organization / institution | organization, organization type, role there |
| Professional | employer, job title, department (optional) |
| Volunteer / individual | city, field of interest |
| Journalist / media | outlet/employer, role |
| Donor / international partner | organization, organization type, role there |
| Other | how they want to be involved |

**Design choice:** for Google sign-in the account is created first and these details are asked in the "one last step" after login (`/api/profile`). That keeps the first click minimal and lets people finish later; an incomplete profile is visible in the dashboard. Email-only registrations collect the same fields in one go, because they are stored as unverified leads (no password login yet).

The Worker validates the required fields per role server-side, so the API cannot be bypassed.

## What gets recorded
- **Sign-up with Google**: verified email, name, photo, signup date, country (from Cloudflare), then the role-aware profile + consent.
- **Sign-up with email**: same fields, marked *unverified*.
- **Every login**: time, method, country, a salted hash of the IP (not the IP itself), browser string.
- **Contact form messages**.

## Security notes
- Google ID tokens are verified in the Worker (RS256 signature, issuer, audience, expiry, verified email).
- Sessions are signed HttpOnly cookies (14 days). Admin access is limited to `ADMIN_EMAILS` with a verified Google email.
- Cross-site POSTs are rejected unless the origin is in `ALLOWED_ORIGINS`; honeypot fields and per-IP rate limits protect the forms; CSV export neutralises spreadsheet formulas.
- Users can ask to be deleted: run `npx wrangler d1 execute masareen --remote --command "DELETE FROM users WHERE email='x@y.com'"`.

## Local test

```bash
cd cloudflare
npm test            # 11 offline API tests against an in-memory SQLite stand-in for D1
npx wrangler d1 execute masareen --local --file=schema.sql
npx wrangler dev    # real Worker at http://localhost:8787 (API only, unless you enable [assets])
```

For `wrangler dev`, create `cloudflare/.dev.vars` with a local signing secret (it is gitignored):

```ini
SESSION_SECRET=local-dev-only-change-me
```

`test/local-server.mjs` serves `../landing` plus the API from Node for a full-stack browser check. Google sign-in locally also requires `http://localhost:8787` in the Google client's *Authorized JavaScript origins*.

## Mobile app

The Flutter app still talks to its own backend (`apps/mobile`, see root README). To use this Worker instead, point it at these `/api/auth/*` routes and send the session cookie with requests.
