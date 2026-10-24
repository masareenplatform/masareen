import axios, { AxiosResponse } from "axios";

// MASAREEN web app → API Gateway (single BFF entry point).
//
// In production the app is served by nginx which proxies `/api/` to the gateway
// container; in dev, vite proxies `/api` to http://localhost:8080 (see
// vite.config.ts). Every microservice is mounted under `/api/v1/...` behind the
// gateway. Responses use the shared `{ success, data }` envelope, which the
// interceptor below unwraps so callers work with the payload directly.
const API_BASE = (import.meta as any).env?.VITE_API_BASE ?? "/api/v1";

export const apiClient = axios.create({
  baseURL: API_BASE,
  headers: { "Content-Type": "application/json" },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Unwrap the shared ApiResponse envelope: `{ success, data }` -> `data`.
// Also transparently refreshes an expired access token on a single 401 and
// retries the original request, so a valid session never gets logged out
// just because the access token (short-lived) expired mid-use. If the
// refresh itself fails (refresh token missing/expired/revoked), the tokens
// are cleared and a "masaren:session-expired" event is dispatched so the UI
// (see store/authStore.tsx) can redirect to /login exactly once, even if
// several requests 401'd concurrently.
let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refresh_token = localStorage.getItem("refresh_token");
  if (!refresh_token) return null;
  try {
    // Bypass apiClient (and its interceptors) to avoid recursive refresh loops.
    const r = await axios.post(`${API_BASE}/auth/refresh`, { refresh_token });
    const body = r.data?.data ?? r.data;
    const newAccess: string | undefined = body?.access_token;
    const newRefresh: string | undefined = body?.refresh_token;
    if (!newAccess) return null;
    localStorage.setItem("access_token", newAccess);
    if (newRefresh) localStorage.setItem("refresh_token", newRefresh);
    return newAccess;
  } catch {
    return null;
  }
}

function clearSessionAndNotify() {
  localStorage.removeItem("access_token");
  localStorage.removeItem("refresh_token");
  localStorage.removeItem("user");
  window.dispatchEvent(new CustomEvent("masaren:session-expired"));
}

apiClient.interceptors.response.use(
  (res: AxiosResponse) => {
    const b = res.data;
    if (b && typeof b === "object" && "success" in b && "data" in b) {
      res.data = (b as any).data;
    }
    return res;
  },
  async (err) => {
    const status = err?.response?.status;
    const original = err?.config;
    const isAuthRoute =
      typeof original?.url === "string" &&
      (original.url.includes("/auth/login") ||
        original.url.includes("/auth/refresh") ||
        original.url.includes("/auth/logout"));

    if (status === 401 && original && !original._retried && !isAuthRoute) {
      original._retried = true;
      // Coalesce concurrent 401s into a single refresh call.
      refreshPromise = refreshPromise ?? refreshAccessToken();
      const newToken = await refreshPromise;
      refreshPromise = null;
      if (newToken) {
        original.headers = { ...original.headers, Authorization: `Bearer ${newToken}` };
        return apiClient(original);
      }
      clearSessionAndNotify();
    }
    return Promise.reject(err);
  },
);

/** Normalize a paginated `{ items, total }` payload or a bare array to an array. */
function asList<T = any>(payload: any): T[] {
  if (Array.isArray(payload)) return payload;
  if (payload && Array.isArray(payload.items)) return payload.items;
  return [];
}

// ── Auth ───────────────────────────────────────────────────────────────────────
export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user_id: string;
  role: string;
}

export const authService = {
  async login(email: string, password: string): Promise<TokenResponse> {
    const r = await apiClient.post("/auth/login", { email, password });
    return (r.data as any)?.data ?? r.data;
  },
  async register(data: any) {
    const r = await apiClient.post("/users/register", data);
    return r.data;
  },
  async refresh(refresh_token: string) {
    const r = await apiClient.post("/auth/refresh", { refresh_token });
    return r.data;
  },
  async logout(refresh_token: string) {
    const r = await apiClient.post("/auth/logout", { refresh_token });
    return r.data;
  },
  async google(id_token: string, audience = "PROFESSIONAL") {
    const r = await apiClient.post("/auth/google", { id_token, audience });
    return r.data;
  },
};

