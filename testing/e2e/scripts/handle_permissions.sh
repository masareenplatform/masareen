#!/bin/bash
# Handle all Android permission dialogs dynamically
# Then launch the app
ADB="/tmp/platform-tools/adb"
MAESTRO="$HOME/.maestro/bin/maestro"
PKG="com.masaren.app"

echo "[perm] Clearing state..."
$ADB shell pm clear $PKG 2>/dev/null
sleep 1

echo "[perm] Launching app..."
$ADB shell am start -n $PKG/.MainActivity
sleep 8

echo "[perm] Handling permission dialogs..."
for i in $(seq 1 20); do
  HIER=$($MAESTRO hierarchy --compact --no-reinstall-driver 2>/dev/null)
  
  # Try "While using the app"
  if echo "$HIER" | grep -q "text=While using the app"; then
    BOUNDS=$(echo "$HIER" | grep "text=While using the app" | grep -oP 'bounds=\[\d+,\d+\]\[\d+,\d+\]' | head -1)
    X1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '1p'); Y1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '2p')
    X2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '3p'); Y2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '4p')
    echo "[perm] $i: While using the app at ($(( (X1+X2)/2 )),$(( (Y1+Y2)/2 )))"
    $ADB shell input tap $(( (X1+X2)/2 )) $(( (Y1+Y2)/2 ))
    sleep 2; continue
  fi
  
  # Try "Allow all"
  if echo "$HIER" | grep -q "text=Allow all"; then
    BOUNDS=$(echo "$HIER" | grep "text=Allow all" | grep -oP 'bounds=\[\d+,\d+\]\[\d+,\d+\]' | head -1)
    X1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '1p'); Y1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '2p')
    X2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '3p'); Y2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '4p')
    echo "[perm] $i: Allow all at ($(( (X1+X2)/2 )),$(( (Y1+Y2)/2 )))"
    $ADB shell input tap $(( (X1+X2)/2 )) $(( (Y1+Y2)/2 ))
    sleep 2; continue
  fi
  
  # Try "Allow" (standalone button)
  if echo "$HIER" | grep -q 'text=Allow;'; then
    BOUNDS=$(echo "$HIER" | grep 'text=Allow;' | grep -oP 'bounds=\[\d+,\d+\]\[\d+,\d+\]' | head -1)
    if [ -n "$BOUNDS" ]; then
      X1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '1p'); Y1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '2p')
      X2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '3p'); Y2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '4p')
      echo "[perm] $i: Allow at ($(( (X1+X2)/2 )),$(( (Y1+Y2)/2 )))"
      $ADB shell input tap $(( (X1+X2)/2 )) $(( (Y1+Y2)/2 ))
      sleep 2; continue
    fi
  fi
  
  # Check for onboarding/login
  if echo "$HIER" | grep -q "accessibilityText=Skip"; then
    BOUNDS=$(echo "$HIER" | grep 'accessibilityText=Skip' | grep -oP 'bounds=\[\d+,\d+\]\[\d+,\d+\]' | head -1)
    X1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '1p'); Y1=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '2p')
    X2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '3p'); Y2=$(echo "$BOUNDS" | grep -oP '\d+' | sed -n '4p')
    echo "[perm] $i: Onboarding - Skip at ($(( (X1+X2)/2 )),$(( (Y1+Y2)/2 )))"
    $ADB shell input tap $(( (X1+X2)/2 )) $(( (Y1+Y2)/2 ))
    sleep 3; break
  fi
  
  if echo "$HIER" | grep -q "accessibilityText=Sign in"; then
    echo "[perm] $i: Login screen reached"
    break
  fi
  
  echo "[perm] $i: Unknown state, waiting..."
  sleep 1
done

echo "[perm] Done. Current state:"
$MAESTRO hierarchy --compact --no-reinstall-driver 2>/dev/null | grep -oP 'text=[^;"]+|accessibilityText=[^;"]+|hintText=[^;"]+' | grep -v "systemui" | head -10
