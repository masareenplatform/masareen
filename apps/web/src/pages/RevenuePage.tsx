import React, { useEffect, useState } from "react";
import { platformService } from "../services/api";
import { useAuth } from "../store/authStore";

export default function RevenuePage() {
  const { user } = useAuth();
  const isAdmin = user?.role === "ADMIN" || user?.role === "SUPER_ADMIN";

  const [feeRate, setFeeRate] = useState<number>(0);
  const [summary, setSummary] = useState<any>(null);
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Fee editor state (admin)
  const [feeInput, setFeeInput] = useState<string>("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [fee, sum, evts] = await Promise.all([
        platformService.getFee().catch(() => null),
        platformService.revenueSummary().catch(() => null),
        platformService.revenueEvents(50).catch(() => []),
      ]);
      const rate = Number(fee?.fee_rate ?? summary?.fee_rate ?? 0);
      setFeeRate(rate);
      setFeeInput((rate * 100).toString());
      setSummary(sum);
      setEvents(evts);
      setError("");
    } catch (e) {
      console.error("Error loading revenue", e);
      setError("Platform revenue service unavailable.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSaveFee = async (e: React.FormEvent) => {
    e.preventDefault();
    const pct = parseFloat(feeInput);
    if (isNaN(pct) || pct < 0 || pct > 100) {
      setError("Fee must be a percentage between 0 and 100.");
      return;
    }
    setSaving(true);
    setSaved(false);
    try {
      const res = await platformService.setFee(pct / 100);
      setFeeRate(Number(res?.fee_rate ?? pct / 100));
      setSaved(true);
      setError("");
      await fetchData();
    } catch (err) {
      console.error("Set fee failed", err);
      setError("Failed to update fee.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="p-8 text-muted">Loading profit & fees…</div>;

  const totals = summary?.totals ?? {};
  const bySource: Record<string, any> = summary?.by_source ?? {};

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-ink mb-6">Profit &amp; Fees</h1>
      {error && <p className="text-rose-600 text-sm mb-4">{error}</p>}

      {/* Brokerage fee headline */}
      <div className="glass-card mb-8">
        <p className="text-muted text-sm">Platform brokerage fee</p>
        <p className="text-4xl font-bold text-gold">{(feeRate * 100).toFixed(2)}%</p>
        <p className="text-sm text-muted mt-1">
          The platform earns this cut on every coin conversion, transfer, PSP payment, and ad
          campaign.
        </p>

        {isAdmin && (
          <form onSubmit={handleSaveFee} className="flex flex-wrap items-end gap-3 mt-5">
            <div>
              <label className="text-sm text-ink/70 mb-1 block">New fee (%)</label>
              <input
                type="number"
                min="0"
                max="100"
                step="any"
                className="glass-input w-40"
                value={feeInput}
                onChange={(e) => setFeeInput(e.target.value)}
              />
            </div>
            <button type="submit" className="btn-gold" disabled={saving}>
              {saving ? "Updating…" : "Update fee"}
            </button>
            {saved && <span className="text-emerald-600 text-sm">Saved ✓</span>}
          </form>
        )}
        {!isAdmin && (
          <p className="text-xs text-ink/40 mt-4">
            Only admins can change the brokerage fee.
          </p>
        )}
      </div>

      {/* Revenue totals */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="glass-card">
          <p className="text-muted text-sm">Total revenue (MRC)</p>
          <p className="text-3xl font-bold text-gold">
            {Number(totals?.MRC ?? 0).toLocaleString()} MRC
          </p>
        </div>
        <div className="glass-card">
          <p className="text-muted text-sm">Total revenue (EGP)</p>
          <p className="text-3xl font-bold text-gold">
            {Number(totals?.EGP ?? 0).toLocaleString()} EGP
          </p>
        </div>
      </div>

      {/* By source breakdown */}
      <div className="glass-card mb-8">
        <h2 className="text-lg font-semibold text-ink mb-4">Revenue by source</h2>
        {Object.keys(bySource).length === 0 ? (
          <p className="text-muted text-sm">No revenue recorded yet.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {Object.entries(bySource).map(([src, amounts]) => (
              <div key={src} className="glass rounded-xl p-4">
                <p className="text-ink font-semibold capitalize">{src}</p>
                <div className="mt-2 text-sm text-ink/70 space-y-1">
                  {(amounts as any)?.MRC != null && (
                    <div className="flex justify-between">
                      <span>MRC</span>
                      <span className="text-gold">
                        {Number((amounts as any).MRC).toLocaleString()}
                      </span>
                    </div>
                  )}
                  {(amounts as any)?.EGP != null && (
                    <div className="flex justify-between">
                      <span>EGP</span>
                      <span className="text-gold">
                        {Number((amounts as any).EGP).toLocaleString()}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Recent revenue events */}
      <div className="glass-card">
        <h2 className="text-lg font-semibold text-ink mb-4">Recent revenue events</h2>
        {events.length === 0 ? (
          <p className="text-muted text-sm">No revenue events yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-ink/50 text-left">
                  <th className="py-2 pr-4">Source</th>
                  <th className="py-2 pr-4">Amount</th>
                  <th className="py-2 pr-4">Currency</th>
                  <th className="py-2 pr-4">Reference</th>
                  <th className="py-2 pr-4">When</th>
                </tr>
              </thead>
              <tbody>
                {events.map((ev: any, i: number) => (
                  <tr key={ev.id ?? i} className="border-t border-line/60 text-ink/80">
                    <td className="py-2 pr-4">{ev.source_service ?? "-"}</td>
                    <td className="py-2 pr-4 text-gold">
                      {ev.amount != null ? Number(ev.amount).toLocaleString() : "-"}
                    </td>
                    <td className="py-2 pr-4">{ev.currency ?? "-"}</td>
                    <td className="py-2 pr-4 font-mono text-xs text-ink/50">
                      {ev.reference ?? "-"}
                    </td>
                    <td className="py-2 pr-4 text-ink/50">{ev.created_at ?? "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
