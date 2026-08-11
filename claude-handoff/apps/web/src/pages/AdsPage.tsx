import React, { useEffect, useMemo, useState } from "react";
import { adsService, platformService } from "../services/api";

export default function AdsPage() {
  const [campaigns, setCampaigns] = useState<any[]>([]);
  const [feeRate, setFeeRate] = useState<number>(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Create form state
  const [name, setName] = useState("");
  const [budget, setBudget] = useState<string>("");
  const [targeting, setTargeting] = useState<string>("");
  const [creating, setCreating] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [list, fee] = await Promise.all([
        adsService.list().catch(() => []),
        platformService.getFee().catch(() => null),
      ]);
      setCampaigns(list);
      setFeeRate(Number(fee?.fee_rate ?? 0));
      setError("");
    } catch (e) {
      console.error("Error loading ads", e);
      setError("Ads service unavailable.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const preview = useMemo(() => {
    const b = parseFloat(budget);
    if (!b || b <= 0) return null;
    const fee = b * feeRate;
    return { fee, deliverable: b - fee };
  }, [budget, feeRate]);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    const b = parseFloat(budget);
    if (!name || !b || b <= 0) return;
    let parsedTargeting: any = {};
    if (targeting.trim()) {
      try {
        parsedTargeting = JSON.parse(targeting);
      } catch {
        setError("Targeting must be valid JSON.");
        return;
      }
    }
    setCreating(true);
    try {
      await adsService.create({
        name,
        budget_coins: b,
        currency: "MRC",
        targeting: parsedTargeting,
      });
      setName("");
      setBudget("");
      setTargeting("");
      setError("");
      await fetchData();
    } catch (err) {
      console.error("Create campaign failed", err);
      setError("Failed to create campaign.");
    } finally {
      setCreating(false);
    }
  };

  const refreshStats = async (id: string) => {
    try {
      const stats = await adsService.stats(id);
      setCampaigns((prev) =>
        prev.map((c) => (c.id === id ? { ...c, ...stats } : c)),
      );
    } catch (err) {
      console.error("Stats refresh failed", err);
    }
  };

  const handleStatus = async (id: string, status: string) => {
    try {
      const updated = await adsService.setStatus(id, status);
      setCampaigns((prev) => prev.map((c) => (c.id === id ? { ...c, ...updated } : c)));
    } catch (err) {
      console.error("Status change failed", err);
      setError("Failed to update campaign status.");
    }
  };

  const handleImpression = async (id: string) => {
    try {
      await adsService.recordImpression(id);
      await refreshStats(id);
    } catch (err) {
      console.error("Impression failed", err);
    }
  };

  const handleClick = async (id: string) => {
    try {
      await adsService.recordClick(id);
      await refreshStats(id);
    } catch (err) {
      console.error("Click failed", err);
    }
  };

  const statusChipClass = (status: string) => {
    switch (status) {
      case "ACTIVE":
        return "bg-emerald-400/15 text-emerald-300";
      case "PAUSED":
        return "bg-amber-400/15 text-amber-300";
      case "COMPLETED":
        return "bg-white/10 text-white/60";
      default:
        return "bg-sky-400/15 text-sky-300";
    }
  };

  if (loading) return <div className="p-8 text-white/60">Loading ads…</div>;

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-white mb-1">Ads Manager</h1>
      <p className="text-sm text-white/60 mb-6">
        The platform deducts a {(feeRate * 100).toFixed(2)}% brokerage fee from every campaign
        budget.
      </p>
      {error && <p className="text-rose-300 text-sm mb-4">{error}</p>}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Create form */}
        <div className="glass-card lg:col-span-1 h-fit">
          <h2 className="text-lg font-semibold text-white mb-4">Create campaign</h2>
          <form onSubmit={handleCreate} className="space-y-4">
            <div>
              <label className="text-sm text-white/70 mb-1 block">Name</label>
              <input
                className="glass-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Campaign name"
              />
            </div>
            <div>
              <label className="text-sm text-white/70 mb-1 block">Budget (MRC)</label>
              <input
                type="number"
                min="0"
                step="any"
                className="glass-input"
                value={budget}
                onChange={(e) => setBudget(e.target.value)}
                placeholder="e.g. 1000"
              />
            </div>
            <div>
              <label className="text-sm text-white/70 mb-1 block">Targeting (JSON, optional)</label>
              <textarea
                className="glass-input font-mono text-xs"
                rows={3}
                value={targeting}
                onChange={(e) => setTargeting(e.target.value)}
                placeholder='{"country":"EG"}'
              />
            </div>
            {preview && (
              <div className="glass rounded-xl p-3 text-sm space-y-1">
                <div className="flex justify-between text-amber-300">
                  <span>Platform brokerage fee ({(feeRate * 100).toFixed(2)}%)</span>
                  <span>-{preview.fee.toFixed(2)} MRC</span>
                </div>
                <div className="flex justify-between font-semibold text-white border-t border-white/10 pt-1">
                  <span>Deliverable budget</span>
                  <span>{preview.deliverable.toFixed(2)} MRC</span>
                </div>
              </div>
            )}
            <button type="submit" className="btn-gold w-full" disabled={creating}>
              {creating ? "Creating…" : "Create campaign"}
            </button>
          </form>
        </div>

        {/* Campaign list */}
        <div className="lg:col-span-2 space-y-4">
          {campaigns.length === 0 ? (
            <div className="glass-card">
              <p className="text-white/60 text-sm">No campaigns yet.</p>
            </div>
          ) : (
            campaigns.map((c: any) => (
              <div key={c.id} className="glass-card">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <p className="text-lg font-semibold text-white">{c.name}</p>
                    <p className="text-xs text-white/40 font-mono">{c.id}</p>
                  </div>
                  <span className={`chip ${statusChipClass(c.status)}`}>{c.status}</span>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4 text-sm">
                  <div>
                    <p className="text-white/50">Deliverable budget</p>
                    <p className="text-white font-semibold">{c.budget_coins ?? 0} MRC</p>
                  </div>
                  <div>
                    <p className="text-white/50">Platform fee</p>
                    <p className="text-amber-300 font-semibold">
                      {c.platform_fee_coins ?? 0} MRC
                    </p>
                  </div>
                  <div>
                    <p className="text-white/50">Spent</p>
                    <p className="text-white font-semibold">{c.spent_coins ?? 0} MRC</p>
                  </div>
                  <div>
                    <p className="text-white/50">Impr. / Clicks</p>
                    <p className="text-white font-semibold">
                      {c.impressions ?? 0} / {c.clicks ?? 0}
                    </p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    className="btn-ghost text-xs"
                    onClick={() => handleStatus(c.id, "ACTIVE")}
                  >
                    Activate
                  </button>
                  <button
                    className="btn-ghost text-xs"
                    onClick={() => handleStatus(c.id, "PAUSED")}
                  >
                    Pause
                  </button>
                  <button className="btn-ghost text-xs" onClick={() => handleImpression(c.id)}>
                    Record impression
                  </button>
                  <button className="btn-ghost text-xs" onClick={() => handleClick(c.id)}>
                    Record click
                  </button>
                  <button className="btn-ghost text-xs" onClick={() => refreshStats(c.id)}>
                    Refresh stats
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
