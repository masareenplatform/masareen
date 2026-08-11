import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import {
  IconCompass, IconCheck, IconTrending, IconImpact, IconShield, IconUsers,
  IconEvidence, IconProgram, IconTask, IconGlobe, IconSparkles, IconArrowRight,
  IconDownload, IconWallet, IconAds, IconHandshake, IconBadge, IconVideo,
  IconImage, IconSearch, IconGroup, IconHeart, IconChat, IconReports,
  IconBell, IconUser, IconTrophy, IconStar, IconFlag,
} from "../components/icons/Icons";
import { useReveal, useCountUp } from "../hooks/anim";
import { BrandMark, BrandWordmark } from "../components/common/Branding";
import { useAuth } from "../store/authStore";
import { GoogleAuth } from "../components/common/GoogleAuth";
import { StackedAvatars, VennAvatars, PhoneMock, FaceAvatar } from "../components/common/Showcase";
import NeonPaths from "../components/common/NeonPaths";

const APK_URL = "/downloads/masaren-app-release.apk";

/* ── shared bits ──────────────────────────────────────────────────────────── */

function Reveal({ children, className = "", variant = "up", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  const base = variant === "up" ? "reveal" : `reveal reveal-${variant}`;
  return (
    <div ref={ref} className={`${base} ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

function Counter({ end, suffix = "", label, icon: Icon, dark = false, decimals = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>({ threshold: 0.4 });
  const value = useCountUp(end, shown, 1700, decimals);
  return (
    <div ref={ref} className="text-center">
      {Icon && <div className={`mx-auto mb-3 grid h-12 w-12 place-items-center rounded-2xl ${dark ? "bg-white/10 text-white" : "bg-brand-50 text-brand"}`}><Icon size={24} /></div>}
      <div className={`stat-big text-4xl sm:text-5xl ${dark ? "text-white" : "text-ink"}`}>{value}{suffix}</div>
      <div className={`mt-1 text-sm ${dark ? "text-white/70" : "text-muted"}`}>{label}</div>
    </div>
  );
}

/* ── top nav (public) — white inverted logo overlaid on dark bar ─────────── */

function Nav() {
  const { isAuthenticated, user } = useAuth();
  const initial = (user?.full_name || user?.email || "M").toString().charAt(0).toUpperCase();
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 backdrop-blur-md">
      <div className="mx-auto flex h-20 max-w-6xl items-center gap-3 px-4">
        <Link to="/" className="flex items-center gap-2">
          <span className="grid place-items-center rounded-2xl px-3 py-1.5 shadow-card">
            <img src="/logo-512.png" alt="MASAREEN" style={{ height: 54, width: "auto", objectFit: "contain", filter: "brightness(0) invert(1)" }} />
          </span>
        </Link>
        <nav className="ms-6 hidden items-center gap-1 text-sm font-medium text-white/75 lg:flex">
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Platform ▾</button>
            <div className="mega grid grid-cols-2 gap-1">
              {[["Feed & Stories","/feed"],["Programs","/programs"],["Tasks","/tasks"],["Evidence","/evidence"],["Impact Passport","/passport"],["Opportunities","/opportunities"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Solutions ▾</button>
            <div className="mega grid grid-cols-2 gap-1">
              {[["NGOs","/solutions/ngo"],["Corporates","/solutions/corporate"],["Government","/solutions/government"],["Universities","/solutions/university"],["Investors","/solutions/investor"],["Communities","/solutions/community"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <div className="nav-item">
            <button className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Resources ▾</button>
            <div className="mega grid grid-cols-1 gap-1">
              {[["How verification works","/how-it-works"],["Evidence & proof","/evidence"],["SDGs & Egypt 2030","#sdg"],["Pricing","/pricing"],["About","/about"],["Blog & guides","/resources"]].map(([t,l]) => (
                <Link key={t} to={l} className="rounded-lg px-3 py-2 text-sm text-ink hover:bg-canvas">{t}</Link>
              ))}
            </div>
          </div>
          <a href="#profiles" className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Profiles</a>
          <a href="#football" className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Football</a>
          <a href="#features" className="rounded-lg px-3 py-1.5 hover:bg-white/10 hover:text-white">Features</a>
        </nav>
        <div className="ms-auto flex items-center gap-2">
          {isAuthenticated ? (
            <Link to="/feed" className="btn-gold px-4 py-1.5 text-sm">Open app</Link>
          ) : (
            <>
              <Link to="/login" className="rounded-xl px-3 py-1.5 text-sm font-semibold text-white/90 hover:bg-white/10">Sign in</Link>
              <a href="#download" className="btn-gold px-3 py-1.5 text-sm">Get the app</a>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

/* ── dark cinematic hero ──────────────────────────────────────────────────── */

function Hero({ onEmail, email, setEmail, sent, reqError }: any) {
  return (
    <section className="hero-dark pt-28 pb-20">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-60" />
      <img src="/logo-full.png" alt="" className="logo-watermark" aria-hidden="true" />
      <div className="pointer-events-none absolute -left-24 top-24 h-72 w-72 rounded-full bg-brand/30 blur-3xl" />
      <div className="pointer-events-none absolute right-10 top-40 h-72 w-72 rounded-full bg-accent/20 blur-3xl" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-4 lg:grid-cols-2">
        <Reveal>
          <span className="eyebrow text-white/80"><IconSparkles size={14} /> Now in alpha · Join the movement</span>
          <h1 className="hero-tracking mt-5 font-display text-5xl font-extrabold leading-[1.05] text-white sm:text-6xl">
            Prove impact.<br />Scale change.<br /><span className="gradient-text">Earn trust.</span>
          </h1>
          <p className="text-white-soft mt-5 max-w-md text-lg">
            MASAREEN is the verified-impact network where NGOs, governments and communities turn
            real-world work into trusted, measurable proof — backed by POAI verification.
          </p>
          <form className="mt-7 flex max-w-md flex-col gap-2 sm:flex-row" onSubmit={(e) => { e.preventDefault(); onEmail(); }}>
            <input className="glass-input !bg-white/10 !border-white/20 !text-white placeholder-white/50" placeholder="you@organization.org" value={email} onChange={(e) => setEmail(e.target.value)} type="email" required />
            <button className="btn-gold whitespace-nowrap text-white" type="submit">Request access</button>
          </form>
          <div className="mt-3 max-w-md">
            <div className="flex items-center gap-3">
              <span className="h-px flex-1 bg-white/15" />
              <span className="text-xs font-semibold uppercase tracking-wide text-white/50">or</span>
              <span className="h-px flex-1 bg-white/15" />
            </div>
            <div className="mt-3"><GoogleAuth mode="register" /></div>
          </div>
          {sent && <p className="mt-2 text-sm font-medium text-emerald-300">You're on the list — your alpha account is ready. 🎉</p>}
          {reqError && <p className="mt-2 text-sm font-medium text-rose-300">{reqError}</p>}
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <StackedAvatars names={["amira.s","yusuf.a","lina.f","omar.t","sara.n","khaled.h"]} size={32} />
            <p className="text-sm text-white/75">Joined by <span className="font-semibold text-white">3,200+ impact workers</span> across 9 countries.</p>
          </div>
        </Reveal>

        <Reveal variant="right" delay={120}>
          <div className="glass-dark animate-float p-0 overflow-hidden">
            <div className="flex items-center gap-3 border-b border-white/10 bg-white/5 px-4 py-3">
              <BrandMark size={30} />
              <div><p className="text-sm font-semibold text-white">Amira Saleh</p><p className="text-xs text-white/60">GreenRoots NGO · Verified</p></div>
              <span className="chip-accent ms-auto">Impact</span>
            </div>
            <div className="space-y-3 p-4">
              <p className="text-sm text-white/90">Planted 12,000 mangrove saplings with 340 volunteers. Geotagged, audited, verified. 🌱</p>
              <div className="grid grid-cols-3 gap-2 text-center">
                <div className="rounded-xl bg-white/5 p-2"><p className="stat-big text-accent-300">12K</p><p className="text-[10px] text-white/60">seedlings</p></div>
                <div className="rounded-xl bg-white/5 p-2"><p className="stat-big text-white">340</p><p className="text-[10px] text-white/60">volunteers</p></div>
                <div className="rounded-xl bg-white/5 p-2"><p className="stat-big text-white">98%</p><p className="text-[10px] text-white/60">verified</p></div>
              </div>
              <div className="flex items-center gap-4 border-t border-white/10 pt-3 text-sm text-white/70">
                <span className="flex items-center gap-1.5 text-rose-400"><IconTrending size={16} /> 482</span>
                <span className="flex items-center gap-1.5"><IconUsers size={16} /> 73</span>
                <span className="ms-auto chip-brand">POAI ✓</span>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── trust / logo cloud ───────────────────────────────────────────────────── */

function TrustBand() {
  const orgs = ["GreenRoots", "Cairo University", "Masrena CSR", "Nile Foundation", "EcoEgypt", "HopeBuilders", "Data4Good", "CivicLabs"];
  return (
    <section className="bg-white py-10">
      <p className="mb-5 text-center text-xs font-semibold uppercase tracking-[0.18em] text-muted">Trusted by impact teams across Egypt & beyond</p>
      <div className="logo-cloud mx-auto max-w-5xl px-4">
        {orgs.map((o) => (
          <span key={o} className="pill"><BrandMark size={18} /> {o}</span>
        ))}
      </div>
    </section>
  );
}

/* ── bento features (dark) ────────────────────────────────────────────────── */

const BENTO = [
  { icon: IconShield, title: "POAI Verification", text: "Every claim scored, audited and traceable through a pipeline you can trust.", cls: "b-tall", big: true },
  { icon: IconCompass, title: "Impact Discovery", text: "A feed of verified stories ranked by real outcomes, not engagement bait.", cls: "b-wide" },
  { icon: IconWallet, title: "MASAREEN Coin", text: "An impact economy with transparent fees.", cls: "b-2" },
  { icon: IconAds, title: "Impact Ads", text: "Fraud-resistant delivery to the right communities.", cls: "b-2" },
  { icon: IconProgram, title: "Programs & Tasks", text: "Launch, join and complete real programs with lifecycle tracking.", cls: "b-3" },
  { icon: IconEvidence, title: "Evidence & GPS", text: "Geo-tagged proof attached to every action.", cls: "b-3" },
];

function Features() {
  return (
    <section id="features" className="hero-dark section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="max-w-2xl">
          <span className="eyebrow text-white/80"><IconSparkles size={14} /> The platform</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Everything impact teams need, in one place</h2>
          <p className="text-white-soft mt-3 text-lg">Social, verified and measurable — built for the people actually doing the work.</p>
        </Reveal>
        <div className="bento mt-12">
          {BENTO.map((f, i) => (
            <Reveal key={f.title} delay={(i % 3) * 80} className={`glass-dark hover-lift p-6 ${f.cls}`}>
              <div className={`mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-white/10 text-white`}><f.icon size={24} /></div>
              <h3 className={`font-display font-bold text-white ${f.big ? "text-2xl" : "text-lg"}`}>{f.title}</h3>
              <p className="text-white-soft mt-2 text-sm">{f.text}</p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── tabbed explorer (dark) — fixed contrast ──────────────────────────────── */

const TABS = [
  { key: "verify", label: "Verify", icon: IconShield, title: "POAI verification, end to end", body: "Submit an outcome. Our pipeline scores evidence, runs an audit trail and stamps it POAI-verified — so funders see proof, not promises.", points: ["Geo-tagged evidence", "Auditable audit trail", "Tamper-resistant scoring"] },
  { key: "programs", label: "Run programs", icon: IconProgram, title: "Programs & tasks that ship", body: "Spin up programs, assign tasks and track them from draft to verified. Everyone sees the same source of truth.", points: ["Lifecycle tracking", "Role-based assignment", "Live progress"] },
  { key: "coin", label: "Earn", icon: IconWallet, title: "An economy for impact", body: "MASAREEN Coin rewards verified outcomes with transparent brokerage — funding the platform and the people creating change.", points: ["Transparent fees", "On-chain proof", "Impact payouts"] },
];

function Explorer() {
  const [tab, setTab] = useState("verify");
  const active = TABS.find((t) => t.key === tab)!;
  return (
    <section className="bg-[#06121F] section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
      <div className="relative mx-auto max-w-5xl px-4">
        <Reveal className="text-center">
          <span className="eyebrow text-white/80 justify-center"><IconCompass size={14} /> How it works</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white">One workflow, three moves</h2>
        </Reveal>
        <Reveal className="mt-8 flex justify-center">
          <div className="tabs">
            {TABS.map((t) => (
              <button key={t.key} className={`tab ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)}>
                <span className="inline-flex items-center gap-1.5"><t.icon size={16} /> {t.label}</span>
              </button>
            ))}
          </div>
        </Reveal>
        <Reveal key={active.key} className="tab-body mt-10 grid gap-8 rounded-3xl glass-dark p-8 md:grid-cols-2">
          <div>
            <h3 className="font-display text-2xl font-bold text-white">{active.title}</h3>
            <p className="mt-3 text-base text-white/85">{active.body}</p>
            <ul className="mt-5 space-y-2">
              {active.points.map((p) => (
                <li key={p} className="flex items-center gap-2 text-base text-white/85"><IconCheck className="text-emerald-300" size={18} /> {p}</li>
              ))}
            </ul>
            <Link to="/login" className="btn-gold mt-6 px-5 py-2.5 text-sm text-white">Try it free</Link>
          </div>
          <div className="grid place-items-center">
            <div className="grid h-40 w-40 place-items-center rounded-3xl bg-gradient-to-br from-brand to-accent text-white shadow-glow">
              <active.icon size={64} />
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── neon convergence (two paths) ─────────────────────────────────────────── */

