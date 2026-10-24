# Upload the static landing page (served by an R2 bucket custom domain).
# Usage: .\upload-to-r2.ps1 <bucket-name>
# Requires: npx wrangler (and `npx wrangler login` once).
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Bucket
)

$ErrorActionPreference = "Stop"
$Wrangler = if ($env:WRANGLER) { $env:WRANGLER } else { "npx" }
$WranglerPrefix = if ($env:WRANGLER) { @() } else { @("wrangler") }

Set-Location -LiteralPath $PSScriptRoot

function Put-Object {
  param(
    [string]$Key,
    [string]$ContentType,
    [string]$CacheControl
  )
  & $Wrangler @WranglerPrefix r2 object put "$Bucket/$Key" --file $Key --content-type $ContentType --cache-control $CacheControl --remote
  if ($LASTEXITCODE -ne 0) { throw "Upload failed for $Key" }
  Write-Host "uploaded $Key"
}

Put-Object "index.html"  "text/html; charset=utf-8" "public, max-age=300"
Put-Object "admin.html"  "text/html; charset=utf-8" "public, max-age=300"
Put-Object "favicon.ico" "image/x-icon" "public, max-age=86400"

Get-ChildItem -LiteralPath "assets" -Filter "*.png" -File | ForEach-Object {
  Put-Object "assets/$($_.Name)" "image/png" "public, max-age=31536000, immutable"
}

Write-Host ""
Write-Host "Done. Remember: purge the Cloudflare cache for the domain after changing files."
