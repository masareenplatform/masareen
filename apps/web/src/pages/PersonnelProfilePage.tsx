import { useState, useEffect, useMemo } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useAuth } from "../store/authStore";
import { personnelService } from "../services/api";
import {
  ResponsiveContainer, AreaChart, Area, BarChart, Bar, LineChart, Line,
  XAxis, YAxis, Tooltip, CartesianGrid, Legend,
} from "recharts";

const BRAND = "#0250A3";
const AZURE = "#0077C8";
const ACCENT = "#2A9D45";

type P = Record<string, any>;

const TABS = ["Overview", "Reports", "Coverage", "Analytics", "Achievements", "Timeline", "Recommendations"];
const METRICS: Record<string, string> = {
  impact_score: "Impact Score", reach: "Reach", engagement: "Engagement",
  verified_reports: "Verified Reports", trust_score: "Trust Score",
  influence: "Influence", knowledge: "Knowledge",
};

export default function PersonnelProfilePage() {
  const { id } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  const userId = id ?? user?.id;

  const [p, setP] = useState<P | null>(null);
  const [reports, setReports] = useState<P[]>([]);
  const [analytics, setAnalytics] = useState<P[]>([]);
  const [timeline, setTimeline] = useState<P[]>([]);
  const [achievements, setAchievements] = useState<P[]>([]);
  const [orgs, setOrgs] = useState<P[]>([]);
  const [recs, setRecs] = useState<P[]>([]);
  const [tab, setTab] = useState("Overview");
  const [metric, setMetric] = useState("impact_score");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const isMe = userId === user?.id;

  useEffect(() => {
    if (!userId) return;
    let alive = true;
    setLoading(true);
    (async () => {
      try {
        const [pp, rr, an, tl, ac, og, rc] = await Promise.all([
          personnelService.get(userId!),
          personnelService.reports(userId!),
          personnelService.analytics(userId!),
          personnelService.timeline(userId!),
          personnelService.achievements(userId!),
          personnelService.organizations(userId!),
          personnelService.recommendations(userId!),
        ]);
        if (!alive) return;
        setP(pp); setReports(rr); setAnalytics(an?.series ?? []);
        setTimeline(tl); setAchievements(ac); setOrgs(og); setRecs(rc);
      } catch (e: any) {
        if (alive) setErr(e?.message ?? "Failed to load profile");
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, [userId, user?.id]);

  const kpi = p?.kpi ?? {};
  const num = (v: any) =>
    v == null ? "0" : (typeof v === "number" && v % 1 === 0 ? v.toLocaleString() : (v ?? "0").toString());

  const follow = async () => {
    if (!userId || isMe || busy) return;
    setBusy(true);
    try { await personnelService.follow(userId); }
    catch { /* ignore */ }
    finally { setBusy(false); }
  };

  const chartData = useMemo(
    () => analytics.map((a) => ({ ...a })),
    [analytics]
  );

  if (loading) return <div className="grid min-h-[50vh] place-items-center text-muted">Loading profile…</div>;
  if (err || !p) return <div className="card p-6 text-red-500">{err ?? "Profile not found"}</div>;

  return (
    <div className="mx-auto max-w-4xl">
      {/* Header */}
      <div className="card overflow-hidden">
        <div
          className="relative h-44 w-full sm:h-56"
          style={p.cover_url
            ? { backgroundImage: `url(${p.cover_url})`, backgroundSize: "cover", backgroundPosition: "center" }
            : { background: "linear-gradient(135deg,#0250A3,#0077C8)" }}>
          <div className="absolute inset-0" style={{ background: "linear-gradient(to top, rgba(5,9,16,.7), transparent)" }} />
          <div className="absolute bottom-4 left-5 right-5 flex items-end gap-4">
            <div className="grid h-20 w-20 shrink-0 place-items-center rounded-full bg-white text-3xl font-bold text-brand ring-4 ring-white">
              {(p.name?.[0] ?? "?").toUpperCase()}
            </div>
            <div className="min-w-0 flex-1 text-white">
              <div className="flex items-center gap-2">
                <h1 className="truncate text-2xl font-extrabold">{p.name}</h1>
                {p.email_verified && <span title="Verified" className="text-sky-300">✓</span>}
              </div>
              <p className="truncate text-sm text-white/80">{p.headline}</p>
              <div className="mt-1 flex flex-wrap gap-2">
                <span className="rounded-full bg-white/15 px-2.5 py-0.5 text-xs font-semibold">{p.professional_rank}</span>
                <span className="rounded-full bg-accent/20 px-2.5 py-0.5 text-xs font-semibold text-accent-200">{p.impact_tier}</span>
              </div>
            </div>
            <div className="flex shrink-0 flex-col gap-2">
              {!isMe && (
                <button onClick={follow} disabled={busy}
                  className="btn-brand px-4 py-1.5 text-sm">{busy ? "…" : "Follow"}</button>
              )}
              <button onClick={() => navigate(`/profile`)}
                className="rounded-full border border-white/40 px-4 py-1.5 text-sm text-white hover:bg-white/10">Share</button>
            </div>
          </div>
        </div>

        {/* meta strip */}
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1 px-5 py-3 text-sm text-muted">
          <span className="font-semibold text-ink">{p.role}</span>
          {p.country && <span>📍 {[p.country, p.city].filter(Boolean).join(", ")}</span>}
          <span>🟢 {p.availability}</span>
          <span>🗓 Joined {p.joined?.slice(0, 10)}</span>
          <span>🏅 {p.verification_level}</span>
        </div>
      </div>

      {/* Primary Impact Card */}
      <div className="card mt-4 p-5">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-bold text-ink">Professional Impact</h2>
          <div className="flex gap-2">
            <ScorePill label="Impact" value={p.impact_score} color={BRAND} />
            <ScorePill label="Trust" value={p.trust_score} color={ACCENT} />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Stat label="Verified Reports" value={num(kpi.verified_reports)} />
          <Stat label="Published" value={num(kpi.total_reports)} />
          <Stat label="Evidence" value={num(kpi.evidence_submitted)} />
          <Stat label="Missions" value={num(kpi.verified_missions)} />
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          <Chip icon="🎯" k="Beat" v={p.beat} />
          <Chip icon="⭐" k="Expertise" v={(p.expertise ?? []).slice(0, 1).join("") || "General Reporting"} />
          <Chip icon="🌐" k="Coverage" v={[p.country, p.city].filter(Boolean).join(", ")} />
          <Chip icon="🗣" k="Languages" v={(p.languages ?? []).slice(0, 3).join(", ")} />
          <Chip icon="💼" k="Status" v={p.employment_status} />
        </div>
      </div>

      {/* KPI grid */}
      <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        <Kpi label="Total Reports" value={num(kpi.total_reports)} icon="📄" />
        <Kpi label="Verified" value={num(kpi.verified_reports)} icon="✓" tint={ACCENT} />
        <Kpi label="Trust Score" value={num(kpi.trust_score)} icon="🛡" />
        <Kpi label="AI Confidence" value={num(kpi.ai_confidence)} icon="🧠" />
        <Kpi label="Community" value={num(kpi.community_rating)} icon="👍" />
        <Kpi label="Followers" value={num(kpi.followers)} icon="👥" />
        <Kpi label="Countries" value={num(kpi.countries_covered)} icon="🌍" />
        <Kpi label="Coverage Hrs" value={num(kpi.coverage_hours)} icon="⏱" />
        <Kpi label="Quality" value={num(kpi.average_quality_score)} icon="⭐" />
        <Kpi label="Growth %" value={num(kpi.monthly_growth)} icon="📈" tint={ACCENT} />
      </div>

      {/* Tabs */}
      <div className="mt-5 flex gap-2 overflow-x-auto pb-1">
        {TABS.map((t) => (
          <button key={t} onClick={() => setTab(t)}
            className={`shrink-0 rounded-full px-4 py-1.5 text-sm font-semibold transition ${
              tab === t ? "bg-brand text-white" : "bg-canvas text-muted hover:bg-brand-50"}`}>
            {t}
          </button>
        ))}
      </div>

      <div className="mt-4">
        {tab === "Overview" && <OverviewTab p={p} orgs={orgs} />}
        {tab === "Reports" && <ReportsTab reports={reports} />}
        {tab === "Coverage" && <CoverageTab p={p} />}
        {tab === "Analytics" && (
          <AnalyticsTab data={chartData} metric={metric} setMetric={setMetric} p={p} />
        )}
        {tab === "Achievements" && <ListTab items={achievements} empty="No achievements recorded yet." icon="🏅"
          render={(a) => (<><p className="font-semibold text-ink">{a.title}</p>{a.detail && <p className="text-sm text-muted">{a.detail}</p>}</>)} />}
        {tab === "Timeline" && <ListTab items={timeline} empty="No activity yet." icon="•"
          render={(t) => (<><p className="font-semibold text-ink">{t.title}</p>{t.happened_at && <p className="text-sm text-muted">{t.happened_at.slice(0, 10)}</p>}</>)} />}
        {tab === "Recommendations" && <ListTab items={recs} empty="No recommendations yet." icon="“"
          render={(r) => (<><div className="flex items-center justify-between"><p className="font-semibold text-ink">{r.author_name}</p>{r.relation && <span className="chip-brand">{r.relation}</span>}</div><p className="text-sm text-muted">{r.text}</p></>)} />}
      </div>
    </div>
  );
}

/* ── sub-components ──────────────────────────────────────────────────────────── */
function ScorePill({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="text-center">
      <p className="text-lg font-extrabold" style={{ color }}>{value?.toFixed?.(0) ?? value}</p>
      <p className="text-[10px] uppercase tracking-wide text-muted">{label}</p>
    </div>
  );
}
function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-canvas p-3 text-center">
      <p className="text-xl font-extrabold text-ink">{value}</p>
      <p className="mt-0.5 text-xs text-muted">{label}</p>
    </div>
  );
}
function Chip({ icon, k, v }: { icon: string; k: string; v: string }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-lg border border-line bg-canvas px-2.5 py-1 text-xs">
      <span>{icon}</span><span className="text-muted">{k}:</span>
      <span className="font-semibold text-ink">{v || "-"}</span>
    </span>
  );
}
function Kpi({ label, value, icon, tint }: { label: string; value: string; icon: string; tint?: string }) {
  return (
    <div className="card p-3">
      <div className="text-xl" style={{ color: tint ?? BRAND }}>{icon}</div>
      <p className="mt-1 text-xl font-extrabold text-ink">{value}</p>
      <p className="text-xs text-muted">{label}</p>
    </div>
  );
}

function OverviewTab({ p, orgs }: { p: P; orgs: P[] }) {
  const expertise = p.expertise ?? [];
  const skills = p.skills ?? [];
  const experience = p.experience ?? [];
  const allExp = [...experience, ...orgs.map((o) => ({ role: o.role, org: o.name, from: "", to: "", duration: o.duration }))];
  return (
    <div className="space-y-4">
      {p.summary && <Section title="Professional Summary">{p.summary}</Section>}
      {p.mission && <Section title="Mission Statement">{p.mission}</Section>}
      {p.bio && <Section title="Biography">{p.bio}</Section>}
      <Section title="Areas of Expertise">
        <div className="flex flex-wrap gap-2">{expertise.length ? expertise.map((e: any, i: number) => <span key={i} className="chip-brand">{e?.name ?? e}</span>) : <span className="text-muted">Not specified</span>}</div>
      </Section>
      <Section title="Skills">
        <div className="flex flex-wrap gap-2">{skills.length ? skills.map((s: any, i: number) => <span key={i} className="chip-accent">{s?.name ?? s}{s?.endorsements ? ` · ${s.endorsements}` : ""}</span>) : <span className="text-muted">Not specified</span>}</div>
      </Section>
      {allExp.length > 0 && (
        <Section title="Experience">
          <div className="space-y-2">
            {allExp.map((e: any, i: number) => (
              <div key={i} className="flex items-center gap-3 rounded-xl bg-canvas p-3">
                <span className="text-brand">💼</span>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-ink">{e.role ?? ""}</p>
                  <p className="text-sm text-muted">{e.org ?? ""}</p>
                </div>
                <span className="text-xs text-muted">{e.duration ?? `${e.from ?? ""} – ${e.to ?? ""}`}</span>
              </div>
            ))}
          </div>
        </Section>
      )}
    </div>
  );
}
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="card p-5">
      <h3 className="mb-2 text-sm font-bold uppercase tracking-wide text-muted">{title}</h3>
      <div className="text-sm leading-relaxed text-ink">{children}</div>
    </div>
  );
}

