# MASAREEN on Cloudflare (free tier)

One Worker serves the **landing page**, the **API** (`/api/*`) and the **CEO dashboard** (`/admin.html`). Registrations, logins and messages are stored in **D1** (SQLite). Everything here fits the Cloudflare free plan (Workers 100k requests/day, D1 5M row reads/day, static assets free).

| Piece | Where |
|---|---|
| API + auth | `src/index.js` |
| Database schema | `schema.sql` (tables: `users`, `login_events`, `contact_messages`) |
| Landing + sign-up window | `../landing/index.html` |
| CEO dashboard | `../landing/admin.html` |
| Tests (9, run offline) | `test/worker.test.mjs` |

## One-time setup (about 10 minutes)

1. **Google client ID** (free): Google Cloud Console > APIs & Services > Credentials > *Create credentials* > *OAuth client ID* > *Web application*. Under *Authorized JavaScript origins* add `https://masareen.com` (and `http://localhost:8787` for local tests). Copy the client ID.
2. **Install and log in**
   ```bash
   cd cloudflare && npm install && npx wrangler login
   ```
3. **Create the database**
   ```bash
   npx wrangler d1 create masareen          # copy the database_id it prints into wrangler.toml
   npm run db:init                          # creates the tables
   ```
4. **Configure**: in `wrangler.toml` set `GOOGLE_CLIENT_ID` and `ADMIN_EMAILS` (comma separated Google emails of the CEO and team). Then the signing secret:
   ```bash
   npx wrangler secret put SESSION_SECRET   # paste a long random string
   ```
5. **Deploy**: `npm run deploy`. Add the custom domain: uncomment `routes` in `wrangler.toml` (or Workers > masareen > Settings > Domains) so `masareen.com` points at the Worker.

The CEO opens `https://masareen.com/admin.html`, signs in with an allowed Google account, and sees: totals, sign-ups and logins for 30 days, who is registering (organization type, country), a searchable list of registrations, every login, contact messages, and a CSV download.

## What gets recorded
- **Sign-up with Google**: verified email, name, photo, signup date, country (from Cloudflare), then the profile step (organization, type, country, consent).
- **Sign-up with email**: same fields, marked *unverified*.
- **Every login**: time, method, country, a salted hash of the IP (not the IP itself), browser string.
- **Contact form messages**.

## Security notes
- Google ID tokens are verified in the Worker (RS256 signature, issuer, audience, expiry, verified email).
- Sessions are signed HttpOnly cookies (14 days). Admin access is limited to `ADMIN_EMAILS` with a verified Google email.
- Cross-site POSTs are rejected, honeypot fields and per-IP rate limits protect the forms, CSV export neutralises spreadsheet formulas.
- Users can ask to be deleted: run `npx wrangler d1 execute masareen --remote --command "DELETE FROM users WHERE email='x@y.com'"`.

## Local test
`npm test` runs the API tests against an in-memory SQLite stand-in for D1. `npx wrangler dev` runs the real Worker locally (needs `wrangler d1 execute masareen --local --file=schema.sql` once).

## Mobile app
The Flutter app still talks to its own backend (`apps/mobile`, see root README). The Worker here covers the website; connect the app later by pointing it at these `/api/auth/*` routes.
