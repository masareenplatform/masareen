# Bring up ONE MASAREN service: build+run, wait, check health, sync ORM schema.
# Usage:  .\bringup.ps1 <compose-service-name>
param($svc)
$ErrorActionPreference = "Continue"
$ROOT = "C:\Users\sherifrashwan\Downloads\MASAREN-FINAL\MASAREN"
Set-Location $ROOT

Write-Host "`n===== [$svc] build+up ====="
docker compose up -d --build $svc 2>&1 | Select-Object -Last 4

# wait for container to appear and attempt readiness
$ok = $false
for ($i=0; $i -lt 12; $i++) {
  Start-Sleep -Seconds 10
  $st = (docker compose ps $svc --format "{{.Status}}" 2>$null)
  if ($st -match "healthy|Up") { $ok=$true; break }
  if ($st -match "Restarting|Exit") { break }
}
$st = (docker compose ps $svc --format "{{.Status}}" 2>$null)
Write-Host "[$svc] status=$st"

if ($st -notmatch "healthy") {
  Write-Host "[$svc] NOT healthy - last logs:"
  docker compose logs $svc --tail 20 2>&1 | Select-Object -Last 20
} else {
  # sync ORM schema (create missing tables) using the service's own models
  Write-Host "[$svc] syncing ORM schema..."
  $sync = docker compose exec -T $svc python -c "
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from shared.base_repository.db import Base
import svc.src.main
async def go():
    e=create_async_engine('postgresql+asyncpg://masaren:masaren_password@postgres:5432/masaren')
    async with e.begin() as c:
        await c.run_sync(Base.metadata.create_all)
    await e.dispose()
asyncio.run(go())
print('CREATE_ALL_OK')
" 2>&1 | Select-Object -Last 6
  Write-Host "[$svc] schema: $($sync -join ' ')"
}
Write-Host "===== [$svc] done ====="
