# MASAREEN landing page (masareen.com)

Static site: `index.html` + `admin.html` + `assets/` + `favicon.ico`. No build step.
It is hosted in an **R2 bucket** (custom domain). The sign-up, login tracking and contact form call the **API Worker** in `../cloudflare`.

## Deploy to R2

1. Upload the files — sets the correct Content-Type and cache headers and uploads `index.html`, `admin.html`, `favicon.ico` and `assets/*.png`:
   - Windows: `.\upload-to-r2.ps1 <bucket>`
   - macOS/Linux: `./upload-to-r2.sh <bucket>`
2. **R2 > bucket > Settings > Custom Domains** > add `masareen.com` (and `www`). The Google client is authorized for `https://masareen.com` only, so either keep `www` redirecting to the apex domain or add `https://www.masareen.com` to *Authorized JavaScript origins* in Google Cloud Console.
3. If `/` does not serve `index.html`, add a Cloudflare **Transform Rule** (Rewrite URL, path): when URI Path equals `/` → rewrite to `/index.html`.
4. Purge the cache for the domain after changing files.

## Connecting the API

The pages call `/api/*` on the same origin by default. That works when the Worker is routed at `masareen.com/api/*` (recommended; see `../cloudflare/wrangler.toml`).

If the Worker is on another host, set the API base in **both** HTML files, in the `<head>`:

```html
<script>window.MASAREEN_API_BASE = "https://api.masareen.com";</script>
```

The Worker must list `https://masareen.com` in `ALLOWED_ORIGINS` and serve CORS with credentials.

## Sign-up form

`index.html` asks **who you are** first and then shows only the fields that fit:

- Student → university, university ID, department, academic year, degree level
- Academic / researcher → university, academic title, department (optional)
- Organization / institution → organization, type, role there
- Professional → employer, job title, department (optional)
- Volunteer / individual → city, field of interest
- Journalist / media → outlet, role
- Donor / international partner → organization, type, role there
- Other → how they want to be involved

Google sign-in creates the account first, then asks these details in the final step (so people can finish later). Email registration asks everything at once because it is stored as an unverified lead (no password login yet).

## v2 notes
- Logos (header, hero, footer) are embedded inside `index.html` as base64, so they can never fail to load. Favicon/OG images still come from `/assets/`.
- Contact form falls back to `mailto:` if the API is unreachable.
- Arabic text is a machine-assisted translation; have a native reviewer check it.
- Stats on the page are sourced (World Bank, DataReportal, UN); personas are labeled illustrative.
