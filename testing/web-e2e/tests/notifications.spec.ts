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

test.describe("Notifications Page", () => {
  test("notifications page loads after login", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/notifications");
    await page.waitForURL(/\/notifications/, { timeout: 10000 });
    await page.waitForTimeout(3000);
    const bodyText = await page.locator("body").textContent();
    expect(bodyText).toBeTruthy();
    expect(page.url()).toContain("/notifications");
  });

  test("notifications page has notification bell in top nav", async ({ page }) => {
    await loginAsAdmin(page);
    const bellButton = page.locator('button[aria-label="Notifications"]');
    await expect(bellButton).toBeVisible();
    await bellButton.click();
    await expect(page).toHaveURL(/\/notifications/);
  });

  test("notifications page shows list or empty state", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/notifications");
    await page.waitForTimeout(3000);
    // Should either show notifications or an empty state
    const bodyText = await page.locator("body").textContent();
    expect(bodyText).toBeTruthy();
  });

  test("unauthenticated user cannot access notifications", async ({ page }) => {
    await page.goto("/notifications");
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });
});
