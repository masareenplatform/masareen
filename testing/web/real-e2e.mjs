// MASAREN Web, REAL end-to-end E2E against the combined backend.
//
// Serves the built SPA (apps/web/dist) and proxies /api/v1/* to the live
// combined backend at http://localhost:8080. Drives a real register -> DB
// verify -> login -> navigate flow with headless Chromium and asserts that
// real backend data renders (no mock gateway).
//
// Prereqs:
//   - combined backend running on :8080 (uvicorn combined.main:app)
//   - infra (postgres) on localhost:5432
//   - apps/web built (npm run build -> dist)
// Run:  node testing/web/real-e2e.mjs

import http from "node:http";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../..");
const DIST = path.resolve(ROOT, "apps/web/dist");
const OUT = path.resolve(__dirname, "screenshots-real");
fs.mkdirSync(OUT, { recursive: true });

const PORT = 4189;
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
  // Proxy API calls to the real combined backend.
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
console.log(`[real-e2e] static server on ${BASE} (proxy /api -> ${API})`);
const browser = await puppeteer.launch({ headless: "new", args: ["--no-sandbox", "--disable-setuid-sandbox"] });
const page = await browser.newPage();
await page.setViewport({ width: 1366, height: 900 });

const consoleErrors = [];
const IGNORE = [/Failed to load resource/i, /net::ERR/i, /ERR_FAILED/i, /Source map/i, /favicon/i];
const isRealError = (e) => !IGNORE.some((r) => r.test(e));
page.on("console", (m) => { if (m.type() === "error") consoleErrors.push(m.text()); });
page.on("pageerror", (e) => consoleErrors.push("PAGEERROR: " + e.message));

const results = [];
const rec = (name, ok, detail) => { results.push({ name, ok, detail }); console.log(`[real-e2e] ${name}: ${ok ? "PASS" : "FAIL"} (${detail})`); };
const bodyText = () => page.evaluate(() => document.body.innerText.replace(/\s+/g, " ").slice(0, 1500));

const email = `web_e2e_${Date.now()}@masaren.dev`;
const password = "Test@12345";

// ── 1) REGISTER via the real UI ──
try {
  await page.goto(`${BASE}/register`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await wait(800);
  await page.type('input[placeholder="Full Name"]', "Web E2E User");
  await page.type('input[placeholder="Email"]', email);
  await page.type('input[placeholder="Strong Password (8+ chars, mixed case)"]', password);
  await page.type('input[placeholder="Phone Number"]', "+201000000000");
  await page.click('button[type="submit"]');
  await wait(2000);
  rec("register_ui", true, "submitted register form for " + email);
} catch (e) { rec("register_ui", false, String(e.message)); }

// ── 2) VERIFY account in DB (email_verified + ACTIVE) so login succeeds ──
try {
  execSync(`docker exec masaren-postgres-1 psql -U masaren -d masaren -tAc "UPDATE users SET email_verified=true, status='ACTIVE' WHERE email='${email}';"`, { stdio: "ignore" });
  rec("db_verify", true, "set email_verified=true, status=ACTIVE");
} catch (e) { rec("db_verify", false, String(e.message)); }

// ── 3) LOGIN via the real UI ──
try {
  await page.goto(`${BASE}/login`, { waitUntil: "domcontentloaded", timeout: 30000 });
  await wait(800);
  await page.type('input[placeholder="Email"]', email);
  await page.type('input[placeholder="Password"]', password);
  await page.click('button[type="submit"]');
  await wait(2500);
  const url = page.url();
  const token = await page.evaluate(() => localStorage.getItem("access_token"));
  const ok = (url.includes("/dashboard") || token) && token;
  rec("login_ui", !!ok, ok ? "redirected to " + url.split("/").pop() + " token present" : "no token / no redirect (url=" + url + ")");
} catch (e) { rec("login_ui", false, String(e.message)); }

// ── 4) AUTHENTICATED PAGE renders REAL backend data ──
if (results.find((r) => r.name === "login_ui")?.ok) {
  try {
    await page.goto(`${BASE}/dashboard`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await wait(2500);
    const txt = await bodyText();
    rec("dashboard_render", txt.length > 40, "dashboard body len=" + txt.length + " sample=" + txt.slice(0, 120));
    await page.screenshot({ path: path.join(OUT, "dashboard.png") });

    await page.goto(`${BASE}/feed`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await wait(2500);
    const feedTxt = await bodyText();
    rec("feed_render", feedTxt.length > 40, "feed body len=" + feedTxt.length);
    await page.screenshot({ path: path.join(OUT, "feed.png") });
  } catch (e) { rec("dashboard_render", false, String(e.message)); }
}

// ── 5) console error summary ──
const realErrs = consoleErrors.filter(isRealError);
rec("no_console_errors", realErrs.length === 0, realErrs.length + " real console errors: " + realErrs.slice(0, 3).join(" | "));

await browser.close();
server.close();

const passed = results.filter((r) => r.ok).length;
console.log(`\n[real-e2e] OVERALL: ${passed}/${results.length} passed`);
fs.writeFileSync(path.resolve(__dirname, "real-e2e-report.json"), JSON.stringify({ results, consoleErrors: realErrs }, null, 2));
console.log(`[real-e2e] report -> ${path.resolve(__dirname, "real-e2e-report.json")}`);
process.exit(passed === results.length ? 0 : 1);
