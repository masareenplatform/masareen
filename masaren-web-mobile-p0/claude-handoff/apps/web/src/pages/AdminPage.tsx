import { useEffect, useState } from "react";
import { adminService } from "../services/api";
import { useAuth } from "../store/authStore";

interface PendingReview {
  id: string;
  entity_id: string;
  entity_type: string;
  confidence_score: number;
  status: string;
}

export default function AdminPage() {
  const { user } = useAuth();
  const [pending, setPending] = useState<PendingReview[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const fetchPending = async () => {
    setLoading(true);
    try {
      const rows = await adminService.pendingReviews({ limit: 50 });
      setPending(rows);
      setError("");
    } catch {
      setError("Review queue unavailable (audit-service unreachable).");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const handleVerdict = async (reviewId: string, verdict: "APPROVED" | "REJECTED") => {
    try {
      await adminService.resolveReview(reviewId, verdict, `${verdict} via Web Admin`, user?.id ?? "admin");
      await fetchPending();
    } catch {
      setError("Failed to submit verdict.");
    }
  };

  if (loading) return <div style={{ padding: 32, color: "#6B7280" }}>Loading review queue…</div>;

  return (
    <div>
      <h2 style={{ margin: "0 0 24px", color: "#0F2044", fontSize: 22 }}>HITL Verification Queue</h2>
      {error && <p style={{ color: "#DC2626", fontSize: 13 }}>{error}</p>}
      {pending.length === 0 ? (
        <p style={{ color: "#6B7280" }}>No pending reviews.</p>
      ) : (
        <div style={{ display: "grid", gap: 12 }}>
          {pending.map((r) => (
            <div key={r.id} style={{ padding: 16, background: "#fff", borderRadius: 10, display: "flex", justifyContent: "space-between", alignItems: "center", boxShadow: "0 1px 4px rgba(0,0,0,.06)" }}>
              <div>
                <p style={{ margin: 0, fontWeight: 600, color: "#0F2044", fontFamily: "monospace" }}>{r.entity_type}: {r.entity_id}</p>
                <p style={{ margin: "4px 0 0", fontSize: 12, color: "#6B7280" }}>
                  Confidence {(r.confidence_score * 100).toFixed(0)}% · {r.status}
                </p>
              </div>
              <div style={{ display: "flex", gap: 8 }}>
                <button onClick={() => handleVerdict(r.id, "APPROVED")} style={{ padding: "8px 16px", background: "#059669", color: "#fff", border: "none", borderRadius: 8, cursor: "pointer", fontWeight: 600 }}>Approve</button>
                <button onClick={() => handleVerdict(r.id, "REJECTED")} style={{ padding: "8px 16px", background: "#DC2626", color: "#fff", border: "none", borderRadius: 8, cursor: "pointer", fontWeight: 600 }}>Reject</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