function Convergence() {
  return (
    <section className="relative overflow-hidden section-pad" style={{ background: "radial-gradient(60% 80% at 50% 0%, #0a1730 0%, #050b16 60%, #04070f 100%)" }}>
      <div className="pointer-events-none absolute inset-0 bg-grid-fade opacity-25" />
      <div className="relative mx-auto max-w-6xl px-4 text-center">
        <Reveal className="text-center">
          <span className="eyebrow text-cyan-300 justify-center" style={{ color: "#5ff0ff" }}><IconHandshake size={14} /> Two streams, one truth</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Where every path meets verified impact</h2>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Two streams of activity — people and organizations — race across the network, converge and collide into a single trusted outcome. That moment of collision is POAI verification.</p>
        </Reveal>
      </div>
      <div className="relative mt-8 w-full">
        <NeonPaths height={Math.max(360, Math.min(460, Math.floor((typeof window !== "undefined" ? window.innerWidth : 1200) * 0.32)))} />
      </div>
    </section>
  );
}

/* ── how it works stepper (light) ─────────────────────────────────────────── */

const STEPS = [
  { n: "01", icon: IconUser, t: "Create your impact profile", d: "Sign up as an individual, NGO or government. Verified from day one." },
  { n: "02", icon: IconProgram, t: "Launch or join programs", d: "Post real-world work, assign tasks and invite your community." },
  { n: "03", icon: IconShield, t: "Verify with POAI", d: "Attach evidence. Our pipeline scores and stamps it trusted." },
  { n: "04", icon: IconTrending, t: "Scale & earn", d: "Track outcomes, earn MASAREEN Coin and grow your impact." },
];