// ── Users / profile / passport ───────────────────────────────────────────────────
export const userService = {
  async me() {
    const r = await apiClient.get("/users/me");
    return r.data;
  },
  async getById(id: string) {
    const r = await apiClient.get(`/users/${id}`);
    return r.data;
  },
  async passport(id: string) {
    const r = await apiClient.get(`/users/${id}/impact-passport`);
    return r.data;
  },
  async pms(id: string) {
    const r = await apiClient.get(`/pms/${id}`);
    return r.data;
  },
  async updateProfile(data: any) {
    const r = await apiClient.patch("/users/me/profile", data);
    return r.data;
  },
  async follow(userId: string) {
    const r = await apiClient.post(`/users/${userId}/follow`, {});
    return r.data;
  },
  async isFollowing(userId: string) {
    const r = await apiClient.get(`/users/${userId}/is-following`);
    return r.data;
  },
  async suggestedUsers(limit = 6) {
    const r = await apiClient.get("/users/suggested", { params: { limit } });
    return asList(r.data);
  },
  async list(params?: { limit?: number; offset?: number; role?: string }) {
    const r = await apiClient.get("/users/", { params });
    return asList(r.data);
  },
};

// ── Programs ─────────────────────────────────────────────────────────────────────
export const programService = {
  async list(params?: any) {
    const r = await apiClient.get("/programs/", { params });
    return asList(r.data);
  },
  async getById(id: string) {
    const r = await apiClient.get(`/programs/${id}`);
    return r.data;
  },
  async create(data: any) {
    const r = await apiClient.post("/programs/", data);
    return r.data;
  },
  async enroll(id: string, user_id: string) {
    const r = await apiClient.post(`/programs/${id}/enroll`, null, { params: { user_id } });
    return r.data;
  },
};

// ── Tasks (per-assignee / per-program in the microservice model) ──────────────────
export const taskService = {
  async listForUser(assignee_id: string, params?: any) {
    const r = await apiClient.get("/tasks/", { params: { assignee_id, ...(params || {}) } });
    return asList(r.data);
  },
  async listForProgram(program_id: string, params?: any) {
    const r = await apiClient.get("/tasks/", { params: { program_id, ...(params || {}) } });
    return asList(r.data);
  },
  async getById(id: string) {
    const r = await apiClient.get(`/tasks/${id}`);
    return r.data;
  },
  async create(data: any) {
    const r = await apiClient.post("/tasks/", data);
    return r.data;
  },
  async assign(id: string, data: any) {
    const r = await apiClient.post(`/tasks/${id}/assign`, data);
    return r.data;
  },
  async start(id: string, started_by: string) {
    const r = await apiClient.post(`/tasks/${id}/start`, null, { params: { started_by } });
    return r.data;
  },
  async submit(id: string, data: any, submitted_by: string) {
    const r = await apiClient.post(`/tasks/${id}/submit`, data, { params: { submitted_by } });
    return r.data;
  },
  async complete(id: string, completed_by: string) {
    const r = await apiClient.post(`/tasks/${id}/complete`, null, { params: { completed_by } });
    return r.data;
  },
  async history(id: string) {
    const r = await apiClient.get(`/tasks/${id}/history`);
    return asList(r.data);
  },
};

// ── Opportunities ────────────────────────────────────────────────────────────────
export const opportunityService = {
  async list(params?: any) {
    const r = await apiClient.get("/opportunities/", { params });
    return asList(r.data);
  },
  async getById(id: string) {
    const r = await apiClient.get(`/opportunities/${id}`);
    return r.data;
  },
  async apply(id: string, user_id: string) {
    const r = await apiClient.post(`/opportunities/${id}/apply`, null, { params: { user_id } });
    return r.data;
  },
  async platformContent(audience = "ALL") {
    const r = await apiClient.get("/opportunities/platform-content", { params: { audience } });
    return asList(r.data);
  },
};

// ── Evidence (per-task in the microservice model) ────────────────────────────────
export const evidenceService = {
  async listForTask(task_id: string) {
    const r = await apiClient.get(`/evidence/task/${task_id}`);
    return asList(r.data);
  },
  async getById(id: string) {
    const r = await apiClient.get(`/evidence/${id}`);
    return r.data;
  },
  async capture(data: any) {
    const r = await apiClient.post("/evidence/", data);
    return r.data;
  },
};

