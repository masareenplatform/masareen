import { test, expect } from "@playwright/test";

const ADMIN_EMAIL = "admin@masaren.org";
const ADMIN_PASSWORD = "Masaren@1234";
const USER_EMAIL = "amira.saleh@masaren.org";
const USER_PASSWORD = "Masaren@1234";

async function loginAs(page: any, email: string, password: string) {
  await page.goto("/login");
  await page.locator('input[type="email"]').fill(email);
  await page.locator('input[type="password"]').fill(password);
  await page.locator('button[type="submit"]').click();
}

test.describe("Authentication", () => {
  test("login with valid admin credentials redirects to /feed or /dashboard", async ({ page }) => {
    await loginAs(page, ADMIN_EMAIL, ADMIN_PASSWORD);
    await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });
    expect(page.url()).toMatch(/\/(feed|dashboard)/);
  });

  test("login with valid regular user credentials redirects to /feed", async ({ page }) => {
    await loginAs(page, USER_EMAIL, USER_PASSWORD);
    await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });
    expect(page.url()).toMatch(/\/(feed|dashboard)/);
  });

  test("login with invalid credentials shows error", async ({ page }) => {
    await page.goto("/login");
    await page.locator('input[type="email"]').fill("nonexistent@test.com");
    await page.locator('input[type="password"]').fill("WrongPassword123!");
    await page.locator('button[type="submit"]').click();
    await expect(page.locator('[role="alert"]')).toBeVisible({ timeout: 10000 });
  });

  test("login with empty credentials shows validation", async ({ page }) => {
    await page.goto("/login");
    await page.locator('button[type="submit"]').click();
    await expect(page.locator('[role="alert"]')).toBeVisible({ timeout: 5000 });
  });

  test("login page has register link", async ({ page }) => {
    await page.goto("/login");
    const registerLink = page.locator('a:has-text("Create one")');
    await expect(registerLink).toBeVisible();
    await registerLink.click();
    await expect(page).toHaveURL(/\/register/);
  });

  test("register page has login link", async ({ page }) => {
    await page.goto("/register");
    const loginLink = page.locator('a:has-text("Sign In")');
    await expect(loginLink).toBeVisible();
    await loginLink.click();
    await expect(page).toHaveURL(/\/login/);
  });

  test("unauthenticated user visiting /dashboard redirects to /login", async ({ page }) => {
    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });

  test("unauthenticated user visiting /feed redirects to /login", async ({ page }) => {
    await page.goto("/feed");
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });

  test("unauthenticated user visiting /admin redirects to /login", async ({ page }) => {
    await page.goto("/admin");
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });

  test("logout from authenticated session redirects to landing", async ({ page }) => {
    await loginAs(page, ADMIN_EMAIL, ADMIN_PASSWORD);
    await page.waitForURL(/\/(feed|dashboard)/, { timeout: 15000 });

    // Open user menu
    const accountButton = page.locator('button[aria-label="Account"]');
    await accountButton.click();

    // Click sign out
    const signOutButton = page.locator('button:has-text("Sign Out")');
    await signOutButton.click();

    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });
  });
});
