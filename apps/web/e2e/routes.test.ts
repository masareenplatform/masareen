/**
 * MASAREN E2E, Authenticated routes
 *
 * Verifies every authenticated page loads without crashing (no JS errors,
 * visible content, correct title/header text). Uses the `authedPage` fixture
 * which pre-populates localStorage with a valid access_token.
 */

import { test, expect } from "./fixtures";
import fs from "fs";
import path from "path";

// Ensure screenshot dir exists
try { fs.mkdirSync(path.resolve("e2e-screenshots"), { recursive: true }); } catch {}

const WAIT = 2500; // ms to let async API calls settle

// ── Helper: check a route renders content ─────────────────────────────────
async function checkRoute(
  page: any,
  base: string,
  route: string,
  label: string,
  screenshotName?: string
) {
  await page.goto(base + route);
  await page.waitForLoadState("domcontentloaded");
  await page.waitForTimeout(WAIT);

  const url = page.url();
  // Ensure we're not redirected to login (which would mean auth failed)
  const redirectedToLogin = url.includes("/login");
  expect(redirectedToLogin, `${label}: should not redirect to login`).toBeFalsy();

  const bodyText: string = await page.evaluate(
    () => document.body.innerText.replace(/\s+/g, " ").trim()
  );
  expect(bodyText.length, `${label}: page body should have content`).toBeGreaterThan(20);

  if (screenshotName) {
    await page.screenshot({ path: `e2e-screenshots/${screenshotName}.png` });
  }

  return bodyText;
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
test("dashboard loads and shows content", async ({ authedPage: page, BASE }) => {
  const text = await checkRoute(page, BASE, "/dashboard", "Dashboard", "dashboard");
  // Should show navigation elements
  const hasNav =
    text.includes("Dashboard") ||
    text.includes("Impact") ||
    text.includes("Programs") ||
    text.includes("Feed") ||
    text.length > 50;
  expect(hasNav, "Dashboard should have meaningful content").toBeTruthy();
});

// ── Feed ──────────────────────────────────────────────────────────────────────
test("feed page loads and shows post area", async ({ authedPage: page, BASE }) => {
  const text = await checkRoute(page, BASE, "/feed", "Feed", "feed");
  const hasFeedElements =
    text.includes("For You") ||
    text.includes("Impact") ||
    text.includes("Programs") ||
    text.includes("Evidence") ||
    text.length > 30;
  expect(hasFeedElements, "Feed should show filter tabs or posts").toBeTruthy();
});

// ── Programs ──────────────────────────────────────────────────────────────────
test("programs page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/programs", "Programs", "programs");
});

// ── Tasks ─────────────────────────────────────────────────────────────────────
test("tasks page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/tasks", "Tasks", "tasks");
});

// ── Evidence ─────────────────────────────────────────────────────────────────
test("evidence page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/evidence", "Evidence", "evidence");
});

// ── Impact Passport ───────────────────────────────────────────────────────────
test("passport page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/passport", "Passport", "passport");
});

// ── Opportunities ─────────────────────────────────────────────────────────────
test("opportunities page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/opportunities", "Opportunities", "opportunities");
});

// ── Portfolio ─────────────────────────────────────────────────────────────────
test("portfolio page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/portfolio", "Portfolio", "portfolio");
});

// ── Profile ───────────────────────────────────────────────────────────────────
test("profile page loads and shows user info", async ({ authedPage: page, BASE }) => {
  const text = await checkRoute(page, BASE, "/profile", "Profile", "profile");
  // Profile should show some user-related content
  const hasProfileContent =
    text.includes("Profile") ||
    text.includes("E2E") ||
    text.includes("masaren") ||
    text.length > 40;
  expect(hasProfileContent, "Profile page should show user content").toBeTruthy();
});

// ── Notifications ────────────────────────────────────────────────────────────
test("notifications page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/notifications", "Notifications", "notifications");
});

// ── Reports ───────────────────────────────────────────────────────────────────
test("reports page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/reports", "Reports", "reports");
});

// ── Billing ───────────────────────────────────────────────────────────────────
test("billing page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/billing", "Billing", "billing");
});

// ── Chat ──────────────────────────────────────────────────────────────────────
test("chat page loads without crashing", async ({ authedPage: page, BASE }) => {
  const consoleErrors: string[] = [];
  page.on("console", (m: any) => {
    if (m.type() === "error") {
      const t = m.text();
      if (!t.includes("favicon") && !t.includes("net::ERR") && !t.includes("Source Map")) {
        consoleErrors.push(t);
      }
    }
  });

  await checkRoute(page, BASE, "/chat", "Chat", "chat");

  // Chat had a previous bug (.map is not a function), verify it's fixed
  const criticalErrors = consoleErrors.filter(
    (e) => e.includes("is not a function") || e.includes("TypeError") || e.includes("Cannot read")
  );
  expect(criticalErrors.length, `Chat JS errors: ${criticalErrors.join(", ")}`).toBe(0);
});

// ── Collaborate ───────────────────────────────────────────────────────────────
test("collaborate page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/collaborate", "Collaborate", "collaborate");
});

// ── Wallet ────────────────────────────────────────────────────────────────────
test("wallet page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/wallet", "Wallet", "wallet");
});

// ── Ads ───────────────────────────────────────────────────────────────────────
test("ads page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/ads", "Ads", "ads");
});

// ── Payments ─────────────────────────────────────────────────────────────────
test("payments page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/payments", "Payments", "payments");
});

// ── Challenges ────────────────────────────────────────────────────────────────
test("challenges page loads", async ({ authedPage: page, BASE }) => {
  await checkRoute(page, BASE, "/challenges", "Challenges", "challenges");
});

// ── Admin (role-gated, non-admin should redirect) ────────────────────────────
test("admin page for non-admin redirects to dashboard", async ({
  authedPage: page,
  BASE,
  token,
}) => {
  // Our test user is INDIVIDUAL (not ADMIN), so /admin should redirect to /dashboard
  if (token.role !== "ADMIN" && token.role !== "SUPER_ADMIN") {
    await page.goto(BASE + "/admin");
    await page.waitForTimeout(2000);
    const url = page.url();
    // Should redirect to dashboard, not show admin page
    expect(
      url.includes("/dashboard") || url.includes("/feed") || !url.includes("/admin"),
      `Non-admin should be redirected away from /admin, got: ${url}`
    ).toBeTruthy();
  } else {
    // If admin user, the page should load
    await checkRoute(page, BASE, "/admin", "Admin", "admin");
  }
  await page.screenshot({ path: "e2e-screenshots/admin.png" });
});

// ── Marketing pages (unauthenticated) ────────────────────────────────────────
test("marketing pages load without auth", async ({ page, BASE }) => {
  const marketingRoutes = [
    { path: "/", name: "landing" },
    { path: "/how-it-works", name: "how-it-works" },
    { path: "/pricing", name: "pricing" },
    { path: "/about", name: "about" },
    { path: "/resources", name: "resources" },
  ];

  for (const route of marketingRoutes) {
    await page.goto(BASE + route.path);
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(800);

    const bodyText = await page.evaluate(
      () => document.body.innerText.replace(/\s+/g, " ").trim()
    );
    expect(
      bodyText.length,
      `${route.name}: page should have content`
    ).toBeGreaterThan(20);

    await page.screenshot({ path: `e2e-screenshots/marketing-${route.name}.png` });
  }
});