// ── Portfolio / reputation ───────────────────────────────────────────────────────
export const portfolioService = {
  async forUser(user_id: string) {
    const r = await apiClient.get(`/portfolio/${user_id}`);
    return r.data;
  },
};

// ── Media Personnel professional profile ───────────────────────────────────────
export const personnelService = {
  async get(userId: string) {
    const r = await apiClient.get(`/personnel/${userId}`);
    return r.data;
  },
  async reports(userId: string, params?: { limit?: number }) {
    const r = await apiClient.get(`/personnel/${userId}/reports`, { params });
    return asList(r.data);
  },
  async analytics(userId: string, params?: { period?: string }) {
    const r = await apiClient.get(`/personnel/${userId}/analytics`, { params });
    return r.data;
  },
  async timeline(userId: string) {
    const r = await apiClient.get(`/personnel/${userId}/timeline`);
    return asList(r.data);
  },
  async achievements(userId: string) {
    const r = await apiClient.get(`/personnel/${userId}/achievements`);
    return asList(r.data);
  },
  async organizations(userId: string) {
    const r = await apiClient.get(`/personnel/${userId}/organizations`);
    return asList(r.data);
  },
  async recommendations(userId: string) {
    const r = await apiClient.get(`/personnel/${userId}/recommendations`);
    return asList(r.data);
  },
  async follow(userId: string) {
    const r = await apiClient.post(`/personnel/${userId}/follow`);
    return r.data;
  },
  async endorse(userId: string, skill: string) {
    const r = await apiClient.post(`/personnel/${userId}/endorse`, { skill });
    return r.data;
  },
};

// ── BFF aggregation (gateway-composed) ───────────────────────────────────────────
export const bffService = {
  async dashboard() {
    const r = await apiClient.get("/bff/dashboard");
    return r.data;
  },
  async leaderboard(limit = 20) {
    const r = await apiClient.get("/bff/leaderboard", { params: { limit } });
    return asList(r.data);
  },
};

// ── Analytics ────────────────────────────────────────────────────────────────────
export const analyticsService = {
  async platformSummary() {
    const r = await apiClient.get("/analytics/platform/summary");
    return r.data;
  },
  async sdgProgress(country?: string) {
    const r = await apiClient.get("/analytics/sdg/progress", { params: country ? { country } : {} });
    return r.data;
  },
  async userStats(user_id: string) {
    const r = await apiClient.get(`/analytics/users/${user_id}/stats`);
    return r.data;
  },
};

// ── Notifications ────────────────────────────────────────────────────────────────
export const notificationService = {
  async list(user_id: string, params?: any) {
    const r = await apiClient.get(`/notifications/${user_id}`, { params });
    return asList(r.data);
  },
  async markRead(user_id: string, notification_id: string) {
    const r = await apiClient.patch(`/notifications/${user_id}/${notification_id}/read`);
    return r.data;
  },
};

// ── Subscription (billing plans / org subscription) ───────────────────────────────
export const subscriptionService = {
  async plans() {
    const r = await apiClient.get("/subscriptions/plans");
    return r.data;
  },
  async getForOrg(org_id: string) {
    const r = await apiClient.get(`/subscriptions/${org_id}`);
    return r.data;
  },
  async subscribe(org_id: string, plan_id: string) {
    const r = await apiClient.post(`/subscriptions/${org_id}/upgrade`, { plan_id });
    return r.data;
  },
};

// ── Reports / billing ────────────────────────────────────────────────────────────
export const reportService = {
  async list(params?: any) {
    const r = await apiClient.get("/reports/", { params });
    return asList(r.data);
  },
  async purchase(id: string) {
    const r = await apiClient.post(`/reports/${id}/purchase`);
    return r.data;
  },
};

export const billingService = {
  async invoices(org_id: string) {
    const r = await apiClient.get(`/billing/invoices/${org_id}`);
    return asList(r.data);
  },
  async paymentHistory(org_id: string) {
    const r = await apiClient.get(`/payments/${org_id}/history`);
    return asList(r.data);
  },
  async pspStatus() {
    const r = await apiClient.get("/payments/psp/status");
    return r.data;
  },
};

