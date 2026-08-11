import React, { useState } from "react";
import { Link } from "react-router-dom";
import {
  IconCompass, IconCheck, IconTrending, IconImpact, IconShield, IconUsers,
  IconEvidence, IconProgram, IconTask, IconGlobe, IconSparkles, IconArrowRight,
  IconDownload, IconWallet, IconAds,
} from "../components/icons/Icons";
import { useReveal, useCountUp } from "../hooks/anim";
import { avatarColors } from "../services/postService";
import { BrandMark, BrandWordmark } from "../components/common/Branding";

const Brand = () => (
  <Link to="/" className="flex items-center gap-2">
    <BrandMark size={32} />
    <BrandWordmark className="!text-xl" />
  </Link>
);

const APK_URL = "/masaren-arm64-v8a.apk"; // served from /public in the built SPA

function RevealBox({ children, className = "", variant = "up", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  const base = variant === "up" ? "reveal" : `reveal reveal-${variant}`;
  return (
    <div ref={ref} className={`${base} ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

function Stat({ end, label, suffix = "", decimals = 0, icon: Icon }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>({ threshold: 0.4 });
  const value = useCountUp(end, shown, 1600, decimals);
  return (
    <div ref={ref} className="text-center">
      <div className="mx-auto mb-2 grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand">
        <Icon size={22} />
      </div>
      <div className="font-display text-3xl font-extrabold text-ink sm:text-4xl">{value}{suffix}</div>
      <div className="mt-1 text-sm text-muted">{label}</div>
    </div>
  );
}

const COMPARISON = [
  { feature: "POAI verified, auditable impact", masaren: true, others: false },
  { feature: "Real-world outcomes, not vanity metrics", masaren: true, others: false },
  { feature: "SDG & Egypt 2030 alignment built-in", masaren: true, others: false },
  { feature: "Brokerage & coin economy for impact", masaren: true, others: false },
  { feature: "Programs, tasks & evidence workflows", masaren: true, others: false },
  { feature: "Generic posting & networking only", masaren: false, others: true },
];

const FEATURES = [
  { icon: IconCompass, title: "Impact Discovery", text: "A social feed of verified impact stories, programs and evidence — ranked by real outcomes, not engagement bait." },
  { icon: IconShield, title: "POAI Verification", text: "Every claim is scored, audited and traced through a verification pipeline you can trust." },
  { icon: IconProgram, title: "Programs & Tasks", text: "Launch, join and complete real programs with lifecycle tracking from assign to verified." },
  { icon: IconEvidence, title: "Evidence & GPS", text: "Attach geo-tagged proof to every action so impact is undeniable and measurable." },
  { icon: IconWallet, title: "MASAREN Coin", text: "An impact economy with transparent brokerage fees that fund the platform." },
  { icon: IconAds, title: "Impact Ads", text: "Promote verified programs to the right communities with fraud-resistant delivery." },
];

const SDGS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
const EGYPT_2030 = [
  { t: "Decent Living", d: "Lift communities via verified social & economic programs." },
  { t: "Digital Egypt", d: "Transparent, data-driven public impact infrastructure." },
  { t: "Green Economy", d: "Climate action and clean energy at the core of every SDG." },
  { t: "Human Capital", d: "Skills, health and education measured by real outcomes." },
];

const TESTIMONIALS = [
  { name: "Amira Saleh", role: "NGO Director", text: "We finally show funders proof, not promises. MASAREN turned our field work into trusted, verifiable impact." },
  { name: "Yusuf Rahman", role: "Community Volunteer", text: "I can see exactly how my hours translate into outcomes. It feels like LinkedIn, but for actual change." },
  { name: "Lina Haddad", role: "Impact Specialist", text: "The verification pipeline saves us weeks of auditing. The social layer makes impact contagious." },
];

function Avatar({ name, size = 44 }: { name: string; size?: number }) {
  const { c1, c2 } = avatarColors(name);
  return (
    <span className="avatar-gradient grid shrink-0 place-items-center rounded-full font-semibold text-white"
      style={{ width: size, height: size, fontSize: size * 0.4, ["--c1" as any]: c1, ["--c2" as any]: c2 }}>
      {name[0]}
    </span>
  );
}

function Nav() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-line/70 bg-white/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4">
        <Brand />
        <nav className="ms-4 hidden items-center gap-1 text-sm font-medium text-muted md:flex">
          <a href="#features" className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Features</a>
          <a href="#compare" className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">Why MASAREN</a>
          <a href="#sdg" className="rounded-lg px-3 py-1.5 hover:bg-canvas hover:text-ink">SDGs & 2030</a>
        </nav>
        <div className="ms-auto flex items-center gap-2">
          <Link to="/login" className="btn-ghost px-3 py-1.5 text-sm">Sign in</Link>
          <a href="#download" className="btn-gold px-3 py-1.5 text-sm">Get the app</a>
        </div>
      </div>
    </header>
  );
}

function Hero({ onEmail, email, setEmail, sent }: any) {
  return (
    <section className="relative overflow-hidden bg-aurora-light pt-28 pb-16">
      <div className="pointer-events-none absolute inset-0 bg-dots opacity-60" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-4 md:grid-cols-2">
        <RevealBox>
          <span className="chip-brand"><IconSparkles size={14} /> Now in alpha · Join early</span>
          <h1 className="mt-4 font-display text-4xl font-extrabold leading-tight text-ink sm:text-5xl">
            The professional network for <span className="gradient-text">real-world impact</span>.
          </h1>
          <p className="mt-4 max-w-md text-lg text-muted">
            MASAREN is where impact workers, NGOs and governments prove, track and scale verified change —
            with POAI verification, programs, evidence and an impact economy built in.
          </p>
          <form className="mt-6 flex max-w-md flex-col gap-2 sm:flex-row" onSubmit={(e) => { e.preventDefault(); onEmail(); }}>
            <input className="glass-input" placeholder="you@organization.org" value={email} onChange={(e) => setEmail(e.target.value)} type="email" required />
            <button className="btn-gold whitespace-nowrap" type="submit">Request alpha access</button>
          </form>
          {sent && <p className="mt-2 text-sm font-medium text-accent-700">You're on the list — we'll email your invite. 🎉</p>}
          <div className="mt-4 flex flex-wrap items-center gap-3 text-sm text-muted">
            <a href="#download" className="inline-flex items-center gap-1.5 font-semibold text-brand hover:underline"><IconDownload size={16} /> Download for Android</a>
            <Link to="/login" className="inline-flex items-center gap-1.5 font-semibold text-ink hover:underline">Open web app <IconArrowRight size={16} /></Link>
          </div>
        </RevealBox>

        <RevealBox variant="right" delay={120}>
          <div className="card animate-float overflow-hidden p-0">
            <div className="flex items-center gap-3 border-b border-line bg-canvas px-4 py-3">
              <Avatar name="Amira" size={36} />
              <div><p className="text-sm font-semibold text-ink">Amira Saleh</p><p className="text-xs text-muted">GreenRoots NGO · Verified</p></div>
              <span className="chip-accent ms-auto">Impact</span>
            </div>
            <div className="space-y-3 p-4">
              <p className="text-sm text-ink">Planted 12,000 mangrove saplings with 340 volunteers. Geotagged, audited, verified. 🌱</p>
              <div className="grid grid-cols-3 gap-2 text-center">
                <div className="rounded-xl bg-accent-50 p-2"><p className="font-display font-bold text-accent-700">12K</p><p className="text-[10px] text-muted">seedlings</p></div>
                <div className="rounded-xl bg-brand-50 p-2"><p className="font-display font-bold text-brand">340</p><p className="text-[10px] text-muted">volunteers</p></div>
                <div className="rounded-xl bg-canvas p-2"><p className="font-display font-bold text-ink">98%</p><p className="text-[10px] text-muted">verified</p></div>
              </div>
              <div className="flex items-center gap-4 border-t border-line pt-3 text-sm text-muted">
                <span className="flex items-center gap-1.5 text-rose-500"><IconTrending size={16} /> 482</span>
                <span className="flex items-center gap-1.5"><IconUsers size={16} /> 73</span>
                <span className="ms-auto chip-brand">POAI ✓</span>
              </div>
            </div>
          </div>
        </RevealBox>
      </div>
    </section>
  );
}

function Stats() {
  return (
    <section className="border-y border-line bg-white py-12">
      <div className="mx-auto grid max-w-5xl grid-cols-2 gap-8 px-4 sm:grid-cols-4">
        <Stat end={128000} label="Verified impact actions" icon={IconImpact} />
        <Stat end={8400} label="Alpha members" suffix="+" icon={IconUsers} />
        <Stat end={17} label="SDGs tracked" icon={IconGlobe} />
        <Stat end={36} label="Countries" icon={IconSparkles} />
      </div>
    </section>
  );
}

function Compare() {
  return (
    <section id="compare" className="py-16">
      <div className="mx-auto max-w-5xl px-4">
        <RevealBox className="text-center">
          <h2 className="font-display text-3xl font-extrabold text-ink">Why MASAREN, not LinkedIn or X</h2>
          <p className="mx-auto mt-2 max-w-xl text-muted">Other networks optimise for attention. MASAREN optimises for outcomes.</p>
        </RevealBox>
        <RevealBox delay={80} className="card mt-8 overflow-hidden">
          <div className="grid grid-cols-3 border-b border-line bg-canvas px-4 py-3 text-sm font-semibold">
            <div className="text-ink">Capability</div>
            <div className="text-center text-brand">MASAREN</div>
            <div className="text-center text-muted">Generic social</div>
          </div>
          {COMPARISON.map((r, i) => (
            <div key={i} className="grid grid-cols-3 items-center border-b border-line px-4 py-3 text-sm last:border-0">
              <div className="text-ink">{r.feature}</div>
              <div className="flex justify-center">{r.masaren ? <IconCheck className="text-accent" size={20} /> : <span className="text-muted">—</span>}</div>
              <div className="flex justify-center">{r.others ? <IconCheck className="text-muted" size={20} /> : <span className="text-muted">—</span>}</div>
            </div>
          ))}
        </RevealBox>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section id="features" className="bg-canvas py-16">
      <div className="mx-auto max-w-6xl px-4">
        <RevealBox className="text-center">
          <h2 className="font-display text-3xl font-extrabold text-ink">Everything impact teams need</h2>
          <p className="mx-auto mt-2 max-w-xl text-muted">One platform — social, verified, and measurable.</p>
        </RevealBox>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f, i) => (
            <RevealBox key={f.title} delay={(i % 3) * 90} className="card hover-lift p-5">
              <div className="mb-3 grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand"><f.icon size={22} /></div>
              <h3 className="font-display text-lg font-bold text-ink">{f.title}</h3>
              <p className="mt-1.5 text-sm text-muted">{f.text}</p>
            </RevealBox>
          ))}
        </div>
      </div>
    </section>
  );
}

function Sdg() {
  return (
    <section id="sdg" className="py-16">
      <div className="mx-auto max-w-6xl px-4">
        <RevealBox className="text-center">
          <h2 className="font-display text-3xl font-extrabold text-ink">Aligned with the UN SDGs & Egypt Vision 2030</h2>
          <p className="mx-auto mt-2 max-w-xl text-muted">Every verified action maps to a goal — and to Egypt's national transformation agenda.</p>
        </RevealBox>
        <RevealBox delay={80} className="mt-8 flex flex-wrap justify-center gap-2">
          {SDGS.map((n) => (
            <span key={n} className="grid h-12 w-12 place-items-center rounded-xl bg-gradient-to-br from-brand to-accent font-display font-bold text-white shadow-card">{n}</span>
          ))}
        </RevealBox>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {EGYPT_2030.map((e, i) => (
            <RevealBox key={e.t} delay={i * 80} className="card p-5">
              <div className="mb-2 flex items-center gap-2 text-brand"><IconGlobe size={18} /><h3 className="font-display font-bold text-ink">{e.t}</h3></div>
              <p className="text-sm text-muted">{e.d}</p>
            </RevealBox>
          ))}
        </div>
      </div>
    </section>
  );
}

function Testimonials() {
  return (
    <section className="bg-canvas py-16">
      <div className="mx-auto max-w-6xl px-4">
        <RevealBox className="text-center">
          <h2 className="font-display text-3xl font-extrabold text-ink">Loved by impact workers</h2>
        </RevealBox>
        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {TESTIMONIALS.map((t, i) => (
            <RevealBox key={t.name} delay={i * 90} className="card p-5">
              <div className="flex items-center gap-3">
                <Avatar name={t.name} />
                <div><p className="text-sm font-semibold text-ink">{t.name}</p><p className="text-xs text-muted">{t.role}</p></div>
              </div>
              <p className="mt-3 text-sm text-ink">“{t.text}”</p>
            </RevealBox>
          ))}
        </div>
      </div>
    </section>
  );
}

function Download() {
  return (
    <section id="download" className="relative overflow-hidden bg-aurora-light py-16">
      <div className="pointer-events-none absolute inset-0 bg-dots opacity-60" />
      <RevealBox className="relative mx-auto max-w-3xl px-4 text-center">
        <h2 className="font-display text-3xl font-extrabold text-ink sm:text-4xl">Join the alpha. Download MASAREN.</h2>
        <p className="mx-auto mt-3 max-w-xl text-muted">Get the Android app and start proving your impact today. Free during alpha.</p>
        <div className="mt-6 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a href={APK_URL} className="btn-gold px-5 py-3 text-base"><IconDownload size={18} /> Download APK (Android)</a>
          <Link to="/login" className="btn-ghost px-5 py-3 text-base">Open web app</Link>
        </div>
        <p className="mt-3 text-xs text-muted">Enable “Install unknown apps” for your browser, then tap the APK. Uninstall any older MASAREN build first.</p>
      </RevealBox>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-line bg-white py-10">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <div className="flex items-center gap-2">
            <BrandMark size={32} />
            <BrandWordmark className="!text-xl" />
          </div>
          <p className="mt-3 text-sm text-muted">Verified impact infrastructure for everyone building a better world.</p>
          <div className="mt-4 flex items-center gap-3">
            <a href="https://www.linkedin.com/company/masaren" target="_blank" rel="noreferrer noopener" aria-label="MASAREN on LinkedIn" className="grid h-9 w-9 place-items-center rounded-full bg-brand/10 text-brand transition hover:-translate-y-0.5 hover:bg-brand hover:text-white">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M4.98 3.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM3 9h4v12H3zM9 9h3.8v1.7h.05c.53-1 1.83-2.05 3.77-2.05 4.03 0 4.38 2.65 4.38 6.1V21h-4v-5.3c0-1.27-.02-2.9-1.77-2.9-1.77 0-2.04 1.38-2.04 2.8V21H9z"/></svg>
            </a>
            <a href="https://www.facebook.com/masaren" target="_blank" rel="noreferrer noopener" aria-label="MASAREN on Facebook" className="grid h-9 w-9 place-items-center rounded-full bg-accent/10 text-accent transition hover:-translate-y-0.5 hover:bg-accent hover:text-white">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.4h-1.2c-1.2 0-1.6.8-1.6 1.5V12h2.7l-.4 2.9h-2.3v7A10 10 0 0 0 22 12z"/></svg>
            </a>
          </div>
        </div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Product</h4><ul className="mt-2 space-y-1 text-muted"><li><a href="#features" className="hover:text-brand">Features</a></li><li><a href="#compare" className="hover:text-brand">Why MASAREN</a></li><li><a href="#download" className="hover:text-brand">Download</a></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Impact</h4><ul className="mt-2 space-y-1 text-muted"><li><a href="#sdg" className="hover:text-brand">SDGs</a></li><li><a href="#sdg" className="hover:text-brand">Egypt 2030</a></li><li><a href="#compare" className="hover:text-brand">POAI Verification</a></li></ul></div>
        <div className="text-sm"><h4 className="font-semibold text-ink">Get started</h4><ul className="mt-2 space-y-1 text-muted"><li><Link to="/login" className="hover:text-brand">Sign in</Link></li><li><a href="#download" className="hover:text-brand">Android APK</a></li><li><a href="#download" className="hover:text-brand">Web app</a></li></ul></div>
      </div>
      <p className="mx-auto mt-8 max-w-6xl px-4 text-xs text-muted">© 2026 MASAREN · Aligned with UN SDGs & Egypt Vision 2030 · POAI Verification</p>
    </footer>
  );
}

export default function LandingPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const onEmail = () => { if (email.trim()) setSent(true); };
  return (
    <div className="min-h-screen bg-white text-ink">
      <Nav />
      <Hero onEmail={onEmail} email={email} setEmail={setEmail} sent={sent} />
      <Stats />
      <Compare />
      <Features />
      <Sdg />
      <Testimonials />
      <Download />
      <Footer />
    </div>
  );
}
