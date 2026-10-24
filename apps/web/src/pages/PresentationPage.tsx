import { useState } from "react";
import { Link } from "react-router-dom";
import {
  IconShield, IconCheck, IconImpact, IconUsers, IconGlobe,
  IconSparkles, IconArrowRight, IconWallet, IconProgram, IconTask,
  IconEvidence, IconCompass, IconChat, IconReports, IconHeart,
  IconFlag, IconTrophy, IconHandshake, IconAdmin, IconVideo,
  IconSearch, IconUser,
} from "../components/icons/Icons";
import { useReveal, useCountUp } from "../hooks/anim";
import { BrandMark } from "../components/common/Branding";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useI18n } from "../i18n";

/* ── shared helpers ──────────────────────────────────────────────────────── */

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

/* ── feature cards ───────────────────────────────────────────────────────── */

const FEATURES = [
  {
    icon: IconHeart,
    title: "Impact Feed & Social",
    color: "#E74C3C",
    desc: "A social feed of verified impact stories ranked by real outcomes. Like, comment, share and follow impact workers, LinkedIn for change-makers.",
    points: ["Real-time impact stories", "Engagement that matters", "Follow verified orgs"],
  },
  {
    icon: IconShield,
    title: "POAI Verification Pipeline",
    color: "#0250A3",
    desc: "Proof of Actual Impact, a five-step pipeline that scores, audits and stamps every claim with a verifiable trust badge.",
    points: ["Evidence scoring engine", "Tamper-evident trail", "Auto-verify 98.6%"],
  },
  {
    icon: IconWallet,
    title: "MASAREEN Coin Economy",
    color: "#F59E0B",
    desc: "A transparent impact economy. Earn coin for verified outcomes, fund programs and move value through the network with clear brokerage.",
    points: ["Transparent fees", "On-chain proof", "Impact payouts"],
  },
  {
    icon: IconProgram,
    title: "Programs & Tasks",
    color: "#2A9D45",
    desc: "Launch programs, assign tasks, track lifecycle from draft to verified completion. Everyone sees the same source of truth.",
    points: ["Lifecycle tracking", "Role-based assignment", "Live progress dashboards"],
  },
  {
    icon: IconEvidence,
    title: "Evidence & GPS Tracking",
    color: "#8B5CF6",
    desc: "Geo-tagged photos, receipts, sensor data and field notes bundled into tamper-evident evidence packages for every action.",
    points: ["GPS verification", "Multi-format uploads", "Cross-referenced audit"],
  },
  {
    icon: IconFlag,
    title: "Institution Profiles",
    color: "#0EA5E9",
    desc: "Tailored profiles for Government, Media, Sports and NGO institutions, each with its own verification widgets and public dashboard.",
    points: ["5 profile types", "Custom dashboards", "Public trust scores"],
  },
  {
    icon: IconCompass,
    title: "Opportunity Marketplace",
    color: "#2A9D45",
    desc: "Browse and apply to volunteering, jobs, grants and partnerships, all backed by verified impact credentials.",
    points: ["Verified credentials", "Smart matching", "Program discovery"],
  },
  {
    icon: IconAdmin,
    title: "Admin & Analytics",
    color: "#0250A3",
    desc: "Full admin panel with reports, R-based analytics, revenue tracking and platform-wide impact metrics.",
    points: ["R integration", "Revenue tracking", "Audit logs"],
  },
  {
    icon: IconTask,
    title: "Courses & Learning",
    color: "#E74C3C",
    desc: "Structured learning paths for impact workers. Complete courses to earn badges and demonstrate verified skill growth.",
    points: ["Skill badges", "Track progress", "Verified certificates"],
  },
  {
    icon: IconChat,
    title: "Interview System",
    color: "#8B5CF6",
    desc: "Built-in interview tools for onboarding, field audits and media. Record, transcribe and attach to impact claims.",
    points: ["Audio/video capture", "Auto-transcription", "Linked to claims"],
  },
];

