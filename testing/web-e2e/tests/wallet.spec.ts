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

test.describe("Wallet Page", () => {
  test("wallet page loads after login", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/wallet");
    await page.waitForURL(/\/wallet/, { timeout: 10000 });
    await page.waitForTimeout(3000);
    // Wallet page should have content
    const bodyText = await page.locator("body").textContent();
    expect(bodyText).toBeTruthy();
    // Should not be redirected to login
    expect(page.url()).toContain("/wallet");
  });

  test("wallet page has balance information", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/wallet");
    await page.waitForTimeout(3000);
    // The wallet page should show some financial/balance content
    const bodyText = await page.locator("body").textContent();
    expect(bodyText).toContain("Wallet");
  });

  test("unauthenticated user cannot access wallet", async ({ page }) => {
    await page.goto("/wallet");
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });
});
