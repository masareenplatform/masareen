# One-time setup for MASAREEN live/VOD on Windows.
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Host "Installing ffmpeg..." -ForegroundColor Cyan
  winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
}

if (-not (Test-Path "C:\Program Files (x86)\cloudflared\cloudflared.exe")) {
  Write-Host "Installing cloudflared..." -ForegroundColor Cyan
  winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements
}

if (-not (Test-Path ".\mediamtx.exe")) {
  Write-Host "Downloading mediaMTX..." -ForegroundColor Cyan
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/bluenviron/mediamtx/releases/latest"
  $asset = $release.assets | Where-Object { $_.name -match 'windows_amd64' } | Select-Object -First 1
  if (-not $asset) { throw "Could not find the Windows mediaMTX release." }
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile ".\mediamtx.zip"
  Expand-Archive -Path ".\mediamtx.zip" -DestinationPath "." -Force
}

if (-not (Test-Path ".\mediamtx.yml")) {
  Copy-Item ".\mediamtx.example.yml" ".\mediamtx.yml"
  Write-Host "Created mediamtx.yml - change CHANGE_ME and run .\live.ps1" -ForegroundColor Yellow
}

Write-Host "Checking NVENC..." -ForegroundColor Cyan
ffmpeg -hide_banner -encoders 2>$null | Select-String nvenc

Write-Host ""
Write-Host "Setup complete. Next:" -ForegroundColor Green
Write-Host "1. Set the publish password in mediamtx.yml"
Write-Host "2. Save the masareen-media tunnel token in $env:USERPROFILE\.cloudflared\masareen-media-token.txt"
Write-Host "3. Run .\live.ps1"
