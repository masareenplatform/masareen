import React, { useEffect, useState } from "react";
import { paymentService } from "../services/api";
import { useAuth } from "../store/authStore";

// No dedicated org context on the individual web session, so we default the
// payment history / intent org to the current user id. Swap for a real org id
// once organization context is wired into the web session.
const DEFAULT_ORG = "org-demo";

export default function PaymentsPage() {
  const { user } = useAuth();
  const orgId = (user as any)?.organization_id ?? user?.id ?? DEFAULT_ORG;

  const [psp, setPsp] = useState<any>(null);
  const [history, setHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Paymob form state
  const [amount, setAmount] = useState<string>("");
  const [phone, setPhone] = useState("");
  const [method, setMethod] = useState<"card" | "vodafone_cash">("card");
  const [submitting, setSubmitting] = useState(false);
  const [intent, setIntent] = useState<any>(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [status, hist] = await Promise.all([
        paymentService.pspStatus().catch(() => null),
        paymentService.history(orgId, 20).catch(() => []),
      ]);
      setPsp(status);
      setHistory(hist);
      setError("");
    } catch (e) {
      console.error("Error loading payments", e);
      setError("Payments service unavailable.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orgId]);

  const handleIntent = async (e: React.FormEvent) => {
    e.preventDefault();
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) return;
    setSubmitting(true);
    setIntent(null);
    try {
      const res = await paymentService.paymobIntent({
        org_id: orgId,
        amount_egp: amt,
        phone: phone || undefined,
        method,
      });
      setIntent(res);
      await fetchData();
    } catch (err) {
      console.error("Paymob intent failed", err);
      setError("Failed to create payment intent.");
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="p-8 text-muted">Loading payments…</div>;

  const stripe = psp?.providers?.stripe;
  const paymob = psp?.providers?.paymob;

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-ink mb-1">Payments</h1>
      <p className="text-sm text-muted mb-6">
        Org: <span className="font-mono text-ink/80">{orgId}</span>
      </p>
      {error && <p className="text-rose-600 text-sm mb-4">{error}</p>}

      {/* PSP status */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="glass-card">
          <div className="flex justify-between items-center">
            <p className="text-lg font-semibold text-ink">Stripe</p>
            <span
              className={`chip ${
                stripe?.enabled
                  ? "bg-emerald-400/15 text-emerald-600"
                  : "bg-rose-400/15 text-rose-600"
              }`}
            >
              {stripe?.enabled ? "Enabled" : "Disabled"}
            </span>
          </div>
        </div>
        <div className="glass-card">
          <div className="flex justify-between items-center mb-2">
            <p className="text-lg font-semibold text-ink">Paymob</p>
            <span
              className={`chip ${
                paymob?.enabled
                  ? "bg-emerald-400/15 text-emerald-600"
                  : "bg-rose-400/15 text-rose-600"
              }`}
            >
              {paymob?.enabled ? "Enabled" : "Disabled"}
            </span>
          </div>
          {paymob?.enabled && (
            <p className="text-sm text-muted">
              Currency: {paymob?.currency ?? "EGP"} · Methods:{" "}
              {(paymob?.methods ?? []).join(", ")}
            </p>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Paymob form */}
        <div className="glass-card">
          <h2 className="text-lg font-semibold text-ink mb-4">Pay with Paymob</h2>
          <form onSubmit={handleIntent} className="space-y-4">
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Amount (EGP)</label>
              <input
                type="number"
                min="0"
                step="any"
                className="glass-input"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="e.g. 250"
              />
            </div>
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Method</label>
              <select
                className="glass-input"
                value={method}
                onChange={(e) => setMethod(e.target.value as "card" | "vodafone_cash")}
              >
                <option value="card">Card</option>
                <option value="vodafone_cash">Vodafone Cash</option>
              </select>
            </div>
            <div>
              <label className="text-sm text-ink/70 mb-1 block">Phone (optional)</label>
              <input
                className="glass-input"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="01xxxxxxxxx"
              />
            </div>
            <button type="submit" className="btn-gold w-full" disabled={submitting}>
              {submitting ? "Creating…" : "Create payment"}
            </button>
          </form>
          {intent && (
            <div className="glass rounded-xl p-3 mt-4 text-sm text-ink/80 space-y-1">
              <p className="text-emerald-600 font-semibold">Payment intent created</p>
              <p>Provider: {intent?.psp?.provider ?? "paymob"}</p>
              <p>Method: {intent?.psp?.method ?? method}</p>
              {intent?.psp?.order_id && (
                <p className="font-mono text-xs">Order: {intent.psp.order_id}</p>
              )}
              {intent?.psp?.payment_key && (
                <p className="font-mono text-xs break-all">
                  Payment key: {intent.psp.payment_key}
                </p>
              )}
              {intent?.psp?.redirect_url && (
                <a
                  href={intent.psp.redirect_url}
                  target="_blank"
                  rel="noreferrer"
                  className="btn-gold w-full mt-2"
                >
                  Continue to payment
                </a>
              )}
            </div>
          )}
        </div>

        {/* Payment history */}
        <div className="glass-card">
          <h2 className="text-lg font-semibold text-ink mb-4">Payment history</h2>
          {history.length === 0 ? (
            <p className="text-muted text-sm">No payments yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-ink/50 text-left">
                    <th className="py-2 pr-4">Amount</th>
                    <th className="py-2 pr-4">Status</th>
                    <th className="py-2 pr-4">Method</th>
                    <th className="py-2 pr-4">When</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((p: any, i: number) => (
                    <tr key={p.id ?? i} className="border-t border-line/60 text-ink/80">
                      <td className="py-2 pr-4">
                        {p.amount ?? p.amount_egp ?? "—"} {p.currency ?? "EGP"}
                      </td>
                      <td className="py-2 pr-4">{p.status ?? "—"}</td>
                      <td className="py-2 pr-4">{p.method ?? p?.psp?.method ?? "—"}</td>
                      <td className="py-2 pr-4 text-ink/50">{p.created_at ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
