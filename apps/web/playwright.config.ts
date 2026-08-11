import { defineConfig, devices } from "@playwright/test";

/**
 * MASAREN Web E2E — Playwright configuration.
 *
 * Serves the pre-built SPA (dist/) through the fixture-level static server
 * (see e2e/fixtures.ts) so no separate `webServer` process is needed.
 * All `/api/*` calls are proxied to the live combined backend on :8080.
 */
export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,       // avoid registration conflicts / port collisions
  retries: 1,
  reporter: [
    ["list"],
    ["json", { outputFile: "e2e-report.json" }],
    ["html", { outputFolder: "e2e-report-html", open: "never" }],
  ],
  use: {
    // baseURL is set by the per-file server fixture
    headless: true,
    screenshot: "only-on-failure",
    video: "off",
    trace: "on-first-retry",
    launchOptions: {
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
      ],
    },
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
