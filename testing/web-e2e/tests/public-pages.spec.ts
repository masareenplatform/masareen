import { test, expect } from "@playwright/test";

test.describe("Public Pages", () => {
  test("landing page loads with title and navigation", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveTitle(/MASAREEN/i);
    const nav = page.locator("header").first();
    await expect(nav).toBeVisible();
    await expect(nav.locator('img[alt="MASAREEN"]')).toBeVisible();
  });

  test("landing page has hero section", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("text=Prove impact")).toBeVisible();
    await expect(page.locator("text=Scale change")).toBeVisible();
  });

  test("landing page has footer", async ({ page }) => {
    await page.goto("/");
    const footer = page.locator("footer");
    await expect(footer).toBeVisible();
    await expect(footer.locator("text=Verified impact infrastructure")).toBeVisible();
  });

  test("login page renders form fields", async ({ page }) => {
    await page.goto("/login");
    await expect(page.locator("h1:text('Welcome back')")).toBeVisible();
    const emailInput = page.locator('input[type="email"]');
    await expect(emailInput).toBeVisible();
    const passwordInput = page.locator('input[type="password"]');
    await expect(passwordInput).toBeVisible();
    await expect(page.locator('button[type="submit"]:has-text("Sign In")')).toBeVisible();
  });

  test("register page renders form fields", async ({ page }) => {
    await page.goto("/register");
    await expect(page.locator("text=Create your account")).toBeVisible();
    await expect(page.locator('input[placeholder="John Doe"]')).toBeVisible();
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"]')).toBeVisible();
    await expect(page.locator('select').first()).toBeVisible();
    await expect(page.locator('button[type="submit"]:has-text("Create Account")')).toBeVisible();
  });

  test("presentation page loads with hero section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Verified Impact Infrastructure")).toBeVisible();
    await expect(page.locator("text=Platform showcase")).toBeVisible();
  });

  test("presentation page has feature cards", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Impact Feed & Social")).toBeVisible();
    await expect(page.locator("text=POAI Verification Pipeline")).toBeVisible();
    await expect(page.locator("text=MASAREEN Coin Economy")).toBeVisible();
  });

  test("presentation page has CTA to register", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator('a:has-text("Join the Alpha")').first()).toBeVisible();
    await expect(page.locator('a:has-text("Sign in")').first()).toBeVisible();
  });

  test("docs page loads with sidebar navigation", async ({ page }) => {
    await page.goto("/docs");
    await expect(page.locator("text=Documentation")).toBeVisible();
    await expect(page.locator("text=Overview")).toBeVisible();
  });

  test("docs page shows all 11 sections in sidebar", async ({ page }) => {
    await page.goto("/docs");
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

  test("about page loads", async ({ page }) => {
    await page.goto("/about");
    await expect(page.locator("text=About").first()).toBeVisible();
    await expect(page.locator("text=Members").first()).toBeVisible();
  });

  test("pricing page loads", async ({ page }) => {
    await page.goto("/pricing");
    await expect(page.locator("text=Pricing").first()).toBeVisible();
    await expect(page.locator("text=Free")).toBeVisible();
    await expect(page.locator("text=Pro")).toBeVisible();
    await expect(page.locator("text=Enterprise")).toBeVisible();
  });

  test("how it works page loads", async ({ page }) => {
    await page.goto("/how-it-works");
    await expect(page.locator("text=Claim the impact")).toBeVisible();
    await expect(page.locator("text=Submit evidence")).toBeVisible();
    await expect(page.locator("text=POAI score")).toBeVisible();
  });
});
