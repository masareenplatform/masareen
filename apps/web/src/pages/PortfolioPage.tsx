import { useState, useEffect } from "react";
import { portfolioService } from "../services/api";
import { useAuth } from "../store/authStore";

interface PortfolioData {
  total_evidence?: number; completed_tasks?: number; programs_joined?: number;
  total_impact_value?: number; badges?: string[];
}

export default function PortfolioPage() {
  const { user } = useAuth();
  const [data, setData] = useState<PortfolioData | null>(null);

  useEffect(() => {
    if (!user?.id) return;
    portfolioService.forUser(user.id).then(setData).catch(() => setData(null));
  }, [user?.id]);

  const n = (v?: number) => (typeof v === "number" ? v.toLocaleString() : "-");

  return (
    <div>
      <h2 className="text-2xl font-bold text-ink mb-6">Portfolio</h2>
      {!data ? <p className="text-muted">No portfolio data yet.</p> : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {[
            { label: "Evidence Items", value: n(data.total_evidence), accent: "text-ink" },
            { label: "Completed Tasks", value: n(data.completed_tasks), accent: "text-gold" },
            { label: "Programs Joined", value: n(data.programs_joined), accent: "text-ink/80" },
            { label: "Impact Value", value: n(data.total_impact_value), accent: "text-ink" },
          ].map(c => (
            <div key={c.label} className="glass-card">
              <p className="mb-2 text-xs uppercase tracking-wide text-muted font-semibold">{c.label}</p>
              <p className={`text-3xl font-bold ${c.accent}`}>{c.value}</p>
            </div>
          ))}
        </div>
      )}
      {data?.badges && data.badges.length > 0 && (
        <div className="glass-card">
          <p className="mb-3 text-sm font-semibold text-ink">Badges</p>
          <div className="flex gap-2 flex-wrap">
            {data.badges.map(b => (
              <span key={b} className="chip text-gold border-gold/30 bg-gold/10">{b}</span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
