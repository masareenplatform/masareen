// MASAREN Web — FULL route-load E2E audit.
//
// Serves the built SPA (apps/web/dist) and proxies /api/v1/* to the live
// combined backend at :8080. Authenticates a real user, then drives a
// headless browser through EVERY authenticated route, capturing:
//   - per-route console errors (real ones only)
//   - rendered body length (proves the page mounts & paints)
//   - a desktop + mobile (375px) pass for responsive verification
//
// Prereqs: combined backend on :8080, infra (postgres) on :5432, web built.
// Run:  node testing/web/audit-routes.mjs

import http from "node:http";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../..");
const DIST = path.resolve(ROOT, "apps/web/dist");
const OUT = path.resolve(__dirname, "screenshots-audit");
fs.mkdirSync(OUT, { recursive: true });

const PORT = 4191;
const BASE = `http://localhost:${PORT}`;
const API = "http://localhost:8080";

const MIME = {
  ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript",
  ".css": "text/css", ".json": "application/json", ".svg": "image/svg+xml",
  ".png": "image/png", ".ico": "image/x-icon", ".woff": "font/woff",
  ".woff2": "font/woff2", ".ttf": "font/ttf", ".map": "application/json",
};

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
  if (urlPath.startsWith("/api/")) {
    const r = http.request(
      API + urlPath + (req.url.includes("?") ? req.url.slice(req.url.indexOf("?")) : ""),
      { method: req.method, headers: req.headers },
      (proxyRes) => {
        const chunks = [];
        proxyRes.on("data", (c) => chunks.push(c));
        proxyRes.on("end", () => {
          res.writeHead(proxyRes.statusCode, { "Content-Type": "application/json" });
          res.end(Buffer.concat(chunks));
        });
      }
    );
    req.on("data", (c) => r.write(c));
    req.on("end", () => r.end());
    r.on("error", () => { res.writeHead(502); res.end("bad gateway"); });
    return;
  }
  let filePath = path.join(DIST, urlPath);
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) filePath = path.join(DIST, "index.html");
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end("not found"); return; }
    res.writeHead(200, { "Content-Type": MIME[path.extname(filePath)] || "application/octet-stream" });
    res.end(data);
  });
});

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
await new Promise((r) => server.listen(PORT, r));

const browser = await puppeteer.launch({ headless: "new", args: ["--no-sandbox", "--disable-setuid-sandbox"] });
const page = await browser.newPage();
await page.setViewport({ width: 1366, height: 900 });

const IGNORE = [/Failed to load resource/i, /net::ERR/i, /ERR_FAILED/i, /Source map/i, /favicon/i];
const allErrors = [];
page.on("console", (m) => { if (m.type() === "error" && !IGNORE.some((r) => r.test(m.text()))) allErrors.push(m.text()); });
page.on("pageerror", (e) => allErrors.push("PAGEERROR: " + e.message));

const bodyLen = () => page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").trim().length);

// ── Authenticate a real user ──
const email = `web_audit_${Date.now()}@masaren.dev`;
const password = "Test@12345";
const results = [];
const rec = (name, ok, detail) => { results.push({ name, ok, detail }); console.log(`[audit] ${name}: ${ok ? "PASS" : "FAIL"} (${detail})`); };

try {
  await page.goto(`${BASE}/register`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await wait(700);
  await page.type('input[placeholder="Full Name"]', "Audit User");
  await page.type('input[placeholder="Email"]', email);
  await page.type('input[placeholder="Strong Password (8+ chars, mixed case)"]', password);
  await page.type('input[placeholder="Phone Number"]', "+201000000000");
  await page.click('button[type="submit"]');
  await wait(1500);
  execSync(`docker exec masaren-postgres-1 psql -U masaren -d masaren -tAc "UPDATE users SET email_verified=true, status='ACTIVE' WHERE email='${email}';"`, { stdio: "ignore" });
  await page.goto(`${BASE}/login`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await wait(700);
  await page.type('input[placeholder="Email"]', email);
  await page.type('input[placeholder="Password"]', password);
  await page.click('button[type="submit"]');
  await wait(2500);
  const token = await page.evaluate(() => localStorage.getItem("access_token"));
  rec("auth_login", !!token, token ? "token obtained" : "NO TOKEN");
} catch (e) {
  rec("auth_login", false, String(e.message));
}

// ── Visit every authenticated route (desktop) ──
const ROUTES = [
  "/dashboard", "/programs", "/tasks", "/evidence", "/passport", "/opportunities",
  "/portfolio", "/profile", "/admin", "/notifications", "/reports", "/billing",
  "/chat", "/feed", "/collaborate", "/wallet", "/ads", "/payments", "/revenue",
];

for (const route of ROUTES) {
  const before = allErrors.length;
  try {
    await page.goto(`${BASE}${route}`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await wait(2200);
    const len = await bodyLen();
    const errs = allErrors.slice(before);
    const ok = len > 60 && errs.length === 0;
    rec(`route ${route}`, ok, `bodyLen=${len} consoleErrs=${errs.length}${errs.length ? " :: " + errs.slice(0, 2).join(" | ") : ""}`);
    await page.screenshot({ path: path.join(OUT, `desktop${route.replace(/\//g, "_") || "_root"}.png`) });
  } catch (e) {
    rec(`route ${route}`, false, String(e.message));
  }
}

// ── Responsive check: mobile viewport shows bottom nav + compose FAB ──
await page.setViewport({ width: 390, height: 844 });
await wait(500);
try {
  await page.goto(`${BASE}/feed`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await wait(2000);
  const hasBottomNav = await page.evaluate(() => !!document.querySelector(".bottom-nav"));
  const hasFab = await page.evaluate(() => !!document.querySelector(".compose-fab"));
  const sidebarHidden = await page.evaluate(() => {
    const a = document.querySelector("aside");
    if (!a) return true;
    return getComputedStyle(a).display === "none";
  });
  rec("mobile_bottom_nav", hasBottomNav, hasBottomNav ? "bottom-nav present" : "missing");
  rec("mobile_compose_fab", hasFab, hasFab ? "FAB present" : "missing");
  rec("mobile_sidebar_hidden", sidebarHidden, sidebarHidden ? "sidebar hidden on mobile" : "sidebar still visible");
  await page.screenshot({ path: path.join(OUT, "mobile_feed.png") });
} catch (e) {
  rec("mobile_feed", false, String(e.message));
}

await browser.close();
server.close();

const passed = results.filter((r) => r.ok).length;
console.log(`\n[audit] OVERALL: ${passed}/${results.length} passed`);
fs.writeFileSync(
  path.resolve(__dirname, "route-audit-report.json"),
  JSON.stringify({ passed, total: results.length, results, consoleErrors: allErrors }, null, 2)
);
console.log(`[audit] report -> ${path.resolve(__dirname, "route-audit-report.json")}`);
process.exit(passed === results.length ? 0 : 1);
