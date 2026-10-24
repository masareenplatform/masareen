---
id: web
title: Web Application
sidebar_position: 2
---

# Web Application (React + Vite)

## Stack

- **React 18 + TypeScript**, bundled by **Vite**.
- **React Router** for routing (`/`, `/login`, `/feed`, `/admin`, marketing pages).
- **Recharts** for the admin analytics dashboard.
- **three.js** for the hero cyberpunk convergence animation.
- Tailwind-style utility classes + a small set of component classes (`btn-brand`,
  `btn-accent`, `card`, `chip-brand`, `app-shell`, `nav-search`, `post-card`).

## Key directories

```text
apps/web/src/
├─ pages/         LandingPage, LoginPage, AdminPage, HowItWorks, Pricing,
│                 About, Resources, Solutions, Verification, Feed...
├─ components/
│  ├─ layout/     Layout, TopNav (dark glass nav w/ overlaid logo), Sidebar
│  ├─ common/     Branding (real logo artwork), GoogleAuth, Showcase, NeonPaths
│  ├─ social/     PostCard, Composer, Messenger
│  └─ icons/      Icon set
├─ services/api.ts   typed HTTP client
├─ store/authStore.ts  auth state (JWT in memory)
└─ i18n/          EN/AR
```

## Layout & branding

- **TopNav**, sticky dark glass bar; the MASAREEN wordmark sits in a white pill overlaid
  on the bar (logo asset `public/logo-full.png?v=4`).
- **Sidebar**, app navigation with a 54px logo pill.
- **App shell**, soft gradient canvas (`app-shell`) for the authenticated experience.
- **PostCard**, hover-lift cards in the feed.

## Marketing & landing

The landing page (`LandingPage.tsx`) is a full dark cinematic editorial experience:
scroll-progress bar, trust band, bento features, a tabbed "explorer", a three.js neon
convergence, an interactive football/profiles section, a verification explainer, and a
full-bleed CTA. All menu links are public (no auth required).

## Running locally

```bash
cd apps/web
npm install
npm run dev          # Vite dev server (HMR)
# or production build:
npm run build
npm run preview -- --port 9000 --host 0.0.0.0
```

The production build is what is served at `masareen.mediahubnetwork.net`.

## Notes

- The web app calls the backend at `/api/v1` (relative), which the domain proxies to `:8080`.
- Google sign-in: `GoogleAuth` opens a popup to `/oauth/google/callback`, then routes to
  `/onboarding`. Requires the Google Cloud redirect URI to be registered.
