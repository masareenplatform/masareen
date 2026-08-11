import { test, expect } from "@playwright/test";

const ADMIN_EMAIL = "admin@masaren.org";
const ADMIN_PASSWORD = "Masaren@1234";

async function loginAsAdmin(page: any) {
  await page.goto("/login");
  await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
  await page.locator('input[type="password"]').fill(ADMIN_PASSWORD);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });
}

test.describe("Admin Page", () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/admin");
    await page.waitForURL(/\/admin/, { timeout: 10000 });
  });

  test("admin page loads with title", async ({ page }) => {
    await expect(page.locator("text=Admin Console")).toBeVisible({ timeout: 10000 });
  });

  test("admin page has tab navigation", async ({ page }) => {
    await expect(page.locator("button:has-text('Overview')")).toBeVisible();
    await expect(page.locator("button:has-text('Users')")).toBeVisible();
    await expect(page.locator("button:has-text('Programs')")).toBeVisible();
    await expect(page.locator("button:has-text('Verification')")).toBeVisible();
    await expect(page.locator("button:has-text('Revenue')")).toBeVisible();
    await expect(page.locator("button:has-text('Engagement')")).toBeVisible();
    await expect(page.locator("button:has-text('Reports')")).toBeVisible();
  });

  test("admin page has KPI cards on Overview tab", async ({ page }) => {
    await page.locator("button:has-text('Overview')").click();
    await page.waitForTimeout(2000);
    const kpiCards = page.locator(".card");
    expect(await kpiCards.count()).toBeGreaterThanOrEqual(3);
  });

  test("admin page shows Users tab with user directory", async ({ page }) => {
    await page.locator("button:has-text('Users')").click();
    await page.waitForTimeout(2000);
    await expect(page.locator("text=User directory")).toBeVisible();
  });

  test("admin page shows Programs tab", async ({ page }) => {
    await page.locator("button:has-text('Programs')").click();
    await page.waitForTimeout(2000);
    await expect(page.locator("text=All programs")).toBeVisible();
  });

  test("admin page shows Verification tab", async ({ page }) => {
    await page.locator("button:has-text('Verification')").click();
    await page.waitForTimeout(2000);
    await expect(page.locator("text=Evidence by status")).toBeVisible();
  });

  test("admin page shows Revenue tab", async ({ page }) => {
    await page.locator("button:has-text('Revenue')").click();
    await page.waitForTimeout(2000);
    await expect(page.locator("text=Monthly revenue")).toBeVisible();
  });

  test("admin page shows Reports tab", async ({ page }) => {
    await page.locator("button:has-text('Reports')").click();
    await page.waitForTimeout(2000);
    await expect(page.locator("text=Statistical Reports")).toBeVisible();
  });

  test("non-admin user cannot access admin page", async ({ page }) => {
    await page.goto("/login");
    await page.locator('input[type="email"]').fill("amira.saleh@masaren.org");
    await page.locator('input[type="password"]').fill("Masaren@1234");
    await page.locator('button[type="submit"]').click();
    await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });
    await page.goto("/admin");
    await page.waitForTimeout(3000);
    expect(page.url()).not.toContain("/admin");
  });
});
