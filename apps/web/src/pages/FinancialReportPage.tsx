import { useState, useEffect } from "react";
import { IconDownload, IconMoney, IconTask, IconReports } from "../components/icons/Icons";
import MarketingNav from "../components/marketing/MarketingNav";
import MarketingFooter from "../components/marketing/MarketingFooter";

interface AIService {
  name: string;
  provider: string;
  model: string;
  monthlyEGP: number;
  monthlyUSD: number;
  annualEGP: number;
  inputTokDay: number;
  outputTokDay: number;
  notes: string;
  recommended: boolean;
}

const AI_SERVICES: AIService[] = [
  {
    name: "Vision AI",
    provider: "Google",
    model: "Gemini 1.5 Pro",
    monthlyEGP: 663,
    monthlyUSD: 13.13,
    annualEGP: 7956,
    inputTokDay: 150000,
    outputTokDay: 50000,
    notes: "Evidence image/video analysis for SDG verification",
    recommended: true,
  },
  {
    name: "Vision AI (Fallback)",
    provider: "OpenAI",
    model: "GPT-4o",
    monthlyEGP: 1326,
    monthlyUSD: 26.25,
    annualEGP: 15912,
    inputTokDay: 150000,
    outputTokDay: 50000,
    notes: "Fallback when Gemini unavailable",
    recommended: false,
  },
  {
    name: "Fraud Detection",
    provider: "Google",
    model: "Gemini 1.5 Flash",
    monthlyEGP: 68,
    monthlyUSD: 1.35,
    annualEGP: 816,
    inputTokDay: 200000,
    outputTokDay: 100000,
    notes: "Geospatial and behavioral fraud scoring",
    recommended: true,
  },
  {
    name: "Fraud Detection (Fallback)",
    provider: "OpenAI",
    model: "GPT-4o",
    monthlyEGP: 2273,
    monthlyUSD: 45.00,
    annualEGP: 27276,
    inputTokDay: 200000,
    outputTokDay: 100000,
    notes: "Fallback when Gemini unavailable",
    recommended: false,
  },
  {
    name: "Impact Economist",
    provider: "OpenAI",
    model: "GPT-4o",
    monthlyEGP: 1591,
    monthlyUSD: 31.50,
    annualEGP: 19092,
    inputTokDay: 100000,
    outputTokDay: 80000,
    notes: "Social value computation and SDG scoring",
    recommended: true,
  },
  {
    name: "Graph Synthesis",
    provider: "OpenAI",
    model: "GPT-4o",
    monthlyEGP: 795,
    monthlyUSD: 15.75,
    annualEGP: 9540,
    inputTokDay: 50000,
    outputTokDay: 40000,
    notes: "Knowledge graph construction and PMS delta analysis",
    recommended: true,
  },
  {
    name: "Chat Assistant",
    provider: "OpenRouter",
    model: "Gemma 4 31B IT",
    monthlyEGP: 47,
    monthlyUSD: 0.94,
    annualEGP: 564,
    inputTokDay: 80000,
    outputTokDay: 60000,
    notes: "User-facing conversational AI support",
    recommended: true,
  },
  {
    name: "Verification Orchestrator",
    provider: "OpenRouter",
    model: "Gemma 4 31B IT",
    monthlyEGP: 76,
    monthlyUSD: 1.51,
    annualEGP: 912,
    inputTokDay: 120000,
    outputTokDay: 100000,
    notes: "Multi-agent CrewAI verification pipeline",
    recommended: true,
  },
  {
    name: "Report Generator",
    provider: "Google",
    model: "Gemini 1.5 Flash",
    monthlyEGP: 32,
    monthlyUSD: 0.63,
    annualEGP: 384,
    inputTokDay: 40000,
    outputTokDay: 60000,
    notes: "Narrative synthesis for impact reports",
    recommended: true,
  },
];

const PROVIDER_COSTS = [
  { provider: "OpenAI", monthlyEGP: 2386, pct: 72.9, services: "Impact Economist + Graph Synthesis" },
  { provider: "Google", monthlyEGP: 763, pct: 23.3, services: "Vision AI + Fraud Detection + Report Generator" },
  { provider: "OpenRouter", monthlyEGP: 123, pct: 3.8, services: "Chat Assistant + Verification Orchestrator" },
];

