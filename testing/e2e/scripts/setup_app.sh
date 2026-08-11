#!/bin/bash
# E2E test setup: clear state, grant ALL permissions, launch app, skip onboarding
# Usage: ./setup_app.sh [--clean]
set -e

ADB="/tmp/platform-tools/adb"
PKG="com.masaren.app"
ACTIVITY="$PKG/.MainActivity"
MAESTRO="$HOME/.maestro/bin/maestro"

# Clean state if requested
if [[ "$1" == "--clean" ]]; then
  echo "[setup] Clearing app state..."
  $ADB shell pm clear $PKG 2>/dev/null || true
  sleep 1
fi

echo "[setup] Granting ALL permissions..."
for perm in \
  android.permission.CAMERA \
  android.permission.ACCESS_FINE_LOCATION \
  android.permission.ACCESS_COARSE_LOCATION \
  android.permission.ACCESS_BACKGROUND_LOCATION \
  android.permission.POST_NOTIFICATIONS \
  android.permission.READ_MEDIA_IMAGES \
  android.permission.READ_MEDIA_VIDEO \
  android.permission.READ_MEDIA_AUDIO \
  android.permission.READ_EXTERNAL_STORAGE \
  android.permission.WRITE_EXTERNAL_STORAGE \
  android.permission.RECORD_AUDIO \
  android.permission.RECEIVE_BOOT_COMPLETED \
  android.permission.VIBRATE; do
  $ADB shell pm grant $PKG $perm 2>/dev/null || true
done

echo "[setup] Force stopping app..."
$ADB shell am force-stop $PKG
sleep 1

echo "[setup] Launching app..."
$ADB shell am start -n $ACTIVITY
sleep 6

echo "[setup] Checking for onboarding..."
# The app shows onboarding after pm clear. Use Maestro to skip.
# Skip up to 4 onboarding pages + handle any lingering permission dialogs
for i in 1 2 3 4 5 6 7 8; do
  HIER=$($MAESTRO hierarchy --compact --no-reinstall-driver 2>/dev/null || echo "")
  if echo "$HIER" | grep -q "content-desc=Skip"; then
    echo "[setup] Skipping onboarding page..."
    $ADB shell input tap 996 191
    sleep 1
  elif echo "$HIER" | grep -q "content-desc=Get Started"; then
    echo "[setup] Tapping Get Started..."
    $ADB shell input tap 540 2200
    sleep 1
  elif echo "$HIER" | grep -q "While using the app"; then
    echo "[setup] Granting permission..."
    $ADB shell input tap 540 1226
    sleep 1
  elif echo "$HIER" | grep -q "Allow all"; then
    echo "[setup] Allowing all..."
    $ADB shell input tap 540 1383
    sleep 1
  elif echo "$HIER" | grep -q "Allow"; then
    echo "[setup] Allowing..."
    $ADB shell input tap 540 1305
    sleep 1
  elif echo "$HIER" | grep -q "content-desc=Sign in"; then
    echo "[setup] On login screen, ready."
    break
  else
    sleep 1
  fi
done

echo "[setup] Done."
