#!/bin/bash
# Run all E2E tests in sequence
# Usage: ./run_all_tests.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP="$SCRIPT_DIR/scripts/setup_app.sh"
MAESTRO="$HOME/.maestro/bin/maestro"
UDID="localhost:15555"
RESULTS=""

echo "========================================="
echo "  MASAREEN E2E Test Suite"
echo "========================================="

run_test() {
  local name="$1"
  local file="$2"
  local needs_clean="${3:-true}"
  local test_timeout="${4:-60}"
  
  echo ""
  echo "--- Running: $name ---"
  
  if [ "$needs_clean" = "true" ]; then
    echo "Setting up fresh app state..."
    $SETUP --clean 2>&1 | sed 's/^/  /'
  fi
  
  echo "Running test..."
  OUTPUT=$(timeout $test_timeout $MAESTRO test "$file" --udid $UDID --no-reinstall-driver --no-ansi 2>&1)
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "  PASS: $name"
    RESULTS="$RESULTS\n  PASS: $name"
  else
    echo "  FAIL: $name (exit code $EXIT_CODE)"
    echo "$OUTPUT" | tail -10 | sed 's/^/    /'
    RESULTS="$RESULTS\n  FAIL: $name"
  fi
  
  return 0
}

# Test 1: Login with valid credentials
run_test "01_login" "$SCRIPT_DIR/01_login.yaml" "true"

# Test 2: Register screen navigation
run_test "02_register" "$SCRIPT_DIR/02_register.yaml" "true"

# Test 3: Bottom navigation (needs login first)
echo ""
echo "--- Running: 03_bottom_nav ---"
echo "Setting up fresh app state..."
$SETUP --clean 2>&1 | sed 's/^/  /'
echo "Logging in first..."
timeout 60 $MAESTRO test "$SCRIPT_DIR/01_login.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1 > /dev/null
echo "Running bottom nav test..."
OUTPUT=$(timeout 60 $MAESTRO test "$SCRIPT_DIR/03_bottom_nav.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: 03_bottom_nav"
  RESULTS="$RESULTS\n  PASS: 03_bottom_nav"
else
  echo "  FAIL: 03_bottom_nav"
  echo "$OUTPUT" | tail -10 | sed 's/^/    /'
  RESULTS="$RESULTS\n  FAIL: 03_bottom_nav"
fi

# Test 4: Drawer logout (fresh login)
run_test "04_drawer_logout" "$SCRIPT_DIR/04_drawer_logout.yaml" "true"

# Test 5: Feed tabs (app already logged in from test 4)
run_test "05_feed_tabs" "$SCRIPT_DIR/05_feed_tabs.yaml" "false"

# Test 6: Create post (app already logged in)
run_test "06_create_post" "$SCRIPT_DIR/06_create_post.yaml" "false"

# Test 7: Feed scroll (fresh login)
run_test "07_feed_scroll" "$SCRIPT_DIR/07_feed_scroll.yaml" "true"

# Test 8: Login with invalid credentials
run_test "08_login_invalid" "$SCRIPT_DIR/08_login_invalid.yaml" "true"

# ========================================
# SIMULATION TESTS (09-18)
# Full user-behavior simulation suite
# ========================================

# Test 9: Individual user simulation
echo ""
echo "--- Running: 09_simulation_individual ---"
echo "Setting up fresh app state..."
$SETUP --clean 2>&1 | sed 's/^/  /'
echo "Logging in first..."
timeout 60 $MAESTRO test "$SCRIPT_DIR/01_login.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1 > /dev/null
echo "Running individual user simulation..."
OUTPUT=$(timeout 120 $MAESTRO test "$SCRIPT_DIR/09_simulation_individual.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: 09_simulation_individual"
  RESULTS="$RESULTS\n  PASS: 09_simulation_individual"
else
  echo "  FAIL: 09_simulation_individual"
  echo "$OUTPUT" | tail -10 | sed 's/^/    /'
  RESULTS="$RESULTS\n  FAIL: 09_simulation_individual"
fi

# Test 10: Content creator simulation
echo ""
echo "--- Running: 10_simulation_content_creator ---"
echo "Setting up fresh app state..."
$SETUP --clean 2>&1 | sed 's/^/  /'
echo "Logging in first..."
timeout 60 $MAESTRO test "$SCRIPT_DIR/01_login.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1 > /dev/null
echo "Running content creator simulation..."
OUTPUT=$(timeout 120 $MAESTRO test "$SCRIPT_DIR/10_simulation_content_creator.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: 10_simulation_content_creator"
  RESULTS="$RESULTS\n  PASS: 10_simulation_content_creator"
else
  echo "  FAIL: 10_simulation_content_creator"
  echo "$OUTPUT" | tail -10 | sed 's/^/    /'
  RESULTS="$RESULTS\n  FAIL: 10_simulation_content_creator"
fi

# Test 11: Program journey simulation
run_test "11_simulation_program_journey" "$SCRIPT_DIR/11_simulation_program_journey.yaml" "true" 120

# Test 12: Wallet economy simulation
run_test "12_simulation_wallet_economy" "$SCRIPT_DIR/12_simulation_wallet_economy.yaml" "true" 120

# Test 13: Opportunities apply simulation
run_test "13_simulation_opportunities_apply" "$SCRIPT_DIR/13_simulation_opportunities_apply.yaml" "true" 120

# Test 14: Notifications flow simulation
run_test "14_simulation_notifications_flow" "$SCRIPT_DIR/14_simulation_notifications_flow.yaml" "true" 120

# Test 15: Admin panel simulation
run_test "15_simulation_admin_panel" "$SCRIPT_DIR/15_simulation_admin_panel.yaml" "true" 120

# Test 16: Theme & language simulation
run_test "16_simulation_theme_language" "$SCRIPT_DIR/16_simulation_theme_language.yaml" "true" 120

# Test 17: Full user journey simulation
echo ""
echo "--- Running: 17_simulation_full_user_journey ---"
echo "Setting up fresh app state (onboarding visible)..."
$SETUP --clean 2>&1 | sed 's/^/  /'
echo "Running full user journey simulation..."
OUTPUT=$(timeout 180 $MAESTRO test "$SCRIPT_DIR/17_simulation_full_user_journey.yaml" --udid $UDID --no-reinstall-driver --no-ansi 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "  PASS: 17_simulation_full_user_journey"
  RESULTS="$RESULTS\n  PASS: 17_simulation_full_user_journey"
else
  echo "  FAIL: 17_simulation_full_user_journey"
  echo "$OUTPUT" | tail -10 | sed 's/^/    /'
  RESULTS="$RESULTS\n  FAIL: 17_simulation_full_user_journey"
fi

# Test 18: Post interactions simulation
run_test "18_simulation_post_interactions" "$SCRIPT_DIR/18_simulation_post_interactions.yaml" "true" 120

echo ""
echo "========================================="
echo "  RESULTS SUMMARY"
echo "========================================="
echo -e "$RESULTS"
echo "========================================="