function FeatureCards() {
  return (
    <section id="features" className="hero-dark section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="max-w-2xl">
          <span className="eyebrow text-white/80"><IconSparkles size={14} /> Platform features</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Everything impact teams need</h2>
          <p className="text-white-soft mt-3 text-lg">Social, verified, measurable, built for the people doing the real work.</p>
        </Reveal>
        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f, i) => (
            <Reveal key={f.title} delay={(i % 3) * 80}>
              <div className="glass-dark hover-lift h-full p-6">
                <div className="mb-4 grid h-12 w-12 place-items-center rounded-2xl text-white" style={{ background: f.color }}>
                  <f.icon size={24} />
                </div>
                <h3 className="font-display text-lg font-bold text-white">{f.title}</h3>
                <p className="mt-2 text-sm text-white/75">{f.desc}</p>
                <ul className="mt-3 space-y-1">
                  {f.points.map((p) => (
                    <li key={p} className="flex items-center gap-2 text-xs text-white/65"><IconCheck className="text-emerald-300" size={14} /> {p}</li>
                  ))}
                </ul>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── verification flow ───────────────────────────────────────────────────── */

const VERIFY_STEPS = [
  { icon: IconImpact, title: "Claim the impact", desc: "Record an action, a tree planted, a clinic run, a goal scored. It becomes a trackable unit of change." },
  { icon: IconEvidence, title: "Submit evidence", desc: "Attach photos, receipts, GPS tags and field notes bundled into a tamper-evident package." },
  { icon: IconGlobe, title: "GPS & field audit", desc: "Pipeline cross-checks location, timestamps and third-party signals for every claim." },
  { icon: IconShield, title: "POAI score", desc: "Algorithm scores plausibility, completeness and SDG alignment in real time." },
  { icon: IconCheck, title: "Verified & published", desc: "Outcome stamped POAI-verified, flows into dashboards and the impact economy." },
];

function VerificationFlow() {
  const [open, setOpen] = useState(0);
  return (
    <section id="verification" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconShield size={14} /> Verification pipeline</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">How verification works</h2>
          <p className="mx-auto mt-3 max-w-2xl text-muted">Every claim moves through an event-driven pipeline, from raw field note to trusted, auditable outcome.</p>
        </Reveal>
        <div className="mt-10 grid gap-8 rounded-3xl border border-line bg-white p-6 shadow-card md:grid-cols-2">
          <div className="space-y-2">
            {VERIFY_STEPS.map((s, i) => (
              <button key={i} onClick={() => setOpen(i)} className={`flow-step flex w-full gap-4 rounded-xl p-3 text-left transition ${open === i ? "bg-brand-50" : "hover:bg-canvas"}`}>
                <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl text-white transition ${open === i ? "bg-brand" : "bg-canvas text-brand"}`}><s.icon size={18} /></span>
                <div>
                  <p className="text-sm font-semibold text-ink">{s.title}</p>
                  <p className="text-xs text-muted">{s.desc}</p>
                </div>
              </button>
            ))}
          </div>
          <div className="grid place-items-center rounded-2xl bg-aurora-light p-6">
            <div className="w-full">
              <div className="mb-2 flex items-center justify-between text-xs font-semibold text-muted"><span>Pipeline visualization</span><span className="text-accent-700">live</span></div>
              <div className="flex h-32 items-end gap-1">
                {Array.from({ length: 32 }).map((_, i) => (
                  <span key={i} className="flex-1 rounded-sm bg-gradient-to-t from-brand to-accent" style={{ height: `${25 + ((i * 37) % 70)}%`, opacity: 0.4 + ((i * 13) % 60) / 100 }} />
                ))}
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3 text-center">
                <div className="rounded-xl bg-white p-3 ring-1 ring-line"><p className="stat-big text-2xl text-ink">1.4s</p><p className="text-[11px] text-muted">avg. verify latency</p></div>
                <div className="rounded-xl bg-white p-3 ring-1 ring-line"><p className="stat-big text-2xl text-ink">98.6%</p><p className="text-[11px] text-muted">auto-verify rate</p></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ── architecture ────────────────────────────────────────────────────────── */

const SERVICES = [
  { name: "Gateway", desc: "API gateway, auth, rate limiting", icon: IconAdmin },
  { name: "Feed Service", desc: "Impact stories, social graph", icon: IconHeart },
  { name: "Verification", desc: "POAI scoring, audit pipeline", icon: IconShield },
  { name: "Coin Ledger", desc: "MASAREEN coin transactions", icon: IconWallet },
  { name: "Programs", desc: "Program & task lifecycle", icon: IconProgram },
  { name: "Evidence Store", desc: "GPS, photos, tamper-evident", icon: IconEvidence },
  { name: "Analytics", desc: "R-based reporting engine", icon: IconReports },
  { name: "Search", desc: "People, programs, opportunities", icon: IconSearch },
];

function Architecture() {
  return (
    <section id="architecture" className="bg-[#06121F] section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="eyebrow text-white/80 justify-center"><IconAdmin size={14} /> Platform architecture</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Microservice-first design</h2>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Built on a distributed microservice architecture for scalability, resilience and independent deployment.</p>
        </Reveal>
        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {SERVICES.map((s, i) => (
            <Reveal key={s.name} delay={i * 60}>
              <div className="glass-dark hover-lift p-5 text-center">
                <div className="mx-auto mb-3 grid h-12 w-12 place-items-center rounded-2xl bg-white/10 text-white"><s.icon size={22} /></div>
                <h3 className="font-display text-sm font-bold text-white">{s.name}</h3>
                <p className="mt-1 text-xs text-white/65">{s.desc}</p>
              </div>
            </Reveal>
          ))}
        </div>
        <Reveal className="mt-8 text-center">
          <div className="inline-flex flex-wrap items-center justify-center gap-3 text-xs font-semibold text-white/50">
            <span className="rounded-full bg-white/10 px-3 py-1.5">Spring Boot</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">PostgreSQL</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">Redis</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">Docker</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">Kafka</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">R Analytics</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">Flutter</span>
            <span className="rounded-full bg-white/10 px-3 py-1.5">React</span>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── user roles ──────────────────────────────────────────────────────────── */

const ROLES = [
  { name: "Individual", icon: IconUser, color: "#2A9D45", abilities: ["Create impact profile", "Post stories & evidence", "Join programs & tasks", "Earn MASAREEN Coin", "Build impact passport"] },
  { name: "NGO", icon: IconHandshake, color: "#E74C3C", abilities: ["Launch programs", "Assign tasks to teams", "Verify field evidence", "Track SDG progress", "Access funders dashboard"] },
  { name: "Government", icon: IconFlag, color: "#0250A3", abilities: ["Public program transparency", "Egypt Vision 2030 tracking", "Citizen audit trails", "Cross-agency analytics", "Policy impact reporting"] },
  { name: "Media", icon: IconVideo, color: "#0EA5E9", abilities: ["Publish verified stories", "Attach POAI proof", "Access media dashboard", "Interview system", "Impact rankings"] },
  { name: "Sports", icon: IconTrophy, color: "#2A9D45", abilities: ["Player impact profiles", "Youth academy tracking", "Community clinics", "Match-to-SDG mapping", "Club sustainability"] },
  { name: "Admin", icon: IconAdmin, color: "#8B5CF6", abilities: ["Platform analytics", "R-based reports", "Revenue tracking", "Audit log review", "User management"] },
];

function Roles() {
  const [active, setActive] = useState(0);
  const role = ROLES[active];
  return (
    <section id="roles" className="section-pad">
      <div className="mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="section-kicker"><IconUsers size={14} /> User roles</span>
          <h2 className="mt-4 font-display text-4xl font-extrabold text-ink">Built for every stakeholder</h2>
          <p className="mx-auto mt-3 max-w-xl text-muted">Each role gets a tailored experience, same network, different superpowers.</p>
        </Reveal>
        <div className="mt-8 flex flex-wrap justify-center gap-2">
          {ROLES.map((r, i) => (
            <button key={r.name} onClick={() => setActive(i)} className={`tile flex items-center gap-2 rounded-2xl border bg-white px-4 py-2.5 text-left text-sm font-semibold transition ${active === i ? "tile-active border-brand-200" : "border-line hover:border-brand/30"}`}>
              <span className="grid h-8 w-8 place-items-center rounded-xl text-white" style={{ background: r.color }}><r.icon size={16} /></span>
              {r.name}
            </button>
          ))}
        </div>
        <Reveal key={active} className="mt-8 rounded-3xl border border-line bg-white p-6 shadow-card">
          <div className="flex items-center gap-3">
            <span className="grid h-12 w-12 place-items-center rounded-2xl text-white" style={{ background: role.color }}><role.icon size={22} /></span>
            <div>
              <h3 className="font-display text-xl font-bold text-ink">{role.name} Role</h3>
              <p className="text-sm text-muted">What they can do on the platform</p>
            </div>
          </div>
          <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {role.abilities.map((a) => (
              <div key={a} className="flex items-center gap-2 rounded-xl bg-canvas p-3 text-sm text-ink">
                <IconCheck className="shrink-0 text-accent" size={16} /> {a}
              </div>
            ))}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ── SDG grid ────────────────────────────────────────────────────────────── */

const SDGS = [
  { n: 1, name: "No Poverty", color: "#E5243B" },
  { n: 2, name: "Zero Hunger", color: "#DDA63A" },
  { n: 3, name: "Good Health", color: "#4C9F38" },
  { n: 4, name: "Quality Education", color: "#C5192D" },
  { n: 5, name: "Gender Equality", color: "#FF3A21" },
  { n: 6, name: "Clean Water", color: "#26BDE2" },
  { n: 7, name: "Clean Energy", color: "#FCC30B" },
  { n: 8, name: "Decent Work", color: "#A21942" },
  { n: 9, name: "Industry & Innovation", color: "#FD6925" },
  { n: 10, name: "Reduced Inequalities", color: "#DD1367" },
  { n: 11, name: "Sustainable Cities", color: "#FD9D24" },
  { n: 12, name: "Responsible Consumption", color: "#BF8B2E" },
  { n: 13, name: "Climate Action", color: "#3F7E44" },
  { n: 14, name: "Life Below Water", color: "#0A97D9" },
  { n: 15, name: "Life on Land", color: "#56C02B" },
  { n: 16, name: "Peace & Justice", color: "#00689D" },
  { n: 17, name: "Partnerships", color: "#19486A" },
];

function SdgGrid() {
  return (
    <section id="sdgs" className="bg-[#06121F] section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
      <div className="relative mx-auto max-w-6xl px-4">
        <Reveal className="text-center">
          <span className="eyebrow text-white/80 justify-center"><IconGlobe size={14} /> Global alignment</span>
          <h2 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">17 SDGs tracked</h2>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Every verified action maps to a United Nations Sustainable Development Goal, and to Egypt Vision 2030.</p>
        </Reveal>
        <div className="mt-10 grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-9">
          {SDGS.map((s, i) => (
            <Reveal key={s.n} delay={i * 30}>
              <div className="glass-dark hover-lift flex flex-col items-center p-3 text-center">
                <span className="grid h-10 w-10 place-items-center rounded-xl text-sm font-bold text-white" style={{ background: s.color }}>{s.n}</span>
                <p className="mt-2 text-[10px] font-semibold leading-tight text-white/80">{s.name}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── stats ───────────────────────────────────────────────────────────────── */

function Stats() {
  return (
    <section className="section-pad">
      <div className="mx-auto grid max-w-5xl grid-cols-2 gap-10 px-4 sm:grid-cols-4">
        <Counter end={18400} label="Verified impact actions" icon={IconImpact} />
        <Counter end={3200} label="Alpha members" suffix="+" icon={IconUsers} />
        <Counter end={17} label="SDGs tracked" icon={IconGlobe} />
        <Counter end={9} label="Countries" icon={IconSparkles} />
      </div>
    </section>
  );
}

/* ── CTA ─────────────────────────────────────────────────────────────────── */

function Cta() {
  return (
    <section className="cta-bleed section-pad">
      <div className="mesh-dark" aria-hidden="true" />
      <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
      <img src="/logo-full.png" alt="" className="logo-watermark" aria-hidden="true" />
      <div className="relative mx-auto max-w-3xl px-4 text-center">
        <span className="eyebrow justify-center text-white/80"><BrandMark size={18} className="rounded-md" /> Get started</span>
        <h2 className="hero-tracking mt-5 font-display text-4xl font-extrabold text-white sm:text-5xl">Join the Alpha</h2>
        <p className="text-white-soft mx-auto mt-3 max-w-xl">Prove real-world impact from your phone. Free during the alpha period.</p>
        <div className="mt-7 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <Link to="/register" className="btn-gold px-6 py-3 text-base text-white"><IconArrowRight size={18} /> Create your account</Link>
          <Link to="/login" className="rounded-xl border border-white/25 px-6 py-3 text-base font-semibold text-white hover:bg-white/10">Sign in</Link>
        </div>
        <div className="mt-6 flex items-center justify-center gap-4 text-sm text-white/60">
          <Link to="/docs" className="hover:text-white transition">Docs</Link>
          <span>·</span>
          <Link to="/how-it-works" className="hover:text-white transition">How it works</Link>
          <span>·</span>
          <Link to="/pricing" className="hover:text-white transition">Pricing</Link>
        </div>
      </div>
    </section>
  );
}

/* ── page ────────────────────────────────────────────────────────────────── */

export default function PresentationPage() {
  return (
    <div className="bg-white text-ink">
      <MarketingNav />

      {/* Hero */}
      <section className="hero-dark pt-28 pb-20">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-60" />
        <img src="/logo-full.png" alt="" className="logo-watermark" aria-hidden="true" />
        <div className="pointer-events-none absolute -left-24 top-24 h-72 w-72 rounded-full bg-brand/30 blur-3xl" />
        <div className="pointer-events-none absolute right-10 top-40 h-72 w-72 rounded-full bg-accent/20 blur-3xl" />
        <div className="relative mx-auto max-w-4xl px-4 text-center">
          <Reveal>
            <span className="eyebrow text-white/80 justify-center"><IconSparkles size={14} /> Platform showcase</span>
            <h1 className="hero-tracking mt-5 font-display text-5xl font-extrabold leading-[1.05] text-white sm:text-6xl">
              MASAREEN -<br /><span className="gradient-text">Verified Impact Infrastructure</span>
            </h1>
            <p className="text-white-soft mt-5 mx-auto max-w-2xl text-lg">
              The verified-impact network where NGOs, governments, communities and sports institutions
              turn real-world work into trusted, measurable proof, backed by POAI verification.
            </p>
            <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <Link to="/register" className="btn-gold px-6 py-3 text-base text-white">Join the Alpha <IconArrowRight size={16} /></Link>
              <a href="#features" className="rounded-xl border border-white/25 px-6 py-3 text-base font-semibold text-white hover:bg-white/10">Explore features</a>
            </div>
          </Reveal>
        </div>
      </section>

      {/* What is MASAREEN */}
      <section className="section-pad">
        <div className="mx-auto max-w-4xl px-4 text-center">
          <Reveal>
            <span className="section-kicker"><BrandMark size={16} /> What is MASAREEN?</span>
            <h2 className="mt-4 font-display text-3xl font-extrabold text-ink sm:text-4xl">The trust layer for real-world impact</h2>
            <p className="mx-auto mt-4 max-w-2xl text-base text-muted">
              MASAREEN is a social-impact platform that combines a feed, verification pipeline and coin economy
              into a single infrastructure for proving change. Organizations and individuals post impact stories,
              attach geo-tagged evidence, and receive a POAI (Proof of Actual Impact) verification badge, creating
              a trusted, auditable record that funders, partners and citizens can rely on.
            </p>
          </Reveal>
          <Reveal delay={100} className="mt-8 inline-flex flex-wrap items-center justify-center gap-3">
            <span className="rounded-full bg-brand-50 px-4 py-2 text-sm font-semibold text-brand-700">Social feed</span>
            <span className="rounded-full bg-accent-50 px-4 py-2 text-sm font-semibold text-accent-700">POAI verification</span>
            <span className="rounded-full bg-amber-50 px-4 py-2 text-sm font-semibold text-amber-700">Coin economy</span>
            <span className="rounded-full bg-purple-50 px-4 py-2 text-sm font-semibold text-purple-700">Programs & tasks</span>
            <span className="rounded-full bg-sky-50 px-4 py-2 text-sm font-semibold text-sky-700">GPS evidence</span>
          </Reveal>
        </div>
      </section>

      <Stats />
      <FeatureCards />
      <VerificationFlow />
      <Architecture />
      <Roles />
      <SdgGrid />
      <Cta />
      <MarketingFooter />
    </div>
  );
}
