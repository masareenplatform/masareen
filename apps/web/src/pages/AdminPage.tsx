import { useState, useEffect, useCallback } from "react";
import { Link } from "react-router-dom";
import {
  IconUsers, IconImpact, IconProgram, IconWallet, IconShield, IconReports,
  IconTrending, IconCheck, IconGlobe, IconChat,
} from "../components/icons/Icons";
import { useReveal, useCountUp } from "../hooks/anim";
import {
  LineChart, Line, AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend,
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
} from "recharts";

const BRAND = "#0250A3";
const ACCENT = "#2A9D45";
const SKY = "#0EA5E9";
const AMBER = "#F59E0B";
const ROSE = "#EF4444";
const PURPLE = "#8B5CF6";

const TABS = ["Overview", "Users", "Programs", "Verification", "Revenue", "Engagement", "Reports"] as const;
type Tab = (typeof TABS)[number];

/* ── generic fetcher ───────────────────────────────────────────────────────── */

async function apiFetch<T>(path: string, fallback: T): Promise<{ data: T | null; error: string }> {
  try {
    const res = await fetch(path);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    return { data: json?.data ?? json ?? fallback, error: "" };
  } catch (e: any) {
    console.warn(`[admin] fetch ${path} failed:`, e?.message);
    return { data: null, error: e?.message || "Network error" };
  }
}

/* ── KPI card with loading ─────────────────────────────────────────────────── */

function KpiCard({ end, label, suffix = "", decimals = 0, icon: Icon, tint, prefix = "", loading = false }: any) {
  const { ref, shown } = useReveal<HTMLDivElement>({ threshold: 0.3 });
  const value = useCountUp(loading ? 0 : end, shown, 1600, decimals);
  return (
    <div ref={ref} className="card flex items-center gap-4 p-4">
      <div className="grid h-12 w-12 shrink-0 place-items-center rounded-xl" style={{ background: `${tint}1a`, color: tint }}>
        <Icon size={22} />
      </div>
      <div className="min-w-0">
        <div className="font-display text-2xl font-extrabold text-ink">
          {loading ? <span className="inline-block h-7 w-20 animate-pulse rounded bg-line" /> : <>{prefix}{value}{suffix}</>}
        </div>
        <div className="truncate text-xs text-muted">{label}</div>
      </div>
    </div>
  );
}

/* ── section card ──────────────────────────────────────────────────────────── */

function SectionCard({ title, subtitle, children, className = "", error, onRetry }: any) {
  return (
    <div className={`card p-5 ${className}`}>
      <div className="mb-4 flex items-start justify-between">
        <div>
          <h3 className="font-display text-base font-bold text-ink">{title}</h3>
          {subtitle && <p className="text-xs text-muted">{subtitle}</p>}
        </div>
        {onRetry && error && (
          <button onClick={onRetry} className="text-xs font-semibold text-brand hover:underline">Retry</button>
        )}
      </div>
      {error ? (
        <div className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">
          <p className="font-semibold">Failed to load data</p>
          <p className="mt-1 text-xs text-rose-500">{error}</p>
        </div>
      ) : children}
    </div>
  );
}

/* ── skeleton loader ───────────────────────────────────────────────────────── */

function Skeleton({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="space-y-2">
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="flex gap-2">
          {Array.from({ length: cols }).map((_, c) => (
            <div key={c} className="h-4 flex-1 animate-pulse rounded bg-line" />
          ))}
        </div>
      ))}
    </div>
  );
}

/* ── static fallback data ──────────────────────────────────────────────────── */

const impactByMonth = [
  { m: "Aug", v: 4200 }, { m: "Sep", v: 5600 }, { m: "Oct", v: 7100 }, { m: "Nov", v: 8300 },
  { m: "Dec", v: 9800 }, { m: "Jan", v: 11200 }, { m: "Feb", v: 12600 }, { m: "Mar", v: 14100 },
  { m: "Apr", v: 15800 }, { m: "May", v: 17400 }, { m: "Jun", v: 19200 }, { m: "Jul", v: 21500 },
];

const usersByAudience = [
  { name: "STUDENT", v: 3120 }, { name: "PROFESSIONAL", v: 3640 }, { name: "CORPORATE", v: 980 },
  { name: "GOVERNMENT", v: 430 }, { name: "NGO", v: 251 },
];

const contentByKind = [
  { name: "Story", v: 42, color: BRAND }, { name: "Program", v: 18, color: ACCENT },
  { name: "Task", v: 21, color: SKY }, { name: "Evidence", v: 12, color: AMBER },
  { name: "Impact", v: 7, color: PURPLE },
];

const signupsByMonth = [
  { m: "Feb", v: 410 }, { m: "Mar", v: 520 }, { m: "Apr", v: 610 }, { m: "May", v: 740 },
  { m: "Jun", v: 880 }, { m: "Jul", v: 1020 },
];

