import { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { IconDownload, IconBilling, IconShield, IconTrending, IconMoney, IconTask, IconReports, IconGlobe } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";

interface CostCategory {
  category: string;
  services: {
    name: string;
    provider: string;
    monthlyEGP: number;
    annualEGP: number;
    notes: string;
    tokensPerDay: number;
    costPerTokenEGP: number;
  }[];
  totalMonthly: number;
  costPerTokenEGP: number;
  tokensPerDay: number;
  annualEGP: number;
}

const COST_CATEGORIES: CostCategory[] = [
  {
    category: "Vision AI Services",
    services: [
      {
        name: "OpenAI GPT-4o Vision",
        provider: "OpenAI",
        monthlyEGP: 2273,
        annualEGP: 27276,
        notes: "150K tokens/day",
        tokensPerDay: 150000,
        costPerTokenEGP: 0.05,
      },
      {
        name: "Google Gemini Pro Vision",
        provider: "Google",
        monthlyEGP: 1964,
        annualEGP: 23574,
        notes: "150K calls/day",
        tokensPerDay: 150000,
        costPerTokenEGP: 0.04,
      },
    ],
    totalMonthly: 4237,
    costPerTokenEGP: 0.05,
    tokensPerDay: 150000,
    annualEGP: 50844,
  },
  {
    category: "Fraud Detection AI",
    services: [
      {
        name: "OpenAI GPT-4o",
        provider: "OpenAI",
        monthlyEGP: 1919,
        annualEGP: 23028,
        notes: "200K input tokens/day",
        tokensPerDay: 200000,
        costPerTokenEGP: 0.03,
      },
      {
        name: "Google Gemini Flash",
        provider: "Google",
        monthlyEGP: 1182,
        annualEGP: 14184,
        notes: "200K calls/day",
        tokensPerDay: 200000,
        costPerTokenEGP: 0.025,
      },
    ],
    totalMonthly: 3101,
    costPerTokenEGP: 0.03,
    tokensPerDay: 200000,
    annualEGP: 37212,
  },
  {
    category: "Impact Economist AI",
    services: [
      {
        name: "OpenAI GPT-4o",
        provider: "OpenAI",
        monthlyEGP: 883,
        annualEGP: 10608,
        notes: "100K tokens/day",
        tokensPerDay: 100000,
        costPerTokenEGP: 0.028,
      },
      {
        name: "Google Gemini Pro",
        provider: "Google",
        monthlyEGP: 1327,
        annualEGP: 15924,
        notes: "100K calls/day",
        tokensPerDay: 100000,
        costPerTokenEGP: 0.025,
      },
    ],
    totalMonthly: 2211,
    costPerTokenEGP: 0.028,
    tokensPerDay: 100000,
    annualEGP: 26532,
  },
  {
    category: "Graph Synthesis AI",
    services: [
      {
        name: "OpenAI GPT-4o",
        provider: "OpenAI",
        monthlyEGP: 429,
        annualEGP: 5154,
        notes: "50K tokens/day",
        tokensPerDay: 50000,
        costPerTokenEGP: 0.022,
      },
      {
        name: "Google Gemini Pro",
        provider: "Google",
        monthlyEGP: 641,
        annualEGP: 7692,
        notes: "50K calls/day",
        tokensPerDay: 50000,
        costPerTokenEGP: 0.02,
      },
    ],
    totalMonthly: 1070,
    costPerTokenEGP: 0.022,
    tokensPerDay: 50000,
    annualEGP: 12840,
  },
];

export default function FinancialReportPage() {
  const [loaded, setLoaded] = useState(false);
  const [activeCategory, setActiveCategory] = useState(0);

  useEffect(() => {
    setLoaded(true);
  }, []);

  const grandTotalEGP = COST_CATEGORIES.reduce((sum, c) => sum + c.totalMonthly, 0);
  const totalDailyTokens = COST_CATEGORIES.reduce((sum, c) => sum + c.tokensPerDay, 0);
  const totalDailyCalls = COST_CATEGORIES.reduce(
    (sum, c) => sum + c.services.reduce((s, svc) => s + svc.tokensPerDay, 0),
    0
  );

  // Per-user rate calculation
  const calculatePerUserRate = (monthlyCost: number, userCount: number) => {
    if (userCount === 0) return 0;
    return Math.round((monthlyCost / userCount) * 100) / 100;
  };

  // Financial analysis constants
  const FINANCIAL_ANALYSIS = {
    exchangeRateUSD: 50.5,
    exchangeRateNote: "1 USD = 50.5 EGP (August 2026)",
    annualInflationRate: 0.12, // 12% annual
    roiBreakEvenMonths: 18, // 18 months to break even at Production scenario
  };

  // Deployment scenarios constants
  const DEPLOYMENT_SCENARIOS = {
    aiDevelopment: {
      name: "AI Development",
      monthlyEGP: 4237,
      annualEGP: 50844,
      description: "Vision AI + Fraud Detection AI services for MVP validation",
      users: "Up to 1,000 MAU",
      dailyTokens: 350000,
      dailyCalls: 300000,
      includedServices: ["Vision AI", "Fraud Detection AI"],
    },
    aiProduction: {
      name: "AI Production",
      monthlyEGP: 9550,
      annualEGP: 114600,
      description: "All 4 AI categories (Vision + Fraud + Economist + Graph) for 5,000+ users",
      users: "5,000+ MAU",
      dailyTokens: 850000,
      dailyCalls: 800000,
      includedServices: ["Vision AI", "Fraud Detection AI", "Impact Economist AI", "Graph Synthesis AI"],
    },
    aiEnterprise: {
      name: "AI Enterprise",
      monthlyEGP: 21032,
      annualEGP: 252384,
      description: "Complete AI services at scale with volume discounts and custom models",
      users: "50,000+ MAU",
      dailyTokens: 2000000,
      dailyCalls: 1800000,
      includedServices: ["All 4 AI categories with volume discounts"],
      discountRate: 0.25, // 25% discount at enterprise scale
    },
  };

  // ROI and financial metrics
  const monthlyRevenueAtBreakEven = Math.round(grandTotalEGP * 1.2 * 100) / 100;
  const annualRevenueAtBreakEven = Math.round(monthlyRevenueAtBreakEven * 12 * 100) / 100;

  // Statistical analysis constants
  const AI_USAGE_METRICS = {
    baselineDailyTokens: 500000,
    baselineDailyCalls: 500000,
    projectedGrowthRate: 0.15, // 15% monthly growth
    quotaSafetyMargin: 0.8, // Use max 80% of quota
  };

  // Handler functions
  const handlePDFDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.tex";
    link.download = "MASAREN_Financial_Report.tex";
    link.click();
  };

  const handleLaTeXDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.tex";
    link.download = "MASAREN_Financial_Report.tex";
    link.click();
  };

  const handleExportCSV = () => {
    const csvData = [
      ["Category", "Monthly EGP", "Annual EGP", "Tokens/Day", "Cost/Token EGP"],
      ...COST_CATEGORIES.map((cat) => [
        cat.category,
        cat.totalMonthly,
        cat.annualEGP,
        cat.tokensPerDay,
        cat.costPerTokenEGP,
      ]),
      ["Total", grandTotalEGP, grandTotalEGP * 12, totalDailyTokens, "—"],
    ];
    const csvString = csvData.map((row) => row.join(",")).join("\n");
    const blob = new Blob([csvString], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.setAttribute("download", "MASAREN_Financial_Data.csv");
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
              Comprehensive AI services cost breakdown in Egyptian Pounds (EGP). All pricing in range 500-10,000 EGP/month per service. Includes statistical analysis, financial planning, and per-user rates.
            </p>
            <div className="mt-8 flex justify-center gap-4">
              <button onClick={handlePDFDownload} className="btn-xl btn-gold flex items-center gap-2">
                <IconDownload size={20} />
                Download Full Report (PDF)
              </button>
              <button onClick={handleLaTeXDownload} className="btn-xl btn-soft flex items-center gap-2">
                <IconMoney size={20} />
                Download LaTeX Source
              </button>
              <button onClick={handleExportCSV} className="btn-xl btn-outline flex items-center gap-2">
                <IconTask size={20} />
                Export Data
              </button>
            </div>
          </div>
        </div>
      </section>

      <section className="py-20 bg-gray-50">
        <div className="mx-auto max-w-6xl px-4">
          <div className="text-center mb-16">
            <span className="eyebrow mb-4 inline-block">AI Services Costs</span>
            <h2 className="font-display text-4xl font-extrabold text-ink">Monthly Cost Breakdown</h2>
            <p className="text-muted mt-4 max-w-2xl mx-auto">
              All prices in EGP using 1 USD = 50.5 EGP exchange rate (August 2026). AI services only. Infrastructure provided separately.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {COST_CATEGORIES.map((cat, i) => (
              <div
                key={cat.category}
                className="card cursor-pointer transition-transform duration-300 hover:scale-105"
                onClick={() => setActiveCategory(i)}
              >
                <div className="p-4 border-b border-line">
                  <h4 className="font-bold text-ink mb-1">{cat.category}</h4>
                  <p className="text-xs text-muted mb-2">
                    {cat.tokensPerDay.toLocaleString()} tokens/day •
                    {cat.costPerTokenEGP} EGP/tokan •
                    {cat.totalMonthly} EGP/month
                  </p>
                </div>
                <div className="p-3">
                  <div className="text-right">
                    <span className="text-xl font-bold text-brand">EGP {cat.totalMonthly.toLocaleString()}</span>
                    <span className="text-sm text-muted">/ month</span>
                  </div>
                  <div className="mt-2 text-sm text-muted">
                    EGP {cat.annualEGP.toLocaleString()} / year
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Cost per token analysis */}
          <div className="mt-8 p-6 bg-canvas rounded-xl">
            <h3 className="font-display text-2xl font-bold text-ink mb-4">Cost Per Token Analysis</h3>
            <div className="grid grid-cols-2 gap-4">
              {COST_CATEGORIES.map((cat) => (
                <div>
                  <p className="font-semibold text-ink">{cat.category}</p>
                  <p className="text-sm text-muted">EGP {cat.costPerTokenEGP}/token</p>
                  <p className="text-xs text-muted">{cat.services[0].notes}</p>
                </div>
              ))
            }
            </div>
          </div>

          {/* Statistical Analysis Section */}
          <section className="mt-8">
            <div className="mb-6">
              <h3 className="font-display text-2xl font-bold text-ink mb-3">Statistical Analysis</h3>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="font-semibold text-ink">Total Daily Tokens</p>
                  <p className="text-3xl font-bold text-brand">{totalDailyTokens.toLocaleString()}</p>
                </div>
                <div>
                  <p className="font-semibold text-ink">Total Daily Calls</p>
                  <p className="text-3xl font-bold text-brand">{totalDailyCalls.toLocaleString()}</p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4 mt-4">
                <div>
                  <p className="font-semibold text-ink">Baseline Daily Usage</p>
                  <p className="text-3xl font-bold text-brand">{AI_USAGE_METRICS.baselineDailyTokens.toLocaleString()}</p>
                </div>
                <div>
                  <p className="font-semibold text-ink">Growth Rate</p>
                  <p className="text-3xl font-bold text-brand">{AI_USAGE_METRICS.projectedGrowthRate * 100}%/month</p>
                </div>
              </div>
            </div>

            <div className="mt-6 p-4 bg-gray-100 rounded-lg">
              <h4 className="font-display text-semibold text-ink mb-2">Cost Efficiency</h4>
              <p className="text-muted">
                Average cost per thousand tokens: {
                  Math.round(
                    (COST_CATEGORIES.reduce(
                      (sum, c) => sum + c.costPerTokenEGP * c.tokensPerDay,
                      0
                    ) / totalDailyTokens) * 1000 * 100
                  ) / 100
                } EGP/ktoken
              </p>
              <p className="text-muted mt-2">
                Monthly savings at 80% quota utilization: {
                  Math.round((grandTotalEGP * 0.2 * 100) / 100)
                } EGP
              </p>
            </div>
          </section>

          {/* Financial Analysis Section */}
          <section className="mt-8">
            <div className="mb-6">
              <h3 className="font-display text-2xl font-bold text-ink mb-3">Financial Analysis</h3>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="font-semibold text-ink">Monthly AI Services Cost</p>
                  <p className="text-3xl font-bold text-brand">EGP {grandTotalEGP.toLocaleString()}</p>
                </div>
                <div>
                  <p className="font-semibold text-ink">Annual AI Services Cost</p>
                  <p className="text-3xl font-bold text-brand">EGP {(grandTotalEGP * 12).toLocaleString()}</p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4 mt-4">
                <div>
                  <p className="font-semibold text-ink">ROI Break-Even</p>
                  <p className="text-3xl font-bold text-brand">{FINANCIAL_ANALYSIS.roiBreakEvenMonths} months</p>
                </div>
                <div>
                  <p className="font-semibold text-ink">Annual Revenue at 20% Margin</p>
                  <p className="text-3xl font-bold text-brand">EGP {annualRevenueAtBreakEven.toLocaleString()}</p>
                </div>
              </div>
              <div className="mt-4 p-3 bg-canvas rounded-lg">
                <p className="text-sm text-muted">
                  {FINANCIAL_ANALYSIS.exchangeRateNote}<br/>
                  Annual inflation adjustment: {FINANCIAL_ANALYSIS.annualInflationRate * 100}%
                </p>
              </div>
            </div>

            {/* Per-User Rate Analysis */}
            <div className="mt-6 grid grid-cols-2 gap-4">
              {[
                { scenario: "AI Development", users: 1000, monthlyCost: DEPLOYMENT_SCENARIOS.aiDevelopment.monthlyEGP },
                { scenario: "AI Production", users: 5000, monthlyCost: DEPLOYMENT_SCENARIOS.aiProduction.monthlyEGP },
                { scenario: "AI Enterprise", users: 50000, monthlyCost: DEPLOYMENT_SCENARIOS.aiEnterprise.monthlyEGP },
              ].map((item) => (
                <div key={item.scenario}>
                  <p className="font-semibold text-ink">{item.scenario}</p>
                  <p className="text-2xl font-bold text-brand">EGP {calculatePerUserRate(item.monthlyCost, item.users).toLocaleString()}/user/month</p>
                  <p className="text-xs text-muted">Based on {item.users} MAU</p>
                </div>
              ))}
            </div>
          </section>

          {/* Deployment Scenarios */}
          <section className="mt-8">
            <div className="mb-6">
              <h3 className="font-display text-2xl font-bold text-ink mb-3">Deployment Scenarios</h3>
              <div className="space-y-4">
                {Object.values(DEPLOYMENT_SCENARIOS).map((scenario) => (
                  <div key={scenario.name} className="border border-line rounded-xl p-6">
                    <div className="font-display text-bold text-ink mb-2">{scenario.name}</div>
                    <p className="text-muted mb-2">{scenario.description}</p>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-sm text-muted">Monthly Cost</p>
                        <p className="font-bold text-brand">EGP {scenario.monthlyEGP.toLocaleString()}</p>
                      </div>
                      <div>
                        <p className="text-sm text-muted">Annual Cost</p>
                        <p className="font-bold text-brand">EGP {scenario.annualEGP.toLocaleString()}</p>
                      </div>
                    </div>
                    <p className="text-sm text-muted mt-2">
                      {scenario.users} target users |
                      {scenario.dailyTokens.toLocaleString()} daily tokens |
                      {scenario.includedServices.join(", ")}
                    </p>
                  </div>
                ))}
              </div>
            </div>

            <div>
              <p className="text-sm text-muted">
                {FINANCIAL_ANALYSIS.exchangeRateNote}. Volume discounts available at Enterprise scale (25% discount applicable).
              </p>
            </div>
          </section>
        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}