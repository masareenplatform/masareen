import { Link } from "react-router-dom";
import { IconCheck, IconSearch, IconShield, IconTrending, IconGlobe, IconImpact, IconReports, IconArrowRight } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useReveal } from "../hooks/anim";

const RESOURCES = [
  { tag: "Guide", icon: IconShield, title: "The POAI verification playbook", text: "A step-by-step guide to submitting evidence that verifies first time, with GPS and audit best practices.", read: "8 min" },
  { tag: "SDG", icon: IconGlobe, title: "Mapping work to the 17 SDGs", text: "How to tag actions to UN goals and Egypt Vision 2030 so funders see alignment instantly.", read: "6 min" },
  { tag: "Case study", icon: IconImpact, title: "GreenRoots: 12K saplings, fully verified", text: "How a local NGO turned field work into trusted, fundable impact in one season.", read: "5 min" },
  { tag: "Guide", icon: IconReports, title: "Writing audit-ready impact reports", text: "Templates and export tips for programs that need to satisfy donors and regulators.", read: "7 min" },
  { tag: "Case study", icon: IconImpact, title: "Masrena CSR: funding clean water", text: "Transparent coin-based funding for three wells, with on-chain proof of delivery.", read: "4 min" },
  { tag: "SDG", icon: IconGlobe, title: "Climate Action starter kit", text: "Programs, tasks and evidence packs to launch a verified climate initiative this quarter.", read: "9 min" },
];

function RevealBox({ children, className = "", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

export default function ResourcesPage() {
  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-6xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center"><IconReports size={14} /> Guides & playbooks</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Resources for impact that holds up</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Verification guides, SDG playbooks and case studies to help you prove and scale real-world change.</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto grid max-w-6xl gap-4 px-4 sm:grid-cols-2 lg:grid-cols-3">
          {RESOURCES.map((r, i) => (
            <RevealBox key={r.title} delay={(i % 3) * 80} className="card hover-lift flex flex-col p-5">
              <div className="mb-3 flex items-center justify-between">
                <div className="grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand"><r.icon size={22} /></div>
                <span className="chip-brand text-[11px]">{r.tag}</span>
              </div>
              <h3 className="font-display text-lg font-bold text-ink">{r.title}</h3>
              <p className="mt-1.5 flex-1 text-sm text-muted">{r.text}</p>
              <a href="#" className="mt-4 inline-flex items-center gap-1.5 text-sm font-semibold text-brand hover:underline">Read guide <IconArrowRight size={16} /></a>
            </RevealBox>
          ))}
        </div>
      </section>

      <section className="cta-bleed section-pad">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-4 px-4 text-center">
          <h2 className="hero-tracking font-display text-3xl font-extrabold text-white sm:text-4xl">Need a tailored playbook?</h2>
          <p className="max-w-xl text-white-soft">Our verification team helps organizations design evidence workflows that pass audit the first time.</p>
          <Link to="/login" className="btn-gold px-5 py-3 text-white">Request a walkthrough <IconArrowRight size={16} /></Link>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
