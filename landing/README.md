> **Deploy note:** the landing page is now served by the Cloudflare Worker in `../cloudflare` (free), together with the sign-up API and the CEO dashboard at `/admin.html`. The R2 steps below still work for a static-only copy, but sign-up, login tracking and the contact form need the Worker. See `../cloudflare/README.md`.

# MASAREEN landing page (masareen.com)
Static site: index.html + assets/ + favicon.ico. No build step.

## Deploy to R2
1. ./upload-to-r2.sh <bucket>   (sets correct Content-Type, needed or the browser downloads index.html instead of rendering it)
2. R2 > bucket > Settings > Custom Domains > add masareen.com
3. R2 custom domains do not serve index.html at "/" by default. Add a Cloudflare
   Transform Rule (Rewrite URL, path): when URI Path equals "/" -> rewrite to static "/index.html".
4. After changing files, purge cache for masareen.com.

Contact email in the page: taskforce@masareen.com (change in index.html if different).

## v2 notes
- Logos (header, hero, footer) are embedded inside index.html as base64, so they can never fail to load. Favicon/OG images still come from /assets/.
- Contact form: by default it opens the visitor's email app (mailto). For real submissions, deploy a Cloudflare Worker/Form endpoint and add before the closing script tag: `<script>window.MASAREEN_FORM_ENDPOINT="https://your-worker.example/submit"</script>` (it receives JSON: name, email, org, type, message).
- Arabic text is a machine-assisted translation; have a native reviewer check it.
- Stats on the page are sourced (World Bank, DataReportal, UN); personas are labeled illustrative.
