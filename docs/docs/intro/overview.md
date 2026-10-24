---
id: overview
title: Welcome to MASAREEN
slug: /
sidebar_position: 1
---

# MASAREEN, Infrastructure for Impact

<blockquote className="masareen-card">
  <strong>Prove impact. Scale change. Earn trust.</strong> MASAREEN is the verified-impact
  network where NGOs, governments, companies, and communities turn real-world work into
  trusted, measurable proof, backed by AI + GPS verification, on-chain-style reputation,
  and a transparent opportunity marketplace.
</blockquote>

MASAREEN (مسارين، "two paths") is a platform built to solve one stubborn problem in the
social-impact world: **good work is invisible**. A volunteer plants a thousand trees, a
municipality runs a recycling program, an NGO delivers food aid, and almost none of it is
provable afterward. Paper reports rot, memories fade, and trust is spent on self-reporting.

MASAREEN makes impact **legible, verifiable, and portable**:

- You do field work → you **capture evidence** (photo, GPS, document, audio) from the mobile app.
- An **AI + human verification pipeline** checks that the evidence is real and on-site.
- Verified work becomes **reputation** (a "credit score for goodness", the PMS/OII scores).
- That reputation **unlocks opportunities** (tasks, funding, partnerships) across the network.

This documentation covers everything: why the platform exists, how its workflow and
verification pipelines work, the full backend architecture, the web + mobile frontends,
and step-by-step guides for individuals, organizations, and administrators.

<div className="masareen-grid">
  <div className="masareen-card">
    <span className="masareen-pill masareen-pill--brand">Concept</span>
    <h3>Why MASAREEN exists</h3>
    <p>Read the problem, the vision, and the two-path workflow model.</p>
    <a href="/docs/concepts/why-masareen">Start here →</a>
  </div>
  <div className="masareen-card">
    <span className="masareen-pill masareen-pill--azure">Backend</span>
    <h3>37 microservices, one process</h3>
    <p>The combined FastAPI backend, verification engine, and REST API.</p>
    <a href="/docs/backend/architecture">Explore →</a>
  </div>
  <div className="masareen-card">
    <span className="masareen-pill masareen-pill--accent">Frontend</span>
    <h3>Web + Mobile</h3>
    <p>React/Vite web app and the Flutter Android app.</p>
    <a href="/docs/frontend/overview">Learn more →</a>
  </div>
  <div className="masareen-card">
    <span className="masareen-pill masareen-pill--brand">Guides</span>
    <h3>How-to</h3>
    <p>Register, capture evidence, run an org, administer the platform.</p>
    <a href="/docs/guides/quickstart">Get going →</a>
  </div>
</div>

## At a glance

| Layer | Technology | Notes |
|-------|-----------|-------|
| Web app | React 18 + TypeScript + Vite | Production build served at `masareen.mediahubnetwork.net` |
| Mobile app | Flutter 3.32 / Dart 3.8 | Plugin-free (`http` + `url_launcher`), Android APK |
| Backend | FastAPI (Python) | 37 services merged into one `uvicorn` process on `:8080` |
| Database | PostgreSQL 16 + Neo4j + Redis | Relational core, graph for networks, cache/queue |
| Auth | JWT + Google OAuth | `AUTO_VERIFY_ON_REGISTER` for demo simplicity |
| Verification | AI review → human review → verdict | Evidence pipelines with GPS + media checks |

> The live platform is at **https://masareen.mediahubnetwork.net**. The Android app is
> downloadable from the landing page and the footer of this site.
