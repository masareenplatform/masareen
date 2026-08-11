import { Link } from "react-router-dom";
import { IconTrophy, IconGlobe, IconHeart, IconUsers, IconImpact, IconShield, IconArrowRight } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { MiniAvatar } from "../components/common/Showcase";
import { useReveal, useCountUp } from "../hooks/anim";

const BRAND = "#0250A3";
const ACCENT = "#2A9D45";

const STATS = [
  { end: 8421, label: "Members", icon: IconUsers },
  { end: 128400, label: "Verified actions", icon: IconImpact },
  { end: 36, label: "Countries", icon: IconGlobe },
  { end: 17, label: "SDGs tracked", icon: IconShield },
];

const TEAM = [
  { name: "Amira Saleh", role: "Co-founder & CEO" },
  { name: "Youssef Adel", role: "Co-founder & CTO" },
  { name: "Lina Farouk", role: "Head of Verification" },
  { name: "Omar Tarek", role: "Field Operations" },
  { name: "Sara Nabil", role: "Partnerships" },
  { name: "Khaled Hassan", role: "Policy & Government" },
];

const TIMELINE = [
  { year: "2024", text: "MASAREEN founded with a single idea: impact should be provable, not performative." },
  { year: "2025", text: "POAI verification pipeline launched; first 1,000 verified actions completed across Egypt." },
  { year: "2026", text: "Crossed 8,400 members in 36 countries and expanded to government programs." },
];

function RevealBox({ children, className = "", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

function Stat({ end, label, icon: Icon }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>({ threshold: 0.4 });
  const value = useCountUp(end, shown, 1600, 0);
  return (
    <div ref={ref} className="card flex flex-col items-center gap-2 p-5 text-center">
      <div className="grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand"><Icon size={22} /></div>
      <div className="font-display text-3xl font-extrabold text-ink">{value}</div>
      <div className="text-sm text-muted">{label}</div>
    </div>
  );
}

export default function AboutPage() {
  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-4xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center"><IconShield size={14} /> Our mission</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Building verified impact infrastructure for everyone</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">MASAREEN is the professional network where NGOs, companies, governments and citizens prove real-world change. We replace promises with proof.</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto grid max-w-5xl grid-cols-2 gap-4 px-4 sm:grid-cols-4">
          {STATS.map((s, i) => <Stat key={i} end={s.end} label={s.label} icon={s.icon} />)}
        </div>
      </section>

      <section className="py-12">
        <div className="mx-auto max-w-5xl px-4">
          <RevealBox className="text-center">
            <h2 className="font-display text-2xl font-extrabold text-ink">The team behind MASAREEN</h2>
            <p className="mx-auto mt-2 max-w-xl text-muted">Verifiers, engineers and field workers building trust into every action.</p>
          </RevealBox>
          <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3">
            {TEAM.map((m, i) => (
              <RevealBox key={m.name} delay={i * 60} className="card flex items-center gap-3 p-4">
                <MiniAvatar name={m.name} size={48} />
                <div>
                  <p className="font-semibold text-ink">{m.name}</p>
                  <p className="text-xs text-muted">{m.role}</p>
                </div>
              </RevealBox>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-canvas py-14">
        <div className="mx-auto max-w-3xl px-4">
          <h2 className="text-center font-display text-2xl font-extrabold text-ink">Our journey</h2>
          <div className="relative mt-8">
            <div className="absolute left-[7px] top-2 bottom-2 w-px bg-line" />
            {TIMELINE.map((t, i) => (
              <RevealBox key={i} delay={i * 80} className="relative mb-6 flex gap-5">
                <div className="z-10 mt-1 h-4 w-4 shrink-0 rounded-full border-4 border-white" style={{ background: i % 2 ? ACCENT : BRAND }} />
                <div className="card flex-1 p-4">
                  <span className="text-xs font-bold uppercase tracking-wide" style={{ color: i % 2 ? ACCENT : BRAND }}>{t.year}</span>
                  <p className="mt-1 text-sm text-ink">{t.text}</p>
                </div>
              </RevealBox>
            ))}
          </div>
        </div>
      </section>

      <section className="cta-bleed section-pad">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-4 px-4 text-center">
          <h2 className="hero-tracking font-display text-3xl font-extrabold text-white sm:text-4xl">Join the impact network</h2>
          <p className="max-w-xl text-white-soft">Prove your work, track outcomes, and grow a verifiable impact record.</p>
          <Link to="/login" className="btn-gold px-5 py-3 text-white">Get started free <IconArrowRight size={16} /></Link>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
