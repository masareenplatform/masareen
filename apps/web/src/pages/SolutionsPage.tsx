import { useParams, Link } from "react-router-dom";
import { IconShield, IconUsers, IconGlobe, IconImpact, IconWallet, IconArrowRight, IconReports } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";
import { useReveal } from "../hooks/anim";

type Segment = "ngo" | "corporate" | "government" | "university" | "investor" | "community";

const CONTENT: Record<Segment, { title: string; sub: string; hero: string; benefits: { icon: any; t: string; d: string }[] }> = {
  ngo: {
    title: "For NGOs",
    sub: "Prove every outcome to funders",
    hero: "Turn field work into trusted, verifiable impact that unlocks the next grant.",
    benefits: [
      { icon: IconShield, t: "Funder-ready proof", d: "Every program outcome carries a POAI badge donors and regulators accept." },
      { icon: IconImpact, t: "Program lifecycle", d: "Launch, assign and complete tasks with evidence attached at each step." },
      { icon: IconWallet, t: "Transparent funding", d: "Receive MASAREEN Coin grants with on-chain proof of delivery." },
    ],
  },
  corporate: {
    title: "For Corporates",
    sub: "Measurable CSR & ESG",
    hero: "Make your social responsibility claims auditable instead of aspirational.",
    benefits: [
      { icon: IconReports, t: "ESG reporting", d: "Export verified impact directly into sustainability disclosures." },
      { icon: IconUsers, t: "Employee programs", d: "Run volunteering at scale with tracked, verified participation." },
      { icon: IconGlobe, t: "SDG alignment", d: "Map initiatives to UN goals and Egypt Vision 2030 automatically." },
    ],
  },
  government: {
    title: "For Government",
    sub: "Accountable public impact",
    hero: "Digital infrastructure that makes public programs transparent and measurable.",
    benefits: [
      { icon: IconShield, t: "Audit pipeline", d: "Independent verification of delivered services across agencies." },
      { icon: IconGlobe, t: "National alignment", d: "Track progress against Egypt Vision 2030 in real time." },
      { icon: IconImpact, t: "Citizen trust", d: "Publish verified outcomes the public can see and trust." },
    ],
  },
  university: {
    title: "For Universities",
    sub: "Research & service learning",
    hero: "Give students a verifiable record of community impact and field research.",
    benefits: [
      { icon: IconUsers, t: "Student passports", d: "Students build portable impact records that follow them to employers." },
      { icon: IconImpact, t: "Field research", d: "GPS-tagged evidence makes community projects citable and verified." },
      { icon: IconShield, t: "Academic trust", d: "POAI scoring supports rigorous, auditable service learning." },
    ],
  },
  investor: {
    title: "For Investors",
    sub: "Impact you can underwrite",
    hero: "Diligence impact the same way you diligence financials, with proof not prose.",
    benefits: [
      { icon: IconReports, t: "Verified metrics", d: "Compare portfolio impact on a single, audited standard." },
      { icon: IconWallet, t: "Coin economy", d: "Fund verified outcomes through transparent MASAREEN Coin flows." },
      { icon: IconShield, t: "Risk reduction", d: "Independent verification lowers greenwashing and reporting risk." },
    ],
  },
  community: {
    title: "For Communities",
    sub: "Change you can see",
    hero: "Organize local action and watch your collective impact get verified and recognized.",
    benefits: [
      { icon: IconUsers, t: "Local organizing", d: "Coordinate cleanups, clinics and drives with shared proof." },
      { icon: IconImpact, t: "Visible outcomes", d: "Your neighborhood's verified impact shows up on the map." },
      { icon: IconShield, t: "Trusted voice", d: "POAI verification gives community work institutional weight." },
    ],
  },
};

function RevealBox({ children, className = "", delay = 0 }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal ${shown ? "is-visible" : ""} ${className}`} style={delay ? { transitionDelay: `${delay}ms` } : undefined}>
      {children}
    </div>
  );
}

export default function SolutionsPage() {
  const { segment } = useParams();
  const key = (segment as Segment) in CONTENT ? (segment as Segment) : "ngo";
  const c = CONTENT[key];

  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-5xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center">{c.title}</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">{c.sub}</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">{c.hero}</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto grid max-w-5xl gap-5 px-4 md:grid-cols-3">
          {c.benefits.map((b, i) => (
            <RevealBox key={i} delay={i * 80} className="card hover-lift p-5">
              <div className="mb-3 grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand">{typeof b.icon === "function" ? <b.icon size={22} /> : b.icon}</div>
              <h3 className="font-display text-lg font-bold text-ink">{b.t}</h3>
              <p className="mt-1.5 text-sm text-muted">{b.d}</p>
            </RevealBox>
          ))}
        </div>
      </section>

      <section className="cta-bleed section-pad">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-40" />
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-4 px-4 text-center">
          <h2 className="hero-tracking font-display text-3xl font-extrabold text-white sm:text-4xl">See MASAREEN for {c.title.replace("For ", "")}</h2>
          <p className="max-w-xl text-white-soft">Set up a tailored workspace and start verifying impact this week.</p>
          <Link to="/login" className="btn-gold px-5 py-3 text-white">Request a demo <IconArrowRight size={16} /></Link>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
