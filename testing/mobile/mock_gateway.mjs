// MASAREN Mobile, lightweight stateful mock gateway for end-to-end testing.
// Implements the contract the Flutter app expects (apps/mobile/lib/services/api_service.dart).
// Every request is logged. Responses are wrapped in { success: true, data } because
// the mobile ApiService interceptor unwraps `data`.
//
// Run:  node mock_gateway.mjs
// Then: adb -s <device> reverse tcp:8080 tcp:8080
//        rebuild app with --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1

import http from "node:http";

const PORT = 8080;
const uid = (p) => `${p}_${(Math.random() * 1e6) | 0}`;

const USER = {
  id: "u_admin", full_name: "Admin User", name: "Admin User", role: "ADMIN",
  email: "admin@masaren.org", status: "ACTIVE", pms_score: 812,
  email_verified: true, avatar_url: null,
};

const state = {
  programs: [
    { id: "pr1", title: "Reforest the Nile", sdg_goals: [15], enrolled_count: 42, status: "ACTIVE", organization: "EcoOrg", location: "Cairo" },
  ],
  tasks: [
    { id: "tk1", title: "Plant 50 seedlings", program_id: "pr1", assignee_id: "u_admin", status: "OPEN", evidence_ids: [], due_date: "2026-08-01" },
    { id: "tk2", title: "Mentor session", program_id: "pr1", assignee_id: "u_admin", status: "IN_PROGRESS", evidence_ids: [1], due_date: "2026-08-10" },
  ],
  opportunities: [
    { id: "op1", title: "Coastal Cleanup Grant", opp_type: "FUNDING", min_pms_score: 200, status: "OPEN", required_skills: ["Logistics"], reward: "5000 MRC", deadline: "2026-09-01" },
  ],
  campaigns: [
    { id: "c1", owner_id: "u_admin", name: "Climate Launch", status: "ACTIVE", budget_coins: 90, spent_coins: 12, currency: "MRC", platform_fee_coins: 10, impressions: 4, clicks: 1 },
  ],
  feed: [
    { id: "f1", creator: "EcoOrg", caption: "10,000 trees planted this quarter", type: "IMAGE", sdg: 15, score: 96, likes: 320, comments: 41, liked: false, timestamp: "2026-07-09T08:00:00Z" },
    { id: "f2", creator: "HealthNet", caption: "Mobile clinic reaches 3 villages", type: "VIDEO", sdg: 3, score: 88, likes: 210, comments: 19, liked: false, timestamp: "2026-07-09T07:30:00Z" },
    { id: "f3", creator: "EduForAll", caption: "Scholarships open for 2026 cohort", type: "TEXT", sdg: 4, score: 81, likes: 154, comments: 22, liked: false, timestamp: "2026-07-09T06:10:00Z" },
    { id: "f4", creator: "WaterWatch", caption: "River quality dashboard goes live", type: "IMAGE", sdg: 6, score: 74, likes: 132, comments: 14, liked: false, timestamp: "2026-07-09T05:40:00Z" },
    { id: "f5", creator: "CityFarm", caption: "Rooftop harvest day in Cairo", type: "TEXT", sdg: 2, score: 67, likes: 98, comments: 9, liked: false, timestamp: "2026-07-09T04:20:00Z" },
    { id: "f6", creator: "SolarCoop", caption: "Aswan microgrid hits 98% uptime", type: "IMAGE", sdg: 7, score: 61, likes: 87, comments: 11, liked: false, timestamp: "2026-07-08T22:00:00Z" },
    { id: "f7", creator: "GreenRoots", caption: "12,000 mangroves geotagged on the coast", type: "IMAGE", sdg: 14, score: 55, likes: 76, comments: 8, liked: false, timestamp: "2026-07-08T20:30:00Z" },
    { id: "f8", creator: "TechForGood", caption: "Open-source impact tool v2 released", type: "TEXT", sdg: 9, score: 49, likes: 64, comments: 6, liked: false, timestamp: "2026-07-08T18:00:00Z" },
    { id: "f9", creator: "EqualEd", caption: "Girls coding club graduates 60 students", type: "VIDEO", sdg: 5, score: 44, likes: 51, comments: 5, liked: false, timestamp: "2026-07-08T16:45:00Z" },
    { id: "f10", creator: "CleanAir", caption: "Low-emission zone cuts PM2.5 by 18%", type: "IMAGE", sdg: 11, score: 38, likes: 40, comments: 3, liked: false, timestamp: "2026-07-08T14:00:00Z" },
    { id: "f11", creator: "ReBuild", caption: "Recycled bricks used in 3 schools", type: "TEXT", sdg: 12, score: 33, likes: 29, comments: 2, liked: false, timestamp: "2026-07-08T11:20:00Z" },
    { id: "f12", creator: "SafeHarbor", caption: "Coastal warning system deployed", type: "IMAGE", sdg: 13, score: 28, likes: 21, comments: 2, liked: false, timestamp: "2026-07-08T09:00:00Z" },
    { id: "f13", creator: "FoodShare", caption: "Surplus produce feeds 400 families", type: "TEXT", sdg: 2, score: 23, likes: 17, comments: 1, liked: false, timestamp: "2026-07-08T07:30:00Z" },
    { id: "f14", creator: "MobilityMatters", caption: "Accessible buses added to 2 routes", type: "IMAGE", sdg: 11, score: 19, likes: 12, comments: 1, liked: false, timestamp: "2026-07-08T05:10:00Z" },
    { id: "f15", creator: "LocalCraft", caption: "Artisan marketplace goes digital", type: "TEXT", sdg: 8, score: 14, likes: 8, comments: 0, liked: false, timestamp: "2026-07-07T23:00:00Z" },
    { id: "f16", creator: "PeerLearn", caption: "Study circles launched in 5 cities", type: "VIDEO", sdg: 4, score: 9, likes: 5, comments: 0, liked: false, timestamp: "2026-07-07T20:30:00Z" },
  ],
  partners: [{ id: "pa1", company_name: "TechCorp", status: "PENDING", service_name: "Maps API" }],
  pendingReviews: [{ id: "rv1", entity_id: "ev1", entity_type: "EVIDENCE", confidence_score: 0.92, status: "PENDING", note: "Evidence awaiting HITL approval" }],
  transactions: [{ id: "t0", type: "EARN", delta: 1280.5, balance: 1280.5, reference: "seed", created_at: "2026-07-01T08:00:00Z" }],
  walletBalance: 1280.5,
  feeRate: 0.025,
};

