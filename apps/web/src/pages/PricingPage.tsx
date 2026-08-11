import { useState } from "react";
import { Link } from "react-router-dom";
import { IconCheck, IconShield, IconWallet } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";

const TIERS = [
  {
    name: "Free", price: "EGP 0", per: "/ forever", highlight: false,
    blurb: "For individuals and volunteers proving their own impact.",
    features: [
      "Personal impact passport", "POAI verification (standard queue)", "Join up to 10 programs",
      "Evidence upload with GPS", "Social feed & stories", "Up to 50 verified actions / month",
    ],
    cta: "Create free account",
  },
  {
    name: "Pro", price: "EGP 149", per: "/ month", highlight: true,
    blurb: "For professionals and small NGOs running real programs.",
    features: [
      "Everything in Free", "Unlimited verified actions", "Create & manage programs",
      "Priority verification (under 24h)", "Impact reports & export", "Team seats: 5",
      "MASAREEN Coin wallet",
    ],
    cta: "Start Pro trial",
  },
  {
    name: "Enterprise", price: "Custom", per: "", highlight: false,
    blurb: "For governments, corporates and large NGO networks.",
    features: [
      "Everything in Pro", "Audit API & data pipelines", "Field auditor network access",
      "SSO & role controls", "Dedicated success manager", "Custom SDG dashboards",
      "Unlimited team seats",
    ],
    cta: "Talk to sales",
  },
];

const FAQ = [
  { q: "Can I switch plans later?", a: "Yes. Upgrade or downgrade at any time from billing settings. Pro features activate immediately; downgrades apply at the next cycle." },
  { q: "What are MASAREEN Coins?", a: "An impact economy token used for brokerage, program funding and rewards. Coin fees fund the verification pipeline and are transparent on every transaction." },
  { q: "Do you offer NGO discounts?", a: "Registered nonprofits get 40% off Pro. Enterprise pilots for government programs are scoped case by case." },
  { q: "Is verification included?", a: "Yes, every plan includes POAI verification. Pro and Enterprise get priority queues and human field audits for high-stakes claims." },
];

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

export default function PricingPage() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <div className="min-h-screen bg-white text-ink">
      <MarketingNav />

      <section className="hero-dark pt-28 pb-16">
        <div className="mesh-dark" aria-hidden="true" />
        <div className="pointer-events-none absolute inset-0 bg-dots-dark opacity-50" />
        <div className="relative mx-auto max-w-6xl px-4 text-center">
          <span className="eyebrow text-white/80 justify-center"><IconWallet size={14} /> Simple, impact-first pricing</span>
          <h1 className="hero-tracking mt-4 font-display text-4xl font-extrabold text-white sm:text-5xl">Plans that scale with your impact</h1>
          <p className="text-white-soft mx-auto mt-3 max-w-2xl">Start free, prove outcomes, and upgrade when you run programs or need priority verification.</p>
        </div>
      </section>

      <section className="section-pad">
        <div className="mx-auto grid max-w-5xl gap-5 px-4 md:grid-cols-3">
          {TIERS.map((t) => (
            <div key={t.name} className={`card relative flex flex-col p-6 ${t.highlight ? "ring-2 ring-brand shadow-card" : ""}`}>
              {t.highlight && <span className="chip-accent absolute -top-3 left-1/2 -translate-x-1/2">Most popular</span>}
              <h3 className="font-display text-lg font-bold text-ink">{t.name}</h3>
              <div className="mt-3 flex items-end gap-1">
                <span className="font-display text-3xl font-extrabold text-ink">{t.price}</span>
                <span className="pb-1 text-sm text-muted">{t.per}</span>
              </div>
              <p className="mt-2 text-sm text-muted">{t.blurb}</p>
              <ul className="mt-4 flex-1 space-y-2.5">
                {t.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-ink">
                    <IconCheck size={18} className="mt-0.5 shrink-0 text-accent" />
                    <span>{f}</span>
                  </li>
                ))}
              </ul>
              <Link to="/login" className={`mt-6 px-4 py-2.5 text-center text-sm font-semibold ${t.highlight ? "btn-gold text-white" : "btn-soft"}`}>{t.cta}</Link>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t border-line bg-canvas py-14">
        <div className="mx-auto max-w-3xl px-4">
          <h2 className="text-center font-display text-2xl font-extrabold text-ink">Pricing questions</h2>
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
