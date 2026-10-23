#!/usr/bin/env bash
# Usage: ./upload-to-r2.sh <bucket-name>
# Requires: npm i -g wrangler && wrangler login
set -euo pipefail
B="${1:?bucket name required}"
put(){ wrangler r2 object put "$B/$1" --file "$1" --content-type "$2" --cache-control "$3" --remote; }
put index.html text/html\;\ charset=utf-8 "public, max-age=300"
put favicon.ico image/x-icon "public, max-age=86400"
for f in assets/*.png; do put "$f" image/png "public, max-age=31536000, immutable"; done
