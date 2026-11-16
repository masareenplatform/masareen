param([string]$TaskName = "MASAREEN Live")

# Registers the live supervisor to start at Windows logon.
# Run once in an elevated PowerShell:
#   .\install-autostart.ps1
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "start-live.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Watch"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Settings $settings -Description "Starts mediaMTX, the Cloudflare media tunnel and the TV loop." -Force | Out-Null
Write-Host "Installed scheduled task '$TaskName'. It will start at the next logon." -ForegroundColor Green
