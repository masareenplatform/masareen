import { useEffect, useState } from "react";
import { adminApi } from "../api";

export default function DashboardPage() {
  const [stats, setStats] = useState<Record<string, any> | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    adminApi
      .dashboard()
      .then(setStats)
      .catch((e) => console.error(e))
      .finally(() => setLoading(false));
  }, []);

  const cards: { label: string; value: any }[] = stats
    ? [
        { label: "Total Users", value: stats.total_users },
        { label: "Active Programs", value: stats.active_programs },
        { label: "Verified Evidence", value: stats.total_evidence },
        { label: "Open Reviews", value: stats.pending_reviews },
      ]
    : [];

  return (
    <div>
      <h1 style={{ color: "var(--navy)" }}>Platform Dashboard</h1>
      {loading ? (
        <p>Loading…</p>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16 }}>
          {cards.map((c) => (
            <div className="card" key={c.label}>
              <div style={{ fontSize: 13, color: "#64748b" }}>{c.label}</div>
              <div style={{ fontSize: 30, fontWeight: 700, color: "var(--navy)" }}>{c.value ?? "-"}</div>
            </div>
          ))}
        </div>
      )}
      {stats && (
        <div className="card" style={{ marginTop: 16 }}>
          <h3 style={{ marginTop: 0 }}>Raw snapshot</h3>
          <pre style={{ fontSize: 12, overflowX: "auto" }}>{JSON.stringify(stats, null, 2)}</pre>
        </div>
      )}
    </div>
  );
}
