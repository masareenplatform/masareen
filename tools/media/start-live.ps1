param(
  [switch]$Watch,
  [int]$IntervalSec = 30,
  [switch]$Restart
)

# Starts and supervises the MASAREEN live origin:
# mediaMTX -> ffmpeg TV loop -> Cloudflare tunnel -> https://masareen.com/live/tv
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$log = Join-Path $PSScriptRoot "live-supervisor.log"
function Log([string]$text) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $text"
  Add-Content -LiteralPath $log -Value $line -Encoding utf8
  Write-Host $line
}

function Get-MediaTunnel {
  Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'tunnel' -and $_.CommandLine -match 'run' -and $_.CommandLine -notmatch '--url' }
}

function Get-TvBroadcast {
  Get-CimInstance Win32_Process -Filter "Name='ffmpeg.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'live/tv|live\\tv|tv-playlist|StreamPath' }
}

function Get-MediaMtx {
  Get-Process mediamtx -ErrorAction SilentlyContinue
}

function Get-CloudflaredPath {
  $candidates = @(
    "C:\Program Files (x86)\cloudflared\cloudflared.exe",
    "C:\Program Files\cloudflared\cloudflared.exe",
    (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  throw "cloudflared.exe not found. Install it with: winget install Cloudflare.cloudflared"
}

function Start-MediaMtx {
  if (Get-MediaMtx) { return }
  if (-not (Test-Path ".\mediamtx.exe")) { throw "mediamtx.exe is missing in $PSScriptRoot" }
  if (-not (Test-Path ".\mediamtx.yml")) { throw "mediamtx.yml is missing in $PSScriptRoot" }
  Log "starting mediaMTX"
  Start-Process -FilePath ".\mediamtx.exe" -WorkingDirectory $PSScriptRoot -WindowStyle Hidden `
    -RedirectStandardOutput "mediamtx-out.log" -RedirectStandardError "mediamtx-err.log" | Out-Null
  Start-Sleep -Seconds 2
}

function Start-MediaTunnel {
  if (Get-MediaTunnel) { return }
  $tokenFile = Join-Path $env:USERPROFILE ".cloudflared\masareen-media-token.txt"
  $token = if (Test-Path $tokenFile) { (Get-Content $tokenFile -Raw).Trim() } else { $env:MASAREEN_TUNNEL_TOKEN }
  $cf = Get-CloudflaredPath
  if ($token) {
    Log "starting Cloudflare media tunnel (token)"
    $cfArgs = @("tunnel", "--no-autoupdate", "run", "--token", $token)
  } elseif ($env:MASAREEN_TUNNEL_ID) {
    Log "starting Cloudflare media tunnel ($env:MASAREEN_TUNNEL_ID)"
    $cfArgs = @("tunnel", "--no-autoupdate", "run", $env:MASAREEN_TUNNEL_ID)
  } else {
    throw "No media tunnel token. Save it to $tokenFile or set MASAREEN_TUNNEL_TOKEN."
  }
  Start-Process -FilePath $cf -ArgumentList $cfArgs -WindowStyle Hidden `
    -RedirectStandardOutput "cloudflared-media-out.log" -RedirectStandardError "cloudflared-media-err.log" | Out-Null
  Start-Sleep -Seconds 5
}

function Start-TvBroadcast {
  if (Get-TvBroadcast) { return }
  $folder = Join-Path $PSScriptRoot "tv"
  $files = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^\.(mp4|mkv|mov|avi|m4v|webm)$' })
  if (-not $files.Count) {
    Log "no TV videos in $folder; add licensed files to go live"
    return
  }
  Log "starting TV broadcast loop ($($files.Count) file(s))"
  Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "broadcast-tv.ps1")
  ) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
  Start-Sleep -Seconds 4
}

function Test-Live {
  try {
    $local = Invoke-WebRequest -Uri "http://127.0.0.1:8888/live/tv/index.m3u8" -TimeoutSec 6 -UseBasicParsing
    $public = Invoke-WebRequest -Uri "https://masareen.com/live/tv/index.m3u8" -TimeoutSec 12 -UseBasicParsing
    return ($local.StatusCode -eq 200 -and $public.StatusCode -eq 200)
  } catch {
    return $false
  }
}

function Ensure-Live([bool]$force = $false) {
  if ($force) {
    Get-TvBroadcast | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
  }
  Start-MediaMtx
  Start-MediaTunnel
  Start-TvBroadcast
  for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 3
    if (Test-Live) {
      Log "LIVE OK  https://masareen.com/live/tv/index.m3u8"
      return $true
    }
  }
  Log "LIVE CHECK FAILED (local mediaMTX, tunnel, or broadcast is down)"
  return $false
}

Log "MASAREEN live supervisor started (watch=$Watch interval=${IntervalSec}s)"
$ok = Ensure-Live -force:$Restart
if (-not $Watch) {
  if (-not $ok) { exit 1 }
  exit 0
}

while ($true) {
  Start-Sleep -Seconds $IntervalSec
  if (-not (Test-Live)) {
    Log "live check failed; repairing"
    Ensure-Live -force | Out-Null
  } else {
    Start-MediaMtx
    Start-MediaTunnel
    Start-TvBroadcast
  }
}
