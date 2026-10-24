// MASAREEN social + impact API (v1), served by the same Worker as the landing API.
// Auth here is email+password with PBKDF2 hashing and HMAC bearer tokens, so the
// mobile app never depends on an external server. All data lives in D1.

const enc = new TextEncoder();
const TOKEN_DAYS = 30;
const PBKDF2_ITERATIONS = 100000;
const ROLES = new Set(['INDIVIDUAL', 'STUDENT', 'ACADEMIC', 'ORGANIZATION', 'PROFESSIONAL',
  'VOLUNTEER', 'JOURNALIST', 'DONOR', 'GOVERNMENT', 'MEDIA', 'SPORTS', 'ATHLETE', 'PLATFORM', 'ADMIN']);
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
      cover_url: null,
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

function postJson(r, likedByMe, ranking) {
  let factors = null;
  if (r.confidence_factors) { try { factors = JSON.parse(r.confidence_factors); } catch { factors = null; } }
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
    const verified = r.author_verified ? 1 : 0;
    const explore = hash01((viewer ? viewer.id : 'guest') + ':' + r.id) * 0.14;
    const seenPenalty = viewer && seen.has(r.id) ? 0.22 : 0;
    const score = 0.30 * Math.min(1.4, velocity) + 0.27 * impact + 0.22 * recency +
      0.10 * (isFollow ? 1 : 0) + 0.06 * interest + 0.04 * verified + explore - seenPenalty + (isSelf ? 0.03 : 0);
    const reasons = [];
    if (impact >= 0.7) reasons.push({ key: 'impact', label: 'High verified impact', weight: 0.27 * impact });
    if (isFollow) reasons.push({ key: 'following', label: 'From a profile you follow', weight: 0.1 });
    if (velocity >= 0.5) reasons.push({ key: 'trending', label: 'Trending in the community', weight: 0.3 * velocity });
    if (interest) reasons.push({ key: 'interest', label: 'Matches your interests', weight: 0.06 });
    if (ageH < 6) reasons.push({ key: 'fresh', label: 'Fresh update', weight: 0.22 * recency });
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
  if (!isEmail(email)) throw new HttpError(400, 'invalid_email', 'Please enter a valid email address.');
  if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Please enter your full name.');
  if (password.length < 8) throw new HttpError(400, 'weak_password', 'Password must be at least 8 characters.');
  const existing = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (existing) {
    if (existing.password_hash) throw new HttpError(409, 'email_taken', 'An account with this email already exists. Please sign in.');
    const { salt, hash } = await hashPassword(password);
    await env.DB.prepare('UPDATE users SET password_hash=?, password_salt=?, name=COALESCE(NULLIF(?,\'\'),name), signup_method=? WHERE id=?')
      .bind(hash, salt, name, 'password', existing.id).run();
    const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(existing.id).first();
    return json({ ok: true, access_token: await signToken({ uid: u.id, exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET), token_type: 'bearer', user: await userJson(env, u, u) });
  }
  const role = ROLES.has(String(b.role || '').toUpperCase()) ? String(b.role).toUpperCase() : 'INDIVIDUAL';
  const { salt, hash } = await hashPassword(password);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO users (email, email_verified, name, role, country, city, interest, phone,
      password_hash, password_salt, handle, bio, consent_at, profile_complete, signup_method, created_at, last_login_at, login_count)
      VALUES (?,0,?,?,?,?,?,?,?,?,?,?,?,1,'password',?,?,1)`)
    .bind(email, name, role, clean(b.country, 60) || null, clean(b.city, 80) || null, clean(b.interest, 120) || null,
      clean(b.phone, 40) || null, hash, salt, handleFor(name, '0'), clean(b.bio, 400) || null, at, at, at).run();
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
  const media = clean(b.media_url || b.url, 500) || null;
  const link = clean(b.link_url || b.link, 500) || null;
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO posts (author_id,text,kind,sdg,impact_value,impact_label,confidence_score,confidence_label,confidence_factors,media_url,link_url,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(u.id, text, kind, sdg && sdg >= 1 && sdg <= 17 ? sdg : null, null, 'Awaiting ratings', 0, 'Low confidence',
      JSON.stringify({ ratings: 0, method: 'weighted ratings + engagement + author trust' }), media, link, at).run();
  const row = await getPostRow(env, r.meta.last_row_id);
  return json(postJson(row, false, null), 201);
}

async function toggleLike(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT id FROM posts WHERE id=? AND hidden=0').bind(id).first();
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
  const post = await env.DB.prepare('SELECT id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const at = nowIso();
  const r = await env.DB.prepare('INSERT INTO post_comments (post_id,user_id,text,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, text, at).run();
  await env.DB.prepare('UPDATE posts SET comment_count=comment_count+1 WHERE id=?').bind(id).run();
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

/* ---------------- misc app endpoints (graceful stubs) ---------------- */
const emptyListRoutes = new Set([
  '/api/v1/programs', '/api/v1/programs/', '/api/v1/opportunities', '/api/v1/opportunities/',
  '/api/v1/campaigns', '/api/v1/campaigns/', '/api/v1/courses', '/api/v1/courses/',
  '/api/v1/notifications', '/api/v1/users/me/notifications', '/api/v1/coin/transactions',
  '/api/v1/payments', '/api/v1/ads', '/api/v1/projects',
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
    else await env.DB.prepare('INSERT INTO follows (follower_id,followee_id,created_at) VALUES (?,?,?)').bind(viewer.id, target, nowIso()).run();
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

/* ---------------- router ---------------- */
export async function socialRoutes(req, env, ctx) {
  const url = new URL(req.url);
  const path = url.pathname;
  try {
    if (path === '/api/testers' || path === '/api/testers/stats') return await testerRoutes(req, env, url, ctx);
    if (path === '/api/v1/users/register' && req.method === 'POST') return await register(req, env);
    if (path === '/api/v1/auth/login' && req.method === 'POST') return await login(req, env);
    if (path.startsWith('/api/v1/admin/')) return await adminRoutes(req, env, url);
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
