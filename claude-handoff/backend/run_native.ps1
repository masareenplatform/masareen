# run_native.ps1, launch all MASAREN microservices natively (no Docker for the app).
# Infra (postgres/neo4j/redis/kafka) is assumed running via Docker containers.
$ErrorActionPreference = "Continue"
$root = "C:\Users\sherifrashwan\Downloads\MASAREN-FINAL\MASAREN"
$venv = "$root\backend\.venv\Scripts\python.exe"
$run  = "$root\backend\_run"
New-Item -ItemType Directory -Force -Path $run | Out-Null

# name -> dir (relative to backend) -> port
$services = @(
  @{n='identity';      d='identity/identity-service';             p=8001},
  @{n='authentication';d='identity/authentication-service';        p=8002},
  @{n='authorization'; d='identity/authorization-service';        p=8003},
  @{n='organization';  d='execution/organization-service';         p=8004},
  @{n='program';       d='execution/program-service';              p=8005},
  @{n='task';          d='execution/task-service';                 p=8006},
  @{n='workflow';      d='execution/workflow-service';             p=8007},
  @{n='verification';  d='verification/verification-service';      p=8008},
  @{n='evidence';      d='verification/evidence-service';          p=8009},
  @{n='gps';           d='verification/gps-service';              p=8010},
  @{n='audit';         d='verification/audit-service';            p=8011},
  @{n='media';         d='verification/media-service';            p=8012},
  @{n='submission';    d='verification/submission-service';       p=8013},
  @{n='graph';         d='graph/graph-service';                   p=8014},
  @{n='reputation';    d='reputation/portfolio-service';          p=8015},
  @{n='impact-score';  d='reputation/impact-score-service';       p=8016},
  @{n='org-score';     d='reputation/organization-score-service'; p=8017},
  @{n='marketplace';   d='marketplace/opportunity-service';       p=8018},
  @{n='matching';      d='marketplace/matching-service';          p=8019},
  @{n='report';        d='reporting/report-service';              p=8020},
  @{n='analytics';     d='reporting/analytics-service';           p=8021},
  @{n='forecast';      d='reporting/forecast-service';            p=8022},
  @{n='chat';          d='chat-service';                          p=8023},
  @{n='billing';       d='billing/billing-service';               p=8024},
  @{n='subscription';  d='billing/subscription-service';          p=8025},
  @{n='payment';       d='billing/payment-service';               p=8026},
  @{n='partner';       d='partners/partner-service';              p=8027},
  @{n='coin';          d='coin/coin-service';                     p=8028},
  @{n='ads';           d='ads/ads-service';                       p=8029},
  @{n='platform';      d='platform/platform-service';             p=8030},
  @{n='notification';  d='notifications/notification-service';    p=8031},
  @{n='orchestrator';  d='ai/verification_orchestrator_service';  p=8032},
  @{n='fraud-python';  d='ai/fraud-service/python';              p=8090},
  @{n='auth-python';   d='identity/authentication-service/python';p=8093},
  @{n='impact-score-python'; d='reputation/impact-score-service/python'; p=8094},
  @{n='gateway';       d='gateway';                               p=8080}
)

