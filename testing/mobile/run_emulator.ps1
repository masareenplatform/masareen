# Launches an Android emulator and runs the MASAREN mobile simulation tests.
param(
  [string]$AvdName = "masaren_test",
  [switch]$MockAuth
)

$ErrorActionPreference = "Stop"
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
$env:PATH = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot\bin;" + $env:PATH

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$mobile = Join-Path $root "apps/mobile"

Write-Host "==> flutter doctor (emulator/device check)"
flutter devices

# Create the AVD if it does not exist.
$existing = flutter emulators --machine | Out-String
if (-not ($existing -match $AvdName)) {
  Write-Host "==> creating AVD $AvdName"
  flutter emulators --create --name $AvdName -s "pixel_6"
}

# Launch the emulator in the background.
Write-Host "==> launching emulator $AvdName"
Start-Process -FilePath "flutter" -ArgumentList "emulators --launch $AvdName" -NoNewWindow

# Wait for a device to appear via adb.
Write-Host "==> waiting for device..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
  $dev = flutter devices 2>$null | Out-String
  if ($dev -match "android") { $ready = $true; break }
  Start-Sleep -Seconds 4
}
if (-not $ready) { Write-Error "Emulator did not come up in time." }

if ($MockAuth) { $env:MASAREN_MOCK_AUTH = "1" }

Write-Host "==> running integration test"
Set-Location $mobile
flutter test integration_test/app_test.dart
if ($LASTEXITCODE -ne 0) { Write-Error "integration test failed" }

Write-Host "==> capturing screenshots via flutter drive"
flutter drive --driver=testing_driver.dart --target=integration_test/app_test.dart
Write-Host "==> done. Screenshots in apps/mobile/screenshots/"
