// MASAREEN social + impact API (v1), served by the same Worker as the landing API.
// Auth here is email+password with PBKDF2 hashing and HMAC bearer tokens, so the
// mobile app never depends on an external server. All data lives in D1.

const enc = new TextEncoder();
const TOKEN_DAYS = 30;
const PBKDF2_ITERATIONS = 100000;
const ROLES = new Set(['INDIVIDUAL', 'STUDENT', 'ACADEMIC', 'ORGANIZATION', 'PROFESSIONAL',
  'VOLUNTEER', 'JOURNALIST', 'DONOR', 'GOVERNMENT', 'MEDIA', 'SPORTS', 'ATHLETE', 'CLUB',
  'FEDERATION', 'INSTITUTION', 'PLATFORM', 'ADMIN']);
const IMPACT_CATEGORIES = new Set(['verified_evidence', 'community_voice', 'policy_change',
  'innovation', 'scale', 'transparency']);
const SDG_NAMES = {
  1: 'No poverty', 2: 'Zero hunger', 3: 'Good health', 4: 'Quality education',
  5: 'Gender equality', 6: 'Clean water', 7: 'Clean energy', 8: 'Decent work',
  9: 'Industry & innovation', 10: 'Reduced inequalities', 11: 'Sustainable cities',
  12: 'Responsible consumption', 13: 'Climate action', 14: 'Life below water',
  15: 'Life on land', 16: 'Peace & justice', 17: 'Partnerships',
};

class HttpError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
const json = (data, status = 200, headers = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers },
  });
const clean = (v, max) => (typeof v === 'string' ? v.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max) : '');
const isEmail = (v) => typeof v === 'string' && /^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$/.test(v) && v.length <= 254;
const nowIso = () => new Date().toISOString();
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
const num = (v) => (v == null || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null);

const b64u = {
  enc: (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
  dec: (s) => {
    s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '=';
    const bin = atob(s); const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  },
};

async function hmacKey(secret) {
  return crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
async function signToken(payload, secret) {
  const body = b64u.enc(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body));
  return body + '.' + b64u.enc(sig);
}
export async function appTokenFor(user, env) {
  return signToken({ uid: user.id, exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET || '');
}

async function readToken(token, secret) {
  if (!token || !secret) return null;
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;
  try {
    const ok = await crypto.subtle.verify('HMAC', await hmacKey(secret), b64u.dec(sig), enc.encode(body));
    if (!ok) return null;
    const payload = JSON.parse(new TextDecoder().decode(b64u.dec(body)));
    if (!payload.uid || !payload.exp || payload.exp < Date.now()) return null;
    return payload;
  } catch { return null; }
}

async function pbkdf2(password, salt, iterations = PBKDF2_ITERATIONS) {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  return new Uint8Array(await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, key, 256));
}
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt);
  return { salt: b64u.enc(salt), hash: b64u.enc(hash) };
}
async function verifyPassword(password, saltB64, hashB64) {
  if (!saltB64 || !hashB64) return false;
  const hash = await pbkdf2(password, b64u.dec(saltB64));
  const expected = b64u.dec(hashB64);
  if (hash.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < hash.length; i++) diff |= hash[i] ^ expected[i];
  return diff === 0;
}

async function ipHash(req, env) {
  const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for') || '';
  if (!ip) return '';
  const data = enc.encode(ip + '|' + (env.SESSION_SECRET || 'masareen'));
  const digest = await crypto.subtle.digest('SHA-256', data);
  return hex(digest).slice(0, 32);
}

function handleFor(name, id) {
  const base = (name || 'member').toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '').slice(0, 18) || 'member';
  return base + String(id).padStart(3, '0');
}

function bearer(req) {
  const h = req.headers.get('authorization') || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1].trim() : null;
}

async function currentUser(req, env) {
  const token = bearer(req);
  const payload = await readToken(token, env.SESSION_SECRET);
  if (!payload) return null;
  const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(payload.uid).first();
  return u || null;
}
async function requireUser(req, env) {
  const u = await currentUser(req, env);
  if (!u) throw new HttpError(401, 'not_signed_in', 'Please sign in to continue.');
  return u;
}
function isAdminUser(env, u) {
  if (!u) return false;
  const list = (env.ADMIN_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  return (u.email && list.includes(u.email.toLowerCase())) || String(u.role || '').toUpperCase() === 'ADMIN';
}
async function requireAdmin(req, env) {
  const u = await requireUser(req, env);
  if (!isAdminUser(env, u)) throw new HttpError(403, 'not_admin', 'This account does not have admin access.');
  return u;
}

const followCount = async (env, id, col) =>
  (await env.DB.prepare(`SELECT COUNT(*) c FROM follows WHERE ${col}=?`).bind(id).first()).c || 0;

async function userJson(env, u, viewer) {
  const [followers, following, posts, votes] = await Promise.all([
    followCount(env, u.id, 'followee_id'),
    followCount(env, u.id, 'follower_id'),
    env.DB.prepare('SELECT COUNT(*) c, COALESCE(AVG(impact_value),0) avg, COALESCE(SUM(impact_value),0) total FROM posts WHERE author_id=? AND hidden=0').bind(u.id).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM post_impact_votes WHERE user_id=?').bind(u.id).first(),
  ]);
  let isFollowing = false;
  if (viewer && viewer.id !== u.id) {
    const f = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, u.id).first();
    isFollowing = !!f;
  }
  const name = u.name || (u.email ? u.email.split('@')[0] : 'Member');
  return {
    id: String(u.id),
    email: u.email || '',
    full_name: name,
    name,
    phone: u.phone || null,
    role: u.role || 'INDIVIDUAL',
    handle: u.handle || handleFor(name, u.id),
    verified: !!u.email_verified || ['GOVERNMENT', 'ORGANIZATION', 'MEDIA', 'PLATFORM'].includes(String(u.role || '').toUpperCase()),
    pms_score: Number((posts.total || 0).toFixed(1)),
    impact_score: Number((posts.total || 0).toFixed(1)),
    email_verified: !!u.email_verified,
    skills: [],
    bio: u.bio || '',
    country: u.country || null,
    city: u.city || null,
    is_tester: !!u.is_tester,
    created_at: u.created_at,
    profile: {
      bio: u.bio || '',
      avatar_url: u.picture || null,
      country: u.country || null,
      city: u.city || null,
      followers_count: followers,
      following_count: following,
      posts_count: posts.c || 0,
      impact_total: Number((posts.total || 0).toFixed(1)),
      impact_average: Number((posts.avg || 0).toFixed(2)),
      ratings_cast: votes.c || 0,
      cover_url: u.cover_url || null,
    },
    followers_count: followers,
    following_count: following,
    posts_count: posts.c || 0,
    is_following: isFollowing,
    is_me: !!(viewer && viewer.id === u.id),
  };
}

function authorJson(r) {
  return {
    id: String(r.author_id),
    name: r.author_name || 'Member',
    handle: r.author_handle || handleFor(r.author_name, r.author_id),
    verified: !!r.author_verified,
    role: r.author_role || 'INDIVIDUAL',
    avatar_url: r.author_picture || null,
  };
}

function safeMediaUrl(v) {
  const s = clean(v, 700);
  if (!s) return null;
  if (/^https?:\/\//i.test(s) || s.startsWith('/media/')) return s;
  return null;
}

function mediaKind(url, type) {
  const t = String(type || '').toUpperCase();
  if (t === 'VIDEO' || t === 'IMAGE') return t;
  return /\.(mp4|webm|mov|m3u8)(\?|#|$)/i.test(url || '') ? 'VIDEO' : 'IMAGE';
}

function normalizeMediaInput(b) {
  const raw = Array.isArray(b.media) ? b.media : (b.media ? [b.media] : []);
  const out = [];
  for (const item of raw.slice(0, 12)) {
    const src = typeof item === 'string' ? { url: item } : (item || {});
    const url = safeMediaUrl(src.url || src.media_url || src.content_url);
    if (!url) continue;
    const type = mediaKind(url, src.type || src.media_type);
    if (type === 'VIDEO' && out.some((m) => m.type === 'VIDEO')) continue;
    if (type === 'IMAGE' && out.filter((m) => m.type === 'IMAGE').length >= 10) continue;
    out.push({
      url,
      type,
      caption: clean(src.caption, 240) || null,
      poster_url: safeMediaUrl(src.poster_url) || null,
      hls_url: safeMediaUrl(src.hls_url) || null,
      duration_seconds: Number.isFinite(Number(src.duration_seconds)) ? Number(src.duration_seconds) : null,
    });
  }
  return out;
}

function postMedia(r) {
  const out = [];
  if (r.media_json) {
    try {
      const parsed = JSON.parse(r.media_json);
      if (Array.isArray(parsed)) {
        for (const item of parsed) {
          if (!item || !safeMediaUrl(item.url)) continue;
          out.push({
            url: safeMediaUrl(item.url),
            type: mediaKind(item.url, item.type),
            caption: item.caption || null,
            poster_url: safeMediaUrl(item.poster_url) || null,
            hls_url: safeMediaUrl(item.hls_url) || null,
            duration_seconds: item.duration_seconds == null ? null : Number(item.duration_seconds),
          });
        }
      }
    } catch { /* ignore malformed legacy media */ }
  }
  const legacy = safeMediaUrl(r.media_url);
  if (!out.length && legacy) out.push({ url: legacy, type: mediaKind(legacy, r.media_type), caption: null });
  const hls = safeMediaUrl(r.video_hls_url);
  if (hls && !out.some((m) => m.type === 'VIDEO')) {
    out.push({ url: legacy || hls, type: 'VIDEO', caption: null, hls_url: hls,
      poster_url: safeMediaUrl(r.video_poster_url), duration_seconds: r.video_duration_seconds == null ? null : Number(r.video_duration_seconds) });
  }
  return out;
}

function postJson(r, likedByMe, ranking) {
  let factors = null;
  if (r.confidence_factors) { try { factors = JSON.parse(r.confidence_factors); } catch { factors = null; } }
  const media = postMedia(r);
  const video = media.find((m) => m.type === 'VIDEO');
  return {
    id: String(r.id),
    author: authorJson(r),
    text: r.text,
    kind: r.kind,
    type: r.kind,
    programTag: r.sdg ? SDG_NAMES[r.sdg] || null : null,
    sdg: r.sdg == null ? null : Number(r.sdg),
    impactValue: r.impact_value == null ? null : Number(r.impact_value),
    impactLabel: r.impact_label || null,
    content_url: r.media_url || null,
    url: r.link_url || null,
    media,
    media_count: media.length,
    media_type: r.media_type || (video ? 'VIDEO' : media.length ? 'GALLERY' : 'TEXT'),
    video_hls_url: safeMediaUrl(r.video_hls_url) || video?.hls_url || null,
    video_poster_url: safeMediaUrl(r.video_poster_url) || video?.poster_url || null,
    video_duration_seconds: r.video_duration_seconds == null ? null : Number(r.video_duration_seconds),
    latitude: r.latitude == null ? null : Number(r.latitude),
    longitude: r.longitude == null ? null : Number(r.longitude),
    verified_content: !!(r.author_verified && Number(r.confidence_score || 0) >= 60),
    likes: Number(r.like_count || 0),
    comments: Number(r.comment_count || 0),
    shares: Number(r.share_count || 0),
    likedByMe: !!likedByMe,
    createdAt: r.created_at,
    confidence_score: r.confidence_score == null ? null : Number(r.confidence_score),
    confidence_label: r.confidence_label || null,
    confidence_factors: factors,
    ranking_score: ranking ? Number(ranking.score.toFixed(4)) : null,
    ranking_reason: ranking ? ranking.reason : null,
    ranking_reasons: ranking ? ranking.reasons : [],
  };
}

const POST_SELECT = `SELECT p.*, u.name author_name, u.handle author_handle, u.picture author_picture,
  u.role author_role, u.email_verified author_verified
  FROM posts p JOIN users u ON u.id=p.author_id`;

async function getPostRow(env, id) {
  return env.DB.prepare(`${POST_SELECT} WHERE p.id=? AND p.hidden=0`).bind(id).first();
}

function impactLabelFor(score, confidence) {
  if (score >= 8 && confidence >= 70) return 'Verified high impact';
  if (score >= 6.5) return 'Strong impact';
  if (score >= 4.5) return 'Emerging impact';
  if (score > 0) return 'Early signal';
  return 'Awaiting ratings';
}

async function recomputeImpact(env, postId) {
  const post = await env.DB.prepare(`${POST_SELECT} WHERE p.id=?`).bind(postId).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const agg = await env.DB.prepare('SELECT COUNT(*) n, COALESCE(AVG(stars),0) avg FROM post_impact_votes WHERE post_id=?')
    .bind(postId).first();
  const n = agg.n || 0;
  const avg = agg.avg || 0;
  const engagement = Math.log1p((post.like_count || 0) * 2 + (post.comment_count || 0) * 2.5 + (post.share_count || 0) * 3) /
    Math.log(61);
  const confidence = clamp(38 + Math.min(34, n * 7) + (post.author_verified ? 16 : 0) +
    (post.confidence_score || 0) * 0.08, 5, 99);
  const score = n === 0 ? (post.impact_value || 0) : clamp(
    10 * (0.55 * (avg / 5) + 0.20 * Math.min(1, engagement) + 0.15 * Math.min(1, n / 5) + 0.10 * (confidence / 100)),
    0, 10);
  const factors = {
    ratings: n, average_stars: Number(avg.toFixed(2)), engagement: Number(Math.min(1, engagement).toFixed(3)),
    author_verified: !!post.author_verified, confidence: Math.round(confidence),
    voters: n, method: 'weighted ratings + engagement + author trust',
  };
  await env.DB.prepare('UPDATE posts SET impact_value=?, impact_label=?, confidence_score=?, confidence_label=?, confidence_factors=? WHERE id=?')
    .bind(Number(score.toFixed(2)), impactLabelFor(score, confidence), Math.round(confidence),
      confidence >= 75 ? 'High confidence' : confidence >= 50 ? 'Moderate confidence' : 'Low confidence',
      JSON.stringify(factors), postId).run();
  return { impact_value: Number(score.toFixed(2)), impact_label: impactLabelFor(score, confidence),
    confidence_score: Math.round(confidence), confidence_factors: factors };
}

async function notify(env, userId, type, title, body, actorId, postId) {
  if (!userId || Number(userId) === Number(actorId)) return;
  try {
    await env.DB.prepare('INSERT INTO notifications (user_id,type,title,body,actor_id,post_id,read,created_at) VALUES (?,?,?,?,?,?,0,?)')
      .bind(userId, type, clean(title, 140), clean(body, 300) || null, actorId || null, postId || null, nowIso()).run();
  } catch { /* notifications must never break the action */ }
}

function hash01(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return (h >>> 0) / 4294967295;
}

function rankCandidates(rows, opts) {
  const { viewer, liked, following, seen, mode, offset, limit } = opts;
  const now = Date.now();
  const items = rows.map((r) => {
    const ageH = Math.max(0, (now - Date.parse(r.created_at)) / 3600000);
    const recency = Math.exp(-ageH / 84);
    const engRaw = (r.like_count || 0) * 2 + (r.comment_count || 0) * 3 + (r.share_count || 0) * 4;
    const velocity = Math.log1p(engRaw) / (1 + Math.pow(ageH / 8, 0.75));
    const impact = (r.impact_value || 0) / 10;
    const isFollow = viewer && following.has(r.author_id);
    const isSelf = viewer && viewer.id === r.author_id;
    const interest = viewer && (r.sdg && viewer.__interests && viewer.__interests.has(r.sdg)) ? 1 : 0;
    const verifiedContent = r.author_verified && Number(r.confidence_score || 0) >= 60 ? 1 : 0;
    const hasMedia = (r.media_json || r.media_url || r.video_hls_url) ? 1 : 0;
    const explore = hash01((viewer ? viewer.id : 'guest') + ':' + r.id) * 0.10;
    const seenPenalty = viewer && seen.has(r.id) ? 0.22 : 0;
    const score = 0.34 * impact + 0.18 * verifiedContent + 0.18 * recency +
      0.14 * Math.min(1.4, velocity) + 0.08 * (isFollow ? 1 : 0) + 0.05 * interest +
      0.03 * hasMedia + explore - seenPenalty + (isSelf ? 0.02 : 0);
    const reasons = [];
    if (impact >= 0.6) reasons.push({ key: 'impact', label: 'High verified impact', weight: 0.34 * impact });
    if (verifiedContent) reasons.push({ key: 'verified', label: 'Verified source', weight: 0.18 });
    if (isFollow) reasons.push({ key: 'following', label: 'From a profile you follow', weight: 0.08 });
    if (velocity >= 0.5) reasons.push({ key: 'trending', label: 'Trending in the community', weight: 0.14 * velocity });
    if (hasMedia) reasons.push({ key: 'media', label: 'Visual evidence attached', weight: 0.03 });
    if (interest) reasons.push({ key: 'interest', label: 'Matches your interests', weight: 0.05 });
    if (ageH < 6) reasons.push({ key: 'fresh', label: 'Fresh update', weight: 0.18 * recency });
    reasons.sort((a, b) => b.weight - a.weight);
    if (!reasons.length) reasons.push({ key: 'explore', label: 'Worth discovering', weight: 0.05 });
    return { row: r, score, reason: reasons[0].label, reasons: reasons.slice(0, 3).map((x) => x.label) };
  });

  if (mode === 'latest') {
    items.sort((a, b) => Date.parse(b.row.created_at) - Date.parse(a.row.created_at));
    return items.slice(offset, offset + limit);
  }
  if (mode === 'impact') {
    items.sort((a, b) => (b.row.impact_value || 0) - (a.row.impact_value || 0) || Date.parse(b.row.created_at) - Date.parse(a.row.created_at));
    return items.slice(offset, offset + limit);
  }
  items.sort((a, b) => b.score - a.score);

  // Author-diversity pass: avoid one voice dominating the top of the feed.
  const picked = [];
  const remaining = items.slice();
  const authorSeen = new Map();
  const want = Math.min(remaining.length, offset + limit + 8);
  while (picked.length < want && remaining.length) {
    let bestI = 0; let best = -Infinity;
    for (let i = 0; i < remaining.length; i++) {
      const a = remaining[i].row.author_id;
      const adj = remaining[i].score - (authorSeen.get(a) || 0) * 0.16;
      if (adj > best) { best = adj; bestI = i; }
    }
    const item = remaining.splice(bestI, 1)[0];
    authorSeen.set(item.row.author_id, (authorSeen.get(item.row.author_id) || 0) + 1);
    picked.push(item);
  }
  return picked.slice(offset, offset + limit);
}

/* ---------------- public testers ---------------- */
async function testerRoutes(req, env, url, ctx) {
  const path = url.pathname;
  if (path === '/api/testers/stats' && req.method === 'GET') {
    const total = (await env.DB.prepare('SELECT COUNT(*) c FROM testers').first()).c || 0;
    const active = (await env.DB.prepare("SELECT COUNT(*) c FROM testers WHERE status IN ('invited','active')").first()).c || 0;
    return json({ ok: true, count: total, active_count: active });
  }
  if (path !== '/api/testers' || req.method !== 'POST') throw new HttpError(404, 'not_found', 'Unknown route.');
  const b = await req.json().catch(() => ({}));
  if (clean(b.website, 10)) return json({ ok: true, count: 0 }); // honeypot
  const name = clean(b.name, 90);
  const email = clean(b.email, 254).toLowerCase();
  if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Please enter your name.');
  if (!isEmail(email)) throw new HttpError(400, 'invalid_email', 'Please enter a valid email address.');
  const ih = await ipHash(req, env);
  if (ih) {
    const recent = await env.DB.prepare('SELECT COUNT(*) c FROM testers WHERE ip_hash=? AND created_at>?')
      .bind(ih, new Date(Date.now() - 86400000).toISOString()).first();
    if ((recent.c || 0) > 8) throw new HttpError(429, 'too_many', 'Too many signups from this network. Try again tomorrow.');
  }
  const country = clean(b.country, 60) || null;
  const device = clean(b.device, 80) || null;
  const android = clean(b.android_version, 40) || null;
  const source = clean(b.source, 40) || 'landing';
  const existing = await env.DB.prepare('SELECT id FROM testers WHERE email=?').bind(email).first();
  if (existing) {
    await env.DB.prepare('UPDATE testers SET name=?, country=COALESCE(?,country), device=COALESCE(?,device), android_version=COALESCE(?,android_version), source=? WHERE id=?')
      .bind(name, country, device, android, source, existing.id).run();
  } else {
    await env.DB.prepare('INSERT INTO testers (name,email,country,device,android_version,source,status,created_at,ip_hash) VALUES (?,?,?,?,?,?,?,?,?)')
      .bind(name, email, country, device, android, source, 'pending', nowIso(), ih).run();
  }
  const total = (await env.DB.prepare('SELECT COUNT(*) c FROM testers').first()).c || 0;
  return json({ ok: true, already: !!existing, count: total, message: "You're on the list. We'll email your testing link before the closed test begins." });
}

/* ---------------- auth ---------------- */
async function register(req, env) {
  const b = await req.json().catch(() => ({}));
  const email = clean(b.email, 254).toLowerCase();
  const name = clean(b.full_name || b.name, 90);
  const password = typeof b.password === 'string' ? b.password : '';
  const isTester = b.is_tester === true || b.is_tester === 'true' || b.tester === true;
  const audience = clean(b.audience, 40).toUpperCase() || null;
  const phone = clean(b.phone, 40) || null;
  const nationalId = clean(b.national_id, 60) || null;
  const university = clean(b.university, 160) || null;
  const universityId = clean(b.university_id, 60) || null;
  const consent = b.consent === true || b.consent === 'true' || b.consent === 1 || b.consent === '1';
  const requestedRole = clean(b.role, 30).toUpperCase();
  const role = ROLES.has(requestedRole) ? requestedRole : 'INDIVIDUAL';
  if (!isEmail(email)) throw new HttpError(400, 'invalid_email', 'Please enter a valid email address.');
  if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Please enter your full name.');
  if (name.length > 90) throw new HttpError(400, 'invalid_name', 'Name is too long.');
  if (password.length < 8) throw new HttpError(400, 'weak_password', 'Password must be at least 8 characters.');
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password))
    throw new HttpError(400, 'weak_password', 'Password must include letters and numbers.');
  if (password.length > 200) throw new HttpError(400, 'weak_password', 'Password is too long.');
  const existing = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (existing) {
    if (existing.password_hash) throw new HttpError(409, 'email_taken', 'An account with this email already exists. Please sign in.');
    const { salt, hash } = await hashPassword(password);
    await env.DB.prepare(`UPDATE users SET password_hash=?, password_salt=?,
      name=COALESCE(NULLIF(?,''),name),
      role=CASE WHEN COALESCE(role,'') IN ('','INDIVIDUAL') THEN ? ELSE role END,
      signup_method=?, is_tester=CASE WHEN ? THEN 1 ELSE is_tester END,
      audience=COALESCE(?,audience), phone=COALESCE(?,phone),
      university=COALESCE(NULLIF(?,''),university),
      university_id=COALESCE(NULLIF(?,''),university_id),
      national_id=COALESCE(NULLIF(?,''),national_id),
      consent_at=COALESCE(consent_at,?)
      WHERE id=?`)
      .bind(hash, salt, name, role, 'password', isTester ? 1 : 0, audience, phone,
        university, universityId, nationalId, consent ? nowIso() : null, existing.id).run();
    const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(existing.id).first();
    return json({ ok: true, access_token: await signToken({ uid: u.id, exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET), token_type: 'bearer', user: await userJson(env, u, u) });
  }
  const { salt, hash } = await hashPassword(password);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO users (email, email_verified, name, role, country, city, interest, phone,
      national_id, university, university_id,
      password_hash, password_salt, handle, bio, audience, is_tester, consent_at, profile_complete, signup_method, created_at, last_login_at, login_count)
      VALUES (?,0,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,'password',?,?,1)`)
    .bind(email, name, role, clean(b.country, 60) || null, clean(b.city, 80) || null, clean(b.interest, 120) || null,
      phone, nationalId, university, universityId, hash, salt, handleFor(name, '0'), clean(b.bio, 400) || null, audience,
      isTester ? 1 : 0, consent ? at : null, at, at).run();
  const id = r.meta.last_row_id;
  await env.DB.prepare('UPDATE users SET handle=? WHERE id=?').bind(handleFor(name, id), id).run();
  const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();
  return json({ ok: true, access_token: await signToken({ uid: u.id, exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET), token_type: 'bearer', user: await userJson(env, u, u) }, 201);
}

async function login(req, env) {
  const b = await req.json().catch(() => ({}));
  const email = clean(b.email, 254).toLowerCase();
  const password = typeof b.password === 'string' ? b.password : '';
  const u = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (!u || !u.password_hash) throw new HttpError(401, 'invalid_credentials', 'Incorrect email or password.');
  if (!(await verifyPassword(password, u.password_salt, u.password_hash)))
    throw new HttpError(401, 'invalid_credentials', 'Incorrect email or password.');
  await env.DB.prepare('UPDATE users SET last_login_at=?, login_count=login_count+1 WHERE id=?').bind(nowIso(), u.id).run();
  await env.DB.prepare('INSERT INTO login_events (user_id,email,method,at) VALUES (?,?,?,?)')
    .bind(u.id, u.email, 'password_app', nowIso()).run();
  return json({ ok: true, access_token: await signToken({ uid: u.id, exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET),
    token_type: 'bearer', user: await userJson(env, u, u) });
}

/* ---------------- feed ---------------- */
async function listPosts(req, env, url) {
  const viewer = await currentUser(req, env);
  const limit = clamp(parseInt(url.searchParams.get('limit') || '40', 10) || 40, 1, 60);
  const offset = Math.max(0, parseInt(url.searchParams.get('offset') || '0', 10) || 0);
  const mode = (url.searchParams.get('mode') || 'for_you').toLowerCase();
  const authorId = num(url.searchParams.get('author_id'));
  const kind = clean(url.searchParams.get('kind'), 40);
  const sdg = num(url.searchParams.get('sdg'));

  const where = ['p.hidden=0'];
  const args = [];
  if (authorId) { where.push('p.author_id=?'); args.push(authorId); }
  if (kind) { where.push('p.kind=?'); args.push(kind); }
  if (sdg) { where.push('p.sdg=?'); args.push(sdg); }
  const rows = (await env.DB.prepare(`${POST_SELECT} WHERE ${where.join(' AND ')} ORDER BY p.created_at DESC LIMIT 400`)
    .bind(...args).all()).results || [];

  const liked = new Set();
  const following = new Set();
  const seen = new Set();
  if (viewer) {
    const [likes, follows, views] = await Promise.all([
      env.DB.prepare('SELECT post_id FROM post_likes WHERE user_id=?').bind(viewer.id).all(),
      env.DB.prepare('SELECT followee_id FROM follows WHERE follower_id=?').bind(viewer.id).all(),
      env.DB.prepare('SELECT post_id FROM post_views WHERE user_id=? AND seen_at>?')
        .bind(viewer.id, new Date(Date.now() - 2 * 86400000).toISOString()).all(),
    ]);
    for (const x of likes.results || []) liked.add(Number(x.post_id));
    for (const x of follows.results || []) following.add(Number(x.followee_id));
    for (const x of views.results || []) seen.add(Number(x.post_id));
    viewer.__interests = new Set((viewer.interest || '').split(/[,\s]+/).map((s) => parseInt(s, 10)).filter((n) => n >= 1 && n <= 17));
  }

  let list = rows;
  if (mode === 'following') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Sign in to see people you follow.');
    const own = rows.filter((r) => following.has(Number(r.author_id)) || Number(r.author_id) === viewer.id);
    list = own;
    if (!list.length) list = rows;
  }

  const ranked = rankCandidates(list, { viewer, liked, following, seen, mode, offset, limit });
  const out = ranked.map((item) => postJson(item.row, liked.has(Number(item.row.id)), { score: item.score, reason: item.reason, reasons: item.reasons }));

  if (viewer && out.length) {
    const at = nowIso();
    const stmts = out.map((p) => env.DB.prepare('INSERT OR IGNORE INTO post_views (user_id,post_id,seen_at) VALUES (?,?,?)')
      .bind(viewer.id, Number(p.id), at));
    if (ctxSafe(env)) await env.DB.batch(stmts);
  }
  return json(out);
}
const ctxSafe = () => true;

async function createPost(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const text = clean(b.text, 2000);
  if (text.length < 2) throw new HttpError(400, 'empty_post', 'Write something before posting.');
  const kind = clean(b.kind || b.type, 30).toUpperCase() || 'UPDATE';
  const sdg = num(b.sdg);
  const media = normalizeMediaInput(b);
  const legacyMedia = safeMediaUrl(b.media_url || b.url) || media[0]?.url || null;
  const link = clean(b.link_url || b.link, 500) || null;
  const rawImpact = b.impact_value == null ? null : Number(b.impact_value);
  const impactValue = Number.isFinite(rawImpact) ? clamp(rawImpact, 0, 10) : null;
  const latitude = Number.isFinite(Number(b.latitude)) ? clamp(Number(b.latitude), -90, 90) : null;
  const longitude = Number.isFinite(Number(b.longitude)) ? clamp(Number(b.longitude), -180, 180) : null;

  let job = null;
  const jobId = clean(b.video_job_id, 80);
  if (jobId) {
    job = await env.DB.prepare('SELECT * FROM video_jobs WHERE id=? AND user_id=?').bind(jobId, u.id).first();
    if (!job) throw new HttpError(404, 'video_job_not_found', 'That video upload could not be found.');
  }
  const video = media.find((m) => m.type === 'VIDEO');
  const videoHls = safeMediaUrl(b.video_hls_url) || safeMediaUrl(video?.hls_url) || safeMediaUrl(job?.hls_url);
  const videoPoster = safeMediaUrl(b.video_poster_url) || safeMediaUrl(video?.poster_url) || safeMediaUrl(job?.poster_url);
  const videoDuration = Number.isFinite(Number(b.video_duration_seconds))
    ? Number(b.video_duration_seconds) : (video?.duration_seconds ?? (job?.duration_seconds == null ? null : Number(job.duration_seconds)));
  if (video && videoHls && !video.hls_url) video.hls_url = videoHls;
  const mediaType = video ? 'VIDEO' : media.length > 1 ? 'GALLERY' : media.length ? 'IMAGE' : 'TEXT';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO posts (author_id,text,kind,sdg,impact_value,impact_label,confidence_score,confidence_label,confidence_factors,
      media_url,link_url,media_json,media_type,video_hls_url,video_poster_url,video_duration_seconds,latitude,longitude,source,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'USER',?,?)`)
    .bind(u.id, text, kind, sdg && sdg >= 1 && sdg <= 17 ? sdg : null,
      impactValue, impactValue == null ? 'Awaiting ratings' : impactLabelFor(impactValue, 0),
      0, 'Low confidence', JSON.stringify({ ratings: 0, method: 'weighted ratings + engagement + author trust' }),
      legacyMedia, link, media.length ? JSON.stringify(media) : null, mediaType,
      videoHls, videoPoster, videoDuration, latitude, longitude, at, at).run();
  const postId = r.meta.last_row_id;
  if (job) {
    await env.DB.prepare('UPDATE video_jobs SET post_id=?, updated_at=? WHERE id=?').bind(postId, at, job.id).run();
  }
  const row = await getPostRow(env, postId);
  return json(postJson(row, false, null), 201);
}

