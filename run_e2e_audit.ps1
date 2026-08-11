# MASAREN Flutter E2E audit runner.
# Runs every Maestro audit flow against the REAL backend (gateway on :8080),
# records PASS/FAIL + the failing assertion, and writes a recoverable audit
# (e2e_audit.json + E2E_AUDIT.md).
#
# Each flow is retried up to $MaxRetries times to absorb the transient
# maestro/emulator gRPC connection drops seen on this host.
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
$env:JAVA_OPTS = "-Xmx1024m -XX:MaxMetaspaceSize=256m"
$env:PATH = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot\bin;C:\Users\sherifrashwan\AppData\Local\maestro-cli\maestro\bin;" + $env:PATH
$ROOT = "C:\Users\sherifrashwan\Downloads\MASAREN-FINAL\MASAREN"
Set-Location $ROOT
$DEVICE = "emulator-5554"
$MaxRetries = 3

# Credentials injected into every flow. ${EMAIL}/${PASSWORD} are consumed by the
# alpha self-serve registration audit; a FRESH email is generated per attempt so
# re-registering an existing address never returns a 409 conflict. The password
# satisfies the app's register regex (upper/lower/digit/symbol, 8+ chars).
$AUDIT_PASSWORD = "Maestro@1234"
function New-AuditEmail {
    # NOTE: the backend's pydantic EmailStr rejects reserved/special-use TLDs
    # such as `.test` / `.example`, so the alpha registration audit must use a
    # syntactically valid real-style domain (`.io`) or every register returns 422.
    "audit_$(Get-Date -UFormat '%Y%m%d%H%M%S')_$(Get-Random)@masaren.io"
}

function Wait-Device {
    for ($i = 0; $i -lt 20; $i++) {
        $st = (adb get-state 2>$null).Trim()
        if ($st -eq "device") { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

$flows = @(Get-ChildItem testing/mobile/maestro/audit_*.yaml | Sort-Object Name | ForEach-Object { $_.FullName })
$results = @()
$ok = 0; $fail = 0
foreach ($f in $flows) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f)
    Write-Host "`n===== AUDIT: $name ====="
    $status = "FAIL"; $failLine = ""; $exit = 1
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        if (-not (Wait-Device)) { Write-Host "  device offline, retrying..."; continue }
        $email = New-AuditEmail
        $env:EMAIL = $email
        $env:PASSWORD = $AUDIT_PASSWORD
        $out = & maestro test $f --device $DEVICE -e EMAIL=$email -e PASSWORD=$AUDIT_PASSWORD 2>&1
        $exit = $LASTEXITCODE
        $failLine = ($out | Where-Object { $_ -match "Assertion is false|Error:|Exception|failed" } | Select-Object -Last 1)
        if ($exit -eq 0) { $status = "PASS"; $failLine = ""; break }
        Write-Host "  attempt $attempt FAILED: $failLine"
        Start-Sleep -Seconds 4
    }
    if ($status -eq "PASS") { $ok++ } else { $fail++; $failLine = $failLine.ToString() }
    Write-Host "$name -> $status  ($failLine)"
    $results += [PSCustomObject]@{ flow=$name; file=$f; status=$status; detail=$failLine; exit=$exit }
}
# backend service summary
$svc = (docker compose ps --format "{{.Names}} {{.Status}}" 2>$null)
$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    backend = "real (docker compose, gateway :8080)"
    totals = [PSCustomObject]@{ total=$results.Count; passed=$ok; failed=$fail }
    flows = $results
    services = $svc
}
$summary | ConvertTo-Json -Depth 4 | Set-Content e2e_audit.json
# markdown
$md = "# MASAREN Flutter E2E Audit (real backend)`n`n"
$md += "Generated: $($summary.generatedAt)`n"
$md += "Backend: $($summary.backend)`n`n"
$md += "## Summary: $ok passed / $fail failed / $($results.Count) total`n`n"
$md += "## Per-test results`n`n"
$md += "| # | Flow | Result | Detail |`n"
$md += "|---|------|--------|--------|`n"
$i=1
foreach ($r in $results) { $md += "| $i | $($r.flow) | $($r.status) | $(($r.detail -replace '\|','/') -replace '`n',' ') |`n"; $i++ }
$md += "`n## Backend service status`n`n"
$md += "``````n" + ($svc -join "`n") + "`n``````n"
Set-Content E2E_AUDIT.md $md
Write-Host "`n===== AUDIT COMPLETE: $ok PASS / $fail FAIL ====="
