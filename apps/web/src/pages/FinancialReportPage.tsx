import { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { IconDownload, IconBilling, IconShield, IconTrending, IconMoney, IconTask, IconReports, IconGlobe } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";

interface CostCategory {
  category: string;
  services: { name: string; provider: string; monthlyEGP: number; annualEGP: number; notes: string }[];
  totalMonthly: number;
}

const COST_CATEGORIES: CostCategory[] = [
  {
    category: "Vision AI Services",
    services: [
      { name: "OpenAI GPT-4o Vision", provider: "OpenAI", monthlyEGP: 22725, annualEGP: 272700, notes: "150K tokens/day" },
      { name: "Google Gemini Pro Vision", provider: "Google", monthlyEGP: 19645, annualEGP: 235740, notes: "150K calls/day" },
    ],
    totalMonthly: 42370,
  },
  {
    category: "Fraud Detection AI",
    services: [
      { name: "OpenAI GPT-4o", provider: "OpenAI", monthlyEGP: 19190, annualEGP: 230280, notes: "200K input tokens/day" },
      { name: "Google Gemini Flash", provider: "Google", monthlyEGP: 11817, annualEGP: 141804, notes: "200K calls/day" },
    ],
    totalMonthly: 31007,
  },
  {
    category: "Impact Economist AI",
    services: [
      { name: "OpenAI GPT-4o", provider: "OpenAI", monthlyEGP: 8838, annualEGP: 106056, notes: "100K tokens/day" },
      { name: "Google Gemini Pro", provider: "Google", monthlyEGP: 13272, annualEGP: 159264, notes: "100K calls/day" },
    ],
    totalMonthly: 22110,
  },
  {
    category: "Graph Synthesis AI",
    services: [
      { name: "OpenAI GPT-4o", provider: "OpenAI", monthlyEGP: 4293, annualEGP: 51516, notes: "50K tokens/day" },
      { name: "Google Gemini Pro", provider: "Google", monthlyEGP: 6414, annualEGP: 76968, notes: "50K calls/day" },
    ],
    totalMonthly: 10707,
  },
];

const DEPLOYMENT_SCENARIOS = [
  {
    name: "AI Development",
    monthlyEGP: 42370,
    annualEGP: 508440,
    description: "Vision + fraud detection + economist AI services for MVP",
    users: "Up to 1,000 MAU",
  },
  {
    name: "AI Production",
    monthlyEGP: 95504,
    annualEGP: 1146048,
    description: "Full AI suite (vision, fraud, economist, graph synthesis) for 5,000+ users",
    users: "5,000+ MAU",
  },
  {
    name: "AI Enterprise",
    monthlyEGP: 210324,
    annualEGP: 2523888,
    description: "Complete AI services at scale with volume discounts and custom models",
    users: "50,000+ MAU",
  },
];

export default function FinancialReportPage() {
  const [loaded, setLoaded] = useState(false);
  const [activeCategory, setActiveCategory] = useState(0);

  useEffect(() => {
    setLoaded(true);
  }, []);

  const grandTotalEGP = COST_CATEGORIES.reduce((sum, c) => sum + c.totalMonthly, 0);

  const handleDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.tex";
    link.download = "MASAREN_Financial_Report.tex";
    link.click();
  };

  const handlePDFDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.pdf";
    link.download = "MASAREN_Financial_Report.pdf";
    link.click();
  };

  return (
    <div className="min-h-screen bg-white text-gray-800">
      <MarketingNav />

      <section className="relative overflow-hidden hero-dark pt-32 pb-24">
        <div className="mesh-dark absolute inset-0 -z-1" />
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-900/30 to-purple-900/30" />
        <div className="relative mx-auto max-w-5xl px-4 text-center">
          <div className={`transition-all duration-500 ${loaded ? "translate-y-0 opacity-100" : "translate-y-8 opacity-0"}`}>
            <span className="eyebrow text-white/80 mb-4 inline-flex items-center">
              <IconReports className="mr-2 h-5 w-5" />
              Complete Financial Infrastructure Report
            </span>
            <h1 className="font-display text-5xl font-extrabold tracking-tight text-white sm:text-6xl mb-6">
              MASAREN Platform Cost Analysis
            </h1>
            <p className="mx-auto mt-4 max-w-3xl text-xl text-white/90">
              Comprehensive infrastructure cost breakdown in Egyptian Pounds (EGP). Includes database, compute, storage, and deployment scenarios.
            </p>
            <div className="mt-8 flex justify-center gap-4">
              <button onClick={handlePDFDownload} className="btn-xl btn-gold flex items-center gap-2">
                <IconDownload size={20} />
                Download Full Report (PDF)
              </button>
              <button onClick={handleDownload} className="btn-xl btn-soft flex items-center gap-2">
                <IconMoney size={20} />
                Download LaTeX Source
              </button>
            </div>
          </div>
        </div>
      </section>

      <section className="py-20 bg-gray-50">
        <div className="mx-auto max-w-6xl px-4">
          <div className="text-center mb-16">
            <span className="eyebrow mb-4 inline-block">Infrastructure Costs</span>
            <h2 className="font-display text-4xl font-extrabold text-ink">Monthly Cost Breakdown</h2>
            <p className="text-muted mt-4 max-w-2xl mx-auto">All prices in EGP using 1 USD = 50.5 EGP exchange rate (August 2026)</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {COST_CATEGORIES.map((cat, i) => (
              <div
                key={cat.category}
                className="card cursor-pointer transition-transform duration-300 hover:scale-105"
                onClick={() => setActiveCategory(i)}
              >
                <h4 className="font-bold text-ink mb-3">{cat.category}</h4>
                <p className="text-sm text-muted mb-3">{cat.services.length} services</p>
                <div className="text-right">
                  <span className="text-2xl font-bold text-brand">EGP {cat.totalMonthly.toLocaleString()}</span>
                  <span className="text-sm text-muted">/ month</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="font-display text-4xl font-extrabold text-center text-ink mb-12">Total Infrastructure Cost</h2>
          <div className="text-center">
            <div className="text-6xl font-bold text-brand mb-4">EGP {grandTotalEGP.toLocaleString()}</div>
            <span className="text-xl text-muted mb-2">per month</span>
            <div className="text-2xl font-semibold text-ink">
              EGP {(grandTotalEGP * 12).toLocaleString()} / year
            </div>
          </div>
        </div>
      </section>

      <section className="py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="font-display text-4xl font-extrabold text-center text-ink mb-12">Deployment Scenarios</h2>
          
          <div className="space-y-8">
            {DEPLOYMENT_SCENARIOS.map((scenario) => (
              <div key={scenario.name} className="border border-line rounded-xl overflow-hidden">
                <div className="bg-canvas px-6 py-4 border-b border-line">
                  <h3 className="font-display text-2xl font-bold text-ink">{scenario.name}</h3>
                  <p className="text-muted mt-1">{scenario.description}</p>
                </div>
                <div className="p-6 grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="text-center">
                    <div className="text-4xl font-bold text-brand">EGP {scenario.monthlyEGP.toLocaleString()}</div>
                    <span className="text-sm text-muted">/ month</span>
                  </div>
                  <div className="text-center">
                    <div className="text-4xl font-bold text-ink">EGP {scenario.annualEGP.toLocaleString()}</div>
                    <span className="text-sm text-muted">/ year</span>
                  </div>
                  <div className="text-center">
                    <div className="font-semibold text-ink">{scenario.users}</div>
                    <span className="text-sm text-muted">Target users</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}