async function toggleLike(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT id, author_id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const has = await env.DB.prepare('SELECT 1 x FROM post_likes WHERE post_id=? AND user_id=?').bind(id, u.id).first();
  if (has) {
    await env.DB.batch([
      env.DB.prepare('DELETE FROM post_likes WHERE post_id=? AND user_id=?').bind(id, u.id),
      env.DB.prepare('UPDATE posts SET like_count=MAX(0,like_count-1) WHERE id=?').bind(id),
    ]);
  } else {
    await env.DB.batch([
      env.DB.prepare('INSERT INTO post_likes (post_id,user_id,created_at) VALUES (?,?,?)').bind(id, u.id, nowIso()),
      env.DB.prepare('UPDATE posts SET like_count=like_count+1 WHERE id=?').bind(id),
    ]);
    await notify(env, post.author_id, 'like', `${u.name || 'Someone'} liked your update`, 'Your impact update is getting attention.', u.id, id);
    await recomputeImpact(env, id);
  }
  const row = await getPostRow(env, id);
  return json({ ok: true, liked: !has, likes: row.like_count });
}

async function addComment(req, env, id) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const text = clean(b.text, 800);
  if (!text) throw new HttpError(400, 'empty_comment', 'Write a comment first.');
  const post = await env.DB.prepare('SELECT id, author_id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const at = nowIso();
  const r = await env.DB.prepare('INSERT INTO post_comments (post_id,user_id,text,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, text, at).run();
  await env.DB.prepare('UPDATE posts SET comment_count=comment_count+1 WHERE id=?').bind(id).run();
  await notify(env, post.author_id, 'comment', `${u.name || 'Someone'} commented on your update`, text, u.id, id);
  await recomputeImpact(env, id);
  return json({ id: String(r.meta.last_row_id), text, author_id: String(u.id), author_name: u.name,
    author_handle: u.handle || handleFor(u.name, u.id), created_at: at }, 201);
}

async function listComments(req, env, id) {
  const rows = (await env.DB.prepare(`SELECT c.*, u.name author_name, u.handle author_handle
    FROM post_comments c JOIN users u ON u.id=c.user_id WHERE c.post_id=? AND c.hidden=0 ORDER BY c.created_at ASC LIMIT 200`)
    .bind(id).all()).results || [];
  return json(rows.map((c) => ({ id: String(c.id), text: c.text, author_id: String(c.user_id),
    author_name: c.author_name, author_handle: c.author_handle, created_at: c.created_at })));
}

async function castImpactVote(req, env, id) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const rawStars = parseInt(b.stars, 10);
  if (!Number.isInteger(rawStars) || rawStars < 1 || rawStars > 5)
    throw new HttpError(400, 'invalid_stars', 'Choose a rating from 1 to 5.');
  const stars = rawStars;
  const post = await env.DB.prepare(`${POST_SELECT} WHERE p.id=? AND p.hidden=0`).bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  if (Number(post.author_id) === u.id) throw new HttpError(400, 'self_vote', 'You cannot rate your own update.');
  const cats = Array.isArray(b.categories) ? b.categories.filter((c) => IMPACT_CATEGORIES.has(c)).slice(0, 6) : [];
  const note = clean(b.note, 300) || null;
  await env.DB.prepare(`INSERT INTO post_impact_votes (post_id,user_id,stars,categories,note,created_at) VALUES (?,?,?,?,?,?)
    ON CONFLICT(post_id,user_id) DO UPDATE SET stars=excluded.stars, categories=excluded.categories, note=excluded.note, created_at=excluded.created_at`)
    .bind(id, u.id, stars, JSON.stringify(cats), note, nowIso()).run();
  await notify(env, post.author_id, 'impact', `${u.name || 'Someone'} rated your impact ${stars}/5`, note || 'A verified community member rated this update.', u.id, id);
  const impact = await recomputeImpact(env, id);
  const mine = JSON.parse((await env.DB.prepare('SELECT categories FROM post_impact_votes WHERE post_id=? AND user_id=?').bind(id, u.id).first()).categories || '[]');
  return json({ ok: true, ...impact, my_vote: { stars, categories: mine, note } });
}