# env var name each service is registered under in the gateway
$envName = @{
  'identity'='IDENTITY_SERVICE_URL'; 'authentication'='AUTHENTICATION_SERVICE_URL';
  'authorization'='AUTHORIZATION_SERVICE_URL'; 'organization'='ORGANIZATION_SERVICE_URL';
  'program'='PROGRAM_SERVICE_URL'; 'task'='TASK_SERVICE_URL'; 'workflow'='WORKFLOW_SERVICE_URL';
  'verification'='VERIFICATION_SERVICE_URL'; 'evidence'='EVIDENCE_SERVICE_URL'; 'gps'='GPS_SERVICE_URL';
  'audit'='AUDIT_SERVICE_URL'; 'media'='MEDIA_SERVICE_URL'; 'submission'='SUBMISSION_SERVICE_URL';
  'graph'='GRAPH_SERVICE_URL'; 'reputation'='REPUTATION_SERVICE_URL'; 'impact-score'='IMPACT_SCORE_SERVICE_URL';
  'org-score'='ORG_SCORE_SERVICE_URL'; 'marketplace'='MARKETPLACE_SERVICE_URL'; 'matching'='MATCHING_SERVICE_URL';
  'report'='REPORT_SERVICE_URL'; 'analytics'='ANALYTICS_SERVICE_URL'; 'forecast'='FORECAST_SERVICE_URL';
  'chat'='CHAT_SERVICE_URL'; 'billing'='BILLING_SERVICE_URL'; 'subscription'='SUBSCRIPTION_SERVICE_URL';
  'payment'='PAYMENT_SERVICE_URL'; 'partner'='PARTNER_SERVICE_URL'; 'coin'='COIN_SERVICE_URL';
  'ads'='ADS_SERVICE_URL'; 'platform'='PLATFORM_SERVICE_URL'; 'notification'='NOTIFICATION_SERVICE_URL';
  'fraud-python'='FRAUD_SCORE_SERVICE_URL'; 'auth-python'='AUTH_VERIFY_SERVICE_URL';
  'impact-score-python'='REPUTATION_SCORE_SERVICE_URL'
}

# Common env (inherited by every process)
$env:PYTHONPATH = "."
$env:DATABASE_URL = "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
$env:REDIS_URL = "redis://localhost:6379"
$env:KAFKA_BOOTSTRAP_SERVERS = "localhost:29092"
$env:NEO4J_URL = "bolt://localhost:7687"; $env:NEO4J_USER="neo4j"; $env:NEO4J_PASSWORD="masaren_dev"
$env:JWT_SECRET="masaren-alpha-change-me"; $env:JWT_ALGORITHM="HS256"
$env:GRAPH_SERVICE_URL="http://localhost:8014/api/v1/graph"
$env:CORS_ORIGINS="*"

# Set every *_SERVICE_URL for the gateway
foreach($s in $services){ if($envName[$s.n]){ Set-Variable -Name "__dummy" -Value $null; [Environment]::SetEnvironmentVariable($envName[$s.n], "http://localhost:$($s.p)") ; $env[$envName[$s.n]] = "http://localhost:$($s.p)" } }

foreach($s in $services){
  $dir = "$run\$($s.n)"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $svcTarget = "$root\backend\$($s.d)"
  if(Test-Path "$dir\svc"){ cmd /c "rmdir `"$dir\svc`"" | Out-Null }
  cmd /c "mklink /J `"$dir\svc`" `"$svcTarget`"" 2>&1 | Out-Null
  if(Test-Path "$dir\shared"){ cmd /c "rmdir `"$dir\shared`"" | Out-Null }
  cmd /c "mklink /J `"$dir\shared`" `"$root\backend\shared`"" 2>&1 | Out-Null
  if(-not (Test-Path "$svcTarget\__init__.py")){ New-Item -ItemType File -Path "$svcTarget\__init__.py" -Force | Out-Null }
  $env:PYTHONPATH = "$dir;."
  $log = "$dir\$($s.n).log"; $err = "$dir\$($s.n).err"
  Start-Process -FilePath $venv -ArgumentList "-m","uvicorn","svc.src.main:app","--host","127.0.0.1","--port",$s.p `
    -WorkingDirectory $dir -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Hidden
  Write-Host "launched $($s.n) on :$($s.p)"
}
Write-Host "All launch requests sent. Waiting for startup..."
Start-Sleep -Seconds 25
# Health summary
foreach($s in $services){
  try { $r = Invoke-RestMethod -Uri "http://127.0.0.1:$($s.p)/health" -TimeoutSec 4; Write-Host "$($s.n) : $($r.status)" }
  catch { Write-Host "$($s.n) : UNREACHABLE" }
}
