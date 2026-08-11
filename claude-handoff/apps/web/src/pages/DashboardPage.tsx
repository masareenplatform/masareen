import { useEffect, useState } from "react";
import { bffService } from "../services/api";
import { useI18n } from "../i18n";

interface DashboardData {
  platform: Record<string, any> | null;
  me: any;
  user_stats: Record<string, any> | null;
  pms: { composite_score?: number; tier?: string } | null;
}

const PLATFORM_LABELS: Record<string, string> = {
  total_users: "Users",
  active_programs: "Active Programs",
  verified_tasks: "Verified Tasks",
  impact_assets_created: "Impact Assets",
  total_economic_value_usd: "Economic Value (USD)",
  countries_active: "Countries Active",
};

const tierColor: Record<string, string> = {
  BRONZE: "#B45309",
  SILVER: "#9CA3AF",
  GOLD: "#C9A84C",
  PLATINUM: "#7DD3FC",
};

export default function DashboardPage() {
  const { t } = useI18n();
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    bffService
      .dashboard()
      .then((d) => setData(d))
      .catch(() => setError("Dashboard data is temporarily unavailable."));
  }, []);

  const platform = data?.platform ?? {};
  const cards = Object.keys(PLATFORM_LABELS)
    .filter((k) => k in platform)
    .map((k) => ({ key: k, label: PLATFORM_LABELS[k], value: (platform as any)[k] }));

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-ink">
            {t("nav.dashboard")}
          </h1>
          <p className="text-sm text-muted">
            {data?.me?.full_name ?? "Welcome back, impact builder"}
          </p>
        </div>
        <span className="chip-brand">Live</span>
      </div>

      {error && (
        <div className="glass-card border-rose-200 text-rose-600">{error}</div>
      )}

      {data?.pms && (
        <div className="glass-card mb-5 flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-muted">
              Proof-of-Mission Score
            </p>
            <div className="mt-1 flex items-baseline gap-3">
              <span className="text-4xl font-extrabold text-ink">
                {((data.pms.composite_score ?? 0) * 100).toFixed(0)}
              </span>
              <span
                className="rounded-md px-3 py-1 text-xs font-bold text-white"
                style={{ background: tierColor[data.pms.tier ?? "BRONZE"] || "#9CA3AF" }}
              >
                {data.pms.tier ?? "—"}
              </span>
            </div>
          </div>
          <div className="hidden h-16 w-16 shrink-0 rounded-full bg-gradient-to-br from-brand to-accent shadow-fab sm:block" />
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-4">
        {cards.map((c) => (
          <div key={c.key} className="glass-card">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted">
              {c.label}
            </p>
            <p className="mt-2 text-2xl font-extrabold text-ink">
              {typeof c.value === "number" ? c.value.toLocaleString() : String(c.value ?? "—")}
            </p>
          </div>
        ))}
        {cards.length === 0 && !error && (
          <div className="col-span-full skeleton h-24" />
        )}
      </div>
    </div>
  );
}
