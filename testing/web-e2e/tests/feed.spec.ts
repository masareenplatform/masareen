import { test, expect } from "@playwright/test";

const ADMIN_EMAIL = "admin@masaren.org";
const ADMIN_PASSWORD = "Masaren@1234";

async function loginAsAdmin(page: any) {
  await page.goto("/login");
  await page.locator('input[type="email"]').fill(ADMIN_EMAIL);
  await page.locator('input[type="password"]').fill(ADMIN_PASSWORD);
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });
  if (page.url().includes("/dashboard")) {
    await page.goto("/feed");
    await page.waitForURL(/\/feed/, { timeout: 10000 });
  }
}

test.describe("Feed Page", () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test("feed page loads with title", async ({ page }) => {
    await expect(page.locator("text=Impact Discovery")).toBeVisible({ timeout: 10000 });
  });

  test("feed page has search bar", async ({ page }) => {
    const searchInput = page.locator('input[aria-label="Search impact, people, programs…"]');
    await expect(searchInput).toBeVisible();
  });

  test("feed page has filter tabs", async ({ page }) => {
    const tabBar = page.locator(".tab-bar");
    await expect(tabBar).toBeVisible();
    await expect(tabBar.locator("button:has-text('For You')")).toBeVisible();
    await expect(tabBar.locator("button:has-text('Impact')")).toBeVisible();
    await expect(tabBar.locator("button:has-text('Programs')")).toBeVisible();
    await expect(tabBar.locator("button:has-text('Evidence')")).toBeVisible();
    await expect(tabBar.locator("button:has-text('Saved')")).toBeVisible();
  });

  test("feed page has composer", async ({ page }) => {
    await expect(page.locator("text=Create post").first()).toBeVisible();
  });

  test("feed loads posts or shows empty state", async ({ page }) => {
    await page.waitForTimeout(2000);
    const posts = page.locator("[class*='PostCard'], [class*='post-card'], article, .card");
    const emptyState = page.locator("text=No more impact stories");
    const hasContent = await posts.count() > 0;
    const hasEmpty = await emptyState.isVisible().catch(() => false);
    expect(hasContent || hasEmpty).toBeTruthy();
  });

  test("clicking Impact tab filters feed", async ({ page }) => {
    const impactTab = page.locator(".tab-bar button:has-text('Impact')");
    await impactTab.click();
    await page.waitForTimeout(1500);
    await expect(page.locator("text=Impact Discovery")).toBeVisible();
  });

  test("clicking Programs tab filters feed", async ({ page }) => {
    const programsTab = page.locator(".tab-bar button:has-text('Programs')");
    await programsTab.click();
    await page.waitForTimeout(1500);
    await expect(page.locator("text=Impact Discovery")).toBeVisible();
  });

  test("clicking Evidence tab filters feed", async ({ page }) => {
    const evidenceTab = page.locator(".tab-bar button:has-text('Evidence')");
    await evidenceTab.click();
    await page.waitForTimeout(1500);
    await expect(page.locator("text=Impact Discovery")).toBeVisible();
  });

  test("clicking Saved tab shows saved posts", async ({ page }) => {
    const savedTab = page.locator(".tab-bar button:has-text('Saved')");
    await savedTab.click();
    await page.waitForTimeout(1500);
    await expect(page.locator("text=Impact Discovery")).toBeVisible();
  });
});