const DEPLOYMENT_SCENARIOS = [
  {
    name: "Development",
    monthlyEGP: 831,
    annualEGP: 9972,
    users: 1000,
    dailyTokens: 310000,
    perUser: 0.83,
    description: "Vision AI + Fraud Detection for MVP validation",
    services: ["Vision AI", "Fraud Detection"],
    servicesActive: 2,
  },
  {
    name: "Production",
    monthlyEGP: 3372,
    annualEGP: 40464,
    users: 5000,
    dailyTokens: 740000,
    perUser: 0.34,
    description: "All 7 AI services at production scale",
    services: ["Vision AI", "Fraud Detection", "Impact Economist", "Graph Synthesis", "Chat", "Verification", "Reports"],
    servicesActive: 7,
  },
  {
    name: "Enterprise",
    monthlyEGP: 2139,
    annualEGP: 25668,
    users: 50000,
    dailyTokens: 3700000,
    perUser: 0.04,
    description: "All AI services with 25% volume discount",
    services: ["All 7 AI services + volume discounts"],
    servicesActive: 7,
  },
];

const TOKEN_STATS = [
  { scenario: "Development", inputTok: 330000, outputTok: 290000, monthlyTok: 18600000, apiCalls: 600 },
  { scenario: "Production", inputTok: 740000, outputTok: 490000, monthlyTok: 36900000, apiCalls: 3000 },
  { scenario: "Enterprise", inputTok: 3700000, outputTok: 2450000, monthlyTok: 184500000, apiCalls: 30000 },
];

const COST_EFFICIENCY = [
  { metric: "Cost per 1K Tokens (EGP)", dev: "0.18", prod: "0.09", ent: "0.02" },
  { metric: "Cost per API Call (EGP)", dev: "1.39", prod: "1.12", ent: "0.07" },
  { metric: "Cost per Evidence (EGP)", dev: "4.16", prod: "1.69", ent: "0.17" },
  { metric: "Cost per Report (EGP)", dev: "83.10", prod: "11.24", ent: "1.07" },
  { metric: "Cost per User/Month (EGP)", dev: "0.83", prod: "0.34", ent: "0.04" },
];

const RISK_MATRIX = [
  { risk: "AI Cost Overruns", prob: "Medium", impact: "High", mitigation: "Usage quotas, prompt optimization, model caching" },
  { risk: "Provider Price Increases", prob: "Low", impact: "Medium", mitigation: "Multi-provider strategy, annual commitments" },
  { risk: "API Rate Limits", prob: "Medium", impact: "Medium", mitigation: "Request queuing, batch processing, fallback models" },
  { risk: "Currency Fluctuation", prob: "High", impact: "Medium", mitigation: "Fix pricing in EGP, quarterly rate reviews" },
  { risk: "Token Usage Spike", prob: "Medium", impact: "Medium", mitigation: "Rate limiting, auto-scaling quotas, burst budgets" },
];

const GROWTH_PROJECTIONS = [
  { month: "Month 1-3", mau: 500, tokens: "310,000", cost: 1636, revenue: 2100, margin: "+28%" },
  { month: "Month 4-6", mau: 2000, tokens: "620,000", cost: 3272, revenue: 4200, margin: "+28%" },
  { month: "Month 7-9", mau: 5000, tokens: "1,230,000", cost: 3372, revenue: 9500, margin: "+182%" },
  { month: "Month 10-12", mau: 10000, tokens: "2,460,000", cost: 5200, revenue: 19000, margin: "+265%" },
  { month: "Year 2", mau: 25000, tokens: "4,920,000", cost: 7800, revenue: 47500, margin: "+509%" },
];

const QUOTA_TABLE = [
  { tier: "Development", dailyTokens: "10,000", dailyCalls: "50", monthlyCap: "200,000", overage: "2x base" },
  { tier: "Production", dailyTokens: "50,000", dailyCalls: "200", monthlyCap: "1,000,000", overage: "1.5x base" },
  { tier: "Enterprise", dailyTokens: "200,000", dailyCalls: "1,000", monthlyCap: "5,000,000", overage: "1.2x base" },
];