const sampleUsers = [
  { name: "Amira Saleh", email: "amira@greenroots.org", role: "NGO_ADMIN", status: "Active", joined: "2025-09-12" },
  { name: "Youssef Adel", email: "youssef@cu.edu.eg", role: "PROFESSIONAL", status: "Active", joined: "2025-10-03" },
  { name: "Lina Farouk", email: "lina@masrena.co", role: "CORPORATE", status: "Active", joined: "2025-08-21" },
  { name: "Omar Tarek", email: "omar@nilecare.org", role: "NGO_MEMBER", status: "Pending", joined: "2026-01-15" },
  { name: "Sara Nabil", email: "sara@youthwave.org", role: "PROFESSIONAL", status: "Active", joined: "2025-11-30" },
  { name: "Khaled Hassan", email: "khaled@gov.eg", role: "GOVERNMENT", status: "Suspended", joined: "2025-07-08" },
  { name: "Nada Ali", email: "nada@cic.edu", role: "STUDENT", status: "Active", joined: "2026-02-02" },
  { name: "Hana Mostafa", email: "hana@rise.ngo", role: "NGO_ADMIN", status: "Active", joined: "2025-12-19" },
];

const programs = [
  { title: "Mangrove Restoration", org: "GreenRoots NGO", status: "Active", participants: 340, verified: 98 },
  { title: "Rural Literacy Bootcamp", org: "Cairo University", status: "Active", participants: 200, verified: 91 },
  { title: "Clean Water Wells", org: "Masrena CSR", status: "Completed", participants: 60, verified: 95 },
  { title: "Mobile Clinic Weeks", org: "Nile Care", status: "Review", participants: 120, verified: 84 },
  { title: "Beach Cleanup Drive", org: "Youth Wave", status: "Active", participants: 210, verified: 88 },
  { title: "Recycling Education", org: "Rise NGO", status: "Active", participants: 150, verified: 90 },
];

const recentVerifications = [
  { who: "GreenRoots NGO", what: "12K mangrove saplings", score: 98, status: "Verified" },
  { who: "Cairo University", what: "Rural literacy bootcamp", score: 91, status: "Verified" },
  { who: "Masrena CSR", what: "3 clean-water wells", score: 95, status: "Verified" },
  { who: "Nile Care", what: "Mobile clinic weeks", score: 84, status: "Under review" },
  { who: "Youth Wave", what: "Beach cleanup 2.4t", score: 88, status: "Verified" },
];

const verificationFunnel = [
  { label: "Submitted", v: 1520, color: SKY },
  { label: "Under review", v: 410, color: AMBER },
  { label: "Verified", v: 980, color: ACCENT },
  { label: "Rejected", v: 130, color: ROSE },
];

const evidenceSubmissions = [
  { who: "GreenRoots NGO", type: "GPS + photo", sdg: "Life on Land", time: "2m ago" },
  { who: "Cairo University", type: "Audit report", sdg: "Quality Education", time: "14m ago" },
  { who: "Masrena CSR", type: "Receipt + GPS", sdg: "Clean Water", time: "1h ago" },
  { who: "Youth Wave", type: "Photo + weight", sdg: "Life Below Water", time: "3h ago" },
  { who: "Rise NGO", type: "Video + GPS", sdg: "Responsible Consumption", time: "5h ago" },
];

const completionsByMonth = [
  { m: "Feb", v: 120 }, { m: "Mar", v: 180 }, { m: "Apr", v: 240 }, { m: "May", v: 310 },
  { m: "Jun", v: 420 }, { m: "Jul", v: 560 },
];

const revenueByMonth = [
  { m: "Feb", fees: 62, subs: 40 }, { m: "Mar", fees: 78, subs: 48 }, { m: "Apr", fees: 91, subs: 55 },
  { m: "May", fees: 108, subs: 63 }, { m: "Jun", fees: 124, subs: 71 }, { m: "Jul", fees: 142, subs: 82 },
];

const topRevenue = [
  { stream: "MASAREEN Coin fees", amount: 642000, pct: 38 },
  { stream: "Pro subscriptions", amount: 410000, pct: 24 },
  { stream: "Enterprise seats", amount: 360000, pct: 21 },
  { stream: "Impact Ads", amount: 188000, pct: 11 },
  { stream: "API / data", amount: 102000, pct: 6 },
];

const dauByDay = [
  { d: "Mon", v: 3120 }, { d: "Tue", v: 3480 }, { d: "Wed", v: 3690 }, { d: "Thu", v: 3820 },
  { d: "Fri", v: 4010 }, { d: "Sat", v: 4520 }, { d: "Sun", v: 4310 },
];

const postsPerWeek = [
  { w: "W1", v: 820 }, { w: "W2", v: 910 }, { w: "W3", v: 1040 }, { w: "W4", v: 1180 }, { w: "W5", v: 1260 }, { w: "W6", v: 1390 },
];

const topSdgs = [
  { name: "Climate Action", v: 312 }, { name: "Quality Education", v: 268 }, { name: "Clean Water", v: 221 },
  { name: "Decent Work", v: 198 }, { name: "Life on Land", v: 176 }, { name: "Zero Hunger", v: 154 },
];

const statusTone: Record<string, string> = {
  Active: "chip-accent", Pending: "chip-brand", Suspended: "chip-ghost",
  Verified: "chip-accent", "Under review": "chip-brand", Review: "chip-brand", Completed: "chip-ghost",
  APPROVED: "chip-accent", REJECTED: "chip-ghost", PENDING: "chip-brand",
};

/* ── tab button ────────────────────────────────────────────────────────────── */

