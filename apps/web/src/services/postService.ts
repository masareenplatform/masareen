// postService, social feed with graceful backend hydration.
//
// The MASAREEN social-service now owns /api/v1/posts (posts/likes/comments/
// bookmarks), served by the combined monolith. This service hydrates its store
// from `/posts` when the gateway is reachable and falls back to a seeded
// in-memory store (persisted to localStorage) for the offline demo. New posts/
// likes/comments are fanned out through the realtime bus (see services/realtime)
// so every open tab updates live, no refresh needed, and remote events from
// other users are merged back in via `applyRemote`.

import { realtime, TOPICS } from "./realtime";
import { apiClient } from "./api";
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

// Platform-authored posts (announcements, synergies, opportunities, recognition).
const PLATFORM_AUTHOR: PostAuthor = {
  id: "u_masaren", name: "MASAREEN Platform", handle: "masaren", verified: true, role: "Platform",
};
const RECOGNIZED_MEDIA: PostAuthor = {
  id: "u_almasareen", name: "Al-Masareen News Network", handle: "almasareen", verified: true, role: "Media Institution",
};
const RECOGNIZED_SPORTS: PostAuthor = {
  id: "u_usf", name: "United Sports Federation", handle: "usports", verified: true, role: "Sports Institution",
};

// Esteemed institutions showcased in the Recognition rail.
export const recognizedInstitutions: {
  id: string; name: string; handle: string; kind: "media" | "sports" | "government";
  badge: string; note: string;
}[] = [
  { id: "u_almasareen", name: "Al-Masareen News Network", handle: "almasareen", kind: "media", badge: "Esteemed Media", note: "96% evidence accuracy · 14 countries" },
  { id: "u_usf", name: "United Sports Federation", handle: "usports", kind: "sports", badge: "Esteemed Sports", note: "Verified youth-impact coverage" },
  { id: "u_gov", name: "Ministry of Environment", handle: "moenv", kind: "government", badge: "Government Partner", note: "Official SDG reporting channel" },
];

