#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================="
echo "  MASAREEN Web E2E Test Suite"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="
echo ""

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "[1/4] Installing dependencies..."
  npm install
  echo ""
else
  echo "[1/4] Dependencies already installed."
  echo ""
fi

# Install Playwright browsers if needed
echo "[2/4] Checking Playwright browsers..."
npx playwright install chromium --with-deps 2>/dev/null || npx playwright install chromium
echo ""

# Create output directory
mkdir -p test-results
echo ""

# Run tests
echo "[3/4] Running Playwright tests..."
echo "---------------------------------------------"
echo ""

EXIT_CODE=0
npx playwright test --reporter=list,json || EXIT_CODE=$?

echo ""
echo "---------------------------------------------"
echo "[4/4] Test Summary"
echo "---------------------------------------------"

# Parse JSON report if it exists
if [ -f "test-results/report.json" ]; then
  TOTAL=$(node -e "const r=require('./test-results/report.json'); console.log(r.suites?.flatMap(s => s.specs || []).length || r.stats?.expected || 0)" 2>/dev/null || echo "?")
  PASSED=$(node -e "const r=require('./test-results/report.json'); console.log(r.stats?.expected || 0)" 2>/dev/null || echo "?")
  FAILED=$(node -e "const r=require('./test-results/report.json'); console.log(r.stats?.unexpected || 0)" 2>/dev/null || echo "?")
  SKIPPED=$(node -e "const r=require('./test-results/report.json'); console.log(r.stats?.skipped || 0)" 2>/dev/null || echo "?")

  echo "  Total:   $TOTAL"
  echo "  Passed:  $PASSED"
  echo "  Failed:  $FAILED"
  echo "  Skipped: $SKIPPED"
else
  echo "  (JSON report not available)"
fi

echo ""
echo "  HTML Report: test-results/html-report/index.html"
echo "  JSON Report: test-results/report.json"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
  echo "  Result: ALL TESTS PASSED"
else
  echo "  Result: SOME TESTS FAILED (exit code: $EXIT_CODE)"
fi

echo ""
echo "============================================="
exit $EXIT_CODE
