import { test, expect } from "@playwright/test";

test.describe("Docs Page", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/docs");
    await page.waitForLoadState("networkidle");
  });

  test("has sidebar navigation", async ({ page }) => {
    const sidebar = page.locator("nav").first();
    await expect(sidebar).toBeVisible();
    await expect(sidebar.locator("text=Documentation")).toBeVisible();
  });

  test("shows all 11 sections in sidebar", async ({ page }) => {
    const sections = [
      "Overview",
      "Getting Started",
      "The Feed",
      "Verification Pipeline",
      "MASAREEN Coin",
      "Programs & Tasks",
      "Opportunities",
      "Profiles",
      "Admin Panel",
      "API Reference",
      "Architecture",
    ];
    for (const section of sections) {
      await expect(page.locator(`nav button:has-text("${section}")`)).toBeVisible();
    }
  });

  test("default section is Overview", async ({ page }) => {
    await expect(page.locator("text=MASAREEN Overview")).toBeVisible();
  });

  test("clicking sidebar section scrolls to it", async ({ page }) => {
    await page.locator('nav button:has-text("Verification Pipeline")').click();
    await page.waitForTimeout(1000);
    const section = page.locator("#doc-section-verification");
    await expect(section).toBeVisible();
  });

  test("clicking Getting Started shows content", async ({ page }) => {
    await page.locator('nav button:has-text("Getting Started")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("text=Sign up")).toBeVisible();
  });

  test("clicking Feed section shows feed docs", async ({ page }) => {
    await page.locator('nav button:has-text("The Feed")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('The Feed')")).toBeVisible();
  });

  test("clicking Verification Pipeline shows verification docs", async ({ page }) => {
    await page.locator('nav button:has-text("Verification Pipeline")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('Verification Pipeline')")).toBeVisible();
  });

  test("clicking MASAREEN Coin shows coin docs", async ({ page }) => {
    await page.locator('nav button:has-text("MASAREEN Coin")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('MASAREEN Coin')")).toBeVisible();
  });

  test("clicking Programs & Tasks shows programs docs", async ({ page }) => {
    await page.locator('nav button:has-text("Programs & Tasks")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('Programs & Tasks')")).toBeVisible();
  });

  test("clicking API Reference shows API docs", async ({ page }) => {
    await page.locator('nav button:has-text("API Reference")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('API Reference')")).toBeVisible();
  });

  test("clicking Architecture shows architecture docs", async ({ page }) => {
    await page.locator('nav button:has-text("Architecture")').click();
    await page.waitForTimeout(1000);
    await expect(page.locator("h2:has-text('Architecture')")).toBeVisible();
  });

  test("has marketing navigation", async ({ page }) => {
    const header = page.locator("header").first();
    await expect(header).toBeVisible();
  });

  test("has marketing footer", async ({ page }) => {
    const footer = page.locator("footer");
    await expect(footer).toBeVisible();
  });
});
