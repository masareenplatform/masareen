import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";
import fs from "fs";

// Preview middleware: keep the Docusaurus docs (served from dist/docs) reachable.
// vite preview's SPA fallback rewrites unknown paths to the root app index.html,
// which makes "/docs" (no trailing slash) load the SPA and redirect to /dashboard.
// Here we redirect "/docs" -> "/docs/" and let "/docs/*" (no file ext) serve the
// docs index.html instead of the app SPA.
function docsPreviewMiddleware() {
  return {
    name: "docs-preview-middleware",
    configurePreviewServer(server: any) {
      server.middlewares.use((req: any, res: any, next: any) => {
        const url: string = req.url || "/";
        const pathname = url.split("?")[0];
        // Serve Android APKs with the correct MIME type so mobile browsers
        // don't rename them to *.apk.zip.
        if (pathname.endsWith(".apk")) {
          const apk = path.resolve(__dirname, "dist", pathname.slice(1));
          if (fs.existsSync(apk) && fs.statSync(apk).isFile()) {
            res.setHeader("Content-Type", "application/vnd.android.package-archive");
            res.setHeader("Content-Disposition", 'attachment; filename="masaren-app-release.apk"');
            fs.createReadStream(apk).pipe(res);
            return;
          }
        }
        if (pathname === "/docs") {
          res.statusCode = 301;
          res.setHeader("Location", "/docs/");
          res.end();
          return;
        }
        if (pathname.startsWith("/docs/")) {
          const docsRoot = path.resolve(__dirname, "dist/docs");
          const rel = pathname.slice("/docs/".length);
          const withoutQuery = pathname;
          // Try the exact file, else index.html (SPA-style) for extension-less paths.
          const candidate = path.join(docsRoot, rel);
          const isFile = rel && !rel.endsWith("/") && fs.existsSync(candidate) && fs.statSync(candidate).isFile();
          if (isFile) return next();
          if (!path.extname(withoutQuery)) {
            const idx = path.join(docsRoot, rel, "index.html");
            if (fs.existsSync(idx)) {
              res.setHeader("Content-Type", "text/html");
              fs.createReadStream(idx).pipe(res);
              return;
            }
          }
        }
        next();
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), docsPreviewMiddleware()],
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
  server: {
    port: 3000,
    host: true,
    strictPort: true,
    proxy: { "/api": "http://localhost:8080" },
    // Allow the public domain (and any LAN IP) to reach the dev server.
    allowedHosts: [
      "masareen.mediahubnetwork.net",
      "localhost",
      "41.33.197.134",
    ],
  },
  build: { outDir: "dist", sourcemap: true },
});
