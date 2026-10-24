#!/usr/bin/env bash
# Upload the static landing page (served by an R2 bucket custom domain).
# Usage: ./upload-to-r2.sh <bucket-name>
# Requires: npm i -g wrangler && wrangler login
set -euo pipefail
cd "$(dirname "$0")"
B="${1:?bucket name required}"
WR="${WRANGLER:-npx wrangler}"
put(){ $WR r2 object put "$B/$1" --file "$1" --content-type "$2" --cache-control "$3" --remote; }
put index.html  "text/html; charset=utf-8" "public, max-age=300"
put admin.html  "text/html; charset=utf-8" "public, max-age=300"
put favicon.ico "image/x-icon" "public, max-age=86400"
for f in assets/*.png; do put "$f" "image/png" "public, max-age=31536000, immutable"; done
echo "Done. Remember: purge the Cloudflare cache for the domain after changing files."
