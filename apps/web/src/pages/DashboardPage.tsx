import { useEffect, useState } from "react";
import { bffService, coinService } from "../services/api";
import { useI18n } from "../i18n";
import { useAuth } from "../store/authStore";
import { Link } from "react-router-dom";
import { IconImpact } from "../components/icons/Icons";

interface DashboardData {
  platform: Record<string, any> | null;
  me: any;
  user_stats: Record<string, any> | null;
  pms: { composite_score?: number; tier?: string } | null;
}

const PLATFORM_LABELS: Record<string, string> = {
  total_users: "Verified Users",
  active_programs: "Active Programs",
  verified_tasks: "Verified Tasks",
  impact_assets_created: "Impact Assets",
  total_economic_value_usd: "Economic Value (USD)",
  countries_active: "Active Countries",
};

const PLATFORM_ICONS: Record<string, string> = {
  total_users: "👥",
  active_programs: "🌱",
  verified_tasks: "✅",
  impact_assets_created: "💎",
  total_economic_value_usd: "💰",
  countries_active: "🌍",
};

const tierColors: Record<string, string> = {
  BRONZE: "bg-amber-100 text-amber-700",
  SILVER: "bg-navy-200 text-navy-700",
  GOLD: "bg-amber-50 text-amber-700",
  PLATINUM: "bg-brand-50 text-brand",
};

export default function DashboardPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [data, setData] = useState<DashboardData | null>(null);
  const [mrcBalance, setMrcBalance] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      bffService.dashboard().catch(() => null),
      user?.id ? coinService.getWallet(user.id).catch(() => null) : Promise.resolve(null),
    ]).then(([dash, wallet]) => {
      setData(dash);
      if (wallet?.balance !== undefined) setMrcBalance(wallet.balance);
    }).finally(() => setLoading(false));
  }, [user?.id]);

  const platform = data?.platform ?? {};
  const cards = Object.keys(PLATFORM_LABELS)
    .filter((k) => k in platform)
    .map((k) => ({ key: k, label: PLATFORM_LABELS[k], value: (platform as any)[k], icon: PLATFORM_ICONS[k] }));

  const score = data?.pms?.composite_score;
  const scoreDisplay = score != null ? (score <= 1 ? (score * 100).toFixed(0) : score.toFixed(0)) : "-";

  if (loading) return (
    <div className="space-y-6 animate-fade-up">
      <div className="skeleton h-48 w-full rounded-2xl" />
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {[0, 1, 2].map(i => <div key={i} className="skeleton h-32 rounded-xl" />)}
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Hero Banner */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-brand via-brand-light to-accent p-8 text-white shadow-xl animate-fade-up">
        <div className="absolute -right-16 -top-16 h-72 w-72 rounded-full bg-white/8 blur-3xl pointer-events-none" />
        <div className="absolute -left-8 -bottom-8 h-48 w-48 rounded-full bg-white/5 blur-2xl pointer-events-none" />

        <div className="relative z-10 flex flex-col md:flex-row md:items-center md:justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1.5 text-xs font-medium backdrop-blur-md mb-4 border border-white/10">
              <span className="h-2 w-2 rounded-full bg-emerald-300 animate-pulse-soft" />
              POAI Verified Network · Live
            </div>
            <h1 className="text-display-sm text-white">
              Welcome back, {data?.me?.full_name ?? user?.full_name ?? "Impact Builder"}
            </h1>
            <p className="mt-2 text-white/70 max-w-xl text-body-md">
              Your actions are verified, immutable, and converting real-world deeds into measurable economic assets.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link to="/evidence" className="btn bg-white text-brand hover:bg-white/90 shadow-lg">
              <IconImpact size={18} /> Submit Evidence
            </Link>
            <Link to="/tasks" className="btn bg-white/15 text-white hover:bg-white/25 backdrop-blur-md border border-white/10">
              View Tasks
            </Link>
          </div>
        </div>
      </div>

      {/* PMS & Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* PMS Score */}
        <div className="stat-card group animate-fade-up" style={{ animationDelay: "50ms" }}>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <p className="text-label-lg text-muted mb-1">Proof-of-Mission Score</p>
              <div className="flex items-baseline gap-3">
                <span className="text-display-sm text-ink">{scoreDisplay}</span>
                {data?.pms?.tier && (
                  <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${tierColors[data.pms.tier] || "bg-navy-100 text-muted"}`}>
                    {data.pms.tier}
                  </span>
                )}
              </div>
              {score != null && <p className="mt-1 text-xs text-muted">Verified contributor score</p>}
            </div>
            <div className="grid h-14 w-14 place-items-center rounded-xl bg-brand-50 text-2xl transition-transform duration-200 group-hover:scale-110">
              🏆
            </div>
          </div>
          {score != null && (
            <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-navy-100">
              <div className="h-full rounded-full bg-gradient-to-r from-brand to-accent transition-all duration-700" style={{ width: `${Math.min(100, score <= 1 ? score * 100 : score)}%` }} />
            </div>
          )}
        </div>

        {/* MRC Balance */}
        <div className="stat-card group animate-fade-up" style={{ animationDelay: "100ms" }}>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <p className="text-label-lg text-muted mb-1">MRC Wallet Balance</p>
              <div className="flex items-baseline gap-2">
                <span className="text-display-sm text-ink">
                  {mrcBalance != null ? mrcBalance.toLocaleString() : "-"}
                </span>
                {mrcBalance != null && <span className="text-sm font-semibold text-accent">MRC</span>}
              </div>
            </div>
            <Link to="/wallet" className="grid h-14 w-14 place-items-center rounded-xl bg-accent-50 text-2xl transition-all duration-200 hover:bg-accent-100 group-hover:scale-110">
              🪙
            </Link>
          </div>
        </div>

        {/* Programs */}
        <div className="stat-card group animate-fade-up" style={{ animationDelay: "150ms" }}>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <p className="text-label-lg text-muted mb-1">Your Programs</p>
              <span className="text-display-sm text-ink">{data?.user_stats?.programs_enrolled ?? "-"}</span>
            </div>
            <Link to="/programs" className="grid h-14 w-14 place-items-center rounded-xl bg-brand-50 text-2xl transition-all duration-200 hover:bg-brand-100 group-hover:scale-110">
              🌱
            </Link>
          </div>
        </div>
      </div>

      {/* Platform Statistics */}
      {cards.length > 0 && (
        <div className="space-y-4 animate-fade-up" style={{ animationDelay: "200ms" }}>
          <h2 className="text-title-lg text-ink">Platform Impact Overview</h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
            {cards.map((c, i) => (
              <div
                key={c.key}
                className="stat-card group text-center animate-fade-up"
                style={{ animationDelay: `${200 + i * 40}ms` }}
              >
                <span className="text-2xl mb-2 block transition-transform duration-200 group-hover:scale-110">{c.icon}</span>
                <p className="text-label-sm text-muted mb-1">{c.label}</p>
                <p className="text-title-lg text-ink font-bold">
                  {typeof c.value === "number" ? c.value.toLocaleString() : String(c.value ?? "-")}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
