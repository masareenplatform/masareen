#!/usr/bin/env bash
# Starts the MASAREEN live origin on macOS/Linux.
# mediaMTX -> looping TV videos -> Cloudflare tunnel -> https://masareen.com/live/tv
set -euo pipefail
cd "$(dirname "$0")"

LOG="$PWD/live-supervisor.log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" | tee -a "$LOG"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing $1. Install it first (mediaMTX, cloudflared, ffmpeg)." >&2
    exit 1
  }
}

need ffmpeg
need cloudflared
[[ -x ./mediamtx ]] || [[ -x ./mediamtx.exe ]] || {
  echo "mediamtx binary is missing in $PWD" >&2
  exit 1
}
[[ -f ./mediamtx.yml ]] || {
  echo "mediamtx.yml is missing in $PWD" >&2
  exit 1
}

TOKEN_FILE="$HOME/.cloudflared/masareen-media-token.txt"
TOKEN="${MASAREEN_TUNNEL_TOKEN:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
fi

start_mediamtx() {
  if pgrep -x mediamtx >/dev/null 2>&1; then return; fi
  log "starting mediaMTX"
  ./mediamtx >>mediamtx-out.log 2>>mediamtx-err.log &
  sleep 2
}

start_tunnel() {
  if pgrep -f "cloudflared.*tunnel.*run" >/dev/null 2>&1; then return; fi
  if [[ -n "$TOKEN" ]]; then
    log "starting Cloudflare media tunnel (token)"
    cloudflared tunnel --no-autoupdate run --token "$TOKEN" \
      >>cloudflared-media-out.log 2>>cloudflared-media-err.log &
  elif [[ -n "${MASAREEN_TUNNEL_ID:-}" ]]; then
    log "starting Cloudflare media tunnel ($MASAREEN_TUNNEL_ID)"
    cloudflared tunnel --no-autoupdate run "$MASAREEN_TUNNEL_ID" \
      >>cloudflared-media-out.log 2>>cloudflared-media-err.log &
  else
    echo "No media tunnel token. Save it to $TOKEN_FILE or set MASAREEN_TUNNEL_TOKEN." >&2
    exit 1
  fi
  sleep 5
}

start_broadcast() {
  if pgrep -f "ffmpeg.*tv-playlist.txt" >/dev/null 2>&1; then return; fi
  mkdir -p tv
  shopt -s nullglob
  FILES=(tv/*.mp4 tv/*.mkv tv/*.mov tv/*.m4v tv/*.webm)
  shopt -u nullglob
  if [[ ${#FILES[@]} -eq 0 ]]; then
    log "no TV videos in $PWD/tv; add licensed files to go live"
    return
  fi
  : >tv-playlist.txt
  for f in "${FILES[@]}"; do
    printf "file '%s'\n" "$PWD/$f" >>tv-playlist.txt
  done
  log "starting TV broadcast loop (${#FILES[@]} file(s))"
  ffmpeg -re -stream_loop -1 -f concat -safe 0 -i tv-playlist.txt \
    -vf "scale='min(1280,iw)':-2" \
    -c:v h264_videotoolbox -b:v 2800k -maxrate 3500k -bufsize 5600k -g 120 \
    -c:a aac -b:a 128k -ar 48000 \
    -f flv "rtmp://127.0.0.1:1935/live/tv?user=masareen&pass=masareen-live-2026" \
    >>ffmpeg-tv.log 2>&1 &
  sleep 4
}

check_live() {
  curl -fsS --max-time 6 http://127.0.0.1:8888/live/tv/index.m3u8 >/dev/null &&
    curl -fsS --max-time 12 https://masareen.com/live/tv/index.m3u8 >/dev/null
}

ensure_live() {
  start_mediamtx
  start_tunnel
  start_broadcast
  for _ in {1..8}; do
    sleep 3
    if check_live; then
      log "LIVE OK  https://masareen.com/live/tv/index.m3u8"
      return 0
    fi
  done
  log "LIVE CHECK FAILED"
  return 1
}

log "MASAREEN live supervisor started"
ensure_live || exit 1

if [[ "${1:-}" == "--watch" ]]; then
  while true; do
    sleep 45
    if ! check_live; then
      log "live check failed; repairing"
      ensure_live || true
    fi
  done
fi