function payload(method, url, body) {
  const raw = url.split("?")[0].replace(/\/api\/v1\//, "").replace(/\/$/, "");
  const isGet = method === "GET";
  const j = (o) => o;

  if (raw === "auth/login") return j({ access_token: "fake.jwt.token", refresh_token: "rt", token_type: "bearer", expires_in: 3600, user_id: "u_admin", role: "ADMIN" });
  if (raw === "auth/refresh" || raw === "auth/logout") return j({});
  if (raw === "users/me") return j(USER);
  if (raw === "users/register") return j({ id: uid("u") });
  if (/^users\/[^/]+$/.test(raw)) return j(USER);
  if (/^users\/[^/]+\/impact-passport$/.test(raw)) return j({ passport_id: "PP-u_admin", full_name: "Admin User", pms_score: 812, tier: "GOLD" });
  if (/^pms\/[^/]+$/.test(raw)) return j({ composite_score: 0.812, tier: "GOLD" });

  if (raw === "bff/dashboard") return j({ platform: { total_users: 1280, active_programs: 64, verified_tasks: 312, impact_assets_created: 980, total_economic_value_usd: 412000, countries_active: 14 }, me: { full_name: "Admin User" }, user_stats: { tasks: 5 }, pms: { composite_score: 0.812, tier: "GOLD" } });
  if (raw === "bff/leaderboard") return [USER, { id: "u_vol", full_name: "Volunteer One", role: "USER", pms_score: 540 }];
  if (raw === "analytics/platform/summary") return j({ total_evidence: 1280, active_programs: 64, avg_impact_score: 812, tasks: 312, sdg_coverage: 14, users: 1280, programs: 64 });

  if (raw === "tasks" && isGet) return [...state.tasks];
  if (raw === "tasks" && method === "POST") { const t = { id: uid("tk"), title: body.title || "New Task", program_id: body.program_id || "pr1", assignee_id: body.assignee_id || "u_admin", status: "OPEN", evidence_ids: [], due_date: body.due_date || "2026-09-01" }; state.tasks.push(t); return t; }
  if (/^tasks\/[^/]+$/.test(raw)) return state.tasks[0];
  if (/^tasks\/[^/]+\/(assign|start|submit|complete|history)$/.test(raw)) return j({ ok: true });

  if (raw === "evidence" && isGet) return [];
  if (raw === "evidence" && method === "POST") return j({ id: uid("ev"), status: "PENDING" });
  if (/^evidence\/[^/]+\/sync$/.test(raw)) return j({ synced: true });

  if (raw === "opportunities" && isGet) return [...state.opportunities];
  if (raw === "opportunities" && method === "POST") { const o = { id: uid("op"), title: "New Opportunity", opp_type: "VOLUNTEER", status: "OPEN" }; state.opportunities.push(o); return o; }
  if (raw === "opportunities/platform-content") return [];
  if (/^opportunities\/[^/]+$/.test(raw)) return state.opportunities[0];
  if (/^opportunities\/[^/]+\/apply$/.test(raw)) return j({ applied: true });

  if (raw === "matching/feed") return [...state.feed];

  if (raw === "audit/review/pending" && isGet) return [...state.pendingReviews];
  if (/^audit\/review\/[^/]+\/resolve$/.test(raw)) { const id = raw.split("/")[2]; state.pendingReviews = state.pendingReviews.filter((r) => r.id !== id); return j({ resolved: true }); }
  if (/^audit\/aggregate\/[^/]+$/.test(raw)) return [];

  if (raw === "partners" && isGet) return [...state.partners];
  if (raw === "partners" && method === "POST") { const p = { id: uid("pa"), status: "PENDING", company_name: body.company_name || "NewCo" }; state.partners.push(p); return p; }
  if (/^partners\/[^/]+\/review$/.test(raw)) return j({ reviewed: true });
  if (/^partners\/[^/]+\/provision$/.test(raw)) return j({ provisioned: true });

  if (/^coin\/wallets\/[^/]+$/.test(raw) || raw === "coin/wallets") return j({ owner_id: "u_admin", balance: state.walletBalance, currency: "MRC" });
  if (raw === "coin/transactions/transfer") { const fee = +(body.amount * state.feeRate).toFixed(2); const net = +(body.amount - fee).toFixed(2); state.walletBalance = +(state.walletBalance - body.amount).toFixed(2); state.transactions.push({ id: uid("t"), type: "TRANSFER", delta: -body.amount, balance: state.walletBalance, reference: body.reference || "transfer", created_at: new Date().toISOString() }); return j({ from_owner: body.from_owner, to_owner: body.to_owner, amount: body.amount, fee, net, from_balance: state.walletBalance, to_balance: net }); }
  if (raw === "coin/transactions/earn") { state.walletBalance = +(state.walletBalance + body.amount).toFixed(2); return j({ owner_id: "u_admin", type: "EARN", delta: body.amount, balance: state.walletBalance }); }
  if (raw === "coin/transactions/spend") { state.walletBalance = +(state.walletBalance - body.amount).toFixed(2); return j({ owner_id: "u_admin", type: "SPEND", delta: -body.amount, balance: state.walletBalance }); }
  if (/^coin\/transactions\/[^/]+$/.test(raw)) return [...state.transactions];
  if (raw === "coin/exchange/rate" && isGet) return j({ currency: "EGP", rate_to_mrc: 10, updated_at: "2026-07-09T00:00:00Z" });
  if (raw === "coin/exchange/rate" && method === "POST") return j({ currency: body.currency || "EGP", rate_to_mrc: body.rate_to_mrc || 10, updated_at: new Date().toISOString() });
  if (raw === "coin/exchange/convert") { const gross = +(body.fiat_amount * 10).toFixed(2); const fee = +(gross * state.feeRate).toFixed(2); const net = +(gross - fee).toFixed(2); state.walletBalance = +(state.walletBalance + net).toFixed(2); state.transactions.push({ id: uid("t"), type: "DEPOSIT", delta: net, balance: state.walletBalance, reference: "deposit", created_at: new Date().toISOString() }); return j({ owner_id: "u_admin", type: "DEPOSIT", delta: net, balance: state.walletBalance, fiat_amount: body.fiat_amount, currency: "EGP", rate_to_mrc: 10, gross_mrc: gross, fee_rate: state.feeRate, fee_mrc: fee, net_mrc: net }); }

  if (raw === "ads/campaigns" && isGet) return [...state.campaigns];
  if (raw === "ads/campaigns" && method === "POST") { const budget = +body.budget_coins || 0; const fee = +(budget * state.feeRate).toFixed(2); const c = { id: uid("c"), owner_id: "u_admin", name: body.name || "Campaign", status: "ACTIVE", budget_coins: budget, spent_coins: 0, currency: "MRC", platform_fee_coins: fee, impressions: 0, clicks: 0 }; state.campaigns.push(c); return c; }
  if (/^ads\/campaigns\/[^/]+$/.test(raw)) return state.campaigns[0];
  if (/^ads\/campaigns\/[^/]+\/status$/.test(raw)) return j({ id: "c1", status: "ACTIVE" });
  if (/^ads\/campaigns\/[^/]+\/creatives$/.test(raw)) return j({ id: "cr1", title: "T", body: "B" });
  if (/^ads\/campaigns\/[^/]+\/(impression|click)$/.test(raw)) { const c = state.campaigns[0]; if (raw.endsWith("impression")) c.impressions += 1; else c.clicks += 1; c.spent_coins = +(c.spent_coins + 2).toFixed(2); return j({ campaign_id: c.id, budget_coins: c.budget_coins, status: c.status, impressions: c.impressions, clicks: c.clicks, spent_coins: c.spent_coins }); }
  if (/^ads\/campaigns\/[^/]+\/stats$/.test(raw)) { const c = state.campaigns[0]; return j({ campaign_id: c.id, budget_coins: c.budget_coins, status: c.status, impressions: c.impressions, clicks: c.clicks, spent_coins: c.spent_coins }); }

  if (/^payments\/[^/]+\/history$/.test(raw)) return [{ id: "p1", amount_usd: 50, status: "SETTLED", created_at: "2026-07-08T10:00:00Z" }];
  if (raw === "payments/psp/status") return j({ providers: { stripe: { enabled: false }, paymob: { enabled: true, currency: "EGP", methods: ["card", "vodafone_cash"] } } });
  if (raw === "payments/psp/paymob/intent") return j({ id: "pay1", psp: { provider: "paymob", method: "vodafone_cash", order_id: 999, payment_key: "pk", redirect_url: "https://accept.paymob.com/iframes/1?payment_token=pk" } });

  if (raw === "platform/config/fee" && isGet) return j({ fee_rate: state.feeRate });
  if (raw === "platform/config/fee" && method === "POST") { state.feeRate = body.rate ?? body.fee_rate ?? state.feeRate; return j({ fee_rate: state.feeRate }); }
  if (raw === "platform/revenue/summary") return j({ totals: { MRC: 1840.5, EGP: 612.75 }, by_source: { coin: { MRC: 540.5 }, transfer: { MRC: 300 }, payment: { EGP: 612.75 }, ads: { MRC: 1000 } }, fee_rate: state.feeRate });
  if (raw === "platform/revenue/events") return [{ id: "e1", source_service: "coin", currency: "MRC", amount: 2.5, reference: "deposit", created_at: "2026-07-09T08:00:00Z" }];

  return isGet ? [] : j({});
}

const server = http.createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    let parsed = {};
    try { parsed = body ? JSON.parse(body) : {}; } catch {}
    const line = `${new Date().toISOString()} ${req.method} ${req.url}`;
    console.log(`[mock] ${line}` + (body ? ` body=${body.slice(0, 200)}` : ""));
    const data = payload(req.method, req.url, parsed);
    res.writeHead(200, { "Content-Type": "application/json", "access-control-allow-origin": "*" });
    res.end(JSON.stringify({ success: true, data }));
  });
});
server.listen(PORT, () => console.log(`[mock] MASAREN mobile mock gateway on :${PORT}`));
