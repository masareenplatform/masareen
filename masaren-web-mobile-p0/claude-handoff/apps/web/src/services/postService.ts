// postService — local mock social feed backed by an in-memory store.
//
// The MASAREN backend does not yet expose /posts, so this service owns a seed
// dataset and a tiny persistence layer (localStorage) so posts survive reloads
// in the demo. New posts/likes/comments are fanned out through the realtime bus
// (see services/realtime) so every open tab updates live — no refresh needed.
//
// When a real /api/v1/posts endpoint exists, swap the local store reads for
// `apiClient.get("/posts")` and the writes for `apiClient.post("/posts", …)`.

import { realtime, TOPICS } from "./realtime";
import type { Post, PostAuthor, PostComment, PostKind, PostMedia } from "../types/social";

const LS_KEY = "masaren_posts_v1";

function uid(prefix = "p"): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

function ago(minutes: number): string {
  return new Date(Date.now() - minutes * 60_000).toISOString();
}

const SEED_AUTHORS: PostAuthor[] = [
  { id: "u_amira", name: "Amira Saleh", handle: "amira", verified: true, role: "Organization" },
  { id: "u_yusuf", name: "Yusuf Rahman", handle: "yusuf", verified: false, role: "Individual" },
  { id: "u_lina", name: "Lina Haddad", handle: "lina", verified: true, role: "Specialist" },
  { id: "u_omar", name: "Omar Nabil", handle: "omar", verified: false, role: "Individual" },
  { id: "u_green", name: "GreenRoots NGO", handle: "greenroots", verified: true, role: "Organization" },
  { id: "u_solar", name: "SolarCoop", handle: "solarcoop", verified: true, role: "Organization" },
  { id: "u_edu", name: "EduForAll", handle: "eduforall", verified: true, role: "Organization" },
  { id: "u_water", name: "WaterWatch", handle: "waterwatch", verified: true, role: "Organization" },
  { id: "u_food", name: "FoodShare", handle: "foodshare", verified: false, role: "Individual" },
];

