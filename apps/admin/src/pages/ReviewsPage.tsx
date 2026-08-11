import { useEffect, useState } from "react";
import { adminApi } from "../api";
import { useAuth } from "../auth";

interface Review {
  review_id: string;
  evidence_id?: string;
  status: string;
  submitted_by?: string;
  created_at?: string;
  [key: string]: any;
}

export default function ReviewsPage() {
  const { user } = useAuth();
  const [reviews, setReviews] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true);
  const [comment, setComment] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const data = await adminApi.pendingReviews();
      setReviews(data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const resolve = async (review: Review, verdict: "APPROVED" | "REJECTED") => {
    setBusy(review.review_id);
    try {
      await adminApi.resolveReview(
        review.review_id,
        verdict,
        comment[review.review_id] || `Reviewed as ${verdict} via admin console`,
        user?.id || "admin"
      );
      setToast(`Review ${review.review_id} → ${verdict}`);
      await load();
    } catch (e: any) {
      setToast(e?.response?.data?.message ?? "Failed to resolve");
    } finally {
      setBusy(null);
      setTimeout(() => setToast(""), 3000);
    }
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h1 style={{ color: "var(--navy)" }}>Verification Queue (HITL)</h1>
        <button className="btn btn-ghost" onClick={load}>Refresh</button>
      </div>

      {toast && (
        <div className="card" style={{ background: "#ecfdf5", borderColor: "#6ee7b7", marginBottom: 16 }}>
          {toast}
        </div>
      )}

      {loading ? (
        <p>Loading pending reviews…</p>
      ) : reviews.length === 0 ? (
        <div className="card">No items awaiting human review. 🎉</div>
      ) : (
        <div style={{ display: "grid", gap: 12 }}>
          {reviews.map((r) => (
            <div className="card" key={r.review_id}>
              <div style={{ display: "flex", justifyContent: "space-between" }}>
                <div>
                  <strong>Review {r.review_id}</strong>
                  {r.evidence_id && <div style={{ fontSize: 13, color: "#64748b" }}>Evidence: {r.evidence_id}</div>}
                  <div style={{ fontSize: 12, color: "#94a3b8" }}>
                    {r.status} · submitted by {r.submitted_by ?? "—"} · {r.created_at ?? ""}
                  </div>
                </div>
                <span className="btn btn-ghost" style={{ height: 28 }}>{r.status}</span>
              </div>
              <textarea
                className="input"
                style={{ marginTop: 12, minHeight: 56 }}
                placeholder="Reviewer comment (optional)"
                value={comment[r.review_id] || ""}
                onChange={(e) => setComment((c) => ({ ...c, [r.review_id]: e.target.value }))}
              />
              <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                <button
                  className="btn btn-success"
                  disabled={busy === r.review_id}
                  onClick={() => resolve(r, "APPROVED")}
                >
                  Approve
                </button>
                <button
                  className="btn btn-danger"
                  disabled={busy === r.review_id}
                  onClick={() => resolve(r, "REJECTED")}
                >
                  Reject
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