const USER_COST_SCHEDULE = [
  { tier: "Development", users: "Up to 1,000", dailyTokens: "350,000", costPerUser: 4.24, services: "Vision AI + Fraud Detection" },
  { tier: "Production", users: "5,000+", dailyTokens: "850,000", costPerUser: 1.91, services: "All 7 AI services" },
  { tier: "Enterprise", users: "50,000+", dailyTokens: "2,000,000", costPerUser: 0.42, services: "All AI + volume discounts" },
];

const REVENUE_PROJECTIONS = [
  { tier: "Development", users: 1000, costPerUser: 4.24, monthlyRevenue: 4240, recovery: "510%" },
  { tier: "Production", users: 5000, costPerUser: 1.91, monthlyRevenue: 9550, recovery: "283%" },
  { tier: "Enterprise", users: 50000, costPerUser: 0.42, monthlyRevenue: 21000, recovery: "985%" },
];

const RECOMMENDED_TOTAL = { monthlyEGP: 3272, monthlyUSD: 64.81, annualEGP: 39264 };

export default function FinancialReportPage() {
  const [loaded, setLoaded] = useState(false);
  const [activeTab, setActiveTab] = useState<"overview" | "services" | "scenarios" | "admin" | "risk">("overview");

  useEffect(() => {
    setLoaded(true);
  }, []);

  const handlePDFDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.pdf";
    link.download = "MASAREN_AI_Financial_Report.pdf";
    link.click();
  };

  const handleLaTeXDownload = () => {
    const link = document.createElement("a");
    link.href = "/docs/techdocs/techdocs.tex";
    link.download = "MASAREN_AI_Financial_Report.tex";
    link.click();
  };

  const handleExportCSV = () => {
    const csvData = [
      ["Service", "Provider", "Model", "Monthly EGP", "Monthly USD", "Annual EGP", "Input Tok/Day", "Output Tok/Day"],
      ...AI_SERVICES.filter((s) => s.recommended).map((s) => [
        s.name, s.provider, s.model, s.monthlyEGP, s.monthlyUSD, s.annualEGP, s.inputTokDay, s.outputTokDay,
      ]),
      ["TOTAL", "", "", RECOMMENDED_TOTAL.monthlyEGP, RECOMMENDED_TOTAL.monthlyUSD, RECOMMENDED_TOTAL.annualEGP, "", ""],
    ];
    const csvString = csvData.map((row) => row.join(",")).join("\n");
    const blob = new Blob([csvString], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.setAttribute("download", "MASAREN_AI_Financial_Data.csv");
    link.click();
  };

  const recommendedServices = AI_SERVICES.filter((s) => s.recommended);
  const totalInputTok = recommendedServices.reduce((sum, s) => sum + s.inputTokDay, 0);
  const totalOutputTok = recommendedServices.reduce((sum, s) => sum + s.outputTokDay, 0);

  return (
    <div className="min-h-screen bg-white text-gray-800">
      <MarketingNav />

      {/* Hero */}
      <section className="relative overflow-hidden hero-dark pt-32 pb-24">
        <div className="mesh-dark absolute inset-0 -z-1" />
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-900/30 to-purple-900/30" />
        <div className="relative mx-auto max-w-5xl px-4 text-center">
          <div className={`transition-all duration-500 ${loaded ? "translate-y-0 opacity-100" : "translate-y-8 opacity-0"}`}>
            <span className="eyebrow text-white/80 mb-4 inline-flex items-center">
              <IconReports className="mr-2 h-5 w-5" />
              AI Services Financial Audit Report
            </span>
            <h1 className="font-display text-5xl font-extrabold tracking-tight text-white sm:text-6xl mb-6">
              MASAREN AI Cost Analysis
            </h1>
            <p className="mx-auto mt-4 max-w-3xl text-xl text-white/90">
              AI-only cost analysis and budget planning for Egyptian Pound (EGP) range: 500-10,000/month per service. Seven AI services, three providers, one user-charged financial model.
            </p>
            <div className="mt-8 flex flex-wrap justify-center gap-4">
              <button onClick={handlePDFDownload} className="btn-xl btn-gold flex items-center gap-2">
                <IconDownload size={20} />
                Download PDF Report
              </button>
              <button onClick={handleLaTeXDownload} className="btn-xl btn-soft flex items-center gap-2">
                <IconMoney size={20} />
                Download LaTeX Source
              </button>
              <button onClick={handleExportCSV} className="btn-xl btn-outline flex items-center gap-2">
                <IconTask size={20} />
                Export CSV Data
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Summary Cards */}
      <section className="py-12 bg-gray-50">
        <div className="mx-auto max-w-6xl px-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: "Total Monthly Cost", value: `EGP ${RECOMMENDED_TOTAL.monthlyEGP.toLocaleString()}`, sub: `USD ${RECOMMENDED_TOTAL.monthlyUSD}` },
              { label: "Annual Cost", value: `EGP ${RECOMMENDED_TOTAL.annualEGP.toLocaleString()}`, sub: "Recommended config" },
              { label: "AI Services", value: "7", sub: "Across 3 providers" },
              { label: "Budget Range", value: "500 - 10K", sub: "EGP / month / service" },
            ].map((card) => (
              <div key={card.label} className="card p-4 text-center">
                <p className="text-xs text-muted uppercase tracking-wider">{card.label}</p>
                <p className="text-2xl font-bold text-brand mt-1">{card.value}</p>
                <p className="text-xs text-muted mt-1">{card.sub}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Tab Navigation */}
      <section className="py-8 bg-white border-b border-line">
        <div className="mx-auto max-w-6xl px-4">
          <div className="flex gap-2 overflow-x-auto">
            {[
              { key: "overview" as const, label: "Cost Overview" },
              { key: "services" as const, label: "Service Breakdown" },
              { key: "scenarios" as const, label: "Deployment Scenarios" },
              { key: "admin" as const, label: "Admin Controls" },
              { key: "risk" as const, label: "Risk & Growth" },
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-colors ${
                  activeTab === tab.key ? "bg-brand text-white" : "bg-gray-100 text-muted hover:bg-gray-200"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16 bg-gray-50">
        <div className="mx-auto max-w-6xl px-4">

          {/* Tab: Cost Overview */}
          {activeTab === "overview" && (
            <div>
              <h2 className="font-display text-3xl font-extrabold text-ink mb-8">AI Services Cost Overview</h2>

              {/* Provider breakdown */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Monthly Cost by Provider</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Provider</th>
                      <th className="text-right p-3 font-bold text-ink">Monthly EGP</th>
                      <th className="text-right p-3 font-bold text-ink">% of Total</th>
                      <th className="text-left p-3 font-bold text-ink">Services</th>
                    </tr></thead>
                    <tbody>
                      {PROVIDER_COSTS.map((p) => (
                        <tr key={p.provider} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{p.provider}</td>
                          <td className="p-3 text-right font-bold text-brand">EGP {p.monthlyEGP.toLocaleString()}</td>
                          <td className="p-3 text-right">{p.pct}%</td>
                          <td className="p-3 text-muted">{p.services}</td>
                        </tr>
                      ))}
                      <tr className="border-t-2 border-ink bg-gray-50 font-bold">
                        <td className="p-3 text-ink">TOTAL</td>
                        <td className="p-3 text-right text-brand">EGP {RECOMMENDED_TOTAL.monthlyEGP.toLocaleString()}</td>
                        <td className="p-3 text-right">100%</td>
                        <td className="p-3 text-muted">7 services</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Provider cost bar visualization */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Provider Cost Distribution</h3>
                <div className="space-y-3">
                  {PROVIDER_COSTS.map((p) => (
                    <div key={p.provider}>
                      <div className="flex justify-between text-sm mb-1">
                        <span className="font-medium text-ink">{p.provider}</span>
                        <span className="text-muted">EGP {p.monthlyEGP.toLocaleString()} ({p.pct}%)</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-4">
                        <div
                          className={`h-4 rounded-full ${p.provider === "OpenAI" ? "bg-blue-600" : p.provider === "Google" ? "bg-green-600" : "bg-purple-600"}`}
                          style={{ width: `${p.pct}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Category breakdown */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Monthly Cost by Category</h3>
                <div className="card p-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <p className="text-sm text-muted">AI Model Inference (LLM)</p>
                      <p className="text-xl font-bold text-brand">EGP 3,172 <span className="text-sm font-normal text-muted">(96.9%)</span></p>
                    </div>
                    <div>
                      <p className="text-sm text-muted">Embedding Services (Qdrant)</p>
                      <p className="text-xl font-bold text-brand">EGP 100 <span className="text-sm font-normal text-muted">(3.1%)</span></p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Key financial metrics */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {[
                  { label: "Cost Recovery Rate", value: "100%", note: "All AI costs billed to users" },
                  { label: "Platform Subsidy", value: "0 EGP", note: "Zero platform cost for AI" },
                  { label: "Per-User (Production)", value: "EGP 1.91", note: "5,000+ users" },
                  { label: "Per-User (Enterprise)", value: "EGP 0.42", note: "50,000+ users" },
                ].map((m) => (
                  <div key={m.label} className="card p-4">
                    <p className="text-xs text-muted uppercase">{m.label}</p>
                    <p className="text-xl font-bold text-brand mt-1">{m.value}</p>
                    <p className="text-xs text-muted mt-1">{m.note}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Tab: Service Breakdown */}
          {activeTab === "services" && (
            <div>
              <h2 className="font-display text-3xl font-extrabold text-ink mb-8">AI Service Cost Breakdown</h2>

              {recommendedServices.map((service) => (
                <div key={service.name} className="card mb-4 p-5">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h4 className="font-bold text-ink text-lg">{service.name}</h4>
                        <span className="px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-muted">{service.provider}</span>
                        <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700">{service.model}</span>
                      </div>
                      <p className="text-sm text-muted mb-3">{service.notes}</p>
                      <div className="grid grid-cols-3 gap-4 text-sm">
                        <div>
                          <p className="text-muted">Input Tokens/Day</p>
                          <p className="font-bold text-ink">{service.inputTokDay.toLocaleString()}</p>
                        </div>
                        <div>
                          <p className="text-muted">Output Tokens/Day</p>
                          <p className="font-bold text-ink">{service.outputTokDay.toLocaleString()}</p>
                        </div>
                        <div>
                          <p className="text-muted">Annual Cost</p>
                          <p className="font-bold text-ink">EGP {service.annualEGP.toLocaleString()}</p>
                        </div>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-3xl font-bold text-brand">EGP {service.monthlyEGP.toLocaleString()}</p>
                      <p className="text-sm text-muted">/ month</p>
                      <p className="text-xs text-muted mt-1">USD {service.monthlyUSD}</p>
                    </div>
                  </div>
                </div>
              ))}

              {/* Total */}
              <div className="card p-5 bg-brand/5 border-2 border-brand/20 mt-6">
                <div className="flex justify-between items-center">
                  <div>
                    <h4 className="font-bold text-ink text-lg">Total Recommended Configuration</h4>
                    <p className="text-sm text-muted">All 7 recommended services, primary models only</p>
                  </div>
                  <div className="text-right">
                    <p className="text-4xl font-bold text-brand">EGP {RECOMMENDED_TOTAL.monthlyEGP.toLocaleString()}</p>
                    <p className="text-sm text-muted">USD {RECOMMENDED_TOTAL.monthlyUSD} / month</p>
                    <p className="text-xs text-muted">EGP {RECOMMENDED_TOTAL.annualEGP.toLocaleString()} / year</p>
                  </div>
                </div>
              </div>

              {/* Token usage stats */}
              <div className="mt-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Token Usage Statistics</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Metric</th>
                      <th className="text-right p-3 font-bold text-ink">Development</th>
                      <th className="text-right p-3 font-bold text-ink">Production</th>
                      <th className="text-right p-3 font-bold text-ink">Enterprise</th>
                    </tr></thead>
                    <tbody>
                      {TOKEN_STATS.map((stat) => (
                        <tr key={stat.scenario} className="border-t border-line">
                          <td className="p-3 text-ink">{stat.scenario}</td>
                          <td className="p-3 text-right text-muted">{stat.inputTok.toLocaleString()} in</td>
                          <td className="p-3 text-right text-muted">{stat.outputTok.toLocaleString()} out</td>
                          <td className="p-3 text-right text-muted">{stat.apiCalls.toLocaleString()} calls</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* Tab: Deployment Scenarios */}
          {activeTab === "scenarios" && (
            <div>
              <h2 className="font-display text-3xl font-extrabold text-ink mb-8">Deployment Scenarios</h2>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                {DEPLOYMENT_SCENARIOS.map((s) => (
                  <div key={s.name} className="card p-6">
                    <div className="mb-4">
                      <span className={`px-3 py-1 rounded-full text-xs font-bold ${s.name === "Development" ? "bg-green-100 text-green-800" : s.name === "Production" ? "bg-blue-100 text-blue-800" : "bg-purple-100 text-purple-800"}`}>
                        {s.name}
                      </span>
                    </div>
                    <p className="text-sm text-muted mb-4">{s.description}</p>
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Monthly Cost</span>
                        <span className="font-bold text-brand">EGP {s.monthlyEGP.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Annual Cost</span>
                        <span className="font-bold text-brand">EGP {s.annualEGP.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Target Users</span>
                        <span className="font-bold text-ink">{s.users.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Cost per User</span>
                        <span className="font-bold text-brand">EGP {s.perUser}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Daily Tokens</span>
                        <span className="font-bold text-ink">{s.dailyTokens.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-muted">Services Active</span>
                        <span className="font-bold text-ink">{s.servicesActive}</span>
                      </div>
                    </div>
                    <div className="mt-4 pt-4 border-t border-line">
                      <p className="text-xs text-muted">{s.services.join(", ")}</p>
                    </div>
                  </div>
                ))}
              </div>

              {/* Cost Efficiency Metrics */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Cost Efficiency Metrics</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Metric</th>
                      <th className="text-right p-3 font-bold text-ink">Development</th>
                      <th className="text-right p-3 font-bold text-ink">Production</th>
                      <th className="text-right p-3 font-bold text-ink">Enterprise</th>
                    </tr></thead>
                    <tbody>
                      {COST_EFFICIENCY.map((row) => (
                        <tr key={row.metric} className="border-t border-line">
                          <td className="p-3 text-ink">{row.metric}</td>
                          <td className="p-3 text-right text-muted">{row.dev}</td>
                          <td className="p-3 text-right text-muted">{row.prod}</td>
                          <td className="p-3 text-right text-muted">{row.ent}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Growth Projections */}
              <div>
                <h3 className="font-display text-xl font-bold text-ink mb-4">12-Month Growth Projection</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Period</th>
                      <th className="text-right p-3 font-bold text-ink">MAU</th>
                      <th className="text-right p-3 font-bold text-ink">Monthly Cost</th>
                      <th className="text-right p-3 font-bold text-ink">Revenue</th>
                      <th className="text-right p-3 font-bold text-ink">Margin</th>
                    </tr></thead>
                    <tbody>
                      {GROWTH_PROJECTIONS.map((row) => (
                        <tr key={row.month} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{row.month}</td>
                          <td className="p-3 text-right">{row.mau.toLocaleString()}</td>
                          <td className="p-3 text-right font-bold text-brand">EGP {row.cost.toLocaleString()}</td>
                          <td className="p-3 text-right text-muted">EGP {row.revenue.toLocaleString()}</td>
                          <td className="p-3 text-right font-bold text-green-600">{row.margin}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* Tab: Admin Controls */}
          {activeTab === "admin" && (
            <div>
              <h2 className="font-display text-3xl font-extrabold text-ink mb-8">Admin Control Panel</h2>

              {/* Usage Quota Management */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Usage Quota Management</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Parameter</th>
                      <th className="text-right p-3 font-bold text-ink">Development</th>
                      <th className="text-right p-3 font-bold text-ink">Production</th>
                      <th className="text-right p-3 font-bold text-ink">Enterprise</th>
                    </tr></thead>
                    <tbody>
                      {QUOTA_TABLE.map((row) => (
                        <tr key={row.tier} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{row.tier}</td>
                          <td className="p-3 text-right">{row.dailyTokens}</td>
                          <td className="p-3 text-right">{row.dailyCalls}</td>
                          <td className="p-3 text-right">{row.monthlyCap}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Model Selection */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Model Selection and Routing</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="card p-5">
                    <h4 className="font-bold text-ink mb-3">Primary Models (Lowest Cost)</h4>
                    <ul className="space-y-2 text-sm text-muted">
                      <li>Google Gemini 1.5 Pro - Vision AI, fallback</li>
                      <li>Google Gemini 1.5 Flash - Fraud Detection, Reports</li>
                      <li>OpenAI GPT-4o - Economist, Graph Synthesis</li>
                      <li>Gemma 4 31B IT - Chat, Verification</li>
                    </ul>
                  </div>
                  <div className="card p-5">
                    <h4 className="font-bold text-ink mb-3">Cost Monitoring Thresholds</h4>
                    <ul className="space-y-2 text-sm text-muted">
                      <li>Per-User Cost: Exceeds 2x average - admin notification</li>
                      <li>Daily Token Usage: Exceeds 80% - automatic user warning</li>
                      <li>Monthly Burn Rate: Budget +15% - alert email to admin</li>
                      <li>Quota Utilization: 100% - API calls blocked, overage charged</li>
                      <li>Provider Latency: Exceeds 10s p95 - automatic failover</li>
                    </ul>
                  </div>
                </div>
              </div>

              {/* User-Charged Financial Plan */}
              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">User-Charged Financial Plan</h3>
                <p className="text-muted mb-4">AI service costs are billed directly to platform users. Zero platform subsidy. 100% cost recovery target.</p>

                <div className="card overflow-hidden mb-4">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Tier</th>
                      <th className="text-left p-3 font-bold text-ink">Users</th>
                      <th className="text-right p-3 font-bold text-ink">Daily Tokens</th>
                      <th className="text-right p-3 font-bold text-ink">Cost/User (EGP/mo)</th>
                      <th className="text-left p-3 font-bold text-ink">Included Services</th>
                    </tr></thead>
                    <tbody>
                      {USER_COST_SCHEDULE.map((row) => (
                        <tr key={row.tier} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{row.tier}</td>
                          <td className="p-3">{row.users}</td>
                          <td className="p-3 text-right">{row.dailyTokens}</td>
                          <td className="p-3 text-right font-bold text-brand">EGP {row.costPerUser}</td>
                          <td className="p-3 text-muted">{row.services}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Scenario</th>
                      <th className="text-right p-3 font-bold text-ink">Users</th>
                      <th className="text-right p-3 font-bold text-ink">Monthly Revenue</th>
                      <th className="text-right p-3 font-bold text-ink">Cost Recovery</th>
                    </tr></thead>
                    <tbody>
                      {REVENUE_PROJECTIONS.map((row) => (
                        <tr key={row.tier} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{row.tier}</td>
                          <td className="p-3 text-right">{row.users.toLocaleString()}</td>
                          <td className="p-3 text-right font-bold text-brand">EGP {row.monthlyRevenue.toLocaleString()}</td>
                          <td className="p-3 text-right font-bold text-green-600">{row.recovery}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* Tab: Risk & Growth */}
          {activeTab === "risk" && (
            <div>
              <h2 className="font-display text-3xl font-extrabold text-ink mb-8">Risk Assessment & Financial Planning</h2>

              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Financial Risk Matrix</h3>
                <div className="card overflow-hidden">
                  <table className="w-full text-sm">
                    <thead><tr className="bg-gray-100">
                      <th className="text-left p-3 font-bold text-ink">Risk</th>
                      <th className="text-center p-3 font-bold text-ink">Probability</th>
                      <th className="text-center p-3 font-bold text-ink">Impact</th>
                      <th className="text-left p-3 font-bold text-ink">Mitigation</th>
                    </tr></thead>
                    <tbody>
                      {RISK_MATRIX.map((row) => (
                        <tr key={row.risk} className="border-t border-line">
                          <td className="p-3 font-medium text-ink">{row.risk}</td>
                          <td className="p-3 text-center">
                            <span className={`px-2 py-0.5 rounded text-xs font-bold ${row.prob === "High" ? "bg-red-100 text-red-800" : row.prob === "Medium" ? "bg-yellow-100 text-yellow-800" : "bg-green-100 text-green-800"}`}>
                              {row.prob}
                            </span>
                          </td>
                          <td className="p-3 text-center">
                            <span className={`px-2 py-0.5 rounded text-xs font-bold ${row.impact === "High" ? "bg-red-100 text-red-800" : row.impact === "Medium" ? "bg-yellow-100 text-yellow-800" : "bg-green-100 text-green-800"}`}>
                              {row.impact}
                            </span>
                          </td>
                          <td className="p-3 text-muted">{row.mitigation}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Sensitivity Analysis</h3>
                <div className="card p-5">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <h4 className="font-bold text-ink mb-2">Usage Variation Impact</h4>
                      <ul className="space-y-2 text-sm text-muted">
                        <li>+20% usage: 3,927 EGP/month (within budget)</li>
                        <li>+50% usage: 4,867 EGP/month (within budget)</li>
                        <li>2x usage: 6,541 EGP/month (within budget)</li>
                      </ul>
                    </div>
                    <div>
                      <h4 className="font-bold text-ink mb-2">Provider Switch Impact</h4>
                      <ul className="space-y-2 text-sm text-muted">
                        <li>Vision AI Google to OpenAI: +663 EGP/month</li>
                        <li>Fraud Google to OpenAI: +2,205 EGP/month</li>
                        <li>Economist OpenAI to Google: -415 EGP/month</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>

              <div className="mb-8">
                <h3 className="font-display text-xl font-bold text-ink mb-4">Implementation Roadmap</h3>
                <div className="space-y-4">
                  {[
                    { phase: "Phase 1: Immediate", time: "Months 0-3", budget: "831 EGP/month", actions: "Deploy quota system, configure prompt caching, enable cost monitoring, bill alongside subscription" },
                    { phase: "Phase 2: Growth", time: "Months 3-12", budget: "3,372 EGP/month", actions: "Activate all 7 AI services, implement model fallback, deploy custom pricing tiers, negotiate annual commitments" },
                    { phase: "Phase 3: Maturity", time: "Year 2+", budget: "2,139 EGP/month", actions: "Negotiate enterprise pricing, deploy fine-tuned open-source models, implement predictive usage management" },
                  ].map((p) => (
                    <div key={p.phase} className="card p-5">
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <h4 className="font-bold text-ink">{p.phase}</h4>
                          <p className="text-sm text-muted mt-1">{p.time}</p>
                          <p className="text-sm text-muted mt-2">{p.actions}</p>
                        </div>
                        <div className="text-right shrink-0">
                          <p className="text-xl font-bold text-brand">EGP {p.budget.replace("/month", "").replace(",", "")}</p>
                          <p className="text-xs text-muted">/ month</p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="card p-5 bg-gray-100">
                <h3 className="font-display text-xl font-bold text-ink mb-2">Key Assumptions</h3>
                <ul className="space-y-1 text-sm text-muted">
                  <li>Exchange rate: 1 USD = 50.5 EGP (August 2026)</li>
                  <li>User growth rate: 15% month-over-month (conservative)</li>
                  <li>Token usage scales linearly with MAU</li>
                  <li>Per-user cost: 4.24 EGP (Dev), 1.91 EGP (Prod), 0.42 EGP (Ent)</li>
                  <li>Platform provides all infrastructure except AI inference</li>
                  <li>100% cost recovery through user-charged billing model</li>
                </ul>
              </div>
            </div>
          )}

        </div>
      </section>

      <MarketingFooter />
    </div>
  );
}