function seed(): Post[] {
  return [
    {
      id: uid(),
      kind: "impact",
      author: SEED_AUTHORS[4],
      text: "We just planted 12,000 mangrove saplings along the northern coast with 340 volunteers. Real, verified impact — every seedling geotagged and audited. 🌱",
      media: [],
      programTag: "Coastal Restoration",
      sdg: 14,
      impactValue: 12000,
      impactLabel: "seedlings planted",
      likes: 482,
      comments: [
        { id: uid("c"), author: SEED_AUTHORS[1], text: "Incredible work! Proud to have joined.", createdAt: ago(42) },
      ],
      shares: 73,
      likedByMe: false,
      createdAt: ago(58),
    },
    {
      id: uid(),
      kind: "program",
      author: SEED_AUTHORS[0],
      text: "Applications are open for the 2026 Clean Water Fellowship. Stipend + mentorship for 60 young engineers. Tag someone who should apply.",
      media: [],
      programTag: "Clean Water Fellowship",
      sdg: 6,
      likes: 211,
      comments: [],
      shares: 38,
      likedByMe: false,
      createdAt: ago(140),
    },
    {
      id: uid(),
      kind: "evidence",
      author: SEED_AUTHORS[2],
      text: "Field verification complete for the solar microgrid in Aswan. 98% uptime this quarter — audit trail attached.",
      media: [{ url: "", type: "image", name: "audit-aswan.jpg" }],
      sdg: 7,
      impactValue: 98,
      impactLabel: "% uptime",
      likes: 156,
      comments: [
        { id: uid("c"), author: SEED_AUTHORS[3], text: "The verification pipeline keeps getting better.", createdAt: ago(20) },
      ],
      shares: 12,
      likedByMe: true,
      createdAt: ago(220),
    },
    {
      id: uid(),
      kind: "story",
      author: SEED_AUTHORS[1],
      text: "Spent the weekend teaching in the community coding club. Small steps, but the kids built their first app today. This is what impact looks like up close.",
      media: [],
      likes: 89,
      comments: [],
      shares: 4,
      likedByMe: false,
      createdAt: ago(310),
    },
    {
      id: uid(),
      kind: "impact",
      author: SEED_AUTHORS[5],
      text: "Aswan solar microgrid just crossed 98% uptime for the quarter — clean energy reaching 4 villages. ☀️",
      media: [],
      programTag: "Rural Electrification",
      sdg: 7,
      impactValue: 98,
      impactLabel: "% uptime",
      likes: 240,
      comments: [{ id: uid("c"), author: SEED_AUTHORS[2], text: "Audited and verified. Great work.", createdAt: ago(15) }],
      shares: 31,
      likedByMe: false,
      createdAt: ago(95),
    },
    {
      id: uid(),
      kind: "program",
      author: SEED_AUTHORS[6],
      text: "Scholarships are open for the 2026 EduForAll cohort — 200 places for girls in STEM across 5 governorates.",
      media: [],
      programTag: "EduForAll 2026",
      sdg: 4,
      likes: 176,
      comments: [],
      shares: 22,
      likedByMe: false,
      createdAt: ago(160),
    },
    {
      id: uid(),
      kind: "evidence",
      author: SEED_AUTHORS[7],
      text: "River quality dashboard is live for the Nile Delta. Real-time sensors, fully auditable. 💧",
      media: [{ url: "", type: "image", name: "river-delta.jpg" }],
      sdg: 6,
      impactValue: 14,
      impactLabel: "sensors online",
      likes: 132,
      comments: [],
      shares: 9,
      likedByMe: false,
      createdAt: ago(205),
    },
    {
      id: uid(),
      kind: "story",
      author: SEED_AUTHORS[8],
      text: "Surplus produce from the community garden fed 400 families this week. Food is impact too. 🥕",
      media: [],
      sdg: 2,
      likes: 64,
      comments: [{ id: uid("c"), author: SEED_AUTHORS[3], text: "Love this initiative!", createdAt: ago(8) }],
      shares: 6,
      likedByMe: false,
      createdAt: ago(70),
    },
    {
      id: uid(),
      kind: "impact",
      author: SEED_AUTHORS[4],
      text: "Recycled bricks from our partners were used to rebuild 3 schools in Minya. Circular impact, verified. ♻️",
      media: [],
      programTag: "Circular Schools",
      sdg: 12,
      impactValue: 3,
      impactLabel: "schools rebuilt",
      likes: 58,
      comments: [],
      shares: 7,
      likedByMe: false,
      createdAt: ago(290),
    },
    {
      id: uid(),
      kind: "task",
      author: SEED_AUTHORS[3],
      text: "Helping map accessible bus routes in Alexandria. Small data, real inclusion. 🚌",
      media: [],
      sdg: 11,
      likes: 41,
      comments: [],
      shares: 3,
      likedByMe: false,
      createdAt: ago(340),
    },
    {
      id: uid(),
      kind: "program",
      author: SEED_AUTHORS[5],
      text: "Clean-air zone pilot cut PM2.5 by 18% in the first month. Evidence attached for audit.",
      media: [],
      programTag: "Clean Air Pilot",
      sdg: 11,
      likes: 119,
      comments: [{ id: uid("c"), author: SEED_AUTHORS[0], text: "Measurable and verified — exactly the standard.", createdAt: ago(12) }],
      shares: 14,
      likedByMe: false,
      createdAt: ago(265),
    },
    {
      id: uid(),
      kind: "story",
      author: SEED_AUTHORS[2],
      text: "Mentored 12 first-time volunteers this month. The community keeps growing. 🤝",
      media: [],
      likes: 73,
      comments: [],
      shares: 5,
      likedByMe: false,
      createdAt: ago(125),
    },
    {
      id: uid(),
      kind: "impact",
      author: SEED_AUTHORS[6],
      text: "Girls coding club graduated 60 students this term — 80% from underserved districts. 💻",
      media: [],
      programTag: "Girls Who Code",
      sdg: 5,
      impactValue: 60,
      impactLabel: "graduates",
      likes: 151,
      comments: [{ id: uid("c"), author: SEED_AUTHORS[8], text: "So proud of these girls!", createdAt: ago(6) }],
      shares: 19,
      likedByMe: false,
      createdAt: ago(180),
    },
    {
      id: uid(),
      kind: "evidence",
      author: SEED_AUTHORS[0],
      text: "Third-party audit confirms 12,000 mangrove seedlings geotagged on the northern coast.",
      media: [{ url: "", type: "image", name: "mangrove-audit.jpg" }],
      sdg: 14,
      impactValue: 12000,
      impactLabel: "seedlings",
      likes: 203,
      comments: [],
      shares: 27,
      likedByMe: false,
      createdAt: ago(232),
    },
  ];
}

