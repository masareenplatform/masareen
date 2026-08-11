/**
 * MASAREN E2E — shared fixtures.
 *
 * Provides:
 *  - `server`  : ephemeral Node HTTP server serving dist/ with /api proxy to :8080
 *  - `page`    : a Playwright Page that always starts against `server.base`
 *  - `authedPage`: a Page whose localStorage already has a valid access_token
 *
 * Usage in tests:
 *   import { test, expect, BASE, API } from "./fixtures";
 */

import { test as base, expect, type Page } from "@playwright/test";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import net from "net";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.resolve(__dirname, "../dist");
const API_BASE = "http://localhost:8080";

// ─── MIME map ───────────────────────────────────────────────────────────────
const MIME: Record<string, string> = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".map": "application/json",
  ".webp": "image/webp",
};

// ─── Static server factory ───────────────────────────────────────────────────
function createStaticServer(): Promise<{ server: http.Server; base: string }> {
  return new Promise((resolve, reject) => {
    const srv = http.createServer((req, res) => {
      const rawUrl = req.url || "/";
      const urlPath = decodeURIComponent(rawUrl.split("?")[0]);

      // Proxy all /api/* to the real combined backend.
      if (urlPath.startsWith("/api/")) {
        const target =
          API_BASE +
          urlPath +
          (rawUrl.includes("?") ? rawUrl.slice(rawUrl.indexOf("?")) : "");
        const proxyReq = http.request(
          target,
          { method: req.method, headers: { ...req.headers, host: "localhost:8080" } },
          (proxyRes) => {
            const chunks: Buffer[] = [];
            proxyRes.on("data", (c) => chunks.push(c));
            proxyRes.on("end", () => {
              const body = Buffer.concat(chunks);
              const ct =
                proxyRes.headers["content-type"] || "application/json";
              res.writeHead(proxyRes.statusCode ?? 200, {
                "Content-Type": ct,
                "Access-Control-Allow-Origin": "*",
              });
              res.end(body);
            });
          }
        );
        req.on("data", (c) => proxyReq.write(c));
        req.on("end", () => proxyReq.end());
        proxyReq.on("error", () => {
          res.writeHead(502);
          res.end("Bad Gateway");
        });
        return;
      }

      // Static file serving with SPA fallback.
      let filePath = path.join(DIST, urlPath);
      try {
        if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
          filePath = path.join(DIST, "index.html");
        }
      } catch {
        filePath = path.join(DIST, "index.html");
      }

      fs.readFile(filePath, (err, data) => {
        if (err) {
          res.writeHead(404);
          res.end("Not Found");
          return;
        }
        const ext = path.extname(filePath);
        res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
        res.end(data);
      });
    });

    srv.listen(0, "127.0.0.1", () => {
      const addr = srv.address() as net.AddressInfo;
      resolve({ server: srv, base: `http://127.0.0.1:${addr.port}` });
    });
    srv.on("error", reject);
  });
}

// ─── API helpers ─────────────────────────────────────────────────────────────
interface TokenBundle {
  access_token: string;
  user_id: string;
  role: string;
  email: string;
}

async function apiPost(path: string, body: unknown): Promise<any> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  // unwrap { success, data } envelope if present
  return json?.data ?? json;
}

async function registerAndLogin(suffix: string): Promise<TokenBundle> {
  const email = `e2e_${suffix}_${Date.now()}@masaren.dev`;
  const password = "E2eTest@1234";

  await apiPost("/api/v1/users/register", {
    full_name: "E2E " + suffix,
    email,
    password,
    phone: "+201000000099",
    role: "INDIVIDUAL",
    audience: "PROFESSIONAL",
  });

  const loginData = await apiPost("/api/v1/auth/login", { email, password });
  return {
    access_token: loginData.access_token,
    user_id: loginData.user_id,
    role: loginData.role,
    email,
  };
}

// ─── Fixtures ────────────────────────────────────────────────────────────────
type Fixtures = {
  /** The base URL of the per-test static server */
  BASE: string;
  /** A Playwright page wired to BASE (not yet authenticated) */
  page: Page;
  /** A Playwright page with localStorage already populated with a valid token */
  authedPage: Page;
  /** Token bundle for the authenticated user */
  token: TokenBundle;
};

export const test = base.extend<Fixtures>({
  BASE: async ({}, use) => {
    const { server, base } = await createStaticServer();
    await use(base);
    server.close();
  },

  page: async ({ browser, BASE }, use) => {
    const ctx = await browser.newContext({ baseURL: BASE });
    const pg = await ctx.newPage();
    // Suppress non-critical console noise in test output.
    pg.on("console", (m) => {
      if (m.type() === "error") {
        const t = m.text();
        // Only surface real app errors, not favicon/network/sourcemap noise.
        if (
          !t.includes("favicon") &&
          !t.includes("net::ERR") &&
          !t.includes("Source Map")
        ) {
          console.error("[PAGE ERROR]", t);
        }
      }
    });
    await use(pg);
    await ctx.close();
  },

  token: async ({}, use) => {
    const bundle = await registerAndLogin("playwright");
    await use(bundle);
  },

  authedPage: async ({ browser, BASE, token }, use) => {
    const ctx = await browser.newContext({ baseURL: BASE });
    const pg = await ctx.newPage();

    // Navigate to BASE first so localStorage is available for this origin.
    await pg.goto(BASE);
    await pg.waitForLoadState("domcontentloaded");

    // Inject token.
    await pg.evaluate((t) => {
      localStorage.setItem("access_token", t.access_token);
      localStorage.setItem(
        "user",
        JSON.stringify({
          id: t.user_id,
          email: t.email,
          role: t.role,
          full_name: "E2E playwright",
        })
      );
    }, token);

    // Reload so the React app reads the token from localStorage on mount
    // (the AuthProvider useEffect triggers on initial load, not on evaluate).
    await pg.reload();
    await pg.waitForLoadState("domcontentloaded");
    // Give the auth state time to initialize
    await pg.waitForTimeout(800);

    await use(pg);
    await ctx.close();
  },
});

export { expect };
export const BASE = "";  // sentinel – use the `BASE` fixture value inside tests
