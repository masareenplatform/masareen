param(
  [switch]$PublishTest
)

# Starts mediaMTX + the Cloudflare tunnel for MASAREEN live.
# Viewer URL (edge-cached by the Worker): https://masareen.com/live/masareen/index.m3u8
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

if (-not (Test-Path ".\mediamtx.exe")) {
  throw "mediamtx.exe not found. Run setup.ps1 or download it from github.com/bluenviron/mediamtx/releases."
}
if (-not (Test-Path ".\mediamtx.yml")) {
  throw "mediamtx.yml not found. Copy mediamtx.example.yml and set a strong publish password."
}

$tokenFile = Join-Path $env:USERPROFILE ".cloudflared\masareen-media-token.txt"
$tunnelToken = if (Test-Path $tokenFile) { (Get-Content $tokenFile -Raw).Trim() } else { $env:MASAREEN_TUNNEL_TOKEN }
if (-not $tunnelToken -and -not $env:MASAREEN_TUNNEL_ID) {
  throw "No tunnel token. Set MASAREEN_TUNNEL_TOKEN or save a token in $tokenFile."
}

Write-Host "Starting mediaMTX on :1935 (RTMP) and :8888 (HLS)..." -ForegroundColor Cyan
$media = Start-Process -FilePath ".\mediamtx.exe" -WorkingDirectory $PSScriptRoot -PassThru `
  -WindowStyle Hidden -RedirectStandardOutput "mediamtx-out.log" -RedirectStandardError "mediamtx-err.log"

try {
  if ($tunnelToken) {
    Write-Host "Starting Cloudflare tunnel masareen-media (token auth)..." -ForegroundColor Cyan
    $cfArgs = @("tunnel", "--no-autoupdate", "run", "--token", $tunnelToken)
  } else {
    Write-Host "Starting Cloudflare tunnel $env:MASAREEN_TUNNEL_ID..." -ForegroundColor Cyan
    $cfArgs = @("tunnel", "--no-autoupdate", "run", $env:MASAREEN_TUNNEL_ID)
  }
  $cf = Start-Process -FilePath "C:\Program Files (x86)\cloudflared\cloudflared.exe" `
    -ArgumentList $cfArgs -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput "cloudflared-media-out.log" -RedirectStandardError "cloudflared-media-err.log"

  if ($PublishTest) {
    Write-Host "Publishing a looping test broadcast..." -ForegroundColor Yellow
    Start-Process -FilePath "ffmpeg" -ArgumentList @(
      "-re", "-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=30",
      "-f", "lavfi", "-i", "sine=frequency=440",
      "-c:v", "h264_nvenc", "-preset", "p4", "-tune", "hq", "-b:v", "2500k", "-g", "60",
      "-c:a", "aac", "-b:a", "128k", "-f", "flv",
      "rtmp://127.0.0.1:1935/live/masareen?user=masareen&pass=masareen-live-2026"
    ) -WindowStyle Hidden -RedirectStandardError "ffmpeg-live.log" | Out-Null
  }

  Write-Host ""
  Write-Host "RTMP publish (OBS): rtmp://127.0.0.1:1935/live/masareen" -ForegroundColor Green
  Write-Host "Stream key/query:   ?user=masareen&pass=masareen-live-2026" -ForegroundColor Green
  Write-Host "Viewer HLS:         https://masareen.com/live/masareen/index.m3u8" -ForegroundColor Green
  Write-Host "Media edge:         https://media.masareen.com/live/masareen/index.m3u8" -ForegroundColor Green
  Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

  Wait-Process -Id $cf.Id
}
finally {
  if (-not $media.HasExited) { Stop-Process -Id $media.Id -Force }
}
