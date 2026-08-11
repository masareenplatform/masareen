import { useState } from "react";
import { Link } from "react-router-dom";
import { IconShield, IconReports, IconGlobe, IconImpact, IconCheck, IconArrowRight } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useReveal } from "../hooks/anim";

const STAGES = [
  { n: 1, title: "Intake", text: "A claim and its evidence package enter the pipeline and get a unique, tamper-evident ID." },
  { n: 2, title: "Signal checks", text: "GPS, timestamps, metadata and third-party feeds are cross-validated automatically." },
  { n: 3, title: "POAI scoring", text: "The Proof of Actual Impact algorithm scores plausibility, completeness and SDG fit." },
  { n: 4, title: "Human audit", text: "High-stakes or low-confidence claims route to a field auditor or partner NGO." },
  { n: 5, title: "Verdict", text: "Each claim is verified, returned for more evidence, or rejected, with a full audit trail." },
];

const STAGE_TONES = ["#0250A3", "#0EA5E9", "#2A9D45", "#F59E0B", "#8B5CF6"];

const FAQ = [
  { q: "How is POAI different from a Like or a testimonial?", a: "A testimonial is someone's word. POAI combines evidence, location, third-party signals and a scoring model, so the outcome is independently checkable." },
  { q: "Can a verified claim ever be reversed?", a: "Yes. New evidence or an audit finding can update a verdict. The full history is preserved, which is exactly what makes it trustworthy." },
  { q: "Who runs the field audits?", a: "Trained MASAREEN auditors and accredited partner NGOs. Enterprises can also plug their own audit teams in via the API." },
];

function RevealBox({ children, className = "", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

function FaqItem({ q, a, open, onToggle }: any) {
  return (
    <div className="card overflow-hidden">
      <button onClick={onToggle} className="flex w-full items-center justify-between gap-3 px-5 py-4 text-left">
        <span className="font-semibold text-ink">{q}</span>
        <span className={`grid h-7 w-7 shrink-0 place-items-center rounded-full transition ${open ? "bg-brand text-white rotate-45" : "bg-canvas text-muted"}`}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
        </span>
      </button>
      {open && <p className="px-5 pb-4 text-sm text-muted">{a}</p>}
    </div>
  );
}

export default function VerificationPage() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-6xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center"><IconShield size={14} /> The verification pipeline</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Proof of Actual Impact, explained</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Every claim on MASAREEN moves through the same rigorous pipeline before it earns a POAI badge.</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto max-w-4xl px-4">
          <div className="relative">
            <div className="absolute left-[27px] top-2 bottom-2 w-px bg-line" />
            {STAGES.map((s, i) => (
              <RevealBox key={s.n} delay={i * 80} className="relative mb-6 flex gap-5">
                <div className="z-10 grid h-14 w-14 shrink-0 place-items-center rounded-2xl text-white shadow-card" style={{ background: STAGE_TONES[i] }}>
                  <span className="font-display text-lg font-bold">{s.n}</span>
                </div>
                <div className="card flex-1 p-5">
                  <h3 className="font-display text-lg font-bold text-ink">{s.title}</h3>
                  <p className="mt-1.5 text-sm text-muted">{s.text}</p>
                </div>
              </RevealBox>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-canvas py-14">
        <div className="mx-auto grid max-w-5xl gap-4 px-4 sm:grid-cols-3">
          {[
            { icon: IconGlobe, t: "Geo-tagged", d: "Location and time bound every piece of evidence." },
            { icon: IconImpact, t: "Outcome scored", d: "Plausibility and SDG fit graded by POAI." },
            { icon: IconCheck, t: "Audit trail", d: "Every verdict is logged and reversible with reason." },
          ].map((x, i) => (
            <RevealBox key={i} delay={i * 80} className="card p-5">
              <div className="mb-3 grid h-11 w-11 place-items-center rounded-xl bg-accent-50 text-accent"><x.icon size={22} /></div>
              <h3 className="font-display text-lg font-bold text-ink">{x.t}</h3>
              <p className="mt-1.5 text-sm text-muted">{x.d}</p>
            </RevealBox>
          ))}
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto max-w-3xl px-4">
          <h2 className="text-center font-display text-2xl font-extrabold text-ink">Why it matters</h2>
          <article className="card mt-6 p-6">
            <div className="flex items-center gap-2 text-brand"><IconReports size={18} /><h3 className="font-display font-bold text-ink">From promises to proof</h3></div>
            <p className="mt-3 text-sm text-muted">Most impact platforms optimise for attention. MASAREEN optimises for outcomes. When a funder, government or community opens a verified action, they see evidence, location and a score, not a slogan. That shift is what lets small NGOs compete for capital, lets companies report ESG without greenwashing, and lets governments show citizens real results. Verification is not a feature on top of the network. It is the network.</p>
          </article>

          <div className="mt-6 space-y-3">
            {FAQ.map((f, i) => (
              <FaqItem key={i} q={f.q} a={f.a} open={open === i} onToggle={() => setOpen(open === i ? null : i)} />
            ))}
          </div>
        </div>
      </section>

      <section className="cta-bleed section-pad">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-4 px-4 text-center">
          <h2 className="hero-tracking font-display text-3xl font-extrabold text-white sm:text-4xl">See the pipeline on your own claims</h2>
          <p className="max-w-xl text-white-soft">Bring a real program and we will run it through verification together.</p>
          <Link to="/login" className="btn-gold px-5 py-3 text-white">Request a demo <IconArrowRight size={16} /></Link>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