function How() {
  return (
    <section id="how" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><BrandMark size={18} /> Your path</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">From sign-up to scaled impact</h2>
        </Reveal>
        <div className="stepper mt-12">
          {STEPS.map((s, i) => (
            <Reveal key={s.n} delay={i * 90} className="card p-6">
              <div className="flex items-center justify-between">
                <span className="step-num"><s.icon size={22} /></span>
                <span className="font-display text-3xl font-extrabold text-line">{s.n}</span>
              </div>
              <h3 className="mt-4 font-display text-lg font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm text-muted">{s.d}</p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── stats band (dark) — realistic modest-server numbers ──────────────────── */

function Stats() {
  return (
    <section className="bg-[#06121F] section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-30" />
      <div className="relative mx-auto grid max-w-5xl grid-cols-2 gap-10 px-4 sm:grid-cols-4">
        <Counter end={18400} label="Verified impact actions" icon={IconImpact} dark />
        <Counter end={3200} label="Alpha members" suffix="+" icon={IconUsers} dark />
        <Counter end={17} label="SDGs tracked" icon={IconGlobe} dark />
        <Counter end={9} label="Countries" icon={IconSparkles} dark />
      </div>
    </section>
  );
}

/* ── profile-type distinctions (interactive) ──────────────────────────────── */

const PROFILES = [
  { key: "media", icon: IconVideo, name: "Media Institution", tag: "Press & broadcast", accent: "#0EA5E9",
    blurb: "Publish verified impact stories with proof attached. Every article links to the underlying POAI claim so readers trust the source.",
    example: { name: "Nile Vision Media", handle: "@nilevision", stats: ["1,240 verified stories", "92% trust score", "18 SDGs covered"] } },
  { key: "gov", icon: IconFlag, name: "Governmental Institution", tag: "Public sector", accent: "#0250A3",
    blurb: "Report program delivery transparently. Citizens see audited outcomes, and agencies track Egypt Vision 2030 progress in real time.",
    example: { name: "Ministry of Environment", handle: "@eg.env", stats: ["340 programs", "Real-time 2030 dashboard", "Public audit trail"] } },
  { key: "sport", icon: IconTrophy, name: "Sport Institution", tag: "Clubs & federations", accent: "#2A9D45",
    blurb: "Turn matches, academies and community clinics into verified impact — from youth training to stadium sustainability.",
    example: { name: "Cairo United FC", handle: "@cairounited", stats: ["240 players tracked", "14 community clinics", "Verified youth academy"] } },
  { key: "company", icon: IconBadge, name: "Company / Entrepreneur", tag: "CSR & startups", accent: "#8B5CF6",
    blurb: "Make CSR and ESG claims auditable instead of aspirational. Startups prove traction with evidence, not screenshots.",
    example: { name: "Masrena CSR", handle: "@masrena", stats: ["3 wells funded", "ESG-ready reports", "Coin-backed grants"] } },
];

function Profiles() {
  const [active, setActive] = useState("media");
  const p = PROFILES.find((x) => x.key === active)!;
  return (
    <section id="profiles" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconUsers size={14} /> One network, many profiles</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">A profile built for who you are</h2>
          <p className="mx-auto mt-3 max-w-xl text-muted">MASAREEN adapts to your institution. Pick a type to see how a real profile looks and what it can prove.</p>
        </Reveal>

        <div className="mt-8 flex flex-wrap justify-center gap-3">
          {PROFILES.map((x) => (
            <button
              key={x.key}
              onClick={() => setActive(x.key)}
              className={`tile flex items-center gap-2 rounded-2xl border bg-white px-4 py-3 text-left ${active === x.key ? "tile-active" : "border-line"}`}
            >
              <span className="grid h-9 w-9 place-items-center rounded-xl text-white" style={{ background: x.accent }}><x.icon size={18} /></span>
              <span><span className="block text-sm font-bold text-ink">{x.name}</span><span className="block text-xs text-muted">{x.tag}</span></span>
            </button>
          ))}
        </div>

        <Reveal key={p.key} className="mt-8 grid gap-6 rounded-3xl border border-line bg-white p-6 shadow-card md:grid-cols-2">
          <div>
            <div className="flex items-center gap-3">
              <span className="grid h-12 w-12 place-items-center rounded-2xl text-white" style={{ background: p.accent }}><p.icon size={22} /></span>
              <div><p className="font-display text-xl font-bold text-ink">{p.name}</p><p className="text-sm text-muted">{p.tag}</p></div>
            </div>
            <p className="mt-4 text-sm text-muted">{p.blurb}</p>
            <div className="mt-5 rounded-2xl bg-canvas p-4">
              <div className="flex items-center gap-3">
                <FaceAvatar seed={p.example.handle} size={48} />
                <div><p className="text-sm font-semibold text-ink">{p.example.name}</p><p className="text-xs text-muted">{p.example.handle}</p></div>
                <span className="chip-brand ms-auto">Verified</span>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                {p.example.stats.map((s) => (
                  <div key={s} className="rounded-xl bg-white p-2 ring-1 ring-line"><p className="text-[11px] font-semibold text-ink">{s}</p></div>
                ))}
              </div>
            </div>
          </div>
          <div className="grid place-items-center rounded-2xl bg-aurora-light p-6">
            <p className="text-center text-sm text-muted">Visual profile preview for <span className="font-semibold text-ink">{p.name}</span> — a verified impact passport tailored to the institution type, with its own proof widgets and public dashboard.</p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── Egyptian football (interactive, comprehensive) ───────────────────────── */

const PLAYERS = [
  { name: "Mohamed Salah", club: "Liverpool", pos: "Forward", goals: 17, matches: 28, rating: 8.9, sdg: "Good Health", img: "https://en.wikipedia.org/wiki/Special:FilePath/Mohamed_Salah_2018.jpg" },
  { name: "Mohamed Elneny", club: "Arsenal", pos: "Midfielder", goals: 2, matches: 22, rating: 7.6, sdg: "Quality Education", img: "https://en.wikipedia.org/wiki/Special:FilePath/Mohamed_Elneny_2018.jpg" },
  { name: "Ahmed Hegazi", club: "Al-Ittihad", pos: "Defender", goals: 3, matches: 21, rating: 7.5, sdg: "Reduced Inequalities", img: "https://en.wikipedia.org/wiki/Special:FilePath/Ahmed_Hegazi_2018.jpg" },
  { name: "Trezeguet", club: "Trabzonspor", pos: "Winger", goals: 9, matches: 24, rating: 7.8, sdg: "Decent Work", img: "https://en.wikipedia.org/wiki/Special:FilePath/Mahmoud_Trezeguet_2019.jpg" },
  { name: "Mohamed El Shenawy", club: "Al Ahly", pos: "Goalkeeper", goals: 0, matches: 26, rating: 8.0, sdg: "Clean Water", img: "https://en.wikipedia.org/wiki/Special:FilePath/Mohamed_El_Shenawy_2018.jpg" },
  { name: "Mostafa Mohamed", club: "Nantes", pos: "Striker", goals: 12, matches: 20, rating: 7.9, sdg: "Gender Equality", img: "https://en.wikipedia.org/wiki/Special:FilePath/Mostafa_Mohamed_2021.jpg" },
];

function Football() {
  const [sel, setSel] = useState(0);
  const p = PLAYERS[sel];
  const maxGoals = Math.max(...PLAYERS.map((x) => x.goals));
  return (
    <section id="football" className="hero-dark section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="eyebrow text-white/80 justify-center"><IconTrophy size={14} /> Egyptian football, verified</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Impact beyond the scoreboard</h2>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Clubs, players and academies turn every match, clinic and community session into verified impact — mapped to the SDGs. Tap a player to explore.</p>
        </Reveal>

        <div className="mt-10 grid gap-6 lg:grid-cols-3">
          <Reveal className="lg:col-span-2 rounded-3xl glass-dark p-6">
            <div className="flex items-center gap-4">
              <FaceAvatar src={p.img} seed={p.name} size={64} ring />
              <div>
                <p className="font-display text-2xl font-bold text-white">{p.name}</p>
                <p className="text-sm text-white/70">{p.club} · {p.pos}</p>
              </div>
              <div className="ms-auto text-right">
                <p className="stat-big text-3xl text-white">{p.rating}</p>
                <p className="text-[11px] text-white/60">performance index</p>
              </div>
            </div>
            <div className="mt-6 space-y-4">
              <div>
                <div className="mb-1 flex justify-between text-sm text-white/80"><span>Goals</span><span className="font-semibold text-white">{p.goals}</span></div>
                <div className="h-2.5 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-gradient-to-r from-brand to-accent" style={{ width: `${(p.goals / maxGoals) * 100}%` }} /></div>
              </div>
              <div>
                <div className="mb-1 flex justify-between text-sm text-white/80"><span>Matches played</span><span className="font-semibold text-white">{p.matches}</span></div>
                <div className="h-2.5 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-gradient-to-r from-brand to-accent" style={{ width: `${(p.matches / 25) * 100}%` }} /></div>
              </div>
              <div className="flex items-center gap-2 pt-2">
                <IconGlobe size={16} className="text-accent-300" />
                <span className="text-sm text-white/85">SDG impact focus: <span className="font-semibold text-white">{p.sdg}</span></span>
              </div>
            </div>
            <div className="mt-6 grid grid-cols-3 gap-3 text-center">
              <div className="rounded-2xl bg-white/5 p-3"><p className="stat-big text-2xl text-white">{p.goals}</p><p className="text-[11px] text-white/60">goals</p></div>
              <div className="rounded-2xl bg-white/5 p-3"><p className="stat-big text-2xl text-white">{p.matches}</p><p className="text-[11px] text-white/60">matches</p></div>
              <div className="rounded-2xl bg-white/5 p-3"><p className="stat-big text-2xl text-white">{p.rating}</p><p className="text-[11px] text-white/60">index</p></div>
            </div>
          </Reveal>

          <Reveal delay={120} className="rounded-3xl glass-dark p-3">
            <p className="px-2 pt-2 text-xs font-semibold uppercase tracking-wide text-white/60">Squad</p>
            <div className="mt-2 space-y-1">
              {PLAYERS.map((x, i) => (
                <button key={x.name} onClick={() => setSel(i)} className={`tile flex w-full items-center gap-3 rounded-xl p-2 text-left ${sel === i ? "tile-active bg-white/10" : ""}`}>
                  <FaceAvatar src={x.img} seed={x.name} size={36} />
                  <div className="min-w-0"><p className="truncate text-sm font-semibold text-white">{x.name}</p><p className="truncate text-[11px] text-white/60">{x.club}</p></div>
                  <span className="ms-auto text-sm font-bold text-white">{x.goals}</span>
                </button>
              ))}
            </div>
          </Reveal>
        </div>

        <Reveal className="mt-6 grid gap-4 sm:grid-cols-3">
          <div className="rounded-2xl glass-dark p-5"><p className="stat-big text-3xl text-white">240</p><p className="text-sm text-white/70">Players with verified profiles</p></div>
          <div className="rounded-2xl glass-dark p-5"><p className="stat-big text-3xl text-white">14</p><p className="text-sm text-white/70">Clubs on the network</p></div>
          <div className="rounded-2xl glass-dark p-5"><p className="stat-big text-3xl text-white">31</p><p className="text-sm text-white/70">Community clinics verified</p></div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── verification: event-driven + data-driven (visual) ────────────────────── */

const VERIFY_FLOW = [
  { icon: IconImpact, t: "Event captured", d: "An action fires — a tree planted, a clinic run, a goal scored. It becomes an event in the stream." },
  { icon: IconEvidence, t: "Evidence attached", d: "Photos, GPS, receipts and sensors bundle into a tamper-evident evidence package." },
  { icon: IconShield, t: "POAI scoring", d: "The algorithm scores plausibility, completeness and SDG fit in real time." },
  { icon: IconReports, t: "Audit & decision", d: "Low-confidence events route to a human or partner audit; the rest auto-verify." },
  { icon: IconCheck, t: "Verified & published", d: "Outcome is stamped POAI-verified and flows into dashboards and the impact economy." },
];

function Verification() {
  const [open, setOpen] = useState(0);
  return (
    <section id="verification" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconShield size={14} /> Event-driven & data-driven</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">Verification as a live data pipeline</h2>
          <p className="mx-auto mt-3 max-w-2xl text-muted">Every claim moves through an event-driven pipeline. Evidence and signals stream in, models score continuously, and decisions are logged — so impact is provable, not performative.</p>
        </Reveal>

        <div className="mt-10 grid gap-8 rounded-3xl border border-line bg-white p-6 shadow-card md:grid-cols-2">
          <div>
            {VERIFY_FLOW.map((s, i) => (
              <button key={i} onClick={() => setOpen(i)} className={`flow-step flex w-full gap-4 rounded-xl p-3 text-left transition ${open === i ? "bg-brand-50" : "hover:bg-canvas"}`}>
                <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl text-white transition ${open === i ? "bg-brand" : "bg-canvas text-brand"}`}><s.icon size={18} /></span>
                <div><p className="text-sm font-semibold text-ink">{s.t}</p><p className="text-xs text-muted">{s.d}</p></div>
              </button>
            ))}
          </div>
          <div className="grid place-items-center rounded-2xl bg-aurora-light p-6">
            <div className="w-full">
              <div className="mb-2 flex items-center justify-between text-xs font-semibold text-muted"><span>Live signal ingestion</span><span className="text-accent-700">streaming</span></div>
              <div className="flex h-24 items-end gap-1">
                {Array.from({ length: 28 }).map((_, i) => (
                  <span key={i} className="flex-1 rounded-sm bg-gradient-to-t from-brand to-accent" style={{ height: `${28 + ((i * 37) % 64)}%`, opacity: 0.5 + ((i * 13) % 50) / 100 }} />
                ))}
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3 text-center">
                <div className="rounded-xl bg-white p-3 ring-1 ring-line"><p className="stat-big text-2xl text-ink">1.4s</p><p className="text-[11px] text-muted">avg. verify latency</p></div>
                <div className="rounded-xl bg-white p-3 ring-1 ring-line"><p className="stat-big text-2xl text-ink">98.6%</p><p className="text-[11px] text-muted">auto-verify rate</p></div>
              </div>
              <p className="mt-4 text-xs text-muted">Open the step on the left to follow a single event from capture to a verified, published outcome.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ── SDG + Egypt 2030 (light) ─────────────────────────────────────────────── */

const SDGS = [
  "No Poverty","Zero Hunger","Good Health","Quality Education","Gender Equality","Clean Water",
  "Clean Energy","Decent Work","Industry & Innovation","Reduced Inequalities","Sustainable Cities",
  "Responsible Consumption","Climate Action","Life Below Water","Life on Land","Peace & Justice","Partnerships",
];
const EGYPT_2030 = [
  { t: "Decent Living", d: "Lift communities via verified social & economic programs." },
  { t: "Digital Egypt", d: "Transparent, data-driven public impact infrastructure." },
  { t: "Green Economy", d: "Climate action and clean energy at the core of every SDG." },
  { t: "Human Capital", d: "Skills, health and education measured by real outcomes." },
];

function Sdg() {
  return (
    <section id="sdg" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconGlobe size={14} /> Global alignment</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">Built for the UN SDGs & Egypt Vision 2030</h2>
          <p className="mx-auto mt-3 max-w-xl text-muted">Every verified action maps to a goal — and to Egypt's national transformation agenda.</p>
        </Reveal>
        <Reveal delay={80} className="mt-8 flex flex-wrap justify-center gap-2">
          {SDGS.map((t) => (
            <span key={t} className="rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-brand-700 shadow-card ring-1 ring-brand/10">{t}</span>
          ))}
        </Reveal>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {EGYPT_2030.map((e, i) => (
            <Reveal key={e.t} delay={i * 80} className="card p-5">
              <div className="mb-2 flex items-center gap-2 text-brand"><IconGlobe size={18} /><h3 className="font-display font-bold text-ink">{e.t}</h3></div>
              <p className="text-sm text-muted">{e.d}</p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── showcase (phone) with real faces ─────────────────────────────────────── */

function Showcase() {
  const sample = [
    { name: "Amira Saleh", org: "GreenRoots NGO", seed: "amira.saleh", text: "Planted 12,000 mangrove saplings with 340 volunteers. Geotagged & verified. 🌱", chip: "Impact", stat: "POAI ✓" },
    { name: "Youssef Adel", org: "Cairo University", seed: "youssef.adel", text: "New program: Rural literacy bootcamp — 8 weeks, 200 seats. Join the field team.", chip: "Program", stat: "200 seats" },
    { name: "Lina Farouk", org: "Masrena CSR", seed: "lina.farouk", text: "Funded 3 clean-water wells via MASAREEN Coin. Transparent, on-chain impact.", chip: "Story", stat: "3 wells" },
  ];
  return (
    <section className="hero-dark section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="eyebrow text-white/80"><BrandMark size={18} className="rounded-md" /> The app</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">See the app people actually use</h2>
          <p className="text-white-soft mx-auto mt-3 max-w-xl">A feed of verified impact, programs you can join, and proof that travels with you.</p>
        </Reveal>
        <div className="mt-12 grid items-center gap-10 lg:grid-cols-5">
          <Reveal variant="left" className="lg:col-span-2 flex justify-center">
            <PhoneMock>
              <div className="space-y-3 p-3">
                {sample.map((p, i) => (
                  <div key={i} className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <div className="flex items-center gap-2">
                      <FaceAvatar seed={p.seed} size={28} />
                      <div className="min-w-0"><p className="truncate text-xs font-semibold text-white">{p.name}</p><p className="truncate text-[10px] text-white/60">{p.org}</p></div>
                      <span className="chip-accent ms-auto text-[10px]">{p.chip}</span>
                    </div>
                    <p className="mt-2 text-xs text-white/90">{p.text}</p>
                    <div className="mt-2 flex items-center justify-between text-[10px] text-white/60">
                      <span>{p.stat}</span><span className="chip-brand">POAI ✓</span>
                    </div>
                  </div>
                ))}
              </div>
            </PhoneMock>
          </Reveal>
          <Reveal variant="right" delay={120} className="lg:col-span-3">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="glass-dark p-5"><VennAvatars names={["amira.s","yusuf.a","lina.f"]} size={44} /><p className="mt-4 text-sm font-semibold text-white">Collaborate in the open</p><p className="mt-1 text-sm text-white/70">Overlapping teams, shared proof — see exactly who drives each outcome.</p></div>
              <div className="glass-dark p-5"><StackedAvatars names={["omar.t","sara.n","nada.k","khaled.h","hana.m","tarek.s"]} size={40} max={5} /><p className="mt-4 text-sm font-semibold text-white">Built for people</p><p className="mt-1 text-sm text-white/70">3,200+ members proving change in 9 countries.</p></div>
              <div className="glass-dark p-5 sm:col-span-2"><div className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-xl bg-white/10 text-white"><IconShield size={20} /></span><div><p className="text-sm font-semibold text-white">POAI verification</p><p className="text-sm text-white/70">Every claim scored, audited, traceable.</p></div></div></div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}

/* ── testimonials (light) ─────────────────────────────────────────────────── */

const TESTIMONIALS = [
  { name: "Amira Saleh", role: "NGO Director", seed: "amira.saleh", text: "We finally show funders proof, not promises. MASAREEN turned our field work into trusted, verifiable impact." },
  { name: "Yusuf Rahman", role: "Community Volunteer", seed: "yusuf.rahman", text: "I can see exactly how my hours translate into outcomes. It feels like LinkedIn, but for actual change." },
  { name: "Lina Haddad", role: "Impact Specialist", seed: "lina.haddad", text: "The verification pipeline saves us weeks of auditing. The social layer makes impact contagious." },
];

function Testimonials() {
  return (
    <section className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconHeart size={14} /> Loved by members</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">Impact workers trust MASAREEN</h2>
        </Reveal>
        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {TESTIMONIALS.map((t, i) => (
            <Reveal key={t.name} delay={i * 90} className="card p-5">
              <div className="flex items-center gap-3"><FaceAvatar seed={t.seed} size={44} /><div><p className="text-sm font-semibold text-ink">{t.name}</p><p className="text-xs text-muted">{t.role}</p></div></div>
              <p className="mt-3 text-sm text-ink">“{t.text}”</p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── full-bleed CTA ───────────────────────────────────────────────────────── */

function Download() {
  const [email, setEmail] = useState("");
  const [reqState, setReqState] = useState<"idle" | "busy" | "done" | "error">("idle");
  const [msg, setMsg] = useState("");

  async function requestAccess() {
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { setMsg("Enter a valid email so we can reach you."); setReqState("error"); return; }
    setReqState("busy"); setMsg("");
    try {
      const res = await fetch("/api/v1/users/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, full_name: email.split("@")[0], password: "Masaren@" + Math.random().toString(36).slice(2, 8), phone: "", role: "INDIVIDUAL", audience: "PROFESSIONAL" }),
      });
      const data = await res.json();
      if (res.ok && data?.data) { setReqState("done"); setMsg("You're in! Your account is ready — download the app and sign in with this email."); }
      else { setReqState("error"); setMsg(data?.message || "Could not request access. Try again."); }
    } catch { setReqState("error"); setMsg("Network error. Please try again."); }
  }

  return (
    <section id="download" className="cta-bleed section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
      <img src="/logo-full.png" alt="" className="logo-watermark" aria-hidden="true" />
      <div className="relative mx-auto max-w-3xl px-4 text-center">
        <span className="eyebrow justify-center text-white/80"><BrandMark size={18} className="rounded-md" /> Get started</span>
        <h2 className="hero-tracking mt-5 font-display text-4xl font-extrabold text-white sm:text-5xl">Join the alpha. Get the MASAREEN app.</h2>
        <p className="text-white-soft mx-auto mt-3 max-w-xl">Prove real-world impact from your phone. Free during the alpha.</p>
        <div className="mt-7 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a href={APK_URL} download="masaren-app-release.apk" className="btn-gold px-6 py-3 text-base text-white"><IconDownload size={18} /> Get the app (Android APK)</a>
          <Link to="/login" className="rounded-xl border border-white/25 px-6 py-3 text-base font-semibold text-white hover:bg-white/10">Open web app</Link>
        </div>
        <div className="mx-auto mt-8 max-w-md rounded-2xl border border-white/15 bg-white/5 p-5 text-left">
          <h3 className="text-sm font-bold text-white">Request access / invite a teammate</h3>
          <p className="mt-1 text-xs text-white/70">We'll create your alpha account instantly so you can sign in right away.</p>
          <div className="mt-3 flex flex-col gap-2 sm:flex-row">
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@organization.org" className="glass-input !bg-white/10 !border-white/20 !text-white placeholder-white/50 flex-1" />
            <button onClick={requestAccess} disabled={reqState === "busy"} className="btn-gold px-4 py-2.5 text-sm text-white">{reqState === "busy" ? "Requesting…" : "Request access"}</button>
          </div>
          {msg && <p className={`mt-2 text-xs ${reqState === "error" ? "text-rose-300" : "text-emerald-300"}`}>{msg}</p>}
        </div>
      </div>
    </section>
  );
}

function Footer() {
  const { isAuthenticated } = useAuth();
  return (
    <footer className="border-t border-line bg-white py-10">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <BrandWordmark height={72} />
          <p className="mt-3 text-sm text-muted">Verified impact infrastructure for everyone building a better world.</p>
        </div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Product</h4><ul className="mt-2 space-y-1 text-muted"><li><a href="#features" className="hover:text-brand">Features</a></li><li><a href="#profiles" className="hover:text-brand">Profiles</a></li><li><a href="#download" className="hover:text-brand">Download</a></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Impact</h4><ul className="mt-2 space-y-1 text-muted"><li><a href="#sdg" className="hover:text-brand">SDGs</a></li><li><a href="#verification" className="hover:text-brand">Verification</a></li><li><a href="#football" className="hover:text-brand">Football</a></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Get started</h4><ul className="mt-2 space-y-1 text-muted"><li>{isAuthenticated ? <Link to="/feed" className="hover:text-brand">Open app</Link> : <Link to="/login" className="hover:text-brand">Sign in</Link>}</li><li><a href="#download" className="hover:text-brand">Android APK</a></li><li><a href="#download" className="hover:text-brand">Web app</a></li></ul></div>
      </div>
      <p className="mx-auto mt-8 max-w-6xl px-4 text-xs text-muted">© 2026 MASAREEN · Aligned with UN SDGs & Egypt Vision 2030 · POAI Verification</p>
    </footer>
  );
}

/* ── page ─────────────────────────────────────────────────────────────────── */

export default function LandingPage() {
  const { isAuthenticated } = useAuth();
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [reqError, setReqError] = useState("");
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const onScroll = () => {
      const h = document.documentElement;
      const scrolled = (h.scrollTop) / (h.scrollHeight - h.clientHeight);
      setProgress(Math.min(1, Math.max(0, scrolled)) * 100);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const onEmail = async () => {
    const value = email.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value)) { setReqError("Enter a valid email to request access."); return; }
    setReqError("");
    try {
      const res = await fetch("/api/v1/users/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: value, full_name: value.split("@")[0], password: "Masaren@" + Math.random().toString(36).slice(2, 8), phone: "", role: "INDIVIDUAL", audience: "PROFESSIONAL" }),
      });
      const data = await res.json();
      if (res.ok && data?.data) setSent(true);
      else setReqError(data?.message || "Could not request access. Try again.");
    } catch { setReqError("Network error. Please try again."); }
  };

  return (
    <div className="bg-white text-ink">
      <div className="scroll-progress" style={{ width: `${progress}%` }} />
      <Nav />
      <Hero onEmail={onEmail} email={email} setEmail={setEmail} sent={sent} reqError={reqError} />
      <TrustBand />
      <Features />
      <Explorer />
      <Convergence />
      <How />
      <Stats />
      <Profiles />
      <Football />
      <Verification />
      <Sdg />
      <Showcase />
      <Testimonials />
      <Download />
      <Footer />
    </div>
  );
}
