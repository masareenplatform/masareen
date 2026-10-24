# One-time Cloudflare setup for MASAREEN (Windows / PowerShell).
# Creates the D1 database, applies the schema, sets SESSION_SECRET, deploys the
# API Worker, and optionally creates an R2 bucket and uploads the landing page.
#
# Usage:  .\setup.ps1
#         .\setup.ps1 -Bucket masareen
#         .\setup.ps1 -SkipR2
[CmdletBinding()]
param(
  [string]$Database = "masareen",
  [string]$Bucket = "",
  [switch]$SkipR2,
  [switch]$ForceSecret
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

function Invoke-Wrangler {
  param([string[]]$Arguments, [switch]$AllowFail)
  & npx wrangler @Arguments
  if (-not $AllowFail -and $LASTEXITCODE -ne 0) {
    throw "wrangler $($Arguments -join ' ') failed"
  }
  return $LASTEXITCODE
}

Write-Host "==> Checking Wrangler login"
$who = & npx wrangler whoami 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Host "Not logged in. A browser window will open."
  Invoke-Wrangler @("login") | Out-Null
} else {
  Write-Host $who.Trim()
}

Write-Host "==> Ensuring dependencies"
if (-not (Test-Path -LiteralPath "node_modules")) {
  & npm install
  if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
}

Write-Host "==> Resolving D1 database '$Database'"
$dbId = $null
try {
  $raw = & npx wrangler d1 list --json 2>$null | Out-String
  $start = $raw.IndexOf("[")
  if ($start -ge 0) {
    $list = ($raw.Substring($start) | ConvertFrom-Json)
    $match = @($list) | Where-Object { $_.name -eq $Database } | Select-Object -First 1
    if ($match) { $dbId = $match.uuid }
  }
} catch {
  # Older Wrangler versions may not support --json; fall through to create.
}

if (-not $dbId) {
  Write-Host "Creating database '$Database'..."
  $out = & npx wrangler d1 create $Database 2>&1 | Out-String
  Write-Host $out.Trim()
  $m = [regex]::Match($out, 'database_id\s*=\s*"([^"]+)"')
  if ($m.Success) {
    $dbId = $m.Groups[1].Value
  } else {
    throw "Could not read the new database_id. Copy it from the output above into wrangler.toml, then re-run."
  }
}

$toml = Get-Content -LiteralPath "wrangler.toml" -Raw
$updated = [regex]::Replace($toml, 'database_id\s*=\s*"[^"]*"', "database_id = `"$dbId`"", 1)
if ($updated -ne $toml) {
  $tomlPath = Join-Path (Get-Location) "wrangler.toml"
  [System.IO.File]::WriteAllText($tomlPath, $updated, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "wrangler.toml updated with database_id $dbId"
} else {
  Write-Host "database_id already set in wrangler.toml"
}

Write-Host "==> Applying schema and migrations"
Invoke-Wrangler @("d1", "execute", $Database, "--remote", "--file=schema.sql", "--yes") | Out-Null
Invoke-Wrangler @("d1", "execute", $Database, "--remote", "--file=migrations/001-profile-fields.sql", "--yes") -AllowFail | Out-Null

Write-Host "==> SESSION_SECRET"
$needSecret = $ForceSecret
if (-not $needSecret) {
  $secrets = & npx wrangler secret list 2>$null | Out-String
  $needSecret = -not ($secrets -match "SESSION_SECRET")
}
if ($needSecret) {
  $bytes = New-Object byte[] 48
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $secret = [Convert]::ToBase64String($bytes)
  $secret | & npx wrangler secret put SESSION_SECRET
  if ($LASTEXITCODE -ne 0) { throw "Could not set SESSION_SECRET" }
  Write-Host "SESSION_SECRET set (generated)."
} else {
  Write-Host "SESSION_SECRET already exists (use -ForceSecret to rotate)."
}

Write-Host "==> Deploying API Worker"
Invoke-Wrangler @("deploy") | Out-Null

Write-Host ""
Write-Host "API deployed. Check: https://masareen.com/api/health"

if (-not $SkipR2) {
  if (-not $Bucket) {
    $Bucket = Read-Host "R2 bucket for the landing page (leave empty to skip)"
  }
  if ($Bucket) {
    Write-Host "==> Uploading landing page to R2 bucket '$Bucket'"
    & npx wrangler r2 bucket create $Bucket 2>$null | Out-Null
    & (Join-Path $PSScriptRoot "..\landing\upload-to-r2.ps1") -Bucket $Bucket
    if ($LASTEXITCODE -ne 0) { throw "Landing page upload failed" }
  }
}

Write-Host ""
Write-Host "Remaining manual step: in Cloudflare, attach the custom domain masareen.com (and www) to the R2 bucket,"
Write-Host "and make sure the domain is proxied by Cloudflare so the /api/* Worker routes apply."
