import { test, expect } from "@playwright/test";

test.describe("Presentation Page", () => {
  test("has hero section with tagline", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Platform showcase")).toBeVisible();
    await expect(page.locator("text=Verified Impact Infrastructure")).toBeVisible();
    await expect(page.locator("text=The verified-impact network")).toBeVisible();
  });

  test("has feature cards section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Everything impact teams need")).toBeVisible();
    await expect(page.locator("text=Impact Feed & Social")).toBeVisible();
    await expect(page.locator("text=POAI Verification Pipeline")).toBeVisible();
    await expect(page.locator("text=MASAREEN Coin Economy")).toBeVisible();
    await expect(page.locator("text=Programs & Tasks")).toBeVisible();
    await expect(page.locator("text=Evidence & GPS Tracking")).toBeVisible();
    await expect(page.locator("text=Institution Profiles")).toBeVisible();
  });

  test("has verification flow section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=How verification works")).toBeVisible();
    await expect(page.locator("text=Claim the impact")).toBeVisible();
  });

  test("has architecture section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Platform architecture")).toBeVisible();
    await expect(page.locator("text=Microservice-first design")).toBeVisible();
  });

  test("has user roles section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=User roles")).toBeVisible();
    await expect(page.locator("text=Built for every stakeholder")).toBeVisible();
  });

  test("has CTA to register and sign in", async ({ page }) => {
    await page.goto("/presentation");
    const joinBtn = page.locator('a:has-text("Join the Alpha")').first();
    await expect(joinBtn).toBeVisible();
    const signInBtn = page.locator('a:has-text("Sign in")').first();
    await expect(signInBtn).toBeVisible();
  });

  test("has marketing navigation", async ({ page }) => {
    await page.goto("/presentation");
    const header = page.locator("header").first();
    await expect(header).toBeVisible();
    await expect(header.locator('img[alt="MASAREEN"]')).toBeVisible();
  });

  test("has marketing footer", async ({ page }) => {
    await page.goto("/presentation");
    const footer = page.locator("footer");
    await expect(footer).toBeVisible();
  });

  test("has stats section", async ({ page }) => {
    await page.goto("/presentation");
    await expect(page.locator("text=Verified impact actions")).toBeVisible();
  });
});