// ── MASAREEN Coin (in-app wallet + exchange) ──────────────────────────────────────
export const coinService = {
  async getWallet(owner_id: string): Promise<any> {
    const r = await apiClient.get(`/coin/wallets/${owner_id}`);
    return r.data;
  },
  async createWallet(owner_id?: string): Promise<any> {
    const r = await apiClient.post("/coin/wallets", owner_id ? { owner_id } : {});
    return r.data;
  },
  async transfer(payload: {
    from_owner: string;
    to_owner: string;
    amount: number;
    reference?: string;
  }): Promise<any> {
    const r = await apiClient.post("/coin/transactions/transfer", payload);
    return r.data;
  },
  async earn(payload: { owner_id: string; amount: number; reference?: string }): Promise<any> {
    const r = await apiClient.post("/coin/transactions/earn", payload);
    return r.data;
  },
  async spend(payload: { owner_id: string; amount: number; reference?: string }): Promise<any> {
    const r = await apiClient.post("/coin/transactions/spend", payload);
    return r.data;
  },
  async transactions(owner_id: string, limit = 50): Promise<any[]> {
    const r = await apiClient.get(`/coin/transactions/${owner_id}`, { params: { limit } });
    return asList(r.data);
  },
  async getRate(currency = "EGP"): Promise<any> {
    const r = await apiClient.get("/coin/exchange/rate", { params: { currency } });
    return r.data;
  },
  async setRate(payload: { currency: string; rate_to_mrc: number }): Promise<any> {
    const r = await apiClient.post("/coin/exchange/rate", payload);
    return r.data;
  },
  async convert(payload: {
    owner_id: string;
    currency: string;
    fiat_amount: number;
    direction: "deposit" | "withdraw";
  }): Promise<any> {
    const r = await apiClient.post("/coin/exchange/convert", payload);
    return r.data;
  },
};

// ── Ads manager ──────────────────────────────────────────────────────────────────
export const adsService = {
  async create(payload: {
    name: string;
    budget_coins: number;
    currency: string;
    targeting: any;
    start_date?: string;
    end_date?: string;
  }): Promise<any> {
    const r = await apiClient.post("/ads/campaigns", payload);
    return r.data;
  },
  async list(status?: string): Promise<any[]> {
    const r = await apiClient.get("/ads/campaigns", { params: status ? { status } : {} });
    return asList(r.data);
  },
  async getById(id: string): Promise<any> {
    const r = await apiClient.get(`/ads/campaigns/${id}`);
    return r.data;
  },
  async setStatus(id: string, status: string): Promise<any> {
    const r = await apiClient.patch(`/ads/campaigns/${id}/status`, { status });
    return r.data;
  },
  async addCreative(
    id: string,
    payload: { title: string; body: string; media_url?: string; cta_url?: string },
  ): Promise<any> {
    const r = await apiClient.post(`/ads/campaigns/${id}/creatives`, payload);
    return r.data;
  },
  async recordImpression(id: string): Promise<any> {
    const r = await apiClient.post(`/ads/campaigns/${id}/impression`);
    return r.data;
  },
  async recordClick(id: string): Promise<any> {
    const r = await apiClient.post(`/ads/campaigns/${id}/click`);
    return r.data;
  },
  async stats(id: string): Promise<any> {
    const r = await apiClient.get(`/ads/campaigns/${id}/stats`);
    return r.data;
  },
};

// ── Payments (PSP / Paymob) ──────────────────────────────────────────────────────
export const paymentService = {
  async history(org_id: string, limit = 20): Promise<any[]> {
    const r = await apiClient.get(`/payments/${org_id}/history`, { params: { limit } });
    return asList(r.data);
  },
  async pspStatus(): Promise<any> {
    const r = await apiClient.get("/payments/psp/status");
    return r.data;
  },
  async paymobIntent(payload: {
    org_id: string;
    amount_egp: number;
    phone?: string;
    invoice_id?: string;
    method?: string;
  }): Promise<any> {
    const r = await apiClient.post("/payments/psp/paymob/intent", payload);
    return r.data;
  },
};

// ── Platform (brokerage fee + revenue / profit) ──────────────────────────────────
export const platformService = {
  async getFee(): Promise<any> {
    const r = await apiClient.get("/platform/config/fee");
    return r.data;
  },
  async setFee(rate: number): Promise<any> {
    const r = await apiClient.post("/platform/config/fee", { rate });
    return r.data;
  },
  async revenueSummary(): Promise<any> {
    const r = await apiClient.get("/platform/revenue/summary");
    return r.data;
  },
  async revenueEvents(limit = 50): Promise<any[]> {
    const r = await apiClient.get("/platform/revenue/events", { params: { limit } });
    return asList(r.data);
  },
};