function seed(): Post[] {
  return [
    {
      id: uid(),
      kind: "impact",
      author: SEED_AUTHORS[4],
      text: "We just planted 12,000 mangrove saplings along the northern coast with 340 volunteers. Real, verified impact, every seedling geotagged and audited. 🌱",
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
      text: "Field verification complete for the solar microgrid in Aswan. 98% uptime this quarter, audit trail attached.",
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
      text: "Aswan solar microgrid just crossed 98% uptime for the quarter, clean energy reaching 4 villages. ☀️",
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
      text: "Scholarships are open for the 2026 EduForAll cohort, 200 places for girls in STEM across 5 governorates.",
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
      comments: [{ id: uid("c"), author: SEED_AUTHORS[0], text: "Measurable and verified, exactly the standard.", createdAt: ago(12) }],
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
      text: "Girls coding club graduated 60 students this term, 80% from underserved districts. 💻",
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

    // ── Generic platform posts: onboarding, synergies & opportunities ──
    {
      id: uid(),
      kind: "announcement",
      author: PLATFORM_AUTHOR,
      text: "👋 Welcome to MASAREEN, the professional impact network for verified media, institutions and field reporters. Publish verified reports, earn recognition, and turn your work into a measurable impact portfolio. Tap “Create post” to share your first story.",
      media: [],
      programTag: undefined,
      sdg: 17,
      impactValue: 0,
      impactLabel: "onboarding",
      likes: 412,
      comments: [],
      shares: 88,
      likedByMe: false,
      createdAt: ago(250),
    },
    {
      id: uid(),
      kind: "announcement",
      author: PLATFORM_AUTHOR,
      text: "🚀 How MASAREEN works: every post is scored by POAI (Proof-of-Action Impact). Verified evidence raises your Impact Tier, unlocks MASAREEN Coin rewards, and builds your public reputation. Complete your verification in the Verify tab to get the blue check.",
      media: [],
      sdg: 17,
      impactValue: 0,
      impactLabel: "guide",
      likes: 276,
      comments: [],
      shares: 51,
      likedByMe: false,
      createdAt: ago(244),
    },
    {
      id: uid(),
      kind: "synergy",
      author: PLATFORM_AUTHOR,
      text: "🤝 Synergy spotlight: Media outlets + NGOs achieve 3× faster verification when they co-publish field reports. Pair a journalist with an on-ground organization to amplify reach and credibility. Open a collaboration in the Collaborate hub.",
      media: [],
      sdg: 17,
      impactValue: 0,
      impactLabel: "synergy",
      likes: 198,
      comments: [],
      shares: 40,
      likedByMe: false,
      createdAt: ago(180),
    },
    {
      id: uid(),
      kind: "opportunity",
      author: PLATFORM_AUTHOR,
      text: "📣 Open opportunity: The Coastal Restoration 2026 program is recruiting verified field reporters across 6 regions. Coverage assignments include drone footage, interviews and evidence capture. Browse Programs to enroll.",
      media: [],
      programTag: "Coastal Restoration 2026",
      sdg: 14,
      impactValue: 0,
      impactLabel: "opportunity",
      likes: 231,
      comments: [],
      shares: 63,
      likedByMe: false,
      createdAt: ago(120),
    },
    {
      id: uid(),
      kind: "opportunity",
      author: PLATFORM_AUTHOR,
      text: "💡 Grant alert: MASAREEN Impact Grants now accept applications from registered media institutions documenting SDG progress. Up to 50,000 MRC per approved portfolio. See the Revenue & Grants center.",
      media: [],
      sdg: 17,
      impactValue: 0,
      impactLabel: "grant",
      likes: 154,
      comments: [],
      shares: 37,
      likedByMe: false,
      createdAt: ago(95),
    },

    // ── Online recognition for esteemed institutions ──
    {
      id: uid(),
      kind: "recognition",
      author: RECOGNIZED_MEDIA,
      text: "🏅 Recognition: Al-Masareen News Network has been verified as an Esteemed Media Institution for outstanding field documentation across 14 countries, maintaining a 96% evidence-verification accuracy.",
      media: [],
      sdg: 16,
      impactValue: 0,
      impactLabel: "media recognition",
      likes: 1240,
      comments: [],
      shares: 310,
      likedByMe: false,
      createdAt: ago(70),
    },
    {
      id: uid(),
      kind: "recognition",
      author: RECOGNIZED_SPORTS,
      text: "🏅 Recognition: United Sports Federation earned Esteemed Sports Institution status for transparent youth-development reporting and verified community-impact coverage this season.",
      media: [],
      sdg: 4,
      impactValue: 0,
      impactLabel: "sports recognition",
      likes: 980,
      comments: [],
      shares: 244,
      likedByMe: false,
      createdAt: ago(50),
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

// ── Bookmarks (Saved posts) ──────────────────────────────────────
const BM_KEY = "masaren_bookmarks_v1";

function loadBm(): Set<string> {
  try {
    const raw = localStorage.getItem(BM_KEY);
    if (raw) return new Set<string>(JSON.parse(raw));
  } catch {}
  return new Set<string>();
}

let saved: Set<string> = loadBm();

function persistBm() {
  try { localStorage.setItem(BM_KEY, JSON.stringify([...saved])); } catch {}
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

// ── Real backend sync (graceful) ──────────────────────────────────────────
// The new social-service owns posts/likes/bookmarks. When the API gateway is
// reachable we hydrate the local store from `/posts` so the UIs render live,
// server-ranked data; when it isn't (demo/offline) the seeded local store is
// used and all writes fall back to the existing optimistic paths. Every
// backend call is best-effort and never throws into the UI.
let _synced = false;

async function syncFromBackend(): Promise<void> {
  try {
    const r = await apiClient.get("/posts");
    const arr = (Array.isArray(r) ? r : ((r as any)?.items ?? r)) as Post[];
    if (arr && arr.length) {
      store = arr;
      // Nudge subscribers (feed re-renders) without a hard refresh.
      realtime.publish(TOPICS.POST_NEW, {});
    }
  } catch {
    /* offline / no gateway → keep the seeded local store */
  }
}

export const postService = {
  list(opts?: { authorId?: string; kind?: PostKind }): Post[] {
    if (!_synced) {
      _synced = true;
      void syncFromBackend();
    }
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
    // Best-effort: persist to the real social-service so the post survives
    // across devices. Failures are non-fatal (local store already updated).
    // On success we reconcile the local client-generated id (`p_…`) with the
    // server-assigned id so subsequent likes/saves target the real record
    // instead of 404-ing (see audit finding D).
    apiClient
      .post("/posts", {
        text: input.text,
        kind: input.kind ?? "story",
        programTag: input.programTag,
        sdg: input.sdg,
        impactValue: input.impactValue,
        impactLabel: input.impactLabel,
        media: input.media ?? [],
      })
      .then((d: any) => {
        const serverId = d?.id ?? (d?.data && d.data.id);
        if (!serverId || serverId === post.id) return;
        const localId = post.id; // capture before we mutate the shared object
        const target = store.find((x) => x.id === localId);
        if (target) {
          target.id = serverId;
          persist();
        }
        if (saved.has(localId)) {
          saved.delete(localId);
          saved.add(serverId);
          persistBm();
        }
        realtime.publish(TOPICS.POST_NEW, { id: serverId, replacedId: localId });
      })
      .catch(() => {});
    return post;
  },

  toggleLike(postId: string): Post | undefined {
    const p = store.find((x) => x.id === postId);
    if (!p) return;
    p.likedByMe = !p.likedByMe;
    p.likes += p.likedByMe ? 1 : -1;
    persist();
    realtime.publish(TOPICS.POST_REACT, { postId, likes: p.likes, likedByMe: p.likedByMe });
    // Best-effort server toggle; reconcile counts with the authoritative response.
    apiClient
      .post(`/posts/${postId}/like`)
      .then((d: any) => {
        if (d && typeof d.likes === "number") {
          p.likes = d.likes;
          p.likedByMe = !!d.likedByMe;
          realtime.publish(TOPICS.POST_REACT, { postId, likes: p.likes, likedByMe: p.likedByMe });
        }
      })
      .catch(() => {});
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

  // ── Bookmarks (Saved posts) ──────────────────────────────────────────────
  // LocalStorage-backed per-browser state that mirrors the server-side bookmark
  // owned by the social-service (`/posts/{id}/save`, `/posts/saved`). The local
  // Set is the source of truth for instant UI feedback; the server call keeps
  // the "Saved" filter consistent across devices.
  isSaved(postId: string): boolean {
    return saved.has(postId);
  },
  toggleSave(postId: string): boolean {
    if (saved.has(postId)) saved.delete(postId);
    else saved.add(postId);
    persistBm();
    // Best-effort server-side bookmark so the "Saved" filter is shared across
    // devices. The local Set remains the source of truth for the UI.
    apiClient.post(`/posts/${postId}/save`).catch(() => {});
    return saved.has(postId);
  },
  saved(): Post[] {
    return store.filter((p) => saved.has(p.id));
  },

  // ── Trending ───────────────────────────────────────────────────────────
  // Derives live topics from the current feed: hashtags found in post
  // text plus each post's program tag. Returns the top tags by frequency
  // so the right rail can surface real, in-platform trends without a
  // dedicated backend endpoint.
  trending(): { tag: string; count: number }[] {
    const counts = new Map<string, number>();
    for (const p of store) {
      const tags = (p.text.match(/#\w+/g) ?? []).map((t) => t.toLowerCase());
      if (p.programTag) tags.push("#" + p.programTag.toLowerCase().replace(/\s+/g, ""));
      for (const t of tags) counts.set(t, (counts.get(t) ?? 0) + 1);
    }
    return [...counts.entries()]
      .map(([tag, count]) => ({ tag, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8);
  },

  // Merge a remote realtime event into the local store so live updates from
  // *other* users actually appear. Id-deduped so locally-originated events
  // (which already mutated the store optimistically and then echo back through
  // the same bus) never double-apply.
  applyRemote(topic: string, payload: any): void {
    if (!payload) return;
    if (topic === TOPICS.POST_NEW) {
      // A `replacedId` arrives when another tab reconciled a client-generated
      // post with its server id; swap the local id so likes/saves line up.
      if (payload.replacedId && payload.id) {
        const target = store.find((p) => p.id === payload.replacedId);
        if (target) {
          target.id = payload.id;
          if (saved.has(payload.replacedId)) {
            saved.delete(payload.replacedId);
            saved.add(payload.id);
            persistBm();
          }
          persist();
        }
        return;
      }
      if (payload.id) {
        if (!store.some((p) => p.id === payload.id)) {
          store = [payload as Post, ...store];
        }
      }
    } else if (topic === TOPICS.POST_REACT && payload.postId) {
      const p = store.find((x) => x.id === payload.postId);
      if (p) {
        if (typeof payload.likes === "number") p.likes = payload.likes;
        p.likedByMe = !!payload.likedByMe;
      }
    } else if (topic === TOPICS.POST_COMMENT && payload.postId && payload.comment) {
      const p = store.find((x) => x.id === payload.postId);
      if (p && !p.comments.some((c) => c.id === payload.comment.id)) {
        p.comments = [...p.comments, payload.comment];
      }
    }
  },

  subscribe(handler: () => void): () => void {
    const wrap = (topic: string) => (payload: any) => {
      this.applyRemote(topic, payload);
      handler();
    };
    const offs = [
      realtime.subscribe(TOPICS.POST_NEW, wrap(TOPICS.POST_NEW)),
      realtime.subscribe(TOPICS.POST_REACT, wrap(TOPICS.POST_REACT)),
      realtime.subscribe(TOPICS.POST_COMMENT, wrap(TOPICS.POST_COMMENT)),
    ];
    return () => offs.forEach((o) => o());
  },
};

// Avatar gradient helper, deterministic colors per handle (used by PostCard,
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
