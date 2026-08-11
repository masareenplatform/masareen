import axios from "axios";

const BASE = import.meta.env.VITE_API_BASE_URL || "/api/v1";

const client = axios.create({
  baseURL: BASE,
  headers: { "Content-Type": "application/json" },
});

// Unwrap the gateway envelope { success, data, message }.
client.interceptors.response.use((res) => {
  const body = res.data;
  if (body && typeof body === "object" && "data" in body) {
    res.data = body.data;
  }
  return res;
});

client.interceptors.request.use((cfg) => {
  const token = localStorage.getItem("admin_token");
  if (token) cfg.headers = cfg.headers ?? {};
  if (token) (cfg.headers as any)["Authorization"] = `Bearer ${token}`;
  return cfg;
});

export const adminApi = {
  async login(email: string, password: string) {
    const r = await client.post("/auth/login", { email, password });
    const data = r.data;
    return data; // tokens envelope already unwrapped to inner payload
  },
  async pendingReviews(limit = 50) {
    const r = await client.get("/audit/review/pending", { params: { limit } });
    return (r.data ?? []) as any[];
  },
  async resolveReview(reviewId: string, verdict: string, comments: string, adminId: string) {
    const r = await client.patch(`/audit/review/${reviewId}/resolve`, {
      verdict,
      comments,
      admin_id: adminId,
    });
    return r.data;
  },
  async dashboard() {
    const r = await client.get("/bff/dashboard");
    return (r.data ?? {}) as Record<string, any>;
  },
  async listCollaborations(status?: string) {
    const r = await client.get("/partners", { params: status ? { status } : {} });
    return (r.data ?? []) as any[];
  },
  async reviewCollaboration(id: string, verdict: string, notes: string, reviewerId: string) {
    const r = await client.patch(`/partners/${id}/review`, { verdict, notes, reviewer_id: reviewerId });
    return r.data;
  },
  async provisionCollaboration(id: string, provisionedBy: string, endpoint?: string) {
    const r = await client.patch(`/partners/${id}/provision`, { provisioned_by: provisionedBy, endpoint });
    return r.data;
  },
};

export default client;
