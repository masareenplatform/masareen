import { test, expect } from "@playwright/test";

test.describe("Responsive Design", () => {
  test.describe("Mobile viewport (375px)", () => {
    test.use({ viewport: { width: 375, height: 812 } });

    test("landing page renders correctly on mobile", async ({ page }) => {
      await page.goto("/");
      await expect(page.locator("text=Prove impact")).toBeVisible();
      await expect(page.locator('img[alt="MASAREEN"]')).toBeVisible();
    });

    test("login page renders correctly on mobile", async ({ page }) => {
      await page.goto("/login");
      await expect(page.locator("h1:text('Welcome back')")).toBeVisible();
      await expect(page.locator('input[type="email"]')).toBeVisible();
      await expect(page.locator('button[type="submit"]')).toBeVisible();
    });

    test("register page renders correctly on mobile", async ({ page }) => {
      await page.goto("/register");
      await expect(page.locator("text=Create your account")).toBeVisible();
      await expect(page.locator('input[type="email"]')).toBeVisible();
    });

    test("presentation page renders correctly on mobile", async ({ page }) => {
      await page.goto("/presentation");
      await expect(page.locator("text=Verified Impact Infrastructure")).toBeVisible();
    });

    test("pricing page renders correctly on mobile", async ({ page }) => {
      await page.goto("/pricing");
      await expect(page.locator("text=Free")).toBeVisible();
      await expect(page.locator("text=Pro")).toBeVisible();
    });

    test("how it works page renders correctly on mobile", async ({ page }) => {
      await page.goto("/how-it-works");
      await expect(page.locator("text=Claim the impact")).toBeVisible();
    });
  });

  test.describe("Tablet viewport (768px)", () => {
    test.use({ viewport: { width: 768, height: 1024 } });

    test("landing page renders correctly on tablet", async ({ page }) => {
      await page.goto("/");
      await expect(page.locator("text=Prove impact")).toBeVisible();
    });

    test("login page renders correctly on tablet", async ({ page }) => {
      await page.goto("/login");
      await expect(page.locator("h1:text('Welcome back')")).toBeVisible();
    });

    test("presentation page renders correctly on tablet", async ({ page }) => {
      await page.goto("/presentation");
      await expect(page.locator("text=Verified Impact Infrastructure")).toBeVisible();
    });

    test("docs page renders correctly on tablet", async ({ page }) => {
      await page.goto("/docs");
      await expect(page.locator("text=Documentation")).toBeVisible();
    });
  });

  test.describe("Desktop viewport (1440px)", () => {
    test.use({ viewport: { width: 1440, height: 900 } });

    test("landing page renders correctly on desktop", async ({ page }) => {
      await page.goto("/");
      await expect(page.locator("text=Prove impact")).toBeVisible();
      // Desktop nav should be visible
      await expect(page.locator('header nav button:has-text("Platform")')).toBeVisible();
    });

    test("login page renders correctly on desktop", async ({ page }) => {
      await page.goto("/login");
      await expect(page.locator("h1:text('Welcome back')")).toBeVisible();
    });

    test("presentation page renders correctly on desktop", async ({ page }) => {
      await page.goto("/presentation");
      await expect(page.locator("text=Verified Impact Infrastructure")).toBeVisible();
    });

    test("docs page sidebar visible on desktop", async ({ page }) => {
      await page.goto("/docs");
      await expect(page.locator("nav >> text=Documentation")).toBeVisible();
    });
  });
});