function TabButton({ tab, active, onClick }: { tab: Tab; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-lg px-3.5 py-2 text-sm font-semibold transition ${active ? "bg-brand text-white shadow-card" : "text-muted hover:bg-canvas hover:text-ink"}`}
    >
      {tab}
    </button>
  );
}

/* ── main page ─────────────────────────────────────────────────────────────── */

export default function AdminPage() {
  const [tab, setTab] = useState<Tab>("Overview");

  return (
    <div className="min-h-screen bg-canvas">
      <div className="mx-auto max-w-6xl px-4 py-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="font-display text-2xl font-extrabold text-ink">Admin Console</h1>
            <p className="text-sm text-muted">Platform operations, verification and revenue at a glance.</p>
          </div>
          <Link to="/revenue" className="btn-ghost text-sm">Open revenue report</Link>
        </div>

        <div className="mt-6 flex flex-wrap gap-2">
          {TABS.map((t) => <TabButton key={t} tab={t} active={tab === t} onClick={() => setTab(t)} />)}
        </div>

        <div className="mt-6">
          {tab === "Overview" && <Overview />}
          {tab === "Users" && <UsersTab />}
          {tab === "Programs" && <ProgramsTab />}
          {tab === "Verification" && <VerificationTab />}
          {tab === "Revenue" && <RevenueTab />}
          {tab === "Engagement" && <EngagementTab />}
          {tab === "Reports" && <ReportsTab />}
        </div>
      </div>
    </div>
  );
}

/* ── overview (fetches platform summary) ───────────────────────────────────── */

function Overview() {
  const [summary, setSummary] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    const { data, error: err } = await apiFetch("/api/v1/analytics/platform/summary", {});
    if (data) setSummary(data);
    if (err) setError(err);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="lg:col-span-2 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <KpiCard end={summary?.total_users ?? 8421} label="Users" icon={IconUsers} tint={BRAND} loading={loading} />
        <KpiCard end={summary?.verified_tasks ?? 128400} label="Verified actions" icon={IconImpact} tint={ACCENT} loading={loading} />
        <KpiCard end={summary?.active_programs ?? 312} label="Programs" icon={IconProgram} tint={SKY} loading={loading} />
        <KpiCard end={1240000} label="Revenue (EGP)" icon={IconWallet} tint={AMBER} prefix="EGP " decimals={0} />
        <KpiCard end={summary?.countries_active ?? 9} label="Countries" icon={IconGlobe} tint={BRAND} loading={loading} />
        <KpiCard end={summary?.impact_assets_created ?? 540} label="Impact assets" icon={IconShield} tint={ACCENT} loading={loading} />
      </div>

      <SectionCard title="Verified impact actions" subtitle="Last 12 months" className="lg:col-span-2">
        <ResponsiveContainer height={260}>
          <AreaChart data={impactByMonth} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="gImpact" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={ACCENT} stopOpacity={0.35} />
                <stop offset="100%" stopColor={ACCENT} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="m" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Area type="monotone" dataKey="v" stroke={ACCENT} strokeWidth={2.5} fill="url(#gImpact)" />
          </AreaChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="Users by audience" subtitle="Segment share">
        <ResponsiveContainer height={260}>
          <BarChart data={usersByAudience} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="name" tick={{ fontSize: 11, fill: "#6B7280" }} interval={0} angle={-12} textAnchor="end" height={50} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Bar dataKey="v" fill={BRAND} radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="Content by kind" subtitle="Share of published items">
        <ResponsiveContainer height={260}>
          <PieChart>
            <Pie data={contentByKind} dataKey="v" nameKey="name" innerRadius={50} outerRadius={90} paddingAngle={2}>
              {contentByKind.map((c, i) => <Cell key={i} fill={c.color} />)}
            </Pie>
            <Tooltip />
            <Legend />
          </PieChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="Recent verifications" subtitle="Latest POAI verdicts" className="lg:col-span-2">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs uppercase tracking-wide text-muted">
                <th className="py-2 pr-4 font-semibold">Organization</th>
                <th className="py-2 pr-4 font-semibold">Action</th>
                <th className="py-2 pr-4 font-semibold">Score</th>
                <th className="py-2 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {recentVerifications.map((r, i) => (
                <tr key={i} className="border-b border-line last:border-0">
                  <td className="py-2.5 pr-4 font-medium text-ink">{r.who}</td>
                  <td className="py-2.5 pr-4 text-muted">{r.what}</td>
                  <td className="py-2.5 pr-4 text-ink">{r.score}%</td>
                  <td className="py-2.5"><span className={statusTone[r.status]}>{r.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}

/* ── users tab ─────────────────────────────────────────────────────────────── */

function UsersTab() {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <SectionCard title="Signups per month" subtitle="New accounts" className="lg:col-span-1">
        <ResponsiveContainer height={260}>
          <BarChart data={signupsByMonth} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="m" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Bar dataKey="v" fill={SKY} radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="User directory" subtitle="Sample of 8,421 accounts" className="lg:col-span-2">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs uppercase tracking-wide text-muted">
                <th className="py-2 pr-4 font-semibold">Name</th>
                <th className="py-2 pr-4 font-semibold">Email</th>
                <th className="py-2 pr-4 font-semibold">Role</th>
                <th className="py-2 pr-4 font-semibold">Status</th>
                <th className="py-2 font-semibold">Joined</th>
              </tr>
            </thead>
            <tbody>
              {sampleUsers.map((u, i) => (
                <tr key={i} className="border-b border-line last:border-0">
                  <td className="py-2.5 pr-4 font-medium text-ink">{u.name}</td>
                  <td className="py-2.5 pr-4 text-muted">{u.email}</td>
                  <td className="py-2.5 pr-4 text-ink">{u.role}</td>
                  <td className="py-2.5 pr-4"><span className={statusTone[u.status]}>{u.status}</span></td>
                  <td className="py-2.5 text-muted">{u.joined}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}

/* ── programs tab ──────────────────────────────────────────────────────────── */

function ProgramsTab() {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <SectionCard title="Program completions" subtitle="Verified outcomes per month" className="lg:col-span-1">
        <ResponsiveContainer height={260}>
          <LineChart data={completionsByMonth} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="m" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Line type="monotone" dataKey="v" stroke={BRAND} strokeWidth={2.5} dot={{ r: 3 }} />
          </LineChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="All programs" subtitle="6 of 312 active programs" className="lg:col-span-2">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs uppercase tracking-wide text-muted">
                <th className="py-2 pr-4 font-semibold">Title</th>
                <th className="py-2 pr-4 font-semibold">Org</th>
                <th className="py-2 pr-4 font-semibold">Status</th>
                <th className="py-2 pr-4 font-semibold">Participants</th>
                <th className="py-2 font-semibold">Verified</th>
              </tr>
            </thead>
            <tbody>
              {programs.map((p, i) => (
                <tr key={i} className="border-b border-line last:border-0">
                  <td className="py-2.5 pr-4 font-medium text-ink">{p.title}</td>
                  <td className="py-2.5 pr-4 text-muted">{p.org}</td>
                  <td className="py-2.5 pr-4"><span className={statusTone[p.status]}>{p.status}</span></td>
                  <td className="py-2.5 pr-4 text-ink">{p.participants}</td>
                  <td className="py-2.5 text-accent-700 font-semibold">{p.verified}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}

/* ── verification tab ──────────────────────────────────────────────────────── */

function VerificationTab() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    const { data, error: err } = await apiFetch("/api/v1/analytics/reports/evidence", {});
    if (data) setData(data);
    if (err) setError(err);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <div className="grid grid-cols-2 gap-3 lg:col-span-2">
        {verificationFunnel.map((f) => (
          <div key={f.label} className="card flex items-center justify-between p-4" style={{ borderLeft: `4px solid ${f.color}` }}>
            <div>
              <div className="font-display text-2xl font-extrabold text-ink">
                {loading ? <span className="inline-block h-7 w-16 animate-pulse rounded bg-line" /> : f.v.toLocaleString()}
              </div>
              <div className="text-xs text-muted">{f.label}</div>
            </div>
            <div className="h-10 w-10 rounded-full" style={{ background: `${f.color}22` }} />
          </div>
        ))}
      </div>

      <SectionCard title="Evidence by status" subtitle={error ? "Using fallback data" : "From evidence table"} error={error} onRetry={load}>
        {loading ? <Skeleton rows={4} cols={2} /> : (
          <ResponsiveContainer height={220}>
            <PieChart>
              <Pie data={(data?.by_status ?? verificationFunnel).map((s: any) => ({ name: s.status || s.label, v: s.count || s.v }))}
                dataKey="v" nameKey="name" innerRadius={45} outerRadius={85} paddingAngle={2}>
                {(data?.by_status ?? verificationFunnel).map((_: any, i: number) => (
                  <Cell key={i} fill={[SKY, AMBER, ACCENT, ROSE, PURPLE, BRAND][i % 6]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        )}
      </SectionCard>

      <SectionCard title="Evidence by media type" subtitle="Submission breakdown" className="lg:col-span-1" error={error} onRetry={load}>
        {loading ? <Skeleton rows={3} cols={2} /> : data?.by_media?.length ? (
          <ResponsiveContainer height={200}>
            <BarChart data={data.by_media} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
              <XAxis dataKey="media_type" tick={{ fontSize: 11, fill: "#6B7280" }} />
              <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
              <Tooltip />
              <Bar dataKey="count" fill={SKY} radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        ) : <p className="text-sm text-muted">No media type data available</p>}
      </SectionCard>

      <SectionCard title="Evidence time series" subtitle="Submissions per day" className="lg:col-span-2" error={error} onRetry={load}>
        {loading ? <Skeleton rows={3} cols={1} /> : data?.over_time?.length ? (
          <ResponsiveContainer height={200}>
            <AreaChart data={data.over_time} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="gEvi" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={SKY} stopOpacity={0.35} />
                  <stop offset="100%" stopColor={SKY} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
              <XAxis dataKey="date" tick={{ fontSize: 10, fill: "#6B7280" }} />
              <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
              <Tooltip />
              <Area type="monotone" dataKey="submissions" stroke={SKY} strokeWidth={2} fill="url(#gEvi)" />
            </AreaChart>
          </ResponsiveContainer>
        ) : <p className="text-sm text-muted">No time series data available</p>}
      </SectionCard>

      <SectionCard title="Recent evidence submissions" subtitle="Awaiting or completed review" className="lg:col-span-3">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs uppercase tracking-wide text-muted">
                <th className="py-2 pr-4 font-semibold">Submitter</th>
                <th className="py-2 pr-4 font-semibold">Evidence type</th>
                <th className="py-2 pr-4 font-semibold">SDG</th>
                <th className="py-2 font-semibold">When</th>
              </tr>
            </thead>
            <tbody>
              {evidenceSubmissions.map((e, i) => (
                <tr key={i} className="border-b border-line last:border-0">
                  <td className="py-2.5 pr-4 font-medium text-ink">{e.who}</td>
                  <td className="py-2.5 pr-4 text-muted">{e.type}</td>
                  <td className="py-2.5 pr-4 text-ink">{e.sdg}</td>
                  <td className="py-2.5 text-muted">{e.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}

/* ── revenue tab ───────────────────────────────────────────────────────────── */

function RevenueTab() {
  return (
    <div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard end={103000} label="MRR (EGP)" icon={IconWallet} tint={BRAND} prefix="EGP " />
        <KpiCard end={1236000} label="ARR (EGP)" icon={IconTrending} tint={ACCENT} prefix="EGP " />
        <KpiCard end={18420} label="Transactions" icon={IconReports} tint={SKY} />
        <KpiCard end={67} label="Avg txn (EGP)" icon={IconChat} tint={AMBER} prefix="EGP " />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-3">
        <SectionCard title="Monthly revenue" subtitle="Coin fees vs subscriptions (EGP k)" className="lg:col-span-2">
          <ResponsiveContainer height={260}>
            <AreaChart data={revenueByMonth} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="gFees" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={BRAND} stopOpacity={0.35} />
                  <stop offset="100%" stopColor={BRAND} stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gSubs" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={AMBER} stopOpacity={0.35} />
                  <stop offset="100%" stopColor={AMBER} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
              <XAxis dataKey="m" tick={{ fontSize: 12, fill: "#6B7280" }} />
              <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
              <Tooltip />
              <Legend />
              <Area type="monotone" dataKey="fees" name="Coin fees" stroke={BRAND} strokeWidth={2.5} fill="url(#gFees)" />
              <Area type="monotone" dataKey="subs" name="Subscriptions" stroke={AMBER} strokeWidth={2.5} fill="url(#gSubs)" />
            </AreaChart>
          </ResponsiveContainer>
        </SectionCard>

        <SectionCard title="Top revenue streams" subtitle="This fiscal year">
          <div className="space-y-3">
            {topRevenue.map((r) => (
              <div key={r.stream}>
                <div className="flex items-center justify-between text-sm">
                  <span className="font-medium text-ink">{r.stream}</span>
                  <span className="text-muted">EGP {(r.amount / 1000).toFixed(0)}k</span>
                </div>
                <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-canvas">
                  <div className="h-full rounded-full" style={{ width: `${r.pct}%`, background: BRAND }} />
                </div>
              </div>
            ))}
          </div>
        </SectionCard>
      </div>
    </div>
  );
}

/* ── engagement tab ────────────────────────────────────────────────────────── */

function EngagementTab() {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <SectionCard title="Daily active users" subtitle="This week">
        <ResponsiveContainer height={260}>
          <LineChart data={dauByDay} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="d" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Line type="monotone" dataKey="v" stroke={ACCENT} strokeWidth={2.5} dot={{ r: 3 }} />
          </LineChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="Posts per week" subtitle="Published content">
        <ResponsiveContainer height={260}>
          <BarChart data={postsPerWeek} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="w" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 12, fill: "#6B7280" }} />
            <Tooltip />
            <Bar dataKey="v" fill={SKY} radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </SectionCard>

      <SectionCard title="Top SDGs engaged" subtitle="Actions mapped to goals" className="lg:col-span-2">
        <ResponsiveContainer height={260}>
          <BarChart layout="vertical" data={topSdgs} margin={{ top: 8, right: 24, left: 8, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis type="number" tick={{ fontSize: 12, fill: "#6B7280" }} />
            <YAxis type="category" dataKey="name" tick={{ fontSize: 12, fill: "#6B7280" }} width={130} />
            <Tooltip />
            <Bar dataKey="v" fill={BRAND} radius={[0, 6, 6, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </SectionCard>
    </div>
  );
}

/* ── R-based statistical reports tab ───────────────────────────────────────── */

function ReportsTab() {
  const [evidence, setEvidence] = useState<any>(null);
  const [verification, setVerification] = useState<any>(null);
  const [institutions, setInstitutions] = useState<any>(null);
  const [forecast, setForecast] = useState<any>(null);
  const [audit, setAudit] = useState<any>(null);
  const [coin, setCoin] = useState<any>(null);
  const [engagement, setEngagement] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const loadAll = useCallback(async () => {
    setLoading(true);
    const errs: Record<string, string> = {};

    const [ev, vi, inst, fc, au, co, en] = await Promise.allSettled([
      apiFetch("/api/v1/analytics/reports/evidence", {}),
      apiFetch("/api/v1/analytics/reports/verification", {}),
      apiFetch("/api/v1/analytics/reports/institutions", {}),
      apiFetch("/api/v1/analytics/reports/forecast", {}),
      apiFetch("/api/v1/analytics/reports/audit", {}),
      apiFetch("/api/v1/analytics/reports/coin", {}),
      apiFetch("/api/v1/analytics/reports/engagement", {}),
    ]);

    const set = (r: any, key: string, setter: any) => {
      if (r.status === "fulfilled" && r.value.data) setter(r.value.data);
      else errs[key] = r.status === "fulfilled" ? r.value.error : "Failed";
    };
    set(ev, "evidence", setEvidence);
    set(vi, "verification", setVerification);
    set(inst, "institutions", setInstitutions);
    set(fc, "forecast", setForecast);
    set(au, "audit", setAudit);
    set(co, "coin", setCoin);
    set(en, "engagement", setEngagement);

    setErrors(errs);
    setLoading(false);
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  const hasAnyData = evidence || verification || institutions || forecast || audit || coin || engagement;

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {/* ── header ── */}
      <div className="lg:col-span-2 card p-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-display text-lg font-bold text-ink">Statistical Reports</h3>
            <p className="text-xs text-muted">
              Real data from PostgreSQL, equivalent to R analytics scripts (evidence, verification, audit, institutions, forecast, coin economy, engagement).
            </p>
          </div>
          <button onClick={loadAll} disabled={loading}
            className="rounded-lg bg-brand px-4 py-2 text-sm font-semibold text-white shadow-card hover:bg-brand-700 disabled:opacity-50">
            {loading ? "Loading…" : "Refresh all"}
          </button>
        </div>
        {Object.keys(errors).length > 0 && !hasAnyData && (
          <div className="mt-3 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <p className="font-semibold">Some report endpoints are unavailable</p>
            <p className="mt-1 text-xs text-rose-500">Endpoints: {Object.keys(errors).join(", ")}</p>
          </div>
        )}
      </div>

      {/* ── evidence analysis ── */}
      <SectionCard
        title="Submissions & Evidence"
        subtitle="By type, status, time series"
        error={errors.evidence} onRetry={loadAll}
      >
        {loading ? <Skeleton rows={4} cols={3} /> : evidence ? (
          <div className="space-y-4">
            <div className="grid grid-cols-4 gap-2 text-center">
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{evidence.summary?.total ?? 0}</p><p className="text-[10px] text-muted">Total submissions</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-accent-700">{evidence.summary?.approved ?? 0}</p><p className="text-[10px] text-muted">Approved</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-rose-600">{evidence.summary?.rejected ?? 0}</p><p className="text-[10px] text-muted">Rejected</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-amber-600">{evidence.summary?.pending ?? 0}</p><p className="text-[10px] text-muted">Pending</p></div>
            </div>
            {evidence.by_type?.length > 0 && (
              <ResponsiveContainer height={180}>
                <BarChart data={evidence.by_type.map((s: any) => ({ name: s.event_type, v: s.count }))} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
                  <XAxis dataKey="name" tick={{ fontSize: 10, fill: "#6B7280" }} />
                  <YAxis tick={{ fontSize: 10, fill: "#6B7280" }} />
                  <Tooltip />
                  <Bar dataKey="v" fill={ACCENT} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
            {evidence.over_time?.length > 0 && (
              <ResponsiveContainer height={120}>
                <AreaChart data={evidence.over_time} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="gEvOver" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={SKY} stopOpacity={0.3} />
                      <stop offset="100%" stopColor={SKY} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="date" tick={{ fontSize: 9, fill: "#6B7280" }} />
                  <YAxis tick={{ fontSize: 9, fill: "#6B7280" }} />
                  <Area type="monotone" dataKey="submissions" stroke={SKY} strokeWidth={1.5} fill="url(#gEvOver)" />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        ) : <p className="text-sm text-muted">No evidence data</p>}
      </SectionCard>

      {/* ── verification pipeline ── */}
      <SectionCard
        title="Verification Pipeline"
        subtitle="Confidence stats, review queue"
        error={errors.verification} onRetry={loadAll}
      >
        {loading ? <Skeleton rows={4} cols={3} /> : verification ? (
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{verification.confidence?.avg_confidence ?? "-"}</p><p className="text-[10px] text-muted">Avg approval score</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{verification.confidence?.high_confidence ?? 0}</p><p className="text-[10px] text-muted">High (≥0.8)</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{verification.confidence?.low_confidence ?? 0}</p><p className="text-[10px] text-muted">Low (&lt;0.5)</p></div>
            </div>
            <ResponsiveContainer height={180}>
              <PieChart>
                <Pie
                  data={verification.funnel?.map((f: any) => ({ name: f.status, v: f.count })) ?? []}
                  dataKey="v" nameKey="name" innerRadius={40} outerRadius={70} paddingAngle={2}
                >
                  {(verification.funnel ?? []).map((_: any, i: number) => (
                    <Cell key={i} fill={[ACCENT, AMBER, SKY, ROSE, PURPLE, BRAND][i % 6]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
            {verification.verdicts?.length > 0 && (
              <div>
                <p className="text-xs font-semibold text-muted mb-1">Admin verdicts</p>
                {verification.verdicts.map((v: any, i: number) => (
                  <div key={i} className="flex items-center justify-between text-xs py-1 border-b border-line last:border-0">
                    <span className={statusTone[v.admin_verdict] ?? "text-ink"}>{v.admin_verdict}</span>
                    <span className="text-muted">{v.count} items</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : <p className="text-sm text-muted">No verification data</p>}
      </SectionCard>

      {/* ── institution performance ── */}
      <SectionCard
        title="Institution Performance"
        subtitle="Programs, members, OII scores"
        error={errors.institutions} onRetry={loadAll}
      >
        {loading ? <Skeleton rows={5} cols={5} /> : institutions?.institutions?.length ? (
          <div>
            <ResponsiveContainer height={200}>
              <BarChart data={institutions.institutions.slice(0, 8)} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
                <XAxis dataKey="org_name" tick={{ fontSize: 9, fill: "#6B7280" }} angle={-15} textAnchor="end" height={50} />
                <YAxis tick={{ fontSize: 10, fill: "#6B7280" }} />
                <Tooltip />
                <Legend />
                <Bar dataKey="programs" name="Programs" fill={BRAND} radius={[4, 4, 0, 0]} />
                <Bar dataKey="members" name="Members" fill={SKY} radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
            <div className="mt-3 overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr className="border-b border-line text-left uppercase tracking-wide text-muted">
                    <th className="py-1.5 pr-3 font-semibold">Institution</th>
                    <th className="py-1.5 pr-3 font-semibold">Type</th>
                    <th className="py-1.5 pr-3 font-semibold">OII</th>
                    <th className="py-1.5 pr-3 font-semibold">Programs</th>
                    <th className="py-1.5 font-semibold">Members</th>
                  </tr>
                </thead>
                <tbody>
                  {institutions.institutions.slice(0, 8).map((inst: any, i: number) => (
                    <tr key={i} className="border-b border-line last:border-0">
                      <td className="py-2 pr-3 font-medium text-ink">{inst.org_name}</td>
                      <td className="py-2 pr-3 text-muted">{inst.org_type ?? "-"}</td>
                      <td className="py-2 pr-3 text-ink">{inst.oii_score?.toFixed(1) ?? "-"}</td>
                      <td className="py-2 pr-3 text-ink">{inst.programs}</td>
                      <td className="py-2 text-ink">{inst.members}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ) : <p className="text-sm text-muted">No institution data available</p>}
      </SectionCard>

      {/* ── impact forecast ── */}
      <SectionCard
        title="Impact Forecast"
        subtitle="OLS linear trend projection"
        error={errors.forecast} onRetry={loadAll}
      >
        {loading ? <Skeleton rows={3} cols={1} /> : forecast ? (
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-2 text-center">
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{forecast.slope ?? 0}</p><p className="text-[10px] text-muted">Trend slope</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{forecast.forecast?.[forecast.forecast.length - 1]?.projected ?? 0}</p><p className="text-[10px] text-muted">End projection</p></div>
            </div>
            <ResponsiveContainer height={200}>
              <LineChart data={[
                ...(forecast.history ?? []).map((h: any) => ({
                  name: typeof h.month === "string" ? h.month.slice(0, 7) : h.month,
                  actual: h.actions,
                })),
                ...(forecast.forecast ?? []).map((f: any) => ({
                  name: f.month?.slice(0, 7) ?? "?",
                  projected: f.projected,
                })),
              ]} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: "#6B7280" }} />
                <YAxis tick={{ fontSize: 10, fill: "#6B7280" }} />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="actual" stroke={BRAND} strokeWidth={2.5} dot={{ r: 2 }} connectNulls />
                <Line type="monotone" dataKey="projected" stroke={AMBER} strokeWidth={2.5} strokeDasharray="6 3" dot={{ r: 2 }} connectNulls />
              </LineChart>
            </ResponsiveContainer>
          </div>
        ) : <p className="text-sm text-muted">Insufficient data for forecast, need 2+ months of submissions</p>}
      </SectionCard>

      {/* ── coin economy ── */}
      <SectionCard
        title="Coin Economy"
        subtitle="MASAREEN Coin transactions and exchange rates"
        error={errors.coin} onRetry={loadAll}
      >
        {loading ? <Skeleton rows={4} cols={2} /> : coin ? (
          <div className="space-y-3">
            <div className="grid grid-cols-3 gap-2 text-center">
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{coin.summary?.total_transactions ?? 0}</p><p className="text-[10px] text-muted">Transactions</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{coin.summary?.total_volume ?? 0}</p><p className="text-[10px] text-muted">Total volume</p></div>
              <div className="rounded-xl bg-canvas p-2"><p className="text-lg font-bold text-ink">{coin.summary?.avg_amount ?? 0}</p><p className="text-[10px] text-muted">Avg amount</p></div>
            </div>
            {coin.by_type?.length > 0 && (
              <ResponsiveContainer height={160}>
                <PieChart>
                  <Pie
                    data={coin.by_type.map((t: any) => ({ name: t.type, v: t.count }))}
                    dataKey="v" nameKey="name" innerRadius={35} outerRadius={60} paddingAngle={2}
                  >
                    {coin.by_type.map((_: any, i: number) => (
                      <Cell key={i} fill={[AMBER, BRAND, ACCENT, SKY, PURPLE, ROSE][i % 6]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            )}
            {coin.over_time?.length > 0 && (
              <ResponsiveContainer height={120}>
                <BarChart data={coin.over_time} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                  <XAxis dataKey="date" tick={{ fontSize: 9, fill: "#6B7280" }} />
                  <YAxis tick={{ fontSize: 9, fill: "#6B7280" }} />
                  <Bar dataKey="transactions" fill={AMBER} radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        ) : <p className="text-sm text-muted">No coin data</p>}
      </SectionCard>

      {/* ── user engagement ── */}
      <SectionCard
        title="User Engagement"
        subtitle="Posts, likes, follows, user growth"
        error={errors.engagement} onRetry={loadAll}
        className="lg:col-span-2"
      >
        {loading ? <Skeleton rows={4} cols={4} /> : engagement ? (
          <div className="space-y-4">
            <div className="grid grid-cols-4 gap-3 text-center">
              <div className="rounded-xl bg-canvas p-3"><p className="text-2xl font-bold text-ink">{engagement.totals?.total_users ?? 0}</p><p className="text-[11px] text-muted">Total users</p></div>
              <div className="rounded-xl bg-canvas p-3"><p className="text-2xl font-bold text-ink">{engagement.totals?.total_posts ?? 0}</p><p className="text-[11px] text-muted">Posts</p></div>
              <div className="rounded-xl bg-canvas p-3"><p className="text-2xl font-bold text-ink">{engagement.totals?.total_likes ?? 0}</p><p className="text-[11px] text-muted">Likes</p></div>
              <div className="rounded-xl bg-canvas p-3"><p className="text-2xl font-bold text-ink">{engagement.totals?.total_follows ?? 0}</p><p className="text-[11px] text-muted">Follows</p></div>
            </div>
            <div className="grid gap-4 lg:grid-cols-2">
              <div>
                <p className="text-xs font-semibold text-muted mb-1">Posts by kind</p>
                <ResponsiveContainer height={160}>
                  <BarChart data={engagement.posts_by_kind?.map((k: any) => ({ name: k.kind, v: k.count })) ?? []} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
                    <XAxis dataKey="name" tick={{ fontSize: 10, fill: "#6B7280" }} />
                    <YAxis tick={{ fontSize: 10, fill: "#6B7280" }} />
                    <Tooltip />
                    <Bar dataKey="v" fill={BRAND} radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
              <div>
                <p className="text-xs font-semibold text-muted mb-1">User roles</p>
                <ResponsiveContainer height={160}>
                  <PieChart>
                    <Pie
                      data={engagement.role_distribution?.map((r: any) => ({ name: r.role, v: r.count })) ?? []}
                      dataKey="v" nameKey="name" innerRadius={35} outerRadius={60} paddingAngle={2}
                    >
                      {(engagement.role_distribution ?? []).map((_: any, i: number) => (
                        <Cell key={i} fill={[BRAND, ACCENT, SKY, AMBER, PURPLE, ROSE][i % 6]} />
                      ))}
                    </Pie>
                    <Tooltip />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>
            {engagement.user_growth?.length > 0 && (
              <div>
                <p className="text-xs font-semibold text-muted mb-1">User signups over time</p>
                <ResponsiveContainer height={120}>
                  <AreaChart data={engagement.user_growth} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                    <defs>
                      <linearGradient id="gGrowth" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={ACCENT} stopOpacity={0.3} />
                        <stop offset="100%" stopColor={ACCENT} stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="month" tick={{ fontSize: 9, fill: "#6B7280" }} />
                    <YAxis tick={{ fontSize: 9, fill: "#6B7280" }} />
                    <Area type="monotone" dataKey="signups" stroke={ACCENT} strokeWidth={1.5} fill="url(#gGrowth)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        ) : <p className="text-sm text-muted">No engagement data</p>}
      </SectionCard>

      {/* ── audit trail ── */}
      <SectionCard
        title="Audit Trail"
        subtitle="Submission events by type"
        error={errors.audit} onRetry={loadAll}
        className="lg:col-span-2"
      >
        {loading ? <Skeleton rows={4} cols={2} /> : audit ? (
          <div className="space-y-3">
            <div className="rounded-xl bg-canvas p-3 text-center">
              <p className="text-2xl font-bold text-ink">{audit.total_events ?? 0}</p>
              <p className="text-[10px] text-muted">Total events</p>
            </div>
            <div className="grid gap-4 lg:grid-cols-2">
              {audit.by_type?.length > 0 && (
                <ResponsiveContainer height={180}>
                  <BarChart data={audit.by_type} layout="vertical" margin={{ top: 4, right: 12, left: 8, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
                    <XAxis type="number" tick={{ fontSize: 10, fill: "#6B7280" }} />
                    <YAxis type="category" dataKey="event_type" tick={{ fontSize: 10, fill: "#6B7280" }} width={100} />
                    <Tooltip />
                    <Bar dataKey="count" fill={PURPLE} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
              {audit.over_time?.length > 0 && (
                <ResponsiveContainer height={180}>
                  <AreaChart data={audit.over_time} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
                    <defs>
                      <linearGradient id="gAudit" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={PURPLE} stopOpacity={0.3} />
                        <stop offset="100%" stopColor={PURPLE} stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="date" tick={{ fontSize: 9, fill: "#6B7280" }} />
                    <YAxis tick={{ fontSize: 9, fill: "#6B7280" }} />
                    <Area type="monotone" dataKey="events" stroke={PURPLE} strokeWidth={1.5} fill="url(#gAudit)" />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>
        ) : <p className="text-sm text-muted">No audit data available</p>}
      </SectionCard>
    </div>
  );
}
