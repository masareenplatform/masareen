import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  retries: 1,
  workers: 1,
  reporter: [
    ["list"],
    ["json", { outputFile: "test-results/report.json" }],
    ["html", { outputFolder: "test-results/html-report", open: "never" }],
  ],
  outputDir: "./test-results/artifacts",
  use: {
    baseURL: "https://masareen.mediahubnetwork.net",
    headless: true,
    screenshot: "only-on-failure",
    video: "off",
    trace: "on-first-retry",
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
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
