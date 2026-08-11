import { useState } from "react";
import { Link } from "react-router-dom";
import {
  IconShield, IconCheck, IconReports, IconGlobe, IconImpact, IconArrowRight,
} from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useReveal } from "../hooks/anim";

const BRAND = "#0250A3";
const ACCENT = "#2A9D45";
const SKY = "#0EA5E9";
const AMBER = "#F59E0B";

const STEP_TONES = [BRAND, SKY, ACCENT, AMBER, "#8B5CF6"];

const STEPS = [
  {
    n: 1, title: "Claim the impact", text: "Record an action on MASAREEN. A volunteer hour, a planted tree, a trained cohort. The claim becomes a trackable unit of change.",
    icon: IconImpact,
  },
  {
    n: 2, title: "Submit evidence", text: "Attach photos, receipts, GPS tags and field notes. Evidence is bundled into a tamper-evident package linked to your impact passport.",
    icon: IconReports,
  },
  {
    n: 3, title: "GPS & field audit", text: "Our pipeline cross-checks location, timestamps and third-party signals. A field auditor or partner NGO can physically verify flagged claims.",
    icon: IconGlobe,
  },
  {
    n: 4, title: "POAI score", text: "The Proof of Actual Impact algorithm scores each claim for plausibility, completeness and SDG alignment. No score, no badge.",
    icon: IconShield,
  },
  {
    n: 5, title: "Verify & amplify", text: "Verified actions earn the POAI badge, count toward program goals, and travel with you across the network. Funders see proof, not promises.",
    icon: IconCheck,
  },
];

const FAQ = [
  { q: "What is POAI?", a: "Proof of Actual Impact is MASAREEN's verification standard. It combines submitted evidence, GPS and audit signals, and an alignment score so each claim is independently trustworthy." },
  { q: "Who can submit evidence?", a: "Any member. Individuals, NGOs, companies and government teams all submit through the same pipeline. Verification rigor scales with the claim's size and stakes." },
  { q: "How long does verification take?", a: "Most automated claims verify within minutes. Claims routed to a human field audit resolve within 2 to 5 business days depending on location." },
  { q: "What happens to rejected claims?", a: "Rejected claims keep their evidence and can be improved and resubmitted. Nothing is deleted, so your impact history stays honest and complete." },
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
        <span className={`grid h-7 w-7 place-items-center rounded-full transition ${open ? "bg-brand text-white rotate-45" : "bg-canvas text-muted"}`}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
        </span>
      </button>
      {open && <p className="px-5 pb-4 text-sm text-muted">{a}</p>}
    </div>
  );
}

export default function HowItWorksPage() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-6xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center"><IconShield size={14} /> POAI Verification</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">How MASAREEN verifies real-world impact</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Five steps take a raw claim from a field note to a trusted, auditable outcome the whole network can rely on.</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="relative mx-auto max-w-4xl px-4">
          <div className="absolute left-[27px] top-2 bottom-2 w-px bg-line" />
          {STEPS.map((s, i) => (
            <RevealBox key={s.n} delay={i * 80} className="relative mb-6 flex gap-5">
              <div className="z-10 grid h-14 w-14 shrink-0 place-items-center rounded-2xl text-white shadow-card" style={{ background: STEP_TONES[i] }}>
                <s.icon size={24} />
              </div>
              <div className="card flex-1 p-5">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold uppercase tracking-wide" style={{ color: STEP_TONES[i] }}>Step {s.n}</span>
                </div>
                <h3 className="mt-1 font-display text-lg font-bold text-ink">{s.title}</h3>
                <p className="mt-1.5 text-sm text-muted">{s.text}</p>
              </div>
            </RevealBox>
          ))}

          <RevealBox className="mt-8 card flex flex-col items-center gap-4 p-6 text-center sm:flex-row sm:text-left">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-accent-50 text-accent"><IconCheck size={24} /></div>
            <div>
              <p className="font-semibold text-ink">Every verified action gets a POAI badge</p>
              <p className="text-sm text-muted">It counts toward programs, your passport, and the metrics funders actually trust.</p>
            </div>
            <Link to="/verification" className="btn-gold ms-auto whitespace-nowrap px-4 py-2.5 text-white">See the pipeline <IconArrowRight size={16} /></Link>
          </RevealBox>
        </div>
      </section>

      <section className="border-t border-line bg-canvas py-14">
        <div className="mx-auto max-w-3xl px-4">
          <h2 className="text-center font-display text-2xl font-extrabold text-ink">Frequently asked</h2>
          <div className="mt-6 space-y-3">
            {FAQ.map((f, i) => (
              <FaqItem key={i} q={f.q} a={f.a} open={open === i} onToggle={() => setOpen(open === i ? null : i)} />
            ))}
          </div>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