function ReportsTab({ reports }: { reports: P[] }) {
  if (!reports.length) return <Empty text="No published reports yet." />;
  return (
    <div className="space-y-3">
      {reports.map((r, i) => {
        const verified = r.verification_status === "VERIFIED";
        return (
          <div key={i} className="card p-4">
            <div className="mb-2 flex items-center gap-2">
              <span className="rounded bg-brand-50 px-2 py-0.5 text-[10px] font-bold text-brand">{r.category?.toUpperCase()}</span>
              <span className={`inline-flex items-center gap-1 text-xs ${verified ? "text-accent" : "text-amber-500"}`}>
                {verified ? "✓ Verified" : "◷ In Review"}
              </span>
              {r.sdg > 0 && <span className="ml-auto text-xs text-muted">SDG {r.sdg}</span>}
            </div>
            <p className="font-semibold text-ink">{r.headline}</p>
            <div className="mt-2 flex gap-4 text-xs text-muted">
              <span>👁 {r.reach?.toLocaleString()}</span>
              <span>❤ {r.likes}</span>
              <span>💬 {r.comments}</span>
              <span>⭐ {r.quality_score}</span>
              <span className="ml-auto font-semibold text-azure">Impact {r.impact_score}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function CoverageTab({ p }: { p: P }) {
  return (
    <div className="space-y-3">
      <div className="card overflow-hidden p-0">
        <div className="flex items-center gap-4 bg-gradient-to-r from-brand to-azure p-5 text-white">
          <span className="text-3xl">🗺️</span>
          <div>
            <p className="text-lg font-extrabold">{p.country ?? "Global"}</p>
            <p className="text-white/80">{p.city ?? "Field coverage"}</p>
          </div>
          <span className="ml-auto text-2xl">📍</span>
        </div>
      </div>
      <div className="card p-5 text-sm text-muted">
        Coverage regions and assignment pins are visualized from the professional's verified field activity. This map aggregates countries, cities and mission pins where reports were produced.
      </div>
    </div>
  );
}

function AnalyticsTab({ data, metric, setMetric, p }: { data: P[]; metric: string; setMetric: (m: string) => void; p: P }) {
  const last = data[data.length - 1] ?? {};
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {Object.entries(METRICS).map(([k, v]) => (
          <button key={k} onClick={() => setMetric(k)}
            className={`rounded-full px-3 py-1 text-xs font-semibold ${metric === k ? "bg-azure text-white" : "bg-canvas text-muted"}`}>{v}</button>
        ))}
      </div>
      <div className="card p-4">
        <h3 className="mb-2 text-sm font-bold uppercase tracking-wide text-muted">Impact Trend</h3>
        <ResponsiveContainer height={280}>
          <AreaChart data={data} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="gP" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={AZURE} stopOpacity={0.4} />
                <stop offset="100%" stopColor={AZURE} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#E6EBF2" />
            <XAxis dataKey="bucket" tick={{ fontSize: 11, fill: "#6B7280" }} />
            <YAxis tick={{ fontSize: 11, fill: "#6B7280" }} />
            <Tooltip />
            <Area type="monotone" dataKey={metric} stroke={AZURE} strokeWidth={2.5} fill="url(#gP)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <TrendCard label="Impact Score" value={(last.impact_score ?? 0).toFixed(0)} trend="+12%" />
        <TrendCard label="Reach" value={((last.reach ?? 0) >= 1000 ? `${(last.reach / 1000).toFixed(1)}k` : (last.reach ?? 0)).toString()} trend="+8%" />
        <TrendCard label="Trust" value={(last.trust_score ?? 0).toFixed(0)} trend="+5%" />
      </div>
    </div>
  );
}
function TrendCard({ label, value, trend }: { label: string; value: string; trend: string }) {
  return (
    <div className="card p-4">
      <p className="text-xs text-muted">{label}</p>
      <p className="text-2xl font-extrabold text-ink">{value}</p>
      <p className="text-xs font-semibold text-accent">{trend}</p>
    </div>
  );
}

function ListTab({ items, empty, icon, render }: { items: P[]; empty: string; icon: string; render: (it: P) => React.ReactNode }) {
  if (!items.length) return <Empty text={empty} />;
  return (
    <div className="space-y-3">
      {items.map((it, i) => (
        <div key={i} className="card flex gap-3 p-4">
          <span className="text-xl">{icon}</span>
          <div className="min-w-0 flex-1">{render(it)}</div>
        </div>
      ))}
    </div>
  );
}
function Empty({ text }: { text: string }) {
  return <div className="card p-10 text-center text-muted">{text}</div>;
}