function load(): Post[] {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (raw) return JSON.parse(raw) as Post[];
  } catch {}
  const s = seed();
  try { localStorage.setItem(LS_KEY, JSON.stringify(s)); } catch {}
  return s;
}

let store: Post[] = load();

function persist() {
  try { localStorage.setItem(LS_KEY, JSON.stringify(store)); } catch {}
}

// Feed ranking algorithm (mock): blends POAI confidence (impact value), raw
// engagement (likes + comments + shares) and recency into a single score, then
// returns the highest-scoring posts first. Runs entirely client-side until the
// real /posts endpoint (with its own ranking) replaces the mock.
function rankScore(p: Post): number {
  const now = Date.now();
  const ageHours = Math.max(0, (now - new Date(p.createdAt).getTime()) / 3_600_000);
  const engagement = (p.likes ?? 0) + (p.comments?.length ?? 0) * 3 + (p.shares ?? 0) * 2;
  const impact = Math.min(1, (p.impactValue ?? 0) / 12000) * 40;
  const recency = Math.max(0, 30 - ageHours / 12);
  return engagement * 0.6 + impact + recency;
}

export const postService = {
  list(opts?: { authorId?: string; kind?: PostKind }): Post[] {
    let out = [...store].sort((a, b) => rankScore(b) - rankScore(a));
    if (opts?.authorId) out = out.filter((p) => p.author.id === opts.authorId);
    if (opts?.kind) out = out.filter((p) => p.kind === opts.kind);
    return out;
  },

  create(input: {
    author: PostAuthor;
    text: string;
    kind?: PostKind;
    media?: PostMedia[];
    programTag?: string;
    sdg?: number;
    impactValue?: number;
    impactLabel?: string;
  }): Post {
    const post: Post = {
      id: uid(),
      kind: input.kind ?? "story",
      author: input.author,
      text: input.text,
      media: input.media ?? [],
      programTag: input.programTag,
      sdg: input.sdg,
      impactValue: input.impactValue,
      impactLabel: input.impactLabel,
      likes: 0,
      comments: [],
      shares: 0,
      likedByMe: false,
      createdAt: new Date().toISOString(),
    };
    store = [post, ...store];
    persist();
    realtime.publish(TOPICS.POST_NEW, post);
    return post;
  },

  toggleLike(postId: string): Post | undefined {
    const p = store.find((x) => x.id === postId);
    if (!p) return;
    p.likedByMe = !p.likedByMe;
    p.likes += p.likedByMe ? 1 : -1;
    persist();
    realtime.publish(TOPICS.POST_REACT, { postId, likes: p.likes, likedByMe: p.likedByMe });
    return p;
  },

  addComment(postId: string, author: PostAuthor, text: string): PostComment | undefined {
    const p = store.find((x) => x.id === postId);
    if (!p) return;
    const c: PostComment = { id: uid("c"), author, text, createdAt: new Date().toISOString() };
    p.comments = [...p.comments, c];
    persist();
    realtime.publish(TOPICS.POST_COMMENT, { postId, comment: c });
    return c;
  },

  share(postId: string): Post | undefined {
    const p = store.find((x) => x.id === postId);
    if (!p) return;
    p.shares += 1;
    persist();
    return p;
  },

  subscribe(handler: () => void): () => void {
    const offs = [
      realtime.subscribe(TOPICS.POST_NEW, handler),
      realtime.subscribe(TOPICS.POST_REACT, handler),
      realtime.subscribe(TOPICS.POST_COMMENT, handler),
    ];
    return () => offs.forEach((o) => o());
  },
};

// Avatar gradient helper — deterministic colors per handle (used by PostCard,
// Messenger, TopNav). Pure CSS classes; no network needed.
export function avatarColors(seed: string): { c1: string; c2: string } {
  const palettes = [
    ["#0250A3", "#0077C8"],
    ["#0077C8", "#2A9D45"],
    ["#0EA5E9", "#2A9D45"],
    ["#1D4ED8", "#3EBD5C"],
    ["#0250A3", "#16A34A"],
  ];
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  return { c1: palettes[h % palettes.length][0], c2: palettes[h % palettes.length][1] };
}
