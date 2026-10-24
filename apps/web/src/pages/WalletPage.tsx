import React, { useEffect, useMemo, useState } from "react";
import { coinService, platformService } from "../services/api";
import { useAuth } from "../store/authStore";

export default function WalletPage() {
  const { user } = useAuth();
  const meId = user?.id ?? "";

  const [wallet, setWallet] = useState<any>(null);
  const [rate, setRate] = useState<any>(null);
  const [feeRate, setFeeRate] = useState<number>(0);
  const [txns, setTxns] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Convert panel state
  const [fiatAmount, setFiatAmount] = useState<string>("");
  const [direction, setDirection] = useState<"deposit" | "withdraw">("deposit");
  const [converting, setConverting] = useState(false);
  const [convertResult, setConvertResult] = useState<any>(null);

  // Transfer panel state
  const [toOwner, setToOwner] = useState("");
  const [transferAmount, setTransferAmount] = useState<string>("");
  const [transferRef, setTransferRef] = useState("");
  const [transferring, setTransferring] = useState(false);
  const [transferResult, setTransferResult] = useState<any>(null);

  const currency = rate?.currency ?? "EGP";
  const rateToMrc = Number(rate?.rate_to_mrc ?? 0);

  const fetchData = async () => {
    if (!meId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const [w, rt, fee, tx] = await Promise.all([
        coinService.getWallet(meId).catch(() => coinService.createWallet(meId)),
        coinService.getRate("EGP").catch(() => null),
        platformService.getFee().catch(() => null),
        coinService.transactions(meId, 50).catch(() => []),
      ]);
      setWallet(w);
      setRate(rt);
      setFeeRate(Number(fee?.fee_rate ?? 0));
      setTxns(tx);
      setError("");
    } catch (e) {
      console.error("Error loading wallet", e);
      setError("Wallet service unavailable.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [meId]);

  // Client-side preview of the brokerage fee on a conversion.
  const preview = useMemo(() => {
    const amt = parseFloat(fiatAmount);
    if (!amt || amt <= 0 || !rateToMrc) return null;
    const grossMrc = amt * rateToMrc;
    const feeMrc = grossMrc * feeRate;
    const netMrc = grossMrc - feeMrc;
    return { grossMrc, feeMrc, netMrc };
  }, [fiatAmount, rateToMrc, feeRate]);

  const handleConvert = async (e: React.FormEvent) => {
    e.preventDefault();
    const amt = parseFloat(fiatAmount);
    if (!amt || amt <= 0) return;
    setConverting(true);
    setConvertResult(null);
    try {
      const res = await coinService.convert({
        owner_id: meId,
        currency,
        fiat_amount: amt,
        direction,
      });
      setConvertResult(res);
      setFiatAmount("");
      await fetchData();
    } catch (err) {
      console.error("Convert failed", err);
      setError("Conversion failed.");
    } finally {
      setConverting(false);
    }
  };

  const handleTransfer = async (e: React.FormEvent) => {
    e.preventDefault();
    const amt = parseFloat(transferAmount);
    if (!toOwner || !amt || amt <= 0) return;
    setTransferring(true);
    setTransferResult(null);
    try {
      const res = await coinService.transfer({
        from_owner: meId,
        to_owner: toOwner,
        amount: amt,
        reference: transferRef || undefined,
      });
      setTransferResult(res);
      setToOwner("");
      setTransferAmount("");
      setTransferRef("");
      await fetchData();
    } catch (err) {
      console.error("Transfer failed", err);
      setError("Transfer failed.");
    } finally {
      setTransferring(false);
    }
  };

  if (loading) return <div className="p-8 text-muted">Loading wallet…</div>;

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-ink mb-1">MASAREEN Coin Wallet</h1>
      <p className="text-sm text-muted mb-6">
        The platform takes a {(feeRate * 100).toFixed(2)}% brokerage fee on every conversion and
        transfer.
      </p>
      {error && <p className="text-rose-600 text-sm mb-4">{error}</p>}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="glass-card">
          <p className="text-muted text-sm">Balance</p>
          <p className="text-3xl font-bold text-gold">
            {Number(wallet?.balance ?? 0).toLocaleString()}{" "}
            <span className="text-base text-ink/70">{wallet?.currency ?? "MRC"}</span>
          </p>
        </div>
        <div className="glass-card">
          <p className="text-muted text-sm">Exchange rate</p>
          <p className="text-2xl font-bold text-ink">
            1 {currency} = {rateToMrc || "-"} MRC
          </p>
          {rate?.updated_at && (
            <p className="text-xs text-ink/40 mt-1">Updated {rate.updated_at}</p>
          )}
        </div>
        <div className="glass-card">
          <p className="text-muted text-sm">Owner ID</p>
          <p className="text-sm font-mono text-ink break-all">{meId || "-"}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Convert panel */}
        <div className="glass-card">
          <h2 className="text-lg font-semibold text-ink mb-4">Convert {currency} ↔ MRC</h2>
          <form onSubmit={handleConvert} className="space-y-4">
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Amount ({currency})</label>
              <input
                type="number"
                min="0"
                step="any"
                className="glass-input"
                value={fiatAmount}
                onChange={(e) => setFiatAmount(e.target.value)}
                placeholder="e.g. 100"
              />
            </div>
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Direction</label>
              <select
                className="glass-input"
                value={direction}
                onChange={(e) => setDirection(e.target.value as "deposit" | "withdraw")}
              >
                <option value="deposit">Deposit (buy coins)</option>
                <option value="withdraw">Withdraw (cash out)</option>
              </select>
            </div>
            {preview && (
              <div className="glass rounded-xl p-3 text-sm space-y-1">
                <div className="flex justify-between text-ink/70">
                  <span>Gross</span>
                  <span>{preview.grossMrc.toFixed(2)} MRC</span>
                </div>
                <div className="flex justify-between text-amber-600">
                  <span>Platform brokerage fee ({(feeRate * 100).toFixed(2)}%)</span>
                  <span>-{preview.feeMrc.toFixed(2)} MRC</span>
                </div>
                <div className="flex justify-between font-semibold text-ink border-t border-line/60 pt-1">
                  <span>You receive (net)</span>
                  <span>{preview.netMrc.toFixed(2)} MRC</span>
                </div>
              </div>
            )}
            <button type="submit" className="btn-gold w-full" disabled={converting}>
              {converting ? "Converting…" : "Convert"}
            </button>
          </form>
          {convertResult && (
            <div className="glass rounded-xl p-3 mt-4 text-sm text-ink/80 space-y-1">
              <p className="text-emerald-600 font-semibold">Conversion complete</p>
              <p>Gross: {Number(convertResult.gross_mrc).toFixed(2)} MRC</p>
              <p className="text-amber-600">
                Fee taken by platform: {Number(convertResult.fee_mrc).toFixed(2)} MRC
              </p>
              <p>Net: {Number(convertResult.net_mrc).toFixed(2)} MRC</p>
              <p>New balance: {Number(convertResult.balance).toFixed(2)} MRC</p>
              <p className="text-xs text-ink/40 font-mono">Ref: {convertResult.reference}</p>
            </div>
          )}
        </div>

        {/* Transfer panel */}
        <div className="glass-card">
          <h2 className="text-lg font-semibold text-ink mb-4">Transfer MRC</h2>
          <form onSubmit={handleTransfer} className="space-y-4">
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Recipient owner ID</label>
              <input
                className="glass-input"
                value={toOwner}
                onChange={(e) => setToOwner(e.target.value)}
                placeholder="owner id"
              />
            </div>
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Amount (MRC)</label>
              <input
                type="number"
                min="0"
                step="any"
                className="glass-input"
                value={transferAmount}
                onChange={(e) => setTransferAmount(e.target.value)}
                placeholder="e.g. 50"
              />
            </div>
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Reference (optional)</label>
              <input
                className="glass-input"
                value={transferRef}
                onChange={(e) => setTransferRef(e.target.value)}
                placeholder="note"
              />
            </div>
            <p className="text-xs text-amber-600">
              A {(feeRate * 100).toFixed(2)}% platform brokerage fee applies to transfers.
            </p>
            <button type="submit" className="btn-gold w-full" disabled={transferring}>
              {transferring ? "Sending…" : "Send"}
            </button>
          </form>
          {transferResult && (
            <div className="glass rounded-xl p-3 mt-4 text-sm text-ink/80 space-y-1">
              <p className="text-emerald-600 font-semibold">Transfer complete</p>
              <p>Amount: {Number(transferResult.amount).toFixed(2)} MRC</p>
              <p className="text-amber-600">
                Fee taken by platform: {Number(transferResult.fee).toFixed(2)} MRC
              </p>
              <p>Net delivered: {Number(transferResult.net).toFixed(2)} MRC</p>
              <p>Your balance: {Number(transferResult.from_balance).toFixed(2)} MRC</p>
            </div>
          )}
        </div>
      </div>

      {/* Recent transactions */}
      <div className="glass-card mt-8">
        <h2 className="text-lg font-semibold text-ink mb-4">Recent transactions</h2>
        {txns.length === 0 ? (
          <p className="text-muted text-sm">No transactions yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-ink/50 text-left">
                  <th className="py-2 pr-4">Type</th>
                  <th className="py-2 pr-4">Delta</th>
                  <th className="py-2 pr-4">Balance</th>
                  <th className="py-2 pr-4">Reference</th>
                  <th className="py-2 pr-4">When</th>
                </tr>
              </thead>
              <tbody>
                {txns.map((tx: any, i: number) => (
                  <tr key={tx.id ?? i} className="border-t border-line/60 text-ink/80">
                    <td className="py-2 pr-4">{tx.type ?? "-"}</td>
                    <td
                      className={`py-2 pr-4 ${
                        Number(tx.delta) < 0 ? "text-rose-600" : "text-emerald-600"
                      }`}
                    >
                      {tx.delta != null ? Number(tx.delta).toFixed(2) : "-"}
                    </td>
                    <td className="py-2 pr-4">
                      {tx.balance != null ? Number(tx.balance).toFixed(2) : "-"}
                    </td>
                    <td className="py-2 pr-4 font-mono text-xs text-ink/50">
                      {tx.reference ?? "-"}
                    </td>
                    <td className="py-2 pr-4 text-ink/50">{tx.created_at ?? "-"}</td>
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
