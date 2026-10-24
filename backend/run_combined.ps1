# run_combined.ps1, single clean MASAREN combined monolith on :8080.
# Kills any existing combined.main processes, then starts ONE instance with
# logs to backend/combined_run.log (tail it to watch: Get-Content combined_run.log -Wait).
$root  = "C:\Users\sherifrashwan\Downloads\MASAREN-FINAL\MASAREN"
$venv   = "$root\backend\.venv\Scripts\python.exe"
$log    = "$root\backend\combined_run.log"
$err    = "$root\backend\combined_run.err"
$work   = "$root\backend"

# 1) Kill any existing combined monolith processes.
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'combined\.main' } | ForEach-Object {
    taskkill /F /PID $_.ProcessId 2>$null | Out-Null
}
Start-Sleep -Seconds 2

# 2) Start one clean instance (cwd=backend so `combined`, `social`, `shared` import as top-level pkgs).
#    Use Postgres (running locally), several services use Postgres-only column types
#    (e.g. ARRAY), which fail under the SQLite fallback and abort startup.
$env:PYTHONPATH        = "."
$env:DATABASE_URL      = "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
$env:REDIS_URL         = "redis://localhost:6379"
$env:JWT_SECRET        = "masaren-alpha-change-me"
$env:JWT_ALGORITHM     = "HS256"
$env:CORS_ORIGINS      = "*"
# Alpha: auto-verify new registrations so people can sign in immediately
# without an email-verification round trip. Remove/set false in production.
$env:AUTO_VERIFY_ON_REGISTER = "true"
Start-Process -FilePath $venv -ArgumentList "-m","uvicorn","combined.main:app","--host","0.0.0.0","--port","8080","--log-level","info" `
    -WorkingDirectory $work -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden

Write-Host "combined monolith starting on http://0.0.0.0:8080  (logs: $log)"
Start-Sleep -Seconds 6
try {
    $h = Invoke-RestMethod -Uri "http://127.0.0.1:8080/health" -TimeoutSec 5
    Write-Host "health: $($h.status)  services_included=$($h.services_included.Count)"
} catch {
    Write-Host "health check failed: $_"
}
