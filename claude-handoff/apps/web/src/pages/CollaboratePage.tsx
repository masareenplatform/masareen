import { useState } from "react";
import { partnerService } from "../services/api";
import { useI18n } from "../i18n";

export default function CollaboratePage() {
  const { t } = useI18n();
  const [form, setForm] = useState({
    company_name: "",
    contact_email: "",
    website: "",
    service_name: "",
    service_description: "",
    desired_tier: "SANDBOX",
    expected_load: "",
  });
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState("");

  const set = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await partnerService.submit(form);
      setDone(true);
    } catch (err: any) {
      setError(err?.response?.data?.message ?? "Submission failed. Please try again.");
    } finally {
      setBusy(false);
    }
  };

  if (done) {
    return (
      <div className="glass-card mx-auto max-w-2xl text-center">
        <div className="text-4xl">✅</div>
        <h1 className="font-display text-2xl font-bold text-white">Request received</h1>
        <p className="mt-2 text-white/60">
          Our partnerships team will review your hosting request and follow up by email.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="font-display text-3xl font-bold text-white">Host your service on MASAREN</h1>
      <p className="mt-1 text-white/50">
        Startups and companies can run their impact services on our verified infrastructure.
      </p>

      <form onSubmit={submit} className="glass-card mt-6 grid gap-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="text-sm text-white/70">
            Company name
            <input className="glass-input mt-1" required value={form.company_name}
              onChange={(e) => set("company_name", e.target.value)} />
          </label>
          <label className="text-sm text-white/70">
            Contact email
            <input type="email" className="glass-input mt-1" required value={form.contact_email}
              onChange={(e) => set("contact_email", e.target.value)} />
          </label>
        </div>
        <label className="text-sm text-white/70">
          Website
          <input className="glass-input mt-1" value={form.website}
            onChange={(e) => set("website", e.target.value)} />
        </label>
        <label className="text-sm text-white/70">
          Service name
          <input className="glass-input mt-1" required value={form.service_name}
            onChange={(e) => set("service_name", e.target.value)} />
        </label>
        <label className="text-sm text-white/70">
          What does your service do?
          <textarea className="glass-input mt-1" required minLength={10} rows={4}
            value={form.service_description}
            onChange={(e) => set("service_description", e.target.value)} />
        </label>
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="text-sm text-white/70">
            Desired tier
            <select className="glass-input mt-1" value={form.desired_tier}
              onChange={(e) => set("desired_tier", e.target.value)}>
              <option>SANDBOX</option>
              <option>STANDARD</option>
              <option>DEDICATED</option>
            </select>
          </label>
          <label className="text-sm text-white/70">
            Expected load
            <input className="glass-input mt-1" placeholder="e.g. 1M req/mo"
              value={form.expected_load}
              onChange={(e) => set("expected_load", e.target.value)} />
          </label>
        </div>

        {error && <p className="text-sm text-rose-300">{error}</p>}
        <button className="btn-gold w-full" disabled={busy} type="submit">
          {busy ? "Submitting…" : "Submit hosting request"}
        </button>
      </form>
    </div>
  );
}