// ── Admin (HITL verification review) ─────────────────────────────────────────────
export const adminService = {
  async pendingReviews(params?: { limit?: number; offset?: number }) {
    const r = await apiClient.get("/audit/review/pending", { params });
    return asList(r.data);
  },
  async resolveReview(review_id: string, verdict: string, comments: string, admin_id: string) {
    const r = await apiClient.patch(`/audit/review/${review_id}/resolve`, {
      verdict,
      comments,
      admin_id,
    });
    return r.data;
  },
  async auditTrail(aggregate_id: string) {
    const r = await apiClient.get(`/audit/aggregate/${aggregate_id}`);
    return asList(r.data);
  },
  async upstreamHealth() {
    // Gateway health aggregation lives at the root, not under /api/v1.
    const r = await axios.get("/health/upstream", { baseURL: "" });
    return r.data;
  },
};

// ── Chat (real chat-service via gateway) ─────────────────────────────────────────
export const chatService = {
  listConversations: async (userId: string) => {
    const r = await apiClient.get(`/chat/conversations`, { params: { user_id: userId } });
    return r.data;
  },
  createConversation: async (userId: string, title = "New conversation") => {
    const r = await apiClient.post("/chat/conversations", { user_id: userId, title });
    return r.data;
  },
  getMessages: async (conversationId: string) => {
    const r = await apiClient.get(`/chat/conversations/${conversationId}/messages`);
    return r.data;
  },
  sendMessage: async (
    conversationId: string,
    userId: string,
    content: string,
    contextType?: string,
    contextId?: string,
  ) => {
    const r = await apiClient.post(`/chat/conversations/${conversationId}/messages`, {
      user_id: userId,
      content,
      context_type: contextType ?? null,
      context_id: contextId ?? null,
    });
    return r.data;
  },
};

// ── Partner / collaboration hosting (companies & startups) ───────────────────────
export const partnerService = {
  async submit(payload: {
    company_name: string;
    contact_email: string;
    website?: string;
    service_name: string;
    service_description: string;
    desired_tier?: string;
    expected_load?: string;
    message?: string;
  }) {
    const r = await apiClient.post("/partners", payload);
    return r.data;
  },
  async list(status?: string) {
    const r = await apiClient.get("/partners", { params: status ? { status } : {} });
    return asList(r.data);
  },
};

// ── Challenges (impact engagement loop) ─────────────────────────────────────────
export interface Challenge {
  id: string;
  title: string;
  description: string;
  sdg: number;
  progress: number;
  participants: number;
  rewardMrc: number;
  joined: boolean;
  endsInDays: number;
}

const MOCK_CHALLENGES: Challenge[] = [
  { id: "c1", title: "Plant 1,000 Trees", description: "Coordinate a neighbourhood planting drive and log verified evidence.", sdg: 15, progress: 0.62, participants: 4182, rewardMrc: 5000, joined: true, endsInDays: 9 },
  { id: "c2", title: "Clean a Coastline", description: "Remove 5 tonnes of plastic from a local beach with photo proof.", sdg: 14, progress: 0.34, participants: 2210, rewardMrc: 8000, joined: false, endsInDays: 14 },
  { id: "c3", title: "Solar for a School", description: "Fund and install off-grid solar for one community school.", sdg: 7, progress: 0.81, participants: 990, rewardMrc: 12000, joined: false, endsInDays: 5 },
  { id: "c4", title: "Zero Hunger Pantry", description: "Stock a verified food pantry and track distributions.", sdg: 2, progress: 0.47, participants: 3320, rewardMrc: 6000, joined: true, endsInDays: 21 },
];

export const challengeService = {
  async list(): Promise<Challenge[]> {
    try {
      const r = await apiClient.get("/challenges/");
      return asList(r.data);
    } catch {
      // Backend /challenges service not deployed yet, fall back to demo data.
      return MOCK_CHALLENGES;
    }
  },
  async join(_id: string): Promise<{ ok: boolean }> {
    try {
      return (await apiClient.post(`/challenges/${_id}/join`)).data;
    } catch {
      return { ok: true };
    }
  },
};