async function sharePost(req, env, id) {
  const post = await env.DB.prepare('SELECT id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  await env.DB.prepare('UPDATE posts SET share_count=share_count+1 WHERE id=?').bind(id).run();
  await recomputeImpact(env, id);
  const row = await getPostRow(env, id);
  return json({ ok: true, shares: row.share_count });
}

/* ---------------- admin ---------------- */
async function adminRoutes(req, env, url) {
  const admin = await requireAdmin(req, env);
  const path = url.pathname;
  if (path === '/api/v1/admin/stats') {
    const one = async (sql, ...a) => (await env.DB.prepare(sql).bind(...a).first()) || {};
    const [users, posts, comments, likes, votes, testers, invited, hidden, dau, wau] = await Promise.all([
      one('SELECT COUNT(*) c FROM users'),
      one('SELECT COUNT(*) c FROM posts WHERE hidden=0'),
      one('SELECT COUNT(*) c FROM post_comments WHERE hidden=0'),
      one('SELECT COUNT(*) c FROM post_likes'),
      one('SELECT COUNT(*) c FROM post_impact_votes'),
      one('SELECT COUNT(*) c FROM testers'),
      one("SELECT COUNT(*) c FROM testers WHERE status IN ('invited','active')"),
      one('SELECT COUNT(*) c FROM posts WHERE hidden=1'),
      one('SELECT COUNT(DISTINCT user_id) c FROM login_events WHERE at>?', new Date(Date.now() - 86400000).toISOString()),
      one('SELECT COUNT(DISTINCT user_id) c FROM login_events WHERE at>?', new Date(Date.now() - 7 * 86400000).toISOString()),
    ]);
    const bySdg = (await env.DB.prepare('SELECT sdg, COUNT(*) c FROM posts WHERE hidden=0 AND sdg IS NOT NULL GROUP BY sdg ORDER BY c DESC LIMIT 17').all()).results || [];
    const top = (await env.DB.prepare(`${POST_SELECT} WHERE p.hidden=0 ORDER BY p.impact_value DESC LIMIT 5`).all()).results || [];
    const recent = (await env.DB.prepare(`${POST_SELECT} WHERE p.hidden=0 ORDER BY p.created_at DESC LIMIT 5`).all()).results || [];
    const avg = (await env.DB.prepare('SELECT COALESCE(AVG(impact_value),0) a, COALESCE(AVG(confidence_score),0) c FROM posts WHERE hidden=0').first()) || {};
    return json({ ok: true, totals: {
      users: users.c || 0, posts: posts.c || 0, comments: comments.c || 0, likes: likes.c || 0,
      impact_votes: votes.c || 0, testers: testers.c || 0, testers_invited: invited.c || 0,
      hidden_posts: hidden.c || 0, active_users_24h: dau.c || 0, active_users_7d: wau.c || 0,
      avg_impact: Number((avg.a || 0).toFixed(2)), avg_confidence: Math.round(avg.c || 0),
    }, by_sdg: bySdg.map((r) => ({ sdg: r.sdg, name: SDG_NAMES[r.sdg] || null, count: r.c })),
      top_posts: top.map((r) => postJson(r, false, null)), recent_posts: recent.map((r) => postJson(r, false, null)) });
  }
  if (path === '/api/v1/admin/users') {
    const search = clean(url.searchParams.get('search') || url.searchParams.get('q'), 80);
    const limit = clamp(parseInt(url.searchParams.get('limit') || '50', 10) || 50, 1, 200);
    const like = `%${search.replace(/[%_]/g, '')}%`;
    const where = search ? 'WHERE email LIKE ? OR name LIKE ? OR role LIKE ?' : '';
    const args = search ? [like, like, like] : [];
    const rows = (await env.DB.prepare(`SELECT id,email,email_verified,name,role,country,city,created_at,last_login_at,login_count,handle
      FROM users ${where} ORDER BY created_at DESC LIMIT ?`).bind(...args, limit).all()).results || [];
    return json(rows.map((u) => ({ id: String(u.id), email: u.email, name: u.name, full_name: u.name, role: u.role,
      handle: u.handle, country: u.country, city: u.city, created_at: u.created_at,
      last_login_at: u.last_login_at, login_count: u.login_count, email_verified: !!u.email_verified })));
  }
  if (path === '/api/v1/admin/testers' && req.method === 'GET') {
    const limit = clamp(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 1, 500);
    const status = clean(url.searchParams.get('status'), 20);
    const rows = (await env.DB.prepare(`SELECT * FROM testers ${status ? 'WHERE status=?' : ''} ORDER BY created_at DESC LIMIT ?`)
      .bind(...(status ? [status, limit] : [limit])).all()).results || [];
    const total = (await env.DB.prepare('SELECT COUNT(*) c FROM testers').first()).c || 0;
    return json({ ok: true, total, rows });
  }
  if (path === '/api/v1/admin/testers.csv') {
    const rows = (await env.DB.prepare('SELECT name,email,country,device,android_version,source,status,created_at FROM testers ORDER BY created_at DESC').all()).results || [];
    const cols = ['name', 'email', 'country', 'device', 'android_version', 'source', 'status', 'created_at'];
    const cell = (v) => { let s = v == null ? '' : String(v); if (/^[=+\-@\t\r]/.test(s)) s = "'" + s; return '"' + s.replace(/"/g, '""') + '"'; };
    const csv = [cols.join(',')].concat(rows.map((r) => cols.map((c) => cell(r[c])).join(','))).join('\n');
    return new Response(csv, { headers: { 'content-type': 'text/csv; charset=utf-8',
      'content-disposition': 'attachment; filename="masareen-testers.csv"', 'cache-control': 'no-store' } });
  }
  const statusMatch = /^\/api\/v1\/admin\/testers\/(\d+)\/status$/.exec(path);
  if (statusMatch && req.method === 'POST') {
    const b = await req.json().catch(() => ({}));
    const status = ['pending', 'invited', 'active', 'declined'].includes(b.status) ? b.status : null;
    if (!status) throw new HttpError(400, 'invalid_status', 'Choose pending, invited, active or declined.');
    await env.DB.prepare('UPDATE testers SET status=?, invited_at=CASE WHEN ?=\'invited\' THEN ? ELSE invited_at END WHERE id=?')
      .bind(status, status, nowIso(), Number(statusMatch[1])).run();
    return json({ ok: true });
  }
  const hideMatch = /^\/api\/v1\/admin\/posts\/(\d+)\/hide$/.exec(path);
  if (hideMatch && req.method === 'POST') {
    const b = await req.json().catch(() => ({}));
    await env.DB.prepare('UPDATE posts SET hidden=? WHERE id=?').bind(b.hidden === false ? 0 : 1, Number(hideMatch[1])).run();
    return json({ ok: true });
  }
  if (path === '/api/v1/admin/review-queue' || path === '/api/v1/admin/submissions') return json([]);
  throw new HttpError(404, 'not_found', 'Unknown admin route.');
}

/* ---------------- courses ---------------- */
const COURSE_LEVELS = new Set(['Beginner', 'Intermediate', 'Advanced']);

function courseJson(c, enrolledByMe) {
  return {
    id: String(c.id), title: c.title, description: c.description || null, provider: c.provider || null,
    level: c.level || 'Beginner', sdg: c.sdg == null ? null : Number(c.sdg),
    lessons: Number(c.lessons || 0), duration_min: Number(c.duration_min || 0),
    thumbnail: c.thumbnail || null, status: c.status || 'PUBLISHED',
    enrolled_count: Number(c.enrolled_count || 0), enrolled_by_me: !!enrolledByMe,
    author: { id: String(c.author_id), name: c.author_name || 'MASAREEN' }, created_at: c.created_at,
  };
}

async function listCourses(env, viewer) {
  const rows = (await env.DB.prepare(`SELECT c.*, u.name author_name,
    (SELECT COUNT(*) FROM course_enrollments e WHERE e.course_id=c.id) enrolled_count
    FROM courses c LEFT JOIN users u ON u.id=c.author_id
    WHERE c.status='PUBLISHED' ORDER BY c.created_at DESC LIMIT 100`).all()).results || [];
  const enrolled = new Set();
  if (viewer) {
    const mine = (await env.DB.prepare('SELECT course_id FROM course_enrollments WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const m of mine) enrolled.add(Number(m.course_id));
  }
  return rows.map((c) => courseJson(c, enrolled.has(Number(c.id))));
}

async function createCourse(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 120);
  const description = clean(b.description, 2000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Course title must be at least 3 characters.');
  const level = COURSE_LEVELS.has(b.level) ? b.level : 'Beginner';
  const sdg = num(b.sdg);
  if (sdg != null && (!Number.isInteger(sdg) || sdg < 1 || sdg > 17)) throw new HttpError(400, 'invalid_sdg', 'Choose an SDG from 1 to 17.');
  const lessons = clamp(parseInt(b.lessons, 10) || 0, 0, 500);
  const duration = clamp(parseInt(b.duration_min, 10) || 0, 0, 60000);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO courses (author_id,title,description,provider,level,sdg,lessons,duration_min,thumbnail,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,'PUBLISHED',?)`)
    .bind(u.id, title, description || null, clean(b.provider, 120) || u.name || null, level, sdg, lessons, duration,
      clean(b.thumbnail, 500) || null, at).run();
  const row = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(r.meta.last_row_id).first();
  return json(courseJson(row, false), 201);
}

async function enrollCourse(req, env, id) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT id FROM courses WHERE id=?').bind(id).first();
  if (!course) throw new HttpError(404, 'course_not_found', 'Course not found.');
  const has = await env.DB.prepare('SELECT 1 x FROM course_enrollments WHERE course_id=? AND user_id=?').bind(id, u.id).first();
  if (!has) await env.DB.prepare('INSERT INTO course_enrollments (course_id,user_id,created_at) VALUES (?,?,?)').bind(id, u.id, nowIso()).run();
  const count = (await env.DB.prepare('SELECT COUNT(*) c FROM course_enrollments WHERE course_id=?').bind(id).first()).c || 0;
  return json({ ok: true, enrolled: true, enrolled_count: count });
}

/* ---------------- events ---------------- */
function eventJson(e, attending) {
  return {
    id: String(e.id), title: e.title, description: e.description || null,
    starts_at: e.starts_at, ends_at: e.ends_at || null, location: e.location || null,
    is_online: !!e.is_online, link_url: e.link_url || null,
    sdg: e.sdg == null ? null : Number(e.sdg), capacity: e.capacity == null ? null : Number(e.capacity),
    status: e.status || 'PUBLISHED', attendees_count: Number(e.attendees_count || 0),
    attending: !!attending, author: { id: String(e.author_id), name: e.author_name || 'MASAREEN' },
    created_at: e.created_at,
  };
}

async function listEvents(env, viewer) {
  const rows = (await env.DB.prepare(`SELECT e.*, u.name author_name,
    (SELECT COUNT(*) FROM event_attendees a WHERE a.event_id=e.id) attendees_count
    FROM events e LEFT JOIN users u ON u.id=e.author_id
    WHERE e.status='PUBLISHED' ORDER BY e.starts_at ASC LIMIT 100`).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const going = (await env.DB.prepare('SELECT event_id FROM event_attendees WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const g of going) mine.add(Number(g.event_id));
  }
  return rows.map((e) => eventJson(e, mine.has(Number(e.id))));
}

async function createEvent(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 140);
  const starts = clean(b.starts_at, 40);
  const ends = clean(b.ends_at, 40);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Event title must be at least 3 characters.');
  const t = Date.parse(starts);
  if (!Number.isFinite(t)) throw new HttpError(400, 'invalid_date', 'Add a valid start date and time.');
  if (ends && !Number.isFinite(Date.parse(ends))) throw new HttpError(400, 'invalid_date', 'End date is not valid.');
  const isOnline = b.is_online === true || b.is_online === 'true' || b.is_online === 1;
  const location = clean(b.location, 200);
  const link = clean(b.link_url, 500);
  if (!isOnline && !location) throw new HttpError(400, 'invalid_location', 'Add a venue or mark the event as online.');
  if (isOnline && !link) throw new HttpError(400, 'invalid_link', 'Add the online meeting link.');
  const sdg = num(b.sdg);
  if (sdg != null && (!Number.isInteger(sdg) || sdg < 1 || sdg > 17)) throw new HttpError(400, 'invalid_sdg', 'Choose an SDG from 1 to 17.');
  const capacity = num(b.capacity);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO events (author_id,title,description,starts_at,ends_at,location,is_online,link_url,sdg,capacity,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,'PUBLISHED',?)`)
    .bind(u.id, title, clean(b.description, 2000) || null, new Date(t).toISOString(), ends ? new Date(Date.parse(ends)).toISOString() : null,
      location || null, isOnline ? 1 : 0, link || null, sdg, capacity != null ? clamp(Math.trunc(capacity), 1, 1000000) : null, at).run();
  const row = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(r.meta.last_row_id).first();
  return json(eventJson(row, false), 201);
}

async function joinEvent(req, env, id) {
  const u = await requireUser(req, env);
  const ev = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(id).first();
  if (!ev) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const has = await env.DB.prepare('SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).first();
  if (has) {
    await env.DB.prepare('DELETE FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).run();
  } else {
    const count = (await env.DB.prepare('SELECT COUNT(*) c FROM event_attendees WHERE event_id=?').bind(id).first()).c || 0;
    if (ev.capacity != null && count >= ev.capacity) throw new HttpError(409, 'event_full', 'This event is full.');
    await env.DB.prepare('INSERT INTO event_attendees (event_id,user_id,created_at) VALUES (?,?,?)').bind(id, u.id, nowIso()).run();
    await notify(env, ev.author_id, 'event', `${u.name || 'Someone'} is attending ${ev.title}`, 'A new attendee joined your event.', u.id, null);
  }
  const count = (await env.DB.prepare('SELECT COUNT(*) c FROM event_attendees WHERE event_id=?').bind(id).first()).c || 0;
  return json({ ok: true, attending: !has, attendees_count: count });
}

/* ---------------- programs, projects and tasks ---------------- */
const PROGRAM_STATUSES = new Set(['PLANNED', 'ACTIVE', 'COMPLETED', 'PAUSED']);
const TASK_STATUSES = new Set(['OPEN', 'IN_PROGRESS', 'SUBMITTED', 'VERIFIED']);

function skillsArray(v) {
  if (Array.isArray(v)) return v.map((s) => clean(String(s), 40)).filter(Boolean).slice(0, 12);
  if (typeof v === 'string') {
    const raw = v.trim();
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return skillsArray(parsed);
    } catch { /* comma separated below */ }
    return raw.split(',').map((s) => clean(s, 40)).filter(Boolean).slice(0, 12);
  }
  return [];
}

function validSdg(v) {
  const n = num(v);
  return n != null && Number.isInteger(n) && n >= 1 && n <= 17 ? n : null;
}

function programJson(p, enrolledByMe) {
  return {
    id: String(p.id), title: p.title, description: p.description || null,
    category: p.category || null, organization: p.organization || null,
    sdg: p.sdg == null ? null : Number(p.sdg), status: p.status || 'ACTIVE',
    budget: Number(p.budget || 0), currency: p.currency || 'EGP',
    country: p.country || null, governorate: p.governorate || null,
    start_date: p.start_date || null, end_date: p.end_date || null,
    target_beneficiaries: Number(p.target_beneficiaries || 0),
    members_count: Number(p.members_count || 0), projects_count: Number(p.projects_count || 0),
    tasks_count: Number(p.tasks_count || 0), enrolled_by_me: !!enrolledByMe,
    author: { id: String(p.author_id), name: p.author_name || 'MASAREEN' },
    created_at: p.created_at,
  };
}

async function listPrograms(env, viewer) {
  const rows = (await env.DB.prepare(`SELECT p.*, u.name author_name,
    (SELECT COUNT(*) FROM program_members m WHERE m.program_id=p.id) members_count,
    (SELECT COUNT(*) FROM projects x WHERE x.program_id=p.id) projects_count,
    (SELECT COUNT(*) FROM tasks t WHERE t.program_id=p.id) tasks_count
    FROM programs p LEFT JOIN users u ON u.id=p.author_id
    ORDER BY p.created_at DESC LIMIT 100`).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const joined = (await env.DB.prepare('SELECT program_id FROM program_members WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const j of joined) mine.add(Number(j.program_id));
  }
  return rows.map((p) => programJson(p, mine.has(Number(p.id))));
}

function taskJson(t) {
  return {
    id: String(t.id), program_id: t.program_id == null ? null : String(t.program_id),
    project_id: t.project_id == null ? null : String(t.project_id),
    assignee_id: t.assignee_id == null ? null : String(t.assignee_id),
    title: t.title, description: t.description || null, status: t.status || 'OPEN',
    due_at: t.due_at || null, location: t.location || null,
    evidence_required: !!t.evidence_required, assignee_name: t.assignee_name || null,
    created_at: t.created_at,
  };
}

async function getProgram(env, viewer, id) {
  const p = await env.DB.prepare(`SELECT p.*, u.name author_name,
    (SELECT COUNT(*) FROM program_members m WHERE m.program_id=p.id) members_count,
    (SELECT COUNT(*) FROM projects x WHERE x.program_id=p.id) projects_count,
    (SELECT COUNT(*) FROM tasks t WHERE t.program_id=p.id) tasks_count
    FROM programs p LEFT JOIN users u ON u.id=p.author_id WHERE p.id=?`).bind(id).first();
  if (!p) throw new HttpError(404, 'program_not_found', 'Program not found.');
  const member = viewer ? await env.DB.prepare('SELECT 1 x FROM program_members WHERE program_id=? AND user_id=?')
    .bind(id, viewer.id).first() : null;
  const out = programJson(p, !!member);
  const tasks = (await env.DB.prepare(`SELECT t.*, u.name assignee_name FROM tasks t
    LEFT JOIN users u ON u.id=t.assignee_id WHERE t.program_id=? ORDER BY t.created_at ASC`).bind(id).all()).results || [];
  const projects = (await env.DB.prepare(`SELECT x.*, u.name owner_name,
    (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members
    FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.program_id=? ORDER BY x.created_at DESC`)
    .bind(id).all()).results || [];
  out.tasks = tasks.map(taskJson);
  out.projects = projects.map((x) => projectJson(x));
  return out;
}

async function createProgram(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 140);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Program title must be at least 3 characters.');
  const goals = Array.isArray(b.sdg_goals) ? b.sdg_goals : [];
  const sdg = validSdg(b.sdg != null ? b.sdg : goals[0]);
  const status = PROGRAM_STATUSES.has(b.status) ? b.status : 'ACTIVE';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO programs
    (author_id,title,description,category,organization,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(u.id, title, clean(b.description, 3000) || null, clean(b.category, 80) || null,
      clean(b.organization, 140) || u.org || null, sdg, status,
      Math.max(0, num(b.budget) || 0), clean(b.currency, 8) || 'EGP',
      clean(b.country, 60) || u.country || null, clean(b.governorate, 80) || null,
      clean(b.start_date, 40) || null, clean(b.end_date, 40) || null,
      Math.max(0, Math.trunc(num(b.target_beneficiaries) || 0)), at).run();
  const id = r.meta.last_row_id;
  await env.DB.prepare('INSERT OR IGNORE INTO program_members (program_id,user_id,role,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, 'OWNER', at).run();
  return json(await getProgram(env, u, id), 201);
}

async function enrollProgram(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM programs WHERE id=?').bind(id).first();
  if (!p) throw new HttpError(404, 'program_not_found', 'Program not found.');
  const has = await env.DB.prepare('SELECT 1 x FROM program_members WHERE program_id=? AND user_id=?').bind(id, u.id).first();
  if (!has) {
    await env.DB.prepare('INSERT INTO program_members (program_id,user_id,role,created_at) VALUES (?,?,?,?)')
      .bind(id, u.id, 'MEMBER', nowIso()).run();
    await notify(env, p.author_id, 'program', `${u.name || 'Someone'} joined ${p.title}`, 'A new member joined your program.', u.id, null);
  }
  return json(await getProgram(env, u, id));
}

async function createTask(req, env, programId) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM programs WHERE id=?').bind(programId).first();
  if (!p) throw new HttpError(404, 'program_not_found', 'Program not found.');
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Task title must be at least 3 characters.');
  const assignee = num(b.assignee_id);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO tasks
    (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?)`)
    .bind(programId, num(b.project_id), assignee, title, clean(b.description, 1500) || null,
      TASK_STATUSES.has(b.status) ? b.status : 'OPEN', clean(b.due_at, 40) || null,
      clean(b.location, 160) || null, b.evidence_required === true ? 1 : 0, at).run();
  if (assignee && Number(assignee) !== Number(u.id))
    await notify(env, assignee, 'task', `New task: ${title}`, `Assigned in ${p.title}.`, u.id, null);
  const row = await env.DB.prepare('SELECT t.*, u.name assignee_name FROM tasks t LEFT JOIN users u ON u.id=t.assignee_id WHERE t.id=?')
    .bind(r.meta.last_row_id).first();
  return json(taskJson(row), 201);
}

function projectJson(x) {
  return {
    id: String(x.id), program_id: x.program_id == null ? null : String(x.program_id),
    title: x.title, description: x.description || null, category: x.category || 'Community',
    sdg: x.sdg == null ? null : Number(x.sdg), cover: x.cover || null,
    goal: Number(x.goal || 0), raised: Number(x.raised || 0), members: Number(x.members || 0),
    status: x.status || 'ACTIVE', owner_name: x.owner_name || 'MASAREEN',
    created_at: x.created_at,
  };
}

async function listProjects(env, viewer) {
  const rows = (await env.DB.prepare(`SELECT x.*, u.name owner_name,
    (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members
    FROM projects x LEFT JOIN users u ON u.id=x.author_id ORDER BY x.created_at DESC LIMIT 100`).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const joined = (await env.DB.prepare('SELECT project_id FROM project_members WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const j of joined) mine.add(Number(j.project_id));
  }
  return rows.map((x) => ({ ...projectJson(x), joined: mine.has(Number(x.id)) }));
}

async function createProject(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 140);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Project title must be at least 3 characters.');
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO projects
    (program_id,author_id,title,description,category,sdg,cover,goal,raised,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,'ACTIVE',?)`)
    .bind(num(b.program_id), u.id, title, clean(b.description, 2000) || null,
      clean(b.category, 80) || 'Community', validSdg(b.sdg), clean(b.cover, 500) || null,
      Math.max(0, num(b.goal) || 0), Math.max(0, num(b.raised) || 0), at).run();
  const id = r.meta.last_row_id;
  await env.DB.prepare('INSERT OR IGNORE INTO project_members (project_id,user_id,role,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, 'OWNER', at).run();
  const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
    .bind(id).first();
  return json(projectJson(row), 201);
}

async function joinProject(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM projects WHERE id=?').bind(id).first();
  if (!p) throw new HttpError(404, 'project_not_found', 'Project not found.');
  const has = await env.DB.prepare('SELECT 1 x FROM project_members WHERE project_id=? AND user_id=?').bind(id, u.id).first();
  if (!has) {
    await env.DB.prepare('INSERT INTO project_members (project_id,user_id,role,created_at) VALUES (?,?,?,?)')
      .bind(id, u.id, 'MEMBER', nowIso()).run();
    await notify(env, p.author_id, 'project', `${u.name || 'Someone'} joined ${p.title}`, 'A new member joined your project.', u.id, null);
  }
  const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
    .bind(id).first();
  return json({ ...projectJson(row), joined: true });
}

async function taskRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (path === '/api/v1/tasks' && req.method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const mine = url.searchParams.get('mine') === '1';
    const programId = num(url.searchParams.get('program_id'));
    const rows = (await env.DB.prepare(`SELECT t.*, u.name assignee_name FROM tasks t
      LEFT JOIN users u ON u.id=t.assignee_id
      WHERE (?=0 OR t.assignee_id=?) AND (?=0 OR t.program_id=?)
      ORDER BY t.created_at DESC LIMIT 100`)
      .bind(mine ? 1 : 0, viewer.id, programId || 0, programId || 0).all()).results || [];
    return json(rows.map(taskJson));
  }
  const statusMatch = /^\/api\/v1\/tasks\/(\d+)\/status$/.exec(path);
  if (statusMatch && req.method === 'POST') {
    const u = await requireUser(req, env);
    const b = await req.json().catch(() => ({}));
    const status = String(b.status || '').toUpperCase();
    if (!TASK_STATUSES.has(status)) throw new HttpError(400, 'invalid_status', 'Unknown task status.');
    const task = await env.DB.prepare('SELECT * FROM tasks WHERE id=?').bind(Number(statusMatch[1])).first();
    if (!task) throw new HttpError(404, 'task_not_found', 'Task not found.');
    if (Number(task.assignee_id) !== Number(u.id) && Number(task.author_id || 0) !== Number(u.id))
      throw new HttpError(403, 'forbidden', 'Only the assignee can update this task.');
    await env.DB.prepare('UPDATE tasks SET status=? WHERE id=?').bind(status, task.id).run();
    const row = await env.DB.prepare('SELECT t.*, u.name assignee_name FROM tasks t LEFT JOIN users u ON u.id=t.assignee_id WHERE t.id=?')
      .bind(task.id).first();
    return json(taskJson(row));
  }
  return null;
}

/* ---------------- opportunity marketplace ---------------- */
const OPPORTUNITY_TYPES = new Set(['JOB', 'INTERNSHIP', 'GRANT', 'VOLUNTEER', 'TRAINING', 'CSR']);

function opportunityJson(o, applied) {
  return {
    id: String(o.id), title: o.title, description: o.description || null,
    type: o.type || 'VOLUNTEER', skills: skillsArray(o.skills), sdg: o.sdg == null ? null : Number(o.sdg),
    location: o.location || (o.is_remote ? 'Remote' : null), is_remote: !!o.is_remote,
    deadline: o.deadline || null, min_pms: o.min_pms == null ? null : Number(o.min_pms),
    status: o.status || 'OPEN', applications_count: Number(o.applications_count || 0),
    applied: !!applied, author: { id: String(o.author_id), name: o.author_name || 'MASAREEN' },
    created_at: o.created_at,
  };
}

async function listOpportunities(env, viewer) {
  const rows = (await env.DB.prepare(`SELECT o.*, u.name author_name,
    (SELECT COUNT(*) FROM opportunity_applications a WHERE a.opportunity_id=o.id) applications_count
    FROM opportunities o LEFT JOIN users u ON u.id=o.author_id
    WHERE o.status='OPEN' ORDER BY o.created_at DESC LIMIT 100`).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const applied = (await env.DB.prepare('SELECT opportunity_id FROM opportunity_applications WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const a of applied) mine.add(Number(a.opportunity_id));
  }
  return rows.map((o) => opportunityJson(o, mine.has(Number(o.id))));
}

async function createOpportunity(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 140);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Opportunity title must be at least 3 characters.');
  const type = OPPORTUNITY_TYPES.has(String(b.type || '').toUpperCase()) ? String(b.type).toUpperCase() : 'VOLUNTEER';
  const isRemote = b.is_remote === true || b.is_remote === 1 || b.is_remote === 'true';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO opportunities
    (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,'OPEN',?)`)
    .bind(u.id, title, clean(b.description, 2500) || null, type,
      JSON.stringify(skillsArray(b.skills)), validSdg(b.sdg), clean(b.location, 160) || null,
      isRemote ? 1 : 0, clean(b.deadline, 40) || null, num(b.min_pms), at).run();
  const row = await env.DB.prepare('SELECT * FROM opportunities WHERE id=?').bind(r.meta.last_row_id).first();
  return json(opportunityJson(row, false), 201);
}

async function applyOpportunity(req, env, id) {
  const u = await requireUser(req, env);
  const o = await env.DB.prepare('SELECT * FROM opportunities WHERE id=?').bind(id).first();
  if (!o) throw new HttpError(404, 'opportunity_not_found', 'Opportunity not found.');
  if (o.status !== 'OPEN') throw new HttpError(409, 'opportunity_closed', 'This opportunity is closed.');
  const has = await env.DB.prepare('SELECT 1 x FROM opportunity_applications WHERE opportunity_id=? AND user_id=?').bind(id, u.id).first();
  if (has) throw new HttpError(409, 'already_applied', 'You already applied to this opportunity.');
  const b = await req.json().catch(() => ({}));
  await env.DB.prepare('INSERT INTO opportunity_applications (opportunity_id,user_id,note,status,created_at) VALUES (?,?,?,?,?)')
    .bind(id, u.id, clean(b.note, 800) || null, 'SUBMITTED', nowIso()).run();
  await notify(env, o.author_id, 'opportunity', `${u.name || 'Someone'} applied to ${o.title}`, 'Review the new application.', u.id, null);
  const row = await env.DB.prepare(`SELECT o.*, u.name author_name,
    (SELECT COUNT(*) FROM opportunity_applications a WHERE a.opportunity_id=o.id) applications_count
    FROM opportunities o LEFT JOIN users u ON u.id=o.author_id WHERE o.id=?`).bind(id).first();
  return json(opportunityJson(row, true));
}

/* ---------------- evidence, verified claims and passports ---------------- */
const EVIDENCE_KINDS = new Set(['PHOTO', 'VIDEO', 'DOCUMENT', 'GPS', 'SENSOR', 'TESTIMONY']);

function evidenceJson(e) {
  return {
    id: String(e.id), submission_id: e.submission_id == null ? null : String(e.submission_id),
    title: e.title, kind: e.kind || 'DOCUMENT', url: e.url || null, sha256: e.sha256 || null,
    latitude: e.latitude == null ? null : Number(e.latitude), longitude: e.longitude == null ? null : Number(e.longitude),
    captured_at: e.captured_at || null, status: e.status || 'PENDING', created_at: e.created_at,
  };
}

async function createEvidence(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Evidence title must be at least 3 characters.');
  const kind = EVIDENCE_KINDS.has(String(b.kind || '').toUpperCase()) ? String(b.kind).toUpperCase() : 'DOCUMENT';
  const lat = num(b.latitude); const lng = num(b.longitude);
  const r = await env.DB.prepare(`INSERT INTO evidence
    (owner_id,submission_id,title,kind,url,sha256,latitude,longitude,captured_at,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,'PENDING',?)`)
    .bind(u.id, num(b.submission_id), title, kind, clean(b.url, 800) || null, clean(b.sha256, 128) || null,
      lat, lng, clean(b.captured_at, 40) || null, nowIso()).run();
  const row = await env.DB.prepare('SELECT * FROM evidence WHERE id=?').bind(r.meta.last_row_id).first();
  return json(evidenceJson(row), 201);
}

function pipelineJson(p) {
  let steps = [];
  try { steps = JSON.parse(p.steps || '[]'); } catch { steps = []; }
  return {
    id: String(p.id), submission_id: String(p.submission_id), status: p.status || 'AI_REVIEW',
    stage: Number(p.stage || 0), confidence: Number(p.confidence || 0), steps,
    updated_at: p.updated_at, created_at: p.created_at,
  };
}

function submissionJson(s) {
  return {
    id: String(s.id), title: s.title, claim: s.claim || null,
    program_id: s.program_id == null ? null : String(s.program_id),
    task_id: s.task_id == null ? null : String(s.task_id),
    evidence_id: s.evidence_id == null ? null : String(s.evidence_id),
    status: s.status || 'SUBMITTED', confidence: Number(s.confidence || 0),
    pipeline_id: s.pipeline_id == null ? null : String(s.pipeline_id),
    created_at: s.created_at,
  };
}

async function listSubmissions(env, viewer, userId) {
  if (!viewer || Number(viewer.id) !== Number(userId))
    throw new HttpError(403, 'forbidden', 'You can only read your own submissions.');
  const rows = (await env.DB.prepare(`SELECT s.*,
    (SELECT p.id FROM verification_pipelines p WHERE p.submission_id=s.id ORDER BY p.id DESC LIMIT 1) pipeline_id
    FROM submissions s WHERE s.owner_id=? ORDER BY s.created_at DESC LIMIT 100`).bind(userId).all()).results || [];
  return json(rows.map(submissionJson));
}

async function createSubmission(req, env) {
  const u = await requireUser(req, env);
  const b = await req.json().catch(() => ({}));
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Submission title must be at least 3 characters.');
  const claim = clean(b.claim, 2000);
  let evidenceId = num(b.evidence_id);
  if (evidenceId != null) {
    const ev = await env.DB.prepare('SELECT * FROM evidence WHERE id=? AND owner_id=?').bind(evidenceId, u.id).first();
    if (!ev) throw new HttpError(404, 'evidence_not_found', 'Evidence not found.');
  } else {
    const evidenceUrl = clean(b.evidence_url, 800);
    if (evidenceUrl) {
      const ev = await env.DB.prepare(`INSERT INTO evidence (owner_id,title,kind,url,captured_at,status,created_at)
        VALUES (?,?,?,?,?,'PENDING',?)`)
        .bind(u.id, clean(b.evidence_title, 160) || title + ' evidence',
          EVIDENCE_KINDS.has(String(b.evidence_kind || '').toUpperCase()) ? String(b.evidence_kind).toUpperCase() : 'LINK',
          evidenceUrl, nowIso(), nowIso()).run();
      evidenceId = ev.meta.last_row_id;
    }
  }
  const r = await env.DB.prepare(`INSERT INTO submissions
    (owner_id,title,claim,program_id,task_id,evidence_id,status,confidence,created_at)
    VALUES (?,?,?,?,?,?,'SUBMITTED',0,?)`)
    .bind(u.id, title, claim || null, num(b.program_id), num(b.task_id), evidenceId, nowIso()).run();
  if (evidenceId != null)
    await env.DB.prepare('UPDATE evidence SET submission_id=? WHERE id=?').bind(r.meta.last_row_id, evidenceId).run();
  const row = await env.DB.prepare('SELECT * FROM submissions WHERE id=?').bind(r.meta.last_row_id).first();
  return json(submissionJson(row), 201);
}

async function startPipeline(req, env, submissionId) {
  const u = await requireUser(req, env);
  const s = await env.DB.prepare('SELECT * FROM submissions WHERE id=? AND owner_id=?').bind(submissionId, u.id).first();
  if (!s) throw new HttpError(404, 'submission_not_found', 'Submission not found.');
  const existing = await env.DB.prepare('SELECT * FROM verification_pipelines WHERE submission_id=? ORDER BY id DESC LIMIT 1')
    .bind(submissionId).first();
  if (existing) return json({ ok: true, ...pipelineJson(existing) });
  const at = nowIso();
  const stages = ['SUBMITTED', 'AI_REVIEW', 'HUMAN_REVIEW', 'VERIFIED'];
  const steps = [
    { stage: stages[0], status: 'COMPLETE', at },
    { stage: stages[1], status: 'IN_PROGRESS', at },
  ];
  const r = await env.DB.prepare(`INSERT INTO verification_pipelines
    (submission_id,status,stage,confidence,steps,updated_at,created_at) VALUES (?,?,?,?,?,?,?)`)
    .bind(submissionId, 'AI_REVIEW', 1, 35, JSON.stringify(steps), at, at).run();
  await env.DB.prepare("UPDATE submissions SET status='AI_REVIEW', confidence=35 WHERE id=?").bind(submissionId).run();
  if (s.evidence_id != null)
    await env.DB.prepare("UPDATE evidence SET status='UNDER_REVIEW' WHERE id=?").bind(s.evidence_id).run();
  const row = await env.DB.prepare('SELECT * FROM verification_pipelines WHERE id=?').bind(r.meta.last_row_id).first();
  return json({ ok: true, ...pipelineJson(row) }, 201);
}

async function getPipeline(req, env, pipelineId) {
  const u = await requireUser(req, env);
  const row = await env.DB.prepare(`SELECT p.* FROM verification_pipelines p
    JOIN submissions s ON s.id=p.submission_id WHERE p.id=?`).bind(pipelineId).first();
  if (!row) throw new HttpError(404, 'pipeline_not_found', 'Verification pipeline not found.');
  const sub = await env.DB.prepare('SELECT owner_id FROM submissions WHERE id=?').bind(row.submission_id).first();
  if (Number(sub.owner_id) !== Number(u.id)) throw new HttpError(403, 'forbidden', 'This pipeline belongs to another member.');
  return json(pipelineJson(row));
}

async function pipelineForEvidence(req, env, evidenceId) {
  const u = await requireUser(req, env);
  const ev = await env.DB.prepare('SELECT * FROM evidence WHERE id=?').bind(evidenceId).first();
  if (!ev) throw new HttpError(404, 'evidence_not_found', 'Evidence not found.');
  if (Number(ev.owner_id) !== Number(u.id)) throw new HttpError(403, 'forbidden', 'This evidence belongs to another member.');
  const row = ev.submission_id == null ? null : await env.DB.prepare(
    'SELECT * FROM verification_pipelines WHERE submission_id=? ORDER BY id DESC LIMIT 1').bind(ev.submission_id).first();
  return json({ ok: true, evidence: evidenceJson(ev), pipeline: row ? pipelineJson(row) : null });
}

async function passportFor(env, userId) {
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(userId).first();
  if (!user) throw new HttpError(404, 'user_not_found', 'Member not found.');
  const count = async (sql, id) => Number((await env.DB.prepare(sql).bind(id).first()).c || 0);
  const verified = await count("SELECT COUNT(*) c FROM submissions WHERE owner_id=? AND status='VERIFIED'", userId);
  const submissions = await count('SELECT COUNT(*) c FROM submissions WHERE owner_id=?', userId);
  const programs = await count('SELECT COUNT(*) c FROM program_members WHERE user_id=?', userId);
  const projects = await count('SELECT COUNT(*) c FROM project_members WHERE user_id=?', userId);
  const tasks = await count("SELECT COUNT(*) c FROM tasks WHERE assignee_id=? AND status='VERIFIED'", userId);
  const badges = [];
  if (verified > 0) badges.push('Verified contributor');
  if (verified >= 3) badges.push('Evidence champion');
  if (programs > 0) badges.push('Program member');
  if (projects > 0) badges.push('Project builder');
  if (tasks > 0) badges.push('Task finisher');
  const claims = (await env.DB.prepare(`SELECT s.*, (SELECT p.id FROM verification_pipelines p
    WHERE p.submission_id=s.id ORDER BY p.id DESC LIMIT 1) pipeline_id
    FROM submissions s WHERE s.owner_id=? ORDER BY s.created_at DESC LIMIT 20`).bind(userId).all()).results || [];
  return json({
    user_id: String(user.id), name: user.name || 'MASAREEN member', role: user.role || null,
    country: user.country || null, city: user.city || null, avatar_url: user.picture || null,
    verified_claims: verified, submissions, programs, projects, tasks_completed: tasks,
    impact_score: Number((verified * 2 + tasks * 1.5 + projects + programs * 0.5).toFixed(1)),
    badges, claims: claims.map(submissionJson), generated_at: nowIso(),
  });
}

const PMS_WEIGHTS = {
  reliability: 0.15, execution_quality: 0.15, leadership: 0.10, documentation_quality: 0.10,
  verification_confidence: 0.15, learning_velocity: 0.08, technical_skills: 0.10,
  innovation: 0.07, consistency: 0.05, community_impact: 0.05,
};

function safeArray(v, fallback = []) {
  if (Array.isArray(v)) return v;
  if (typeof v !== 'string' || !v) return fallback;
  try { const parsed = JSON.parse(v); return Array.isArray(parsed) ? parsed : fallback; } catch { return fallback; }
}
function safeObject(v) {
  if (v && typeof v === 'object' && !Array.isArray(v)) return v;
  if (typeof v !== 'string' || !v) return {};
  try { const parsed = JSON.parse(v); return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {}; } catch { return {}; }
}
function roleLabel(role) {
  const r = String(role || 'INDIVIDUAL').replace(/_/g, ' ').toLowerCase();
  return r.replace(/\b\w/g, (c) => c.toUpperCase());
}
function pmsTier(total) {
  if (total >= 85) return 'PLATINUM';
  if (total >= 70) return 'GOLD';
  if (total >= 50) return 'SILVER';
  return 'BRONZE';
}
function titleCaseTier(tier) {
  return String(tier || 'BRONZE').charAt(0) + String(tier || 'BRONZE').slice(1).toLowerCase();
}
function profileArray(v, max = 30) {
  if (Array.isArray(v)) return v.slice(0, max).map((x) => typeof x === 'string' ? clean(x, 180) : x);
  if (typeof v === 'string') return v.split(',').map((s) => clean(s, 180)).filter(Boolean).slice(0, max);
  return null;
}
function profileCompleteness(profile, user) {
  const p = profile || {};
  const checks = [
    p.headline, p.summary, p.mission, safeArray(p.expertise).length, safeArray(p.skills).length,
    safeArray(p.languages).length, safeArray(p.education).length || safeArray(p.experience).length,
    p.employment_status, p.website || Object.keys(safeObject(p.social_links)).length,
    safeArray(p.coverage_regions).length || user.country || user.city,
  ];
  return Math.round((checks.filter(Boolean).length / checks.length) * 100);
}
function headlineFromText(text, max = 110) {
  const value = String(text || '').replace(/\s+/g, ' ').trim();
  if (value.length <= max) return value;
  const cut = value.slice(0, max);
  return cut.slice(0, cut.lastIndexOf(' ')) + '…';
}
function pmsDimensions(row, ctx) {
  const fallback = {
    reliability: clamp(40 + ctx.verifiedPosts * 10 + (ctx.emailVerified ? 10 : 0) + ctx.verifiedSubmissions * 6, 0, 100),
    execution_quality: clamp(30 + ctx.verifiedTasks * 15 + ctx.verifiedSubmissions * 10 + ctx.projects * 4, 0, 100),
    leadership: clamp(25 + ctx.ownedPrograms * 12 + ctx.ownedProjects * 8 + (ctx.ownerOrg ? 15 : 0) + ctx.followers * 0.3, 0, 100),
    documentation_quality: clamp(30 + ctx.evidence * 8 + ctx.posts * 2 + ctx.submissions * 3, 0, 100),
    verification_confidence: clamp(ctx.confidence || 50, 0, 100),
    learning_velocity: clamp(30 + ctx.courses * 10 + ctx.certificates * 6, 0, 100),
    technical_skills: clamp(30 + ctx.skills * 10 + ctx.endorsements * 2, 0, 100),
    innovation: clamp(30 + ctx.projects * 6 + ctx.innovationPosts * 10, 0, 100),
    consistency: clamp(30 + ctx.activeMonths * 8, 0, 100),
    community_impact: clamp(20 + ctx.followers * 2 + ctx.recommendations * 8 + ctx.impactPosts * 4, 0, 100),
  };
  if (!row) return fallback;
  const result = {};
  for (const key of Object.keys(PMS_WEIGHTS)) result[key] = Math.round(Number(row[key] ?? fallback[key]));
  return result;
}
function weightedPms(dimensions) {
  let total = 0;
  for (const [key, weight] of Object.entries(PMS_WEIGHTS)) total += Number(dimensions[key] || 0) * weight;
  return Number(total.toFixed(1));
}

async function personnelJson(env, user, viewer) {
  const uid = Number(user.id);
  const profile = await env.DB.prepare('SELECT * FROM user_profiles WHERE user_id=?').bind(uid).first();
  const [postStats, submissionStats, taskStats, evidenceRow, programRow, projectRow, ownedProgramRow, ownedProjectRow,
    recommendationRow, endorsementRows, orgRows, courseRow, pmsRow, followerTotal, followingTotal, growthRow] = await Promise.all([
    env.DB.prepare(`SELECT COUNT(*) c, COALESCE(SUM(impact_value),0) impact, COALESCE(AVG(confidence_score),0) confidence,
      COALESCE(SUM(like_count),0) likes, COALESCE(SUM(comment_count),0) comments, COALESCE(SUM(share_count),0) shares,
      COALESCE(SUM(CASE WHEN confidence_score>=70 THEN 1 ELSE 0 END),0) verified,
      COUNT(DISTINCT substr(created_at,1,7)) months,
      COALESCE(SUM(CASE WHEN kind='IMPACT' THEN 1 ELSE 0 END),0) impact_posts,
      COALESCE(SUM(CASE WHEN kind='INNOVATION' THEN 1 ELSE 0 END),0) innovation_posts
      FROM posts WHERE author_id=? AND hidden=0`).bind(uid).first(),
    env.DB.prepare(`SELECT COUNT(*) c, COALESCE(SUM(CASE WHEN status='VERIFIED' THEN 1 ELSE 0 END),0) verified,
      COALESCE(AVG(confidence),0) confidence FROM submissions WHERE owner_id=?`).bind(uid).first(),
    env.DB.prepare(`SELECT COUNT(*) c, COALESCE(SUM(CASE WHEN status='VERIFIED' THEN 1 ELSE 0 END),0) verified
      FROM tasks WHERE assignee_id=?`).bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM evidence WHERE owner_id=?').bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM program_members WHERE user_id=?').bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM project_members WHERE user_id=?').bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM programs WHERE author_id=?').bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM projects WHERE author_id=?').bind(uid).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM profile_recommendations WHERE user_id=? AND status=\'PUBLISHED\'').bind(uid).first(),
    env.DB.prepare('SELECT skill, COUNT(*) c FROM profile_endorsements WHERE user_id=? GROUP BY skill').bind(uid).all(),
    env.DB.prepare(`SELECT o.*, om.role member_role, om.title member_title, om.start_date, om.end_date
      FROM organization_members om JOIN organizations o ON o.id=om.organization_id
      WHERE om.user_id=? ORDER BY om.created_at DESC`).bind(uid).all(),
    env.DB.prepare('SELECT COUNT(*) c FROM course_enrollments WHERE user_id=?').bind(uid).first(),
    env.DB.prepare('SELECT * FROM pms_scores WHERE user_id=?').bind(uid).first(),
    followCount(env, uid, 'followee_id'),
    followCount(env, uid, 'follower_id'),
    env.DB.prepare(`SELECT COALESCE(SUM(CASE WHEN created_at>=date('now','-30 days') THEN 1 ELSE 0 END),0) recent,
      COALESCE(SUM(CASE WHEN created_at<date('now','-30 days') AND created_at>=date('now','-60 days') THEN 1 ELSE 0 END),0) prior
      FROM posts WHERE author_id=? AND hidden=0`).bind(uid).first(),
  ]);
  const endorsements = endorsementRows.results || [];
  const endorsementBySkill = {};
  for (const row of endorsements) endorsementBySkill[row.skill] = Number(row.c || 0);
  const orgs = orgRows.results || [];
  const skills = safeArray(profile && profile.skills).map((s) => {
    const name = typeof s === 'string' ? s : String(s && s.name || '');
    return { name, endorsements: endorsementBySkill[name] || 0 };
  }).filter((s) => s.name);
  const certificates = safeArray(profile && profile.certificates);
  const publications = safeArray(profile && profile.publications);
  const posts = Number(postStats.c || 0);
  const verifiedPosts = Number(postStats.verified || 0);
  const submissions = Number(submissionStats.c || 0);
  const verifiedSubmissions = Number(submissionStats.verified || 0);
  const tasks = Number(taskStats.c || 0);
  const verifiedTasks = Number(taskStats.verified || 0);
  const evidence = Number(evidenceRow.c || 0);
  const programs = Number(programRow.c || 0);
  const projects = Number(projectRow.c || 0);
  const ownedPrograms = Number(ownedProgramRow.c || 0);
  const ownedProjects = Number(ownedProjectRow.c || 0);
  const recommendations = Number(recommendationRow.c || 0);
  const courses = Number(courseRow.c || 0);
  const followers = Number(followerTotal || 0);
  const following = Number(followingTotal || 0);
  const confidence = Math.round(Number(postStats.confidence || submissionStats.confidence || 0));
  const dimensions = pmsDimensions(pmsRow, {
    verifiedPosts, verifiedSubmissions, verifiedTasks, projects, ownedPrograms, ownedProjects,
    ownerOrg: orgs.some((o) => String(o.member_role).toUpperCase() === 'OWNER'),
    followers, evidence, posts, submissions, confidence, courses, certificates: certificates.length,
    skills: skills.length, endorsements: endorsements.length,
    innovationPosts: Number(postStats.innovation_posts || 0), activeMonths: Number(postStats.months || 0),
    recommendations, impactPosts: Number(postStats.impact_posts || 0), emailVerified: !!user.email_verified,
  });
  const pmsTotal = pmsRow ? Number(pmsRow.total || weightedPms(dimensions)) : weightedPms(dimensions);
  const tier = pmsRow && pmsRow.tier ? pmsRow.tier : pmsTier(pmsTotal);
  const impactScore = Number((Number(postStats.impact || 0) + verifiedSubmissions * 2 + verifiedTasks * 1.5 + projects + programs * 0.5).toFixed(1));
  const trustScore = Number(clamp(
    (posts ? (verifiedPosts / posts) * 35 : 0) + (submissions ? (verifiedSubmissions / submissions) * 35 : 0) +
    (user.email_verified ? 15 : 0) + Math.min(15, recommendations * 3), 0, 100).toFixed(1));
  const engagement = Number(postStats.likes || 0) + Number(postStats.comments || 0) + Number(postStats.shares || 0);
  const currentReach = Number(postStats.likes || 0) * 35 + Number(postStats.comments || 0) * 20 + Number(postStats.shares || 0) * 90 + posts * 120;
  const recent = Number(growthRow.recent || 0);
  const prior = Number(growthRow.prior || 0);
  const audienceGrowth = prior > 0 ? Number((((recent - prior) / prior) * 100).toFixed(1)) : (recent > 0 ? 100 : 0);
  const coverageRegions = safeArray(profile && profile.coverage_regions).length
    ? safeArray(profile && profile.coverage_regions)
    : [user.country, user.city].filter(Boolean);
  const expertise = safeArray(profile && profile.expertise).length
    ? safeArray(profile && profile.expertise)
    : String(user.interest || '').split(',').map((v) => SDG_NAMES[Number(v)]).filter(Boolean);
  const experience = safeArray(profile && profile.experience).length
    ? safeArray(profile && profile.experience)
    : orgs.map((o) => ({ role: o.member_title || roleLabel(o.member_role), org: o.name, from: String(o.start_date || '').slice(0, 4), to: o.end_date ? String(o.end_date).slice(0, 4) : 'Present' }));
  const badges = [];
  if (user.email_verified) badges.push('Verified professional');
  if (verifiedSubmissions > 0) badges.push('Verified contributor');
  if (verifiedSubmissions >= 3) badges.push('Evidence champion');
  if (programs > 0) badges.push('Program member');
  if (projects > 0) badges.push('Project builder');
  if (verifiedTasks > 0) badges.push('Task finisher');
  if (recommendations >= 2) badges.push('Recommended by peers');
  if (pmsTotal >= 70) badges.push(`PMS ${titleCaseTier(tier)}`);
  const isMe = !!(viewer && Number(viewer.id) === uid);
  let isFollowing = false;
  if (viewer && !isMe) {
    const f = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, uid).first();
    isFollowing = !!f;
  }
  return {
    user_id: String(uid), name: user.name || 'MASAREEN member',
    email: isMe ? (user.email || '') : '', role: roleLabel(user.role), role_type: user.role || 'INDIVIDUAL',
    status: 'ACTIVE', email_verified: !!user.email_verified,
    avatar_url: user.picture || null, cover_url: user.cover_url || null,
    country: user.country || null, city: user.city || null,
    website: (profile && profile.website) || null,
    social_links: safeObject(profile && profile.social_links),
    bio: user.bio || '', joined: user.created_at, member_since: user.created_at,
    headline: (profile && profile.headline) || [user.job_title, user.employer].filter(Boolean).join(' at ') || `${roleLabel(user.role)} on MASAREEN`,
    summary: (profile && profile.summary) || user.bio || '',
    mission: (profile && profile.mission) || '',
    beat: (profile && profile.beat) || 'Cross-sector impact',
    expertise, specializations: safeArray(profile && profile.specializations),
    skills, languages: safeArray(profile && profile.languages).length ? safeArray(profile && profile.languages) : ['Arabic', 'English'],
    education: safeArray(profile && profile.education), experience,
    certificates, awards: safeArray(profile && profile.awards), publications,
    memberships: safeArray(profile && profile.memberships),
    employment_status: (profile && profile.employment_status) || (String(user.role).toUpperCase() === 'STUDENT' ? 'Student' : 'Independent'),
    availability: (profile && profile.availability) || 'Open to opportunities',
    verification_level: user.email_verified ? 'VERIFIED' : 'UNVERIFIED',
    impact_tier: titleCaseTier(tier), professional_rank: roleLabel(user.role),
    impact_score: impactScore, trust_score: trustScore,
    verification_confidence: confidence, community_rating: Number((posts ? clamp(engagement / posts / 8, 0, 5) : 0).toFixed(1)),
    current_reach: currentReach, lifetime_reach: Number((currentReach + impactScore * 400).toFixed(0)),
    average_reach: Number((posts ? currentReach / posts : 0).toFixed(0)),
    audience_growth: audienceGrowth, average_engagement: Number((posts ? engagement / posts : 0).toFixed(1)),
    media_value: Number((currentReach * 0.02).toFixed(0)),
    contribution_score: verifiedSubmissions * 10 + verifiedTasks * 8 + projects * 5 + programs * 4,
    knowledge_score: Number(clamp(posts * 3 + publications.length * 5 + certificates.length * 4, 0, 100).toFixed(0)),
    field_activity_score: Number(clamp((posts + submissions + evidence) * 5, 0, 100).toFixed(0)),
    professional_consistency: Math.round(dimensions.consistency),
    kpi: {
      total_reports: posts, verified_reports: verifiedPosts, evidence_submitted: evidence, verified_missions: verifiedTasks,
      trust_score: trustScore, ai_confidence: confidence, community_rating: Number((posts ? clamp(engagement / posts / 8, 0, 5) : 0).toFixed(1)),
      followers, countries_covered: coverageRegions.length, coverage_hours: Number((profile && profile.coverage_hours) || 0),
      average_quality_score: confidence, monthly_growth: audienceGrowth,
    },
    pms: { dimensions, weights: PMS_WEIGHTS, total: pmsTotal, tier },
    pms_score: pmsTotal, pms_tier: tier,
    completeness: profileCompleteness(profile, user),
    badges, followers_count: followers, following_count: following, posts_count: posts,
    recommendations_count: recommendations, endorsements_count: endorsements.length,
    organizations_count: orgs.length, is_following: isFollowing, is_me: isMe,
    coverage_regions: coverageRegions,
    profile_visibility: (profile && profile.visibility) || 'PUBLIC',
  };
}

async function personnelReports(env, userId, limit = 40) {
  const rows = (await env.DB.prepare(`SELECT * FROM posts WHERE author_id=? AND hidden=0
    ORDER BY created_at DESC LIMIT ?`).bind(userId, clamp(Number(limit) || 40, 1, 100)).all()).results || [];
  return rows.map((r) => ({
    id: String(r.id), headline: headlineFromText(r.text), text: r.text,
    category: String(r.kind || 'UPDATE').toLowerCase(), program_tag: r.sdg ? SDG_NAMES[r.sdg] || null : null,
    sdg: r.sdg == null ? 0 : Number(r.sdg), status: 'PUBLISHED',
    verification_status: Number(r.confidence_score || 0) >= 70 ? 'VERIFIED' : 'REVIEW',
    published_at: r.created_at,
    reach: 120 + Number(r.like_count || 0) * 35 + Number(r.comment_count || 0) * 20 + Number(r.share_count || 0) * 90,
    engagement: Number(r.like_count || 0) + Number(r.comment_count || 0) + Number(r.share_count || 0),
    evidence_count: Number(r.confidence_score || 0) >= 70 ? 1 : 0,
    quality_score: Number(r.confidence_score || 0), impact_score: Number(r.impact_value || 0),
    cover_image: r.media_url || null, comments: Number(r.comment_count || 0), likes: Number(r.like_count || 0),
  }));
}

async function personnelAnalytics(env, userId) {
  const rows = (await env.DB.prepare('SELECT * FROM profile_analytics WHERE user_id=? ORDER BY created_at ASC').bind(userId).all()).results || [];
  if (rows.length) {
    return rows.map((r) => ({
      bucket: r.bucket, impact_score: Number(r.impact_score || 0), reach: Number(r.reach || 0),
      engagement: Number(r.engagement || 0), verified_reports: Number(r.verified_reports || 0),
      evidence: Number(r.evidence || 0), trust_score: Number(r.trust_score || 0),
      knowledge: Number(r.knowledge || 0), influence: Number(r.influence || 0),
    }));
  }
  const grouped = (await env.DB.prepare(`SELECT substr(created_at,1,7) bucket, COUNT(*) c,
    COALESCE(SUM(impact_value),0) impact, COALESCE(SUM(like_count),0) likes,
    COALESCE(SUM(comment_count),0) comments, COALESCE(SUM(share_count),0) shares,
    COALESCE(AVG(confidence_score),0) confidence,
    COALESCE(SUM(CASE WHEN confidence_score>=70 THEN 1 ELSE 0 END),0) verified
    FROM posts WHERE author_id=? AND hidden=0 AND created_at>=date('now','-6 months')
    GROUP BY bucket ORDER BY bucket ASC`).bind(userId).all()).results || [];
  const byBucket = new Map(grouped.map((r) => [r.bucket, r]));
  const now = new Date();
  const out = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
    const key = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
    const r = byBucket.get(key);
    const reach = r ? 120 * Number(r.c || 0) + Number(r.likes || 0) * 35 + Number(r.comments || 0) * 20 + Number(r.shares || 0) * 90 : 0;
    out.push({
      bucket: d.toLocaleString('en-US', { month: 'short', timeZone: 'UTC' }),
      impact_score: r ? Number(r.impact || 0) + Number(r.verified || 0) * 2 : 0,
      reach, engagement: r ? Number(r.likes || 0) + Number(r.comments || 0) + Number(r.shares || 0) : 0,
      verified_reports: r ? Number(r.verified || 0) : 0, evidence: 0,
      trust_score: r ? Number(r.confidence || 0) : 0, knowledge: r ? Number(r.c || 0) * 3 : 0,
      influence: Number((reach / 1000).toFixed(1)),
    });
  }
  return out;
}

async function personnelTimeline(env, userId) {
  const rows = (await env.DB.prepare(`SELECT 'report' kind, p.text title, p.created_at happened_at FROM posts p WHERE p.author_id=? AND p.hidden=0
    UNION ALL SELECT 'evidence', s.title, s.created_at FROM submissions s WHERE s.owner_id=?
    UNION ALL SELECT 'mission', 'Joined ' || pr.title, pm.created_at FROM program_members pm JOIN programs pr ON pr.id=pm.program_id WHERE pm.user_id=?
    UNION ALL SELECT 'mission', 'Joined ' || x.title, xm.created_at FROM project_members xm JOIN projects x ON x.id=xm.project_id WHERE xm.user_id=?
    UNION ALL SELECT 'award', a.title, a.earned_at FROM profile_achievements a WHERE a.user_id=?
    UNION ALL SELECT 'org', 'Joined ' || o.name, om.created_at FROM organization_members om JOIN organizations o ON o.id=om.organization_id WHERE om.user_id=?
    ORDER BY happened_at DESC LIMIT 40`).bind(userId, userId, userId, userId, userId, userId).all()).results || [];
  return rows.map((r) => ({
    kind: r.kind, title: r.kind === 'report' ? headlineFromText(r.title) : r.title,
    happened_at: r.happened_at,
  }));
}

async function personnelAchievements(env, userId) {
  const rows = (await env.DB.prepare('SELECT * FROM profile_achievements WHERE user_id=? ORDER BY earned_at DESC LIMIT 40').bind(userId).all()).results || [];
  const items = rows.map((r) => ({ id: String(r.id), title: r.title, detail: r.detail, kind: r.kind, earned_at: r.earned_at }));
  const seen = new Set(items.map((i) => i.title));
  const count = async (sql) => Number((await env.DB.prepare(sql).bind(userId).first()).c || 0);
  const verifiedSubs = await count("SELECT COUNT(*) c FROM submissions WHERE owner_id=? AND status='VERIFIED'");
  const programs = await count('SELECT COUNT(*) c FROM program_members WHERE user_id=?');
  const projects = await count('SELECT COUNT(*) c FROM project_members WHERE user_id=?');
  const tasks = await count("SELECT COUNT(*) c FROM tasks WHERE assignee_id=? AND status='VERIFIED'");
  const followers = await followCount(env, userId, 'followee_id');
  const dynamic = [
    [verifiedSubs > 0, 'Verified contributor', `${verifiedSubs} verified claim${verifiedSubs === 1 ? '' : 's'} in the impact record.`],
    [programs > 0, 'Program member', `Active in ${programs} programme${programs === 1 ? '' : 's'}.`],
    [projects > 0, 'Project builder', `Contributing to ${projects} project${projects === 1 ? '' : 's'}.`],
    [tasks > 0, 'Task finisher', `${tasks} verified task${tasks === 1 ? '' : 's'} completed.`],
    [followers >= 10, 'Community builder', `${followers} people follow this work.`],
  ];
  for (const [show, title, detail] of dynamic) {
    if (show && !seen.has(title)) items.push({ id: null, title, detail, kind: 'BADGE', earned_at: null });
  }
  return items;
}

async function personnelOrganizations(env, userId) {
  const rows = (await env.DB.prepare(`SELECT o.*, om.role member_role, om.title member_title, om.start_date, om.end_date
    FROM organization_members om JOIN organizations o ON o.id=om.organization_id
    WHERE om.user_id=? ORDER BY om.created_at DESC`).bind(userId).all()).results || [];
  return rows.map((o) => {
    const start = o.start_date ? String(o.start_date).slice(0, 4) : '';
    const end = o.end_date ? String(o.end_date).slice(0, 4) : 'Present';
    return {
      id: String(o.id), name: o.name, type: o.type, role: o.member_title || roleLabel(o.member_role),
      member_role: o.member_role, description: o.description, logo_url: o.logo_url, cover_url: o.cover_url,
      country: o.country, city: o.city, verified: !!o.verified, verification_level: o.verification_level,
      pms_score: Number(o.pms_score || 0), oii_score: Number(o.oii_score || 0),
      start_date: o.start_date, end_date: o.end_date, duration: start ? `${start} – ${end}` : '',
    };
  });
}

async function personnelRecommendations(env, userId) {
  const rows = (await env.DB.prepare(`SELECT r.*, u.name author_name, u.picture author_avatar, u.role author_role
    FROM profile_recommendations r JOIN users u ON u.id=r.author_id
    WHERE r.user_id=? AND r.status='PUBLISHED' ORDER BY r.created_at DESC LIMIT 40`).bind(userId).all()).results || [];
  return rows.map((r) => ({
    id: String(r.id), author_id: String(r.author_id), author_name: r.author_name || 'MASAREEN member',
    author_avatar: r.author_avatar || null, author_role: roleLabel(r.author_role), relation: r.relation,
    text: r.text, created_at: r.created_at,
  }));
}

async function personnelCoverage(env, userId) {
  const profile = await env.DB.prepare('SELECT * FROM user_profiles WHERE user_id=?').bind(userId).first();
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(userId).first();
  const regions = safeArray(profile && profile.coverage_regions).length
    ? safeArray(profile && profile.coverage_regions) : [user && user.country, user && user.city].filter(Boolean);
  return {
    country: (user && user.country) || null, city: (user && user.city) || null,
    regions, lat: null, lng: null, radius_km: null,
    countries_covered: new Set(regions.map((r) => typeof r === 'string' ? r : r.country || '')).size,
    coverage_hours: Number((profile && profile.coverage_hours) || 0),
  };
}

async function personnelMedia(env, userId) {
  const rows = (await env.DB.prepare(`SELECT id, text, media_url, kind, created_at FROM posts
    WHERE author_id=? AND hidden=0 AND media_url IS NOT NULL AND media_url<>'' ORDER BY created_at DESC LIMIT 50`).bind(userId).all()).results || [];
  return rows.map((r) => ({ id: String(r.id), url: r.media_url, kind: String(r.kind || 'MEDIA').toLowerCase(),
    caption: headlineFromText(r.text), created_at: r.created_at }));
}

async function personnelOpinions(env, userId) {
  const rows = (await env.DB.prepare(`SELECT * FROM posts WHERE author_id=? AND hidden=0 AND kind='OPINION'
    ORDER BY created_at DESC LIMIT 50`).bind(userId).all()).results || [];
  return rows.map((r) => ({ id: String(r.id), headline: headlineFromText(r.text), text: r.text, created_at: r.created_at }));
}

async function personnelEvidence(env, userId) {
  const rows = (await env.DB.prepare('SELECT * FROM evidence WHERE owner_id=? ORDER BY created_at DESC LIMIT 50').bind(userId).all()).results || [];
  return rows.map(evidenceJson);
}

async function listPersonnel(env, viewer, url) {
  const orgId = num(url.searchParams.get('org_id'));
  const q = clean(url.searchParams.get('q') || '', 80);
  const limit = clamp(Number(url.searchParams.get('limit')) || 30, 1, 50);
  const bind = [];
  let sql = 'SELECT DISTINCT u.* FROM users u';
  if (orgId) { sql += ' JOIN organization_members om ON om.user_id=u.id AND om.organization_id=?'; bind.push(orgId); }
  sql += ' LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.role IS NOT NULL';
  if (q) { sql += ' AND (u.name LIKE ? OR p.headline LIKE ? OR p.summary LIKE ?)'; bind.push(`%${q}%`, `%${q}%`, `%${q}%`); }
  sql += ' ORDER BY u.name LIMIT ?';
  bind.push(limit);
  const rows = (await env.DB.prepare(sql).bind(...bind).all()).results || [];
  const out = [];
  for (const row of rows) {
    const full = await personnelJson(env, row, viewer);
    out.push({
      user_id: full.user_id, name: full.name, email: full.email, role: full.role, role_type: full.role_type,
      avatar_url: full.avatar_url, cover_url: full.cover_url, country: full.country, city: full.city,
      headline: full.headline, summary: full.summary, skills: full.skills, email_verified: full.email_verified,
      impact_score: full.impact_score, trust_score: full.trust_score, impact_tier: full.impact_tier,
      professional_rank: full.professional_rank, is_following: full.is_following, is_me: full.is_me,
    });
  }
  return out;
}

async function updatePersonnelProfile(req, env, targetId, viewer) {
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
  if (Number(viewer.id) !== Number(targetId) && !isAdminUser(env, viewer))
    throw new HttpError(403, 'forbidden', 'You can only edit your own professional profile.');
  const body = await req.json().catch(() => ({}));
  const currentUser = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(targetId).first();
  const current = await env.DB.prepare('SELECT * FROM user_profiles WHERE user_id=?').bind(targetId).first();
  const text = (key, max, fallback = '') => body[key] === undefined ? (current && current[key]) || fallback : clean(body[key], max);
  const list = (key) => {
    if (body[key] === undefined) return current && current[key] ? current[key] : '[]';
    const value = profileArray(body[key]);
    return JSON.stringify(value === null ? safeArray(current && current[key]) : value);
  };
  const name = body.full_name !== undefined || body.name !== undefined
    ? clean(body.full_name || body.name, 90) : currentUser.name || '';
  const bio = body.bio === undefined ? currentUser.bio || '' : clean(body.bio, 400);
  const country = body.country === undefined ? currentUser.country || '' : clean(body.country, 60);
  const city = body.city === undefined ? currentUser.city || '' : clean(body.city, 80);
  const social = body.social_links === undefined
    ? JSON.stringify(safeObject(current && current.social_links)) : JSON.stringify(safeObject(body.social_links));
  const coverageHours = body.coverage_hours === undefined ? Number((current && current.coverage_hours) || 0) : Number(body.coverage_hours) || 0;
  const visibility = ['PUBLIC', 'CONNECTIONS', 'PRIVATE'].includes(String(body.visibility || '').toUpperCase())
    ? String(body.visibility).toUpperCase() : (current && current.visibility) || 'PUBLIC';
  const merged = {
    headline: text('headline', 120), summary: text('summary', 1200), mission: text('mission', 600), beat: text('beat', 120),
    expertise: list('expertise'), specializations: list('specializations'), skills: list('skills'), languages: list('languages'),
    education: list('education'), experience: list('experience'), certificates: list('certificates'), awards: list('awards'),
    publications: list('publications'), memberships: list('memberships'),
    employment_status: text('employment_status', 80), availability: text('availability', 80), website: text('website', 200),
    social_links: social, coverage_regions: list('coverage_regions'), coverage_hours: coverageHours,
    visibility, updated_at: nowIso(),
  };
  const completeness = profileCompleteness({ ...merged, expertise: safeArray(merged.expertise), skills: safeArray(merged.skills),
    languages: safeArray(merged.languages), education: safeArray(merged.education), experience: safeArray(merged.experience),
    coverage_regions: safeArray(merged.coverage_regions), social_links: safeObject(merged.social_links) }, { country, city });
  await env.DB.prepare(`UPDATE users SET name=?, bio=?, country=?, city=? WHERE id=?`)
    .bind(name || currentUser.name, bio, country, city, targetId).run();
  await env.DB.prepare(`INSERT INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations,
    skills, languages, education, experience, certificates, awards, publications, memberships, employment_status,
    availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(user_id) DO UPDATE SET headline=excluded.headline, summary=excluded.summary, mission=excluded.mission,
    beat=excluded.beat, expertise=excluded.expertise, specializations=excluded.specializations, skills=excluded.skills,
    languages=excluded.languages, education=excluded.education, experience=excluded.experience,
    certificates=excluded.certificates, awards=excluded.awards, publications=excluded.publications,
    memberships=excluded.memberships, employment_status=excluded.employment_status, availability=excluded.availability,
    website=excluded.website, social_links=excluded.social_links, coverage_regions=excluded.coverage_regions,
    coverage_hours=excluded.coverage_hours, visibility=excluded.visibility, completeness=excluded.completeness,
    updated_at=excluded.updated_at`)
    .bind(targetId, merged.headline, merged.summary, merged.mission, merged.beat, merged.expertise, merged.specializations,
      merged.skills, merged.languages, merged.education, merged.experience, merged.certificates, merged.awards,
      merged.publications, merged.memberships, merged.employment_status, merged.availability, merged.website,
      merged.social_links, merged.coverage_regions, merged.coverage_hours, merged.visibility, completeness, merged.updated_at).run();
  const updated = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(targetId).first();
  return personnelJson(env, updated, viewer);
}

async function personnelRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if ((path === '/api/v1/personnel' || path === '/api/v1/personnel/') && req.method === 'GET')
    return json(await listPersonnel(env, viewer, url));
  const match = /^\/api\/v1\/personnel\/(me|\d+)(?:\/([a-z-]+))?$/.exec(path);
  if (!match) return null;
  const targetId = match[1] === 'me' ? (viewer && viewer.id) : Number(match[1]);
  if (!targetId) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(targetId).first();
  if (!user) throw new HttpError(404, 'user_not_found', 'Profile not found.');
  const sub = match[2] || '';
  if (!sub && req.method === 'GET') return json(await personnelJson(env, user, viewer));
  if (!sub && req.method === 'PATCH') return json(await updatePersonnelProfile(req, env, targetId, viewer));
  if (sub === 'follow' && req.method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    if (Number(viewer.id) === Number(targetId)) throw new HttpError(400, 'self_follow', 'You cannot follow yourself.');
    const has = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, targetId).first();
    if (has) await env.DB.prepare('DELETE FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, targetId).run();
    else {
      await env.DB.prepare('INSERT INTO follows (follower_id,followee_id,created_at) VALUES (?,?,?)').bind(viewer.id, targetId, nowIso()).run();
      await notify(env, targetId, 'follow', `${viewer.name || 'Someone'} started following you`, 'Open their profile to follow back.', viewer.id, null);
    }
    return json({ ok: true, following: !has, followers_count: await followCount(env, targetId, 'followee_id') });
  }
  if (sub === 'endorse' && req.method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const body = await req.json().catch(() => ({}));
    const skill = clean(body.skill, 80);
    if (!skill) throw new HttpError(400, 'skill_required', 'Choose a skill to endorse.');
    if (Number(viewer.id) === Number(targetId)) throw new HttpError(400, 'self_endorse', 'You cannot endorse yourself.');
    await env.DB.prepare('INSERT OR IGNORE INTO profile_endorsements (user_id,endorser_id,skill,created_at) VALUES (?,?,?,?)')
      .bind(targetId, viewer.id, skill, nowIso()).run();
    const row = await env.DB.prepare('SELECT COUNT(*) c FROM profile_endorsements WHERE user_id=? AND skill=?').bind(targetId, skill).first();
    return json({ ok: true, skill, endorsements: Number(row.c || 0) });
  }
  if (sub === 'reports' && req.method === 'GET') return json(await personnelReports(env, targetId, url.searchParams.get('limit')));
  if (sub === 'analytics' && req.method === 'GET') return json({ series: await personnelAnalytics(env, targetId) });
  if (sub === 'timeline' && req.method === 'GET') return json(await personnelTimeline(env, targetId));
  if (sub === 'achievements' && req.method === 'GET') return json(await personnelAchievements(env, targetId));
  if (sub === 'organizations' && req.method === 'GET') return json(await personnelOrganizations(env, targetId));
  if (sub === 'recommendations' && req.method === 'GET') return json(await personnelRecommendations(env, targetId));
  if (sub === 'coverage' && req.method === 'GET') return json(await personnelCoverage(env, targetId));
  if (sub === 'media' && req.method === 'GET') return json(await personnelMedia(env, targetId));
  if (sub === 'opinions' && req.method === 'GET') return json(await personnelOpinions(env, targetId));
  if (sub === 'evidence' && req.method === 'GET') return json(await personnelEvidence(env, targetId));
  if (sub === 'overview' && req.method === 'GET') {
    const full = await personnelJson(env, user, viewer);
    return json({ profile: full, organizations: await personnelOrganizations(env, targetId),
      achievements: await personnelAchievements(env, targetId), recommendations: await personnelRecommendations(env, targetId) });
  }
  throw new HttpError(404, 'not_found', 'Unknown profile route.');
}

async function listStoryPacks(env) {
  const rows = (await env.DB.prepare(`SELECT sp.*, u.name author_name, e.url evidence_url, e.kind evidence_kind
    FROM story_packs sp LEFT JOIN users u ON u.id=sp.author_id
    LEFT JOIN submissions s ON s.id=sp.submission_id LEFT JOIN evidence e ON e.id=s.evidence_id
    WHERE sp.status='READY' ORDER BY sp.created_at DESC LIMIT 50`).all()).results || [];
  return json(rows.map((sp) => ({
    id: String(sp.id), submission_id: sp.submission_id == null ? null : String(sp.submission_id),
    title: sp.title, summary: sp.summary || null, status: sp.status,
    author_name: sp.author_name || 'MASAREEN', evidence_url: sp.evidence_url || null,
    evidence_kind: sp.evidence_kind || null, created_at: sp.created_at,
  })));
}

/* ---------------- notifications ---------------- */
async function listNotifications(req, env, userId) {
  const viewer = await requireUser(req, env);
  if (viewer.id !== Number(userId) && !isAdminUser(env, viewer))
    throw new HttpError(403, 'forbidden', 'You can only read your own notifications.');
  const rows = (await env.DB.prepare('SELECT * FROM notifications WHERE user_id=? ORDER BY created_at DESC LIMIT 100')
    .bind(Number(userId)).all()).results || [];
  return json(rows.map((n) => ({ id: String(n.id), type: n.type, title: n.title, body: n.body,
    read: !!n.read, created_at: n.created_at, actor_id: n.actor_id == null ? null : String(n.actor_id),
    post_id: n.post_id == null ? null : String(n.post_id) })));
}

async function notificationRoutes(req, env, path) {
  if (path === '/api/v1/notifications/read-all' && req.method === 'POST') {
    const viewer = await requireUser(req, env);
    await env.DB.prepare('UPDATE notifications SET read=1 WHERE user_id=?').bind(viewer.id).run();
    return json({ ok: true });
  }
  const readMatch = /^\/api\/v1\/notifications\/(\d+)\/read$/.exec(path);
  if (readMatch && req.method === 'POST') {
    const viewer = await requireUser(req, env);
    await env.DB.prepare('UPDATE notifications SET read=1 WHERE id=? AND user_id=?').bind(Number(readMatch[1]), viewer.id).run();
    return json({ ok: true });
  }
  const listMatch = /^\/api\/v1\/notifications\/(\d+)$/.exec(path);
  if (listMatch && req.method === 'GET') return await listNotifications(req, env, Number(listMatch[1]));
  return null;
}

/* ---------------- media uploads (R2) ---------------- */
const IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const VIDEO_TYPES = new Set(['video/mp4', 'video/webm', 'video/quicktime']);

async function uploadMedia(req, env, kind) {
  const u = await requireUser(req, env);
  if (!env.MEDIA) throw new HttpError(503, 'media_unavailable', 'Media uploads are not configured yet.');
  let form;
  try { form = await req.formData(); } catch { throw new HttpError(400, 'bad_upload', 'Choose a file to upload.'); }
  const file = form.get('file');
  if (!file || typeof file === 'string') throw new HttpError(400, 'bad_upload', 'Choose a file to upload.');
  const maxBytes = kind === 'video' ? 80 * 1024 * 1024 : 12 * 1024 * 1024;
  if (file.size > maxBytes) throw new HttpError(413, 'too_large', kind === 'video'
    ? 'Videos must be 80 MB or smaller.' : 'Images must be 12 MB or smaller.');
  const ct = String(file.type || '').toLowerCase();
  const isImage = IMAGE_TYPES.has(ct);
  const isVideo = VIDEO_TYPES.has(ct);
  if (!isImage && !isVideo) throw new HttpError(415, 'unsupported_type', 'Use a JPG, PNG, WEBP, GIF, MP4 or WEBM file.');
  if (kind === 'avatar' || kind === 'cover') {
    if (!isImage) throw new HttpError(415, 'unsupported_type', 'Profile photos must be images.');
  }
  const ext = ct === 'image/jpeg' ? 'jpg' : ct === 'video/quicktime' ? 'mov' : ct.split('/')[1];
  const folder = kind === 'avatar' ? 'avatars' : kind === 'cover' ? 'covers' : kind === 'video' ? 'videos' : 'posts';
  const key = `media/${folder}/${u.id}-${Date.now()}.${ext}`;
  await env.MEDIA.put(key, await file.arrayBuffer(), { httpMetadata: { contentType: ct, cacheControl: 'public, max-age=31536000, immutable' } });
  const base = (env.MEDIA_PUBLIC_BASE || 'https://masareen.com').replace(/\/+$/, '');
  const url = `${base}/${key}`;
  if (kind === 'avatar') await env.DB.prepare('UPDATE users SET picture=? WHERE id=?').bind(url, u.id).run();
  if (kind === 'cover') await env.DB.prepare('UPDATE users SET cover_url=? WHERE id=?').bind(url, u.id).run();
  let jobId = null;
  if (kind === 'video') {
    jobId = crypto.randomUUID();
    const at = nowIso();
    await env.DB.prepare(`INSERT INTO video_jobs (id,user_id,status,original_url,created_at,updated_at)
      VALUES (?,?,'queued',?,?,?)`).bind(jobId, u.id, url, at, at).run();
  }
  return json({ ok: true, url, avatar_url: kind === 'avatar' ? url : null,
    cover_url: kind === 'cover' ? url : null, content_type: ct, size: file.size,
    job_id: jobId, video_job_id: jobId, status: jobId ? 'queued' : null });
}

/* ---------------- misc app endpoints (graceful stubs) ---------------- */
const emptyListRoutes = new Set([
  '/api/v1/campaigns', '/api/v1/campaigns/', '/api/v1/coin/transactions',
  '/api/v1/payments', '/api/v1/ads',
]);

async function userRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (path === '/api/v1/users/me' && req.method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    return json(await userJson(env, viewer, viewer));
  }
  if (path === '/api/v1/users/me/profile' && (req.method === 'PATCH' || req.method === 'POST')) {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await req.json().catch(() => ({}));
    const name = clean(b.full_name || b.name, 90);
    const bio = clean(b.bio, 400);
    const country = clean(b.country, 60);
    const city = clean(b.city, 80);
    const handleRaw = clean(b.handle, 30).replace(/^@/, '').toLowerCase().replace(/[^a-z0-9_]/g, '');
    await env.DB.prepare(`UPDATE users SET name=COALESCE(NULLIF(?,''),name), bio=COALESCE(NULLIF(?,''),bio),
      country=COALESCE(NULLIF(?,''),country), city=COALESCE(NULLIF(?,''),city),
      handle=COALESCE(NULLIF(?,''),handle) WHERE id=?`)
      .bind(name, bio, country, city, handleRaw, viewer.id).run();
    const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(viewer.id).first();
    return json(await userJson(env, u, u));
  }
  const followMatch = /^\/api\/v1\/users\/(\d+)\/follow$/.exec(path);
  if (followMatch && req.method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const target = Number(followMatch[1]);
    if (target === viewer.id) throw new HttpError(400, 'self_follow', 'You cannot follow yourself.');
    const exists = await env.DB.prepare('SELECT 1 x FROM users WHERE id=?').bind(target).first();
    if (!exists) throw new HttpError(404, 'user_not_found', 'Profile not found.');
    const has = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, target).first();
    if (has) await env.DB.prepare('DELETE FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, target).run();
    else {
      await env.DB.prepare('INSERT INTO follows (follower_id,followee_id,created_at) VALUES (?,?,?)').bind(viewer.id, target, nowIso()).run();
      await notify(env, target, 'follow', `${viewer.name || 'Someone'} started following you`, 'Open their profile to follow back.', viewer.id, null);
    }
    return json({ ok: true, following: !has, followers_count: await followCount(env, target, 'followee_id') });
  }
  const idMatch = /^\/api\/v1\/users\/(\d+)$/.exec(path);
  if (idMatch && req.method === 'GET') {
    const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(Number(idMatch[1])).first();
    if (!u) throw new HttpError(404, 'user_not_found', 'Profile not found.');
    const jsonUser = await userJson(env, u, viewer);
    jsonUser.posts = (await env.DB.prepare(`${POST_SELECT} WHERE p.author_id=? AND p.hidden=0 ORDER BY p.created_at DESC LIMIT 20`)
      .bind(u.id).all()).results.map((r) => postJson(r, false, null));
    return json(jsonUser);
  }
  if (path === '/api/v1/coin/wallets' || path === '/api/v1/wallet') {
    return json({ owner_id: viewer ? String(viewer.id) : '', ownerId: viewer ? String(viewer.id) : '',
      balance: 0, currency: 'MAS', updated_at: nowIso() });
  }
  return null;
}

/* ---------------- sports organisations, athletes and institution profiles ---------------- */
function parseJsonObject(raw) {
  if (!raw) return {};
  try { const v = JSON.parse(raw); return v && typeof v === 'object' && !Array.isArray(v) ? v : {}; } catch { return {}; }
}

function parseJsonValue(raw, fallback) {
  if (!raw) return fallback;
  try { const v = JSON.parse(raw); return v == null ? fallback : v; } catch { return fallback; }
}

function metricRowJson(m) {
  return {
    id: String(m.id),
    season: m.season || null,
    competition: m.competition || null,
    team: m.team || null,
    appearances: Number(m.appearances || 0),
    starts: Number(m.starts || 0),
    minutes: Number(m.minutes || 0),
    goals: Number(m.goals || 0),
    assists: Number(m.assists || 0),
    rating: m.rating == null ? null : Number(m.rating),
    yellow_cards: Number(m.yellow_cards || 0),
    red_cards: Number(m.red_cards || 0),
    clean_sheets: Number(m.clean_sheets || 0),
    saves: Number(m.saves || 0),
    passes_accuracy: m.passes_accuracy == null ? null : Number(m.passes_accuracy),
    distance_km: m.distance_km == null ? null : Number(m.distance_km),
    sprint_count: m.sprint_count == null ? null : Number(m.sprint_count),
    payload: parseJsonObject(m.payload_json),
    source: m.source || 'MANUAL',
  };
}

async function metricsFor(env, userId) {
  const rows = (await env.DB.prepare('SELECT * FROM sports_metrics WHERE user_id=? ORDER BY season DESC, competition ASC')
    .bind(userId).all()).results || [];
  const totals = { appearances: 0, starts: 0, minutes: 0, goals: 0, assists: 0, yellow_cards: 0, red_cards: 0,
    clean_sheets: 0, saves: 0, rating: 0, rated: 0 };
  for (const r of rows) {
    totals.appearances += Number(r.appearances || 0);
    totals.starts += Number(r.starts || 0);
    totals.minutes += Number(r.minutes || 0);
    totals.goals += Number(r.goals || 0);
    totals.assists += Number(r.assists || 0);
    totals.yellow_cards += Number(r.yellow_cards || 0);
    totals.red_cards += Number(r.red_cards || 0);
    totals.clean_sheets += Number(r.clean_sheets || 0);
    totals.saves += Number(r.saves || 0);
    if (r.rating != null) { totals.rating += Number(r.rating); totals.rated += 1; }
  }
  totals.rating = totals.rated ? Number((totals.rating / totals.rated).toFixed(2)) : null;
  delete totals.rated;
  return { rows: rows.map(metricRowJson), totals };
}

async function resolveOrg(env, id) {
  let org = await env.DB.prepare('SELECT * FROM organizations WHERE id=?').bind(id).first();
  if (!org) org = await env.DB.prepare('SELECT * FROM organizations WHERE owner_id=? ORDER BY id LIMIT 1').bind(id).first();
  const owner = org?.owner_id ? await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(org.owner_id).first() : null;
  const fallbackUser = !org ? await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first() : null;
  return { org, owner, fallbackUser };
}

async function orgRecord(env, org, owner, viewer) {
  const stats = { wins: 0, draws: 0, losses: 0, points: 0 };
  if (org) {
    const rows = (await env.DB.prepare("SELECT home_away,home_score,away_score FROM sports_events WHERE org_id=? AND status='FINISHED'")
      .bind(org.id).all()).results || [];
    for (const e of rows) {
      const home = e.home_away !== 'AWAY';
      const us = Number(home ? e.home_score : e.away_score) || 0;
      const them = Number(home ? e.away_score : e.home_score) || 0;
      if (us > them) stats.wins += 1; else if (us === them) stats.draws += 1; else stats.losses += 1;
    }
    stats.points = stats.wins * 3 + stats.draws;
  }
  const meta = parseJsonObject(org?.metadata_json);
  const ownerId = org?.owner_id || owner?.id || null;
  const isFollowing = viewer && ownerId ? !!(await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
    .bind(viewer.id, ownerId).first()) : false;
  const followers = ownerId ? Number((await env.DB.prepare('SELECT COUNT(*) c FROM follows WHERE followee_id=?').bind(ownerId).first()).c || 0) : 0;
  const base = org ? {
    id: String(org.id), owner_id: org.owner_id == null ? null : String(org.owner_id), name: org.name, slug: org.slug,
    type: org.type, description: org.description, logo_url: org.logo_url, cover_url: org.cover_url, website: org.website,
    country: org.country, city: org.city, verified: !!org.verified, verification_level: org.verification_level,
    pms_score: Number(org.pms_score || 0), oii_score: Number(org.oii_score || 0), created_at: org.created_at,
  } : {
    id: String(owner?.id || ''), owner_id: owner ? String(owner.id) : null, name: owner?.name || 'Sports profile',
    slug: null, type: owner?.role || 'SPORTS', description: owner?.bio || '', logo_url: owner?.picture || null,
    cover_url: owner?.cover_url || null, website: null, country: owner?.country || null, city: owner?.city || null,
    verified: !!owner?.email_verified, verification_level: 'UNVERIFIED', pms_score: 0, oii_score: 0,
    created_at: owner?.created_at || null,
  };
  return {
    ...meta, ...base,
    league: meta.league || null, division: meta.division || null, stadium: meta.stadium || null,
    capacity: meta.capacity || null, founded: meta.founded || null, trophies: Array.isArray(meta.trophies) ? meta.trophies : [],
    bio: meta.bio || base.description || '', wins: stats.wins, draws: stats.draws, losses: stats.losses, points: stats.points,
    followers_count: followers, is_following: isFollowing,
  };
}

async function orgSquad(env, orgId, orgName) {
  let rows = (await env.DB.prepare(`SELECT u.id, u.name, u.picture avatar_url, u.role, u.country,
      COALESCE(sp.photo_url,u.picture) photo_url, COALESCE(sp.position,r.position) position,
      COALESCE(r.jersey_number,sp.jersey_number) jersey_number, sp.sport, sp.nationality, sp.club,
      COALESCE(SUM(m.appearances),0) appearances, COALESCE(SUM(m.goals),0) goals, COALESCE(SUM(m.assists),0) assists,
      COALESCE(SUM(m.minutes),0) minutes, AVG(m.rating) rating
    FROM sports_roster r JOIN users u ON u.id=r.athlete_id
    LEFT JOIN sports_profiles sp ON sp.user_id=u.id
    LEFT JOIN sports_metrics m ON m.user_id=u.id
    WHERE r.org_id=? AND r.status='ACTIVE'
    GROUP BY u.id ORDER BY r.jersey_number IS NULL, r.jersey_number, u.name`).bind(orgId).all()).results || [];
  if (!rows.length && orgName) {
    rows = (await env.DB.prepare(`SELECT u.id, u.name, u.picture avatar_url, u.role, u.country,
        COALESCE(sp.photo_url,u.picture) photo_url, sp.position, sp.jersey_number, sp.sport, sp.nationality, sp.club,
        COALESCE(SUM(m.appearances),0) appearances, COALESCE(SUM(m.goals),0) goals, COALESCE(SUM(m.assists),0) assists,
        COALESCE(SUM(m.minutes),0) minutes, AVG(m.rating) rating
      FROM sports_profiles sp JOIN users u ON u.id=sp.user_id
      LEFT JOIN sports_metrics m ON m.user_id=u.id
      WHERE sp.club=? OR sp.team_id=?
      GROUP BY u.id ORDER BY sp.jersey_number IS NULL, sp.jersey_number, u.name`).bind(orgName, orgId).all()).results || [];
  }
  return rows.map((r) => ({ ...r, id: String(r.id), appearances: Number(r.appearances || 0),
    goals: Number(r.goals || 0), assists: Number(r.assists || 0), minutes: Number(r.minutes || 0),
    rating: r.rating == null ? null : Number(Number(r.rating).toFixed(2)) }));
}

async function orgEvents(env, orgId, status) {
  const rows = (await env.DB.prepare('SELECT * FROM sports_events WHERE org_id=? AND status=? ORDER BY starts_at ASC LIMIT 100')
    .bind(orgId, status).all()).results || [];
  return rows.map((e) => {
    const isHome = e.home_away !== 'AWAY';
    const date = e.starts_at || '';
    const scoreFor = Number(isHome ? e.home_score : e.away_score) || 0;
    const scoreAgainst = Number(isHome ? e.away_score : e.home_score) || 0;
    const result = scoreFor > scoreAgainst ? 'W' : scoreFor === scoreAgainst ? 'D' : 'L';
    return {
      id: String(e.id), opponent: e.opponent_name, opponent_logo: e.opponent_logo || null,
      competition: e.competition || null, date, match_date: date, time: date.length >= 16 ? date.slice(11, 16) : '',
      kick_off: date.length >= 16 ? date.slice(11, 16) : '', venue: e.venue || null, is_home: isHome,
      status: e.status, home_score: e.home_score, away_score: e.away_score, score_for: scoreFor,
      score_against: scoreAgainst, result,
    };
  });
}

async function orgNews(env, ownerId) {
  if (!ownerId) return [];
  const rows = (await env.DB.prepare(`${POST_SELECT} WHERE p.author_id=? AND p.hidden=0 ORDER BY p.created_at DESC LIMIT 30`)
    .bind(ownerId).all()).results || [];
  return rows.map((r) => postJson(r, false, null));
}

async function playerRecord(env, user, viewer) {
  const profile = await env.DB.prepare('SELECT * FROM sports_profiles WHERE user_id=?').bind(user.id).first();
  const { rows: career, totals } = await metricsFor(env, user.id);
  const achievements = (await env.DB.prepare('SELECT * FROM profile_achievements WHERE user_id=? ORDER BY earned_at DESC LIMIT 30')
    .bind(user.id).all()).results || [];
  const profileMeta = parseJsonObject(profile?.metrics_json);
  const trophies = Array.isArray(profileMeta.trophies) ? profileMeta.trophies : [];
  const followers = Number((await env.DB.prepare('SELECT COUNT(*) c FROM follows WHERE followee_id=?').bind(user.id).first()).c || 0);
  const isFollowing = viewer ? !!(await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
    .bind(viewer.id, user.id).first()) : false;
  const achievementList = achievements.map((a) => ({ id: String(a.id), title: a.title, name: a.title,
    detail: a.detail || null, kind: a.kind, year: String(a.earned_at || '').slice(0, 4), earned_at: a.earned_at, date: a.earned_at }));
  for (const t of trophies) {
    achievementList.push({ id: null, title: t.name || t.title || 'Trophy', name: t.name || t.title || 'Trophy',
      detail: t.detail || null, kind: 'TROPHY', year: String(t.year || ''), earned_at: t.year ? `${t.year}-01-01` : null, date: t.year || null });
  }
  const timeline = [
    ...achievementList.map((a) => ({ kind: a.kind || 'milestone', title: a.title, detail: a.detail, date: a.earned_at || a.year })),
    ...career.filter((c) => c.season).map((c) => ({ kind: 'season', title: `${c.season} · ${c.team || c.competition || 'Season'}`,
      detail: `${c.appearances} apps · ${c.goals} goals · ${c.assists} assists`, date: c.season })),
  ];
  return {
    id: String(user.id), user_id: String(user.id), name: user.name, full_name: user.name,
    email: viewer && Number(viewer.id) === Number(user.id) ? user.email : '', role: user.role, avatar_url: user.picture || null, photo_url: profile?.photo_url || user.picture || null,
    cover_url: user.cover_url || null, country: user.country || null, city: user.city || null,
    bio: profile?.bio || user.bio || '', verified: !!user.email_verified, sport: profile?.sport || null,
    discipline: profile?.discipline || null, position: profile?.position || null, secondary_position: profile?.secondary_position || null,
    club: profile?.club || null, nationality: profile?.nationality || null, birth_date: profile?.birth_date || null,
    height_cm: profile?.height_cm == null ? null : Number(profile.height_cm),
    weight_kg: profile?.weight_kg == null ? null : Number(profile.weight_kg),
    preferred_foot: profile?.preferred_foot || null, jersey_number: profile?.jersey_number == null ? null : Number(profile.jersey_number),
    market_value: profile?.market_value || null, external_source: profile?.external_source || null,
    external_id: profile?.external_id || null, metrics_json: profileMeta,
    followers_count: followers, is_following: isFollowing,
    appearances: totals.appearances, goals: totals.goals, assists: totals.assists,
    minutes: totals.minutes, minutes_played: totals.minutes, starts: totals.starts,
    yellow_cards: totals.yellow_cards, red_cards: totals.red_cards, clean_sheets: totals.clean_sheets,
    saves: totals.saves, rating: totals.rating, totals, career, achievements: achievementList, timeline,
  };
}

async function relatedPlayers(env, user, profile) {
  if (!profile) return [];
  const rows = (await env.DB.prepare(`SELECT u.id, u.name, COALESCE(sp.photo_url,u.picture) photo_url, u.picture avatar_url,
      sp.position, sp.jersey_number, sp.club, sp.sport
    FROM sports_profiles sp JOIN users u ON u.id=sp.user_id
    WHERE u.id<>? AND (sp.sport=? OR (? IS NOT NULL AND sp.club=?))
    ORDER BY (sp.club=?) DESC, u.name LIMIT 12`)
    .bind(user.id, profile.sport || 'FOOTBALL', profile.club || null, profile.club || null, profile.club || '')
    .all()).results || [];
  return rows.map((r) => ({ ...r, id: String(r.id) }));
}

async function toggleFollow(env, viewer, targetId) {
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
  if (Number(viewer.id) === Number(targetId)) throw new HttpError(400, 'self_follow', 'You cannot follow yourself.');
  const exists = await env.DB.prepare('SELECT 1 x FROM users WHERE id=?').bind(targetId).first();
  if (!exists) throw new HttpError(404, 'user_not_found', 'Profile not found.');
  const has = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, targetId).first();
  if (has) await env.DB.prepare('DELETE FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, targetId).run();
  else {
    await env.DB.prepare('INSERT INTO follows (follower_id,followee_id,created_at) VALUES (?,?,?)').bind(viewer.id, targetId, nowIso()).run();
    await notify(env, targetId, 'follow', `${viewer.name || 'Someone'} started following you`, 'Open their profile to follow back.', viewer.id, null);
  }
  const followers = Number((await env.DB.prepare('SELECT COUNT(*) c FROM follows WHERE followee_id=?').bind(targetId).first()).c || 0);
  return { ok: true, following: !has, followers_count: followers };
}

async function saveSportsProfile(req, env, targetId) {
  const viewer = await requireUser(req, env);
  if (Number(viewer.id) !== Number(targetId) && !isAdminUser(env, viewer))
    throw new HttpError(403, 'forbidden', 'You can only edit your own sports profile.');
  const b = await req.json().catch(() => ({}));
  const at = nowIso();
  const sport = clean(b.sport, 60).toUpperCase() || 'FOOTBALL';
  const profile = {
    discipline: clean(b.discipline, 80) || null,
    position: clean(b.position, 40) || null,
    secondary_position: clean(b.secondary_position, 40) || null,
    club: clean(b.club, 120) || null,
    team_id: num(b.team_id),
    nationality: clean(b.nationality, 80) || null,
    birth_date: clean(b.birth_date, 40) || null,
    height_cm: num(b.height_cm),
    weight_kg: num(b.weight_kg),
    preferred_foot: clean(b.preferred_foot, 20) || null,
    jersey_number: num(b.jersey_number),
    market_value: clean(b.market_value, 40) || null,
    photo_url: safeMediaUrl(b.photo_url),
    external_source: clean(b.external_source, 40) || null,
    external_id: clean(b.external_id, 80) || null,
    bio: clean(b.bio, 1200) || null,
    metrics_json: b.metrics_json && typeof b.metrics_json === 'object' ? JSON.stringify(b.metrics_json) : null,
  };
  await env.DB.prepare(`INSERT INTO sports_profiles (user_id,sport,discipline,position,secondary_position,club,team_id,
      nationality,birth_date,height_cm,weight_kg,preferred_foot,jersey_number,market_value,photo_url,external_source,
      external_id,bio,metrics_json,verified,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?,?)
    ON CONFLICT(user_id) DO UPDATE SET sport=excluded.sport, discipline=excluded.discipline, position=excluded.position,
      secondary_position=excluded.secondary_position, club=excluded.club, team_id=excluded.team_id,
      nationality=excluded.nationality, birth_date=excluded.birth_date, height_cm=excluded.height_cm,
      weight_kg=excluded.weight_kg, preferred_foot=excluded.preferred_foot, jersey_number=excluded.jersey_number,
      market_value=excluded.market_value, photo_url=COALESCE(excluded.photo_url,sports_profiles.photo_url),
      external_source=excluded.external_source, external_id=excluded.external_id,
      bio=COALESCE(excluded.bio,sports_profiles.bio), metrics_json=COALESCE(excluded.metrics_json,sports_profiles.metrics_json),
      updated_at=excluded.updated_at`)
    .bind(targetId, sport, profile.discipline, profile.position, profile.secondary_position, profile.club, profile.team_id,
      profile.nationality, profile.birth_date, profile.height_cm, profile.weight_kg, profile.preferred_foot,
      profile.jersey_number, profile.market_value, profile.photo_url, profile.external_source, profile.external_id,
      profile.bio, profile.metrics_json, at, at).run();
  const metrics = Array.isArray(b.metrics) ? b.metrics.slice(0, 30) : [];
  for (const m of metrics) {
    const season = clean(m.season, 30) || '';
    const competition = clean(m.competition, 80) || '';
    const team = clean(m.team, 120) || '';
    await env.DB.prepare(`INSERT INTO sports_metrics (user_id,sport,season,competition,team,appearances,starts,minutes,
        goals,assists,rating,yellow_cards,red_cards,clean_sheets,saves,passes_accuracy,distance_km,sprint_count,
        payload_json,source,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(user_id,season,competition,team) DO UPDATE SET appearances=excluded.appearances, starts=excluded.starts,
        minutes=excluded.minutes, goals=excluded.goals, assists=excluded.assists, rating=excluded.rating,
        yellow_cards=excluded.yellow_cards, red_cards=excluded.red_cards, clean_sheets=excluded.clean_sheets,
        saves=excluded.saves, passes_accuracy=excluded.passes_accuracy, distance_km=excluded.distance_km,
        sprint_count=excluded.sprint_count, payload_json=excluded.payload_json, source=excluded.source, updated_at=excluded.updated_at`)
      .bind(targetId, sport, season, competition, team, num(m.appearances) || 0, num(m.starts) || 0, num(m.minutes) || 0,
        num(m.goals) || 0, num(m.assists) || 0, num(m.rating), num(m.yellow_cards) || 0, num(m.red_cards) || 0,
        num(m.clean_sheets) || 0, num(m.saves) || 0, num(m.passes_accuracy), num(m.distance_km), num(m.sprint_count),
        m.payload && typeof m.payload === 'object' ? JSON.stringify(m.payload) : null,
        clean(m.source, 40) || 'MANUAL', at, at).run();
  }
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(targetId).first();
  if (!user) throw new HttpError(404, 'player_not_found', 'Player not found.');
  return playerRecord(env, user, viewer);
}

function sportsDbHeight(v) {
  const n = parseFloat(String(v || '').replace(',', '.'));
  if (!Number.isFinite(n) || n <= 0) return null;
  return n < 3 ? Number((n * 100).toFixed(0)) : n;
}
function sportsDbWeight(v) {
  const n = parseFloat(String(v || '').replace(',', '.'));
  return Number.isFinite(n) && n > 0 ? n : null;
}

async function searchSports(req, env, url) {
  const q = clean(url.searchParams.get('q'), 80);
  if (!q) throw new HttpError(400, 'missing_query', 'Enter a team or player name.');
  const key = env.SPORTS_API_KEY || '3';
  const localTeams = (await env.DB.prepare(`SELECT id,name,sport,league,country,badge_url,stadium,founded,external_source,external_id
    FROM sports_teams WHERE name LIKE ? ORDER BY name LIMIT 12`).bind(`%${q}%`).all()).results || [];
  const localPlayers = (await env.DB.prepare(`SELECT sp.user_id id,u.name,sp.sport,sp.club,sp.nationality,sp.position,
      sp.jersey_number,sp.photo_url,u.picture avatar_url FROM sports_profiles sp JOIN users u ON u.id=sp.user_id
    WHERE u.name LIKE ? OR sp.club LIKE ? ORDER BY u.name LIMIT 12`).bind(`%${q}%`, `%${q}%`).all()).results || [];
  const result = { teams: localTeams, players: localPlayers, source: 'local' };
  try {
    const [teamsRes, playersRes] = await Promise.all([
      fetch(`https://www.thesportsdb.com/api/v1/json/${key}/searchteams.php?t=${encodeURIComponent(q)}`).then((r) => r.json()).catch(() => null),
      fetch(`https://www.thesportsdb.com/api/v1/json/${key}/searchplayers.php?p=${encodeURIComponent(q)}`).then((r) => r.json()).catch(() => null),
    ]);
    if (Array.isArray(teamsRes?.teams)) {
      result.teams = teamsRes.teams.slice(0, 20).map((t) => ({
        external_source: 'THESPORTSDB', external_id: t.idTeam, name: t.strTeam, short_name: t.strTeamShort,
        sport: t.strSport, league: t.strLeague, country: t.strCountry, badge_url: t.strTeamBadge,
        banner_url: t.strTeamBanner, stadium: t.strStadium, founded: t.intFormedYear,
        description: t.strDescriptionEN ? String(t.strDescriptionEN).slice(0, 800) : null,
      }));
      result.source = 'THESPORTSDB';
    }
    if (Array.isArray(playersRes?.players)) {
      result.players = playersRes.players.slice(0, 20).map((p) => ({
        external_source: 'THESPORTSDB', external_id: p.idPlayer, name: p.strPlayer, sport: p.strSport,
        club: p.strTeam, nationality: p.strNationality, birth_date: p.dateBorn, position: p.strPosition,
        height_cm: sportsDbHeight(p.strHeight), weight_kg: sportsDbWeight(p.strWeight),
        photo_url: p.strThumb || p.strCutout || null, bio: p.strDescriptionEN ? String(p.strDescriptionEN).slice(0, 1200) : null,
      }));
      result.source = 'THESPORTSDB';
    }
  } catch { /* keep local results when the public API is unavailable */ }
  return json(result);
}

async function syncSportsPlayer(req, env, targetId) {
  const viewer = await requireUser(req, env);
  if (Number(viewer.id) !== Number(targetId) && !isAdminUser(env, viewer))
    throw new HttpError(403, 'forbidden', 'You can only sync your own sports profile.');
  const b = await req.json().catch(() => ({}));
  const externalId = clean(b.external_id, 80);
  if (!externalId) throw new HttpError(400, 'missing_external_id', 'Choose a player from the sports search first.');
  const key = env.SPORTS_API_KEY || '3';
  const data = await fetch(`https://www.thesportsdb.com/api/v1/json/${key}/lookupplayer.php?id=${encodeURIComponent(externalId)}`)
    .then((r) => r.json()).catch(() => null);
  const p = Array.isArray(data?.players) ? data.players[0] : null;
  if (!p) throw new HttpError(404, 'player_not_found', 'That player could not be found in the sports database.');
  const at = nowIso();
  await env.DB.prepare(`INSERT INTO sports_profiles (user_id,sport,position,club,nationality,birth_date,height_cm,weight_kg,
      photo_url,external_source,external_id,bio,metrics_json,verified,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,0,?,?)
    ON CONFLICT(user_id) DO UPDATE SET sport=excluded.sport, position=COALESCE(excluded.position,sports_profiles.position),
      club=COALESCE(excluded.club,sports_profiles.club), nationality=COALESCE(excluded.nationality,sports_profiles.nationality),
      birth_date=COALESCE(excluded.birth_date,sports_profiles.birth_date), height_cm=COALESCE(excluded.height_cm,sports_profiles.height_cm),
      weight_kg=COALESCE(excluded.weight_kg,sports_profiles.weight_kg), photo_url=COALESCE(excluded.photo_url,sports_profiles.photo_url),
      external_source=excluded.external_source, external_id=excluded.external_id, bio=COALESCE(excluded.bio,sports_profiles.bio),
      updated_at=excluded.updated_at`)
    .bind(targetId, clean(p.strSport, 60).toUpperCase() || 'FOOTBALL', clean(p.strPosition, 40) || null,
      clean(p.strTeam, 120) || null, clean(p.strNationality, 80) || null, clean(p.dateBorn, 40) || null,
      sportsDbHeight(p.strHeight), sportsDbWeight(p.strWeight), safeMediaUrl(p.strThumb || p.strCutout),
      'THESPORTSDB', externalId, clean(p.strDescriptionEN, 1200) || null, at, at).run();
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(targetId).first();
  return json(await playerRecord(env, user, viewer));
}

async function sportsRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (path === '/api/v1/sports/search' && req.method === 'GET') return await searchSports(req, env, url);
  if (path === '/api/v1/sports/teams' && req.method === 'GET') {
    const q = clean(url.searchParams.get('q'), 80);
    const rows = (await env.DB.prepare(`SELECT * FROM sports_teams ${q ? 'WHERE name LIKE ? OR league LIKE ?' : ''} ORDER BY name LIMIT 100`)
      .bind(...(q ? [`%${q}%`, `%${q}%`] : [])).all()).results || [];
    return json(rows);
  }

  const orgMatch = /^\/api\/v1\/orgs\/(\d+)(?:\/(squad|fixtures|results|news|follow))?$/.exec(path);
  if (orgMatch) {
    const id = Number(orgMatch[1]);
    const sub = orgMatch[2] || '';
    const { org, owner, fallbackUser } = await resolveOrg(env, id);
    if (!org && !fallbackUser) throw new HttpError(404, 'org_not_found', 'Team not found.');
    if (!sub && req.method === 'GET') return json(await orgRecord(env, org, owner || fallbackUser, viewer));
    if (sub === 'follow' && req.method === 'POST') {
      const target = org?.owner_id || owner?.id || fallbackUser?.id;
      if (!target) throw new HttpError(400, 'org_not_followable', 'This team has no owner account.');
      return json(await toggleFollow(env, viewer, target));
    }
    if (!org) throw new HttpError(404, 'org_not_found', 'Team not found.');
    if (sub === 'squad' && req.method === 'GET') return json(await orgSquad(env, org.id, org.name));
    if (sub === 'fixtures' && req.method === 'GET') return json(await orgEvents(env, org.id, 'SCHEDULED'));
    if (sub === 'results' && req.method === 'GET') return json(await orgEvents(env, org.id, 'FINISHED'));
    if (sub === 'news' && req.method === 'GET') return json(await orgNews(env, org.owner_id));
    throw new HttpError(404, 'not_found', 'Unknown team route.');
  }

  const playerMatch = /^\/api\/v1\/players\/(\d+)(?:\/(career|timeline|achievements|related|follow|sports-profile|sync))?$/.exec(path);
  if (playerMatch) {
    const id = Number(playerMatch[1]);
    const sub = playerMatch[2] || '';
    const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();
    if (!user) throw new HttpError(404, 'player_not_found', 'Player not found.');
    if (sub === 'follow' && req.method === 'POST') return json(await toggleFollow(env, viewer, id));
    if (sub === 'sports-profile' && (req.method === 'POST' || req.method === 'PATCH'))
      return json(await saveSportsProfile(req, env, id));
    if (sub === 'sync' && req.method === 'POST') return await syncSportsPlayer(req, env, id);
    const profile = await env.DB.prepare('SELECT * FROM sports_profiles WHERE user_id=?').bind(id).first();
    if (!sub && req.method === 'GET') return json(await playerRecord(env, user, viewer));
    if (sub === 'career' && req.method === 'GET') return json((await metricsFor(env, id)).rows);
    if (sub === 'related' && req.method === 'GET') return json(await relatedPlayers(env, user, profile));
    if (sub === 'achievements' && req.method === 'GET') {
      const rows = (await env.DB.prepare('SELECT * FROM profile_achievements WHERE user_id=? ORDER BY earned_at DESC LIMIT 30')
        .bind(id).all()).results || [];
      return json(rows.map((a) => ({ id: String(a.id), title: a.title, name: a.title, detail: a.detail || null,
        kind: a.kind, year: String(a.earned_at || '').slice(0, 4), earned_at: a.earned_at })));
    }
    if (sub === 'timeline' && req.method === 'GET') {
      const record = await playerRecord(env, user, viewer);
      return json(record.timeline);
    }
    throw new HttpError(404, 'not_found', 'Unknown player route.');
  }

  const institutionMatch = /^\/api\/v1\/(?:institutions|users)\/(\d+)\/institution$/.exec(path);
  if (institutionMatch && req.method === 'GET') {
    const id = Number(institutionMatch[1]);
    const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();
    if (!user) throw new HttpError(404, 'user_not_found', 'Institution not found.');
    const row = await env.DB.prepare('SELECT * FROM institution_profiles WHERE user_id=?').bind(id).first();
    return json({ user_id: String(user.id), name: user.name, handle: user.handle || null, role: user.role, bio: user.bio || '',
      avatar_url: user.picture || null, cover_url: user.cover_url || null, country: user.country || null,
      city: user.city || null, verified: !!user.email_verified,
      institution_type: row?.institution_type || (user.role || 'GOVERNMENT'),
      jurisdiction: row?.jurisdiction || null, services: parseJsonValue(row?.services_json, []),
      departments: parseJsonValue(row?.departments_json, []), metrics: parseJsonValue(row?.metrics_json, {}),
      transparency_score: row ? Number(row.transparency_score || 0) : 0 });
  }
  return null;
}

/* ---------------- internal HLS ingest (secret-protected) ---------------- */
function requireIngest(req, env) {
  if (!env.INGEST_SECRET) throw new HttpError(503, 'ingest_unavailable', 'Video ingest is not configured yet.');
  const supplied = req.headers.get('x-ingest-secret') || '';
  if (supplied !== env.INGEST_SECRET) throw new HttpError(401, 'unauthorized', 'Invalid ingest secret.');
}

async function videoJobRoutes(req, env, url) {
  const path = url.pathname;
  if (!path.startsWith('/api/v1/internal/')) return null;
  requireIngest(req, env);
  if (path === '/api/v1/internal/video-jobs' && req.method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20) || 'queued';
    const limit = clamp(parseInt(url.searchParams.get('limit') || '10', 10) || 10, 1, 50);
    const rows = (await env.DB.prepare('SELECT * FROM video_jobs WHERE status=? ORDER BY created_at ASC LIMIT ?')
      .bind(status, limit).all()).results || [];
    return json(rows.map((j) => ({ id: j.id, user_id: String(j.user_id), post_id: j.post_id == null ? null : String(j.post_id),
      status: j.status, original_url: j.original_url, hls_url: j.hls_url || null, poster_url: j.poster_url || null,
      duration_seconds: j.duration_seconds == null ? null : Number(j.duration_seconds), error: j.error || null,
      attempts: Number(j.attempts || 0), created_at: j.created_at, updated_at: j.updated_at })));
  }
  const jobMatch = /^\/api\/v1\/internal\/video-jobs\/([\w-]+)$/.exec(path);
  if (jobMatch && req.method === 'POST') {
    const id = jobMatch[1];
    const b = await req.json().catch(() => ({}));
    const job = await env.DB.prepare('SELECT * FROM video_jobs WHERE id=?').bind(id).first();
    if (!job) throw new HttpError(404, 'job_not_found', 'Video job not found.');
    const status = clean(b.status, 20).toLowerCase();
    if (!['queued', 'processing', 'ready', 'error'].includes(status)) throw new HttpError(400, 'bad_status', 'Unknown video job status.');
    const hls = safeMediaUrl(b.hls_url) || job.hls_url;
    const poster = safeMediaUrl(b.poster_url) || job.poster_url;
    const duration = Number.isFinite(Number(b.duration_seconds)) ? Number(b.duration_seconds) : job.duration_seconds;
    const at = nowIso();
    await env.DB.prepare(`UPDATE video_jobs SET status=?, hls_url=?, poster_url=?, duration_seconds=?, error=?,
      attempts=attempts+?, updated_at=? WHERE id=?`)
      .bind(status, hls, poster, duration, clean(b.error, 400) || null,
        status === 'processing' ? 1 : 0, at, id).run();
    if (job.post_id) {
      await env.DB.prepare(`UPDATE posts SET video_hls_url=COALESCE(?,video_hls_url),
        video_poster_url=COALESCE(?,video_poster_url), video_duration_seconds=COALESCE(?,video_duration_seconds),
        updated_at=? WHERE id=?`).bind(hls, poster, duration, at, job.post_id).run();
    }
    return json({ ok: true, id, status, hls_url: hls || null, poster_url: poster || null, post_id: job.post_id == null ? null : String(job.post_id) });
  }
  if (path === '/api/v1/internal/hls/upload' && req.method === 'POST') {
    if (!env.MEDIA) throw new HttpError(503, 'media_unavailable', 'Media storage is not configured yet.');
    const key = clean(url.searchParams.get('key'), 400);
    if (!key || !key.startsWith('media/hls/') || key.includes('..')) throw new HttpError(400, 'bad_key', 'Invalid HLS object key.');
    const ct = String(req.headers.get('content-type') || '').toLowerCase() ||
      (key.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : key.endsWith('.ts') ? 'video/mp2t' : key.endsWith('.jpg') ? 'image/jpeg' : 'application/octet-stream');
    const body = await req.arrayBuffer();
    if (body.byteLength > 40 * 1024 * 1024) throw new HttpError(413, 'too_large', 'HLS object is too large.');
    await env.MEDIA.put(key, body, { httpMetadata: { contentType: ct,
      cacheControl: key.endsWith('.m3u8') ? 'public, max-age=60' : 'public, max-age=31536000, immutable' } });
    const base = (env.MEDIA_PUBLIC_BASE || 'https://masareen.com').replace(/\/+$/, '');
    return json({ ok: true, key, url: `${base}/${key}` });
  }
  throw new HttpError(404, 'not_found', 'Unknown internal route.');
}

/* ---------------- router ---------------- */
export async function socialRoutes(req, env, ctx) {
  const url = new URL(req.url);
  const path = url.pathname;
  try {
    if (path === '/api/testers' || path === '/api/testers/stats') return await testerRoutes(req, env, url, ctx);
    if (path.startsWith('/api/v1/internal/')) return await videoJobRoutes(req, env, url);
    if (path === '/api/v1/users/register' && req.method === 'POST') return await register(req, env);
    if (path === '/api/v1/auth/login' && req.method === 'POST') return await login(req, env);
    if (path.startsWith('/api/v1/admin/')) return await adminRoutes(req, env, url);
    if (path === '/api/v1/courses' || path === '/api/v1/courses/') {
      if (req.method === 'GET') return json(await listCourses(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createCourse(req, env);
    }
    const courseMatch = /^\/api\/v1\/courses\/(\d+)(\/enroll)?$/.exec(path);
    if (courseMatch) {
      if (courseMatch[2] === '/enroll' && req.method === 'POST') return await enrollCourse(req, env, Number(courseMatch[1]));
      if (!courseMatch[2] && req.method === 'GET') {
        const row = await env.DB.prepare(`SELECT c.*, u.name author_name,
          (SELECT COUNT(*) FROM course_enrollments e WHERE e.course_id=c.id) enrolled_count
          FROM courses c LEFT JOIN users u ON u.id=c.author_id WHERE c.id=?`).bind(Number(courseMatch[1])).first();
        if (!row) throw new HttpError(404, 'course_not_found', 'Course not found.');
        const viewer = await currentUser(req, env);
        const mine = viewer ? await env.DB.prepare('SELECT 1 x FROM course_enrollments WHERE course_id=? AND user_id=?')
          .bind(row.id, viewer.id).first() : null;
        return json(courseJson(row, !!mine));
      }
    }
    if (path === '/api/v1/events' || path === '/api/v1/events/') {
      if (req.method === 'GET') return json(await listEvents(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createEvent(req, env);
    }
    const eventMatch = /^\/api\/v1\/events\/(\d+)(\/join)?$/.exec(path);
    if (eventMatch) {
      if (eventMatch[2] === '/join' && req.method === 'POST') return await joinEvent(req, env, Number(eventMatch[1]));
      if (!eventMatch[2] && req.method === 'GET') {
        const row = await env.DB.prepare(`SELECT e.*, u.name author_name,
          (SELECT COUNT(*) FROM event_attendees a WHERE a.event_id=e.id) attendees_count
          FROM events e LEFT JOIN users u ON u.id=e.author_id WHERE e.id=?`).bind(Number(eventMatch[1])).first();
        if (!row) throw new HttpError(404, 'event_not_found', 'Event not found.');
        const viewer = await currentUser(req, env);
        const mine = viewer ? await env.DB.prepare('SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?')
          .bind(row.id, viewer.id).first() : null;
        return json(eventJson(row, !!mine));
      }
    }
    if (path === '/api/v1/programs' || path === '/api/v1/programs/') {
      if (req.method === 'GET') return json(await listPrograms(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createProgram(req, env);
    }
    const programMatch = /^\/api\/v1\/programs\/(\d+)(\/enroll|\/tasks)?$/.exec(path);
    if (programMatch) {
      const id = Number(programMatch[1]);
      const sub = programMatch[2] || '';
      if (!sub && req.method === 'GET') return json(await getProgram(env, await currentUser(req, env), id));
      if (sub === '/enroll' && (req.method === 'POST' || req.method === 'GET')) return await enrollProgram(req, env, id);
      if (sub === '/tasks' && req.method === 'POST') return await createTask(req, env, id);
    }
    if (path === '/api/v1/projects' || path === '/api/v1/projects/') {
      if (req.method === 'GET') return json(await listProjects(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createProject(req, env);
    }
    const projectJoin = /^\/api\/v1\/projects\/(\d+)\/join$/.exec(path);
    if (projectJoin && req.method === 'POST') return await joinProject(req, env, Number(projectJoin[1]));
    if (path === '/api/v1/opportunities' || path === '/api/v1/opportunities/') {
      if (req.method === 'GET') return json(await listOpportunities(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createOpportunity(req, env);
    }
    const opportunityMatch = /^\/api\/v1\/opportunities\/(\d+)(\/apply)?$/.exec(path);
    if (opportunityMatch) {
      const id = Number(opportunityMatch[1]);
      if (opportunityMatch[2] === '/apply' && req.method === 'POST') return await applyOpportunity(req, env, id);
      if (!opportunityMatch[2] && req.method === 'GET') {
        const viewer = await currentUser(req, env);
        const row = await env.DB.prepare(`SELECT o.*, u.name author_name,
          (SELECT COUNT(*) FROM opportunity_applications a WHERE a.opportunity_id=o.id) applications_count
          FROM opportunities o LEFT JOIN users u ON u.id=o.author_id WHERE o.id=?`).bind(id).first();
        if (!row) throw new HttpError(404, 'opportunity_not_found', 'Opportunity not found.');
        const applied = viewer ? await env.DB.prepare('SELECT 1 x FROM opportunity_applications WHERE opportunity_id=? AND user_id=?')
          .bind(id, viewer.id).first() : null;
        return json(opportunityJson(row, !!applied));
      }
    }
    const taskHandled = await taskRoutes(req, env, url, await currentUser(req, env));
    if (taskHandled) return taskHandled;
    if (path === '/api/v1/evidence' && req.method === 'POST') return await createEvidence(req, env);
    if (path === '/api/v1/evidence' && req.method === 'GET') {
      const viewer = await requireUser(req, env);
      const rows = (await env.DB.prepare('SELECT * FROM evidence WHERE owner_id=? ORDER BY created_at DESC LIMIT 100')
        .bind(viewer.id).all()).results || [];
      return json(rows.map(evidenceJson));
    }
    if (path === '/api/v1/submissions' && req.method === 'POST') return await createSubmission(req, env);
    const submissionsUser = /^\/api\/v1\/submissions\/users\/(\d+)$/.exec(path);
    if (submissionsUser && req.method === 'GET')
      return await listSubmissions(env, await requireUser(req, env), Number(submissionsUser[1]));
    const startPipelineMatch = /^\/api\/v1\/submissions\/(\d+)\/pipeline$/.exec(path);
    if (startPipelineMatch && req.method === 'POST') return await startPipeline(req, env, Number(startPipelineMatch[1]));
    const evidencePipeline = /^\/api\/v1\/verification\/pipelines\/evidence\/(\d+)$/.exec(path);
    if (evidencePipeline && req.method === 'GET') return await pipelineForEvidence(req, env, Number(evidencePipeline[1]));
    const pipelineMatch = /^\/api\/v1\/verification\/pipelines\/(\d+)$/.exec(path);
    if (pipelineMatch && req.method === 'GET') return await getPipeline(req, env, Number(pipelineMatch[1]));
    if (path === '/api/v1/story-packs' && req.method === 'GET') return await listStoryPacks(env);
    const personnelHandled = await personnelRoutes(req, env, url, await currentUser(req, env));
    if (personnelHandled) return personnelHandled;
    if (path.startsWith('/api/v1/notifications') || path === '/api/v1/users/me/notifications') {
      if (path === '/api/v1/users/me/notifications' && req.method === 'GET') {
        const viewer = await requireUser(req, env);
        return await listNotifications(req, env, viewer.id);
      }
      const handled = await notificationRoutes(req, env, path);
      if (handled) return handled;
    }
    if (path === '/api/v1/users/me/avatar' && req.method === 'POST') return await uploadMedia(req, env, 'avatar');
    if (path === '/api/v1/users/me/cover' && req.method === 'POST') return await uploadMedia(req, env, 'cover');
    if (path === '/api/v1/media/upload' && req.method === 'POST') return await uploadMedia(req, env, 'post');
    if (path === '/api/v1/videos/upload' && req.method === 'POST') return await uploadMedia(req, env, 'video');
    if (path === '/api/v1/posts' && req.method === 'GET') return await listPosts(req, env, url);
    if (path === '/api/v1/posts' && req.method === 'POST') return await createPost(req, env);
    const postMatch = /^\/api\/v1\/posts\/(\d+)(\/[a-z]+)?$/.exec(path);
    if (postMatch) {
      const id = Number(postMatch[1]);
      const sub = postMatch[2] || '';
      if (!sub && req.method === 'GET') {
        const viewer = await currentUser(req, env);
        const row = await getPostRow(env, id);
        if (!row) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
        const liked = viewer ? await env.DB.prepare('SELECT 1 x FROM post_likes WHERE post_id=? AND user_id=?').bind(id, viewer.id).first() : null;
        return json(postJson(row, !!liked, null));
      }
      if (sub === '/like' && req.method === 'POST') return await toggleLike(req, env, id);
      if (sub === '/comment' && req.method === 'POST') return await addComment(req, env, id);
      if (sub === '/comments' && req.method === 'GET') return await listComments(req, env, id);
      if (sub === '/impact' && req.method === 'POST') return await castImpactVote(req, env, id);
      if (sub === '/share' && req.method === 'POST') return await sharePost(req, env, id);
    }
    const passportMatch = /^\/api\/v1\/users\/(\d+)\/passport$/.exec(path);
    if (passportMatch && req.method === 'GET') return await passportFor(env, Number(passportMatch[1]));
    const sportsHandled = await sportsRoutes(req, env, url, await currentUser(req, env));
    if (sportsHandled) return sportsHandled;
    const viewer = await currentUser(req, env);
    const u = await userRoutes(req, env, url, viewer);
    if (u) return u;
    if (emptyListRoutes.has(path) && req.method === 'GET') return json([]);
    throw new HttpError(404, 'not_found', 'Unknown API route.');
  } catch (e) {
    if (e instanceof HttpError) return json({ ok: false, error: e.code, message: e.message }, e.status);
    console.error('social_api_error', e && e.stack || e);
    return json({ ok: false, error: 'server_error', message: 'Something went wrong. Please try again.' }, 500);
  }
}
