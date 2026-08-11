import { useEffect, useState } from "react";
import { adminApi } from "../api";
import { useAuth } from "../auth";

type Collab = Record<string, any>;

const STATUS_COLORS: Record<string, string> = {
  SUBMITTED: "#C9A84C",
  APPROVED: "#16a34a",
  REJECTED: "#dc2626",
  PROVISIONED: "#0ea5e9",
};

export default function CollaborationsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<Collab[]>([]);
  const [filter, setFilter] = useState<string>("SUBMITTED");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState("");
  const [notes, setNotes] = useState<Record<string, string>>({});

  const load = async () => {
    setLoading(true);
    try {
      const data = await adminApi.listCollaborations(filter === "ALL" ? undefined : filter);
      setItems(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const review = async (id: string, verdict: "APPROVED" | "REJECTED") => {
    setBusy(id);
    try {
      await adminApi.reviewCollaboration(
        id,
        verdict,
        notes[id] || `Reviewed as ${verdict} via admin console`,
        user?.id || "admin"
      );
      setToast(`Collaboration ${id} → ${verdict}`);
      await load();
    } catch (e: any) {
      setToast(e?.response?.data?.message ?? "Failed to review");
    } finally {
      setBusy(null);
      setTimeout(() => setToast(""), 3000);
    }
  };

  const provision = async (id: string) => {
    setBusy(id);
    try {
      await adminApi.provisionCollaboration(id, user?.id || "admin");
      setToast(`Collaboration ${id} provisioned`);
      await load();
    } catch (e: any) {
      setToast(e?.response?.data?.message ?? "Failed to provision");
    } finally {
      setBusy(null);
      setTimeout(() => setToast(""), 3000);
    }
  };

  return (
    <div>
      <div className="card" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
        <h1 style={{ margin: 0, color: "var(--navy)" }}>Collaboration Hosting</h1>
        <select
          className="input"
          style={{ width: "auto" }}
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        >
          <option value="ALL">All</option>
          <option value="SUBMITTED">Pending review</option>
          <option value="APPROVED">Approved</option>
          <option value="REJECTED">Rejected</option>
          <option value="PROVISIONED">Provisioned</option>
        </select>
      </div>

      {toast && (
        <div className="card" style={{ background: "#ecfdf5", borderColor: "#6ee7b7", marginBottom: 16 }}>
          {toast}
        </div>
      )}

      {loading ? (
        <p>Loading collaborations…</p>
      ) : items.length === 0 ? (
        <div className="card">No collaboration requests in this state.</div>
      ) : (
        <div style={{ display: "grid", gap: 12 }}>
          {items.map((c) => (
            <div className="card" key={c.id}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                <div>
                  <strong>{c.company_name}</strong>
                  <div style={{ fontSize: 13, color: "#64748b" }}>{c.service_name} · {c.desired_tier}</div>
                  <div style={{ fontSize: 12, color: "#94a3b8" }}>{c.contact_email}</div>
                </div>
                <span
                  className="btn btn-ghost"
                  style={{ color: STATUS_COLORS[c.status] ?? "#475569", borderColor: STATUS_COLORS[c.status] }}
                >
                  {c.status}
                </span>
              </div>
              <p style={{ fontSize: 13, color: "#334155", marginTop: 8 }}>{c.service_description}</p>

              {c.status === "SUBMITTED" && (
                <>
                  <textarea
                    className="input"
                    style={{ marginTop: 10, minHeight: 48 }}
                    placeholder="Review notes (optional)"
                    value={notes[c.id] || ""}
                    onChange={(e) => setNotes((s) => ({ ...s, [c.id]: e.target.value }))}
                  />
                  <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                    <button className="btn btn-success" disabled={busy === c.id} onClick={() => review(c.id, "APPROVED")}>
                      Approve
                    </button>
                    <button className="btn btn-danger" disabled={busy === c.id} onClick={() => review(c.id, "REJECTED")}>
                      Reject
                    </button>
                  </div>
                </>
              )}

              {c.status === "APPROVED" && (
                <button className="btn btn-primary" style={{ marginTop: 10 }} disabled={busy === c.id} onClick={() => provision(c.id)}>
                  Mark as Provisioned
                </button>
              )}

              {c.status === "PROVISIONED" && c.endpoint && (
                <div style={{ fontSize: 12, color: "#0ea5e9", marginTop: 8 }}>Endpoint: {c.endpoint}</div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
