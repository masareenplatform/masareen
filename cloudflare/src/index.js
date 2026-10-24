// MASAREEN API: Cloudflare Worker + D1. Free tier friendly (no paid services).
// The landing page is served from the R2 bucket; this Worker only answers /api/*.
// It works either same-origin (Worker route masareen.com/api/*) or on a subdomain
// (api.masareen.com) thanks to the CORS handling below.

import { socialRoutes, appTokenFor } from './social.js';

const enc = new TextEncoder();
const dec = new TextDecoder();
const SESSION_DAYS = 14;
const GOOGLE_CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const SITE_URL = 'https://masareen.com';
const ROLES = [
  'Student',
  'Academic / researcher',
  'Organization / institution',
  'Professional',
  'Volunteer / individual',
  'Journalist / media',
  'Donor / international partner',
  'Other',
];
const ORG_TYPES = ['Ministry / government', 'University', 'NGO / civil society', 'Company / CSR',
  'Donor / international partner', 'Student / volunteer', 'Journalist / media', 'Other'];
const DEFAULT_ORIGINS = 'https://masareen.com,https://www.masareen.com,http://localhost:8787,http://127.0.0.1:8787,http://localhost:3000';

/* ---------- helpers ---------- */
const json = (data, status = 200, headers = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers },
  });
const err = (status, code, message) => json({ ok: false, error: code, message }, status);

const b64u = {
  enc: (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
  dec: (s) => {
    s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '=';
    const bin = atob(s); const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  },
};
const clean = (v, max) => (typeof v === 'string' ? v.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max) : '');
const isEmail = (v) => /^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$/.test(v) && v.length <= 254;
const nowIso = () => new Date().toISOString();

/* ---------- CORS (landing page on R2, API on a Worker) ---------- */
function allowedOrigin(origin, req, env) {
  if (!origin || origin === 'null') return false;
  try {
    if (new URL(origin).host === new URL(req.url).host) return true;
    const list = (env.ALLOWED_ORIGINS || DEFAULT_ORIGINS)
      .split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
        try { return new URL(s).origin; } catch { return s.replace(/\/+$/, ''); }
      });
    return list.includes(new URL(origin).origin);
  } catch { return false; }
}
function corsHeaders(req, env) {
  const origin = req.headers.get('origin');
  if (!allowedOrigin(origin, req, env)) return {};
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-credentials': 'true',
    'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-max-age': '86400',
    vary: 'Origin',
  };
}

async function hmacKey(secret) {
  return crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
async function signSession(payload, secret) {
  const body = b64u.enc(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body));
  return body + '.' + b64u.enc(sig);
}
async function readSession(token, secret) {
  if (!token || !secret) return null;
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;
  const ok = await crypto.subtle.verify('HMAC', await hmacKey(secret), b64u.dec(sig), enc.encode(body));
  if (!ok) return null;
  try {
    const p = JSON.parse(dec.decode(b64u.dec(body)));
    return p.exp > Date.now() / 1000 ? p : null;
  } catch { return null; }
}
function cookie(req, name) {
  const m = (req.headers.get('cookie') || '').match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
  return m ? decodeURIComponent(m[1]) : '';
}
function sessionCookie(value, req, maxAge, env) {
  const url = new URL(req.url);
  const secure = url.protocol === 'https:' ? '; Secure' : '';
  let cross = false;
  const origin = req.headers.get('origin');
  if (origin && origin !== 'null') {
    try { cross = new URL(origin).host !== url.host; } catch { cross = false; }
  }
  // SameAsite=None is required for a cross-site (subdomain on another registrable domain)
  // API. Same-site subdomains also work with None; it is simply stricter.
  const sameSite = cross ? '; SameSite=None' : '; SameSite=Lax';
  const domain = env && env.COOKIE_DOMAIN ? '; Domain=' + env.COOKIE_DOMAIN : '';
  return `masareen_session=${encodeURIComponent(value)}; Path=/; HttpOnly${sameSite}${domain}; Max-Age=${maxAge}${secure}`;
}
async function sha256Hex(s) {
  const d = await crypto.subtle.digest('SHA-256', enc.encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
async function ipHash(req, env) {
  const ip = req.headers.get('cf-connecting-ip') || 'unknown';
  return (await sha256Hex(ip + '|' + (env.SESSION_SECRET || ''))).slice(0, 24);
}
const admins = (env) => (env.ADMIN_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);

async function body(req) {
  const ct = req.headers.get('content-type') || '';
  if (!ct.includes('application/json')) throw new HttpError(415, 'bad_content_type', 'Send JSON.');
  const text = await req.text();
  if (text.length > 20000) throw new HttpError(413, 'too_large', 'Request too large.');
  try { return JSON.parse(text || '{}'); } catch { throw new HttpError(400, 'bad_json', 'Invalid JSON.'); }
}
class HttpError extends Error { constructor(status, code, message) { super(message); this.status = status; this.code = code; } }

/* ---------- Google ID token verification (RS256 via WebCrypto) ---------- */
let certCache = { at: 0, keys: null };
async function googleKeys(fetcher) {
  if (certCache.keys && Date.now() - certCache.at < 3600_000) return certCache.keys;
  const r = await fetcher(GOOGLE_CERTS_URL);
  if (!r.ok) throw new Error('certs_unavailable');
  certCache = { at: Date.now(), keys: (await r.json()).keys };
  return certCache.keys;
}
export async function verifyGoogleIdToken(idToken, clientId, fetcher = fetch) {
  const parts = String(idToken || '').split('.');
  if (parts.length !== 3) throw new HttpError(401, 'bad_token', 'Invalid Google token.');
  let header, claims;
  try {
    header = JSON.parse(dec.decode(b64u.dec(parts[0])));
    claims = JSON.parse(dec.decode(b64u.dec(parts[1])));
  } catch {
    throw new HttpError(401, 'bad_token', 'Invalid Google token.');
  }
  if (header.alg !== 'RS256') throw new HttpError(401, 'bad_token', 'Unsupported token algorithm.');
  let jwk = (await googleKeys(fetcher)).find((k) => k.kid === header.kid);
  if (!jwk) { certCache.keys = null; jwk = (await googleKeys(fetcher)).find((k) => k.kid === header.kid); }
  if (!jwk) throw new HttpError(401, 'bad_token', 'Unknown signing key.');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  let valid = false;
  try {
    valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64u.dec(parts[2]), enc.encode(parts[0] + '.' + parts[1]));
  } catch {
    throw new HttpError(401, 'bad_token', 'Invalid Google token.');
  }
  if (!valid) throw new HttpError(401, 'bad_token', 'Token signature check failed.');
  if (!['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss)) throw new HttpError(401, 'bad_token', 'Wrong issuer.');
  if (claims.aud !== clientId) throw new HttpError(401, 'bad_token', 'Token was issued for another app.');
  if (!(claims.exp > Date.now() / 1000 - 30)) throw new HttpError(401, 'token_expired', 'Google token expired. Try again.');
  if (!claims.sub || !claims.email) throw new HttpError(401, 'bad_token', 'Missing account data.');
  return claims;
}

/* ---------- data access ---------- */
const publicUser = (u, env) => u && ({
  id: u.id, email: u.email, name: u.name, picture: u.picture, org: u.org, orgType: u.org_type,
  country: u.country, city: u.city, interest: u.interest, role: u.role,
  university: u.university, universityId: u.university_id, department: u.department,
  academicYear: u.academic_year, degreeLevel: u.degree_level,
  employer: u.employer, jobTitle: u.job_title,
  profileComplete: !!u.profile_complete, signupMethod: u.signup_method,
  isTester: !!u.is_tester,
  isAdmin: admins(env).includes(u.email.toLowerCase()),
});

async function recordLogin(env, req, user, method) {
  const t = nowIso();
  await env.DB.batch([
    env.DB.prepare('UPDATE users SET last_login_at=?, login_count=login_count+1 WHERE id=?').bind(t, user.id),
    env.DB.prepare('INSERT INTO login_events (user_id,email,method,at,country,ip_hash,user_agent) VALUES (?,?,?,?,?,?,?)')
      .bind(user.id, user.email, method, t, req.cf?.country || null, await ipHash(req, env), clean(req.headers.get('user-agent'), 160)),
  ]);
}
async function currentUser(req, env) {
  const s = await readSession(cookie(req, 'masareen_session'), env.SESSION_SECRET);
  if (!s) return null;
  return env.DB.prepare('SELECT * FROM users WHERE id=?').bind(s.uid).first();
}
async function startSession(env, req, user) {
  const exp = Math.floor(Date.now() / 1000) + SESSION_DAYS * 86400;
  const token = await signSession({ uid: user.id, exp }, env.SESSION_SECRET);
  return sessionCookie(token, req, SESSION_DAYS * 86400, env);
}

/* ---------- route handlers ---------- */
async function googleAuth(req, env, ctx) {
  if (!env.GOOGLE_CLIENT_ID) throw new HttpError(503, 'google_not_configured', 'Google sign-in is not configured yet.');
  if (!env.SESSION_SECRET) throw new HttpError(503, 'server_not_configured', 'Server secret missing.');
  const b = await body(req);
  const claims = await verifyGoogleIdToken(b.credential, env.GOOGLE_CLIENT_ID, env.__fetch || fetch);
  if (claims.email_verified === false || claims.email_verified === 'false') throw new HttpError(403, 'email_unverified', 'Your Google email is not verified.');
  const email = claims.email.toLowerCase();
  const locale = ['en', 'ar'].includes(b.locale) ? b.locale : null;
  let user = await env.DB.prepare('SELECT * FROM users WHERE google_sub=? OR email=?').bind(claims.sub, email).first();
  let isNew = false;
  if (!user) {
    isNew = true;
    await env.DB.prepare(`INSERT INTO users (google_sub,email,email_verified,name,picture,signup_method,locale,signup_country,created_at)
      VALUES (?,?,1,?,?,'google',?,?,?)`).bind(claims.sub, email, clean(claims.name || email.split('@')[0], 120), clean(claims.picture, 300) || null, locale, req.cf?.country || null, nowIso()).run();
  } else {
    await env.DB.prepare('UPDATE users SET google_sub=?, email_verified=1, picture=COALESCE(?,picture), name=CASE WHEN name=\'\' THEN ? ELSE name END WHERE id=?')
      .bind(claims.sub, clean(claims.picture, 300) || null, clean(claims.name, 120), user.id).run();
  }
  user = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  await recordLogin(env, req, user, 'google');
  user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(user.id).first();
  if (isNew) {
    ctx && ctx.waitUntil && ctx.waitUntil(sendWelcomeEmail(env, user));
  }
  return json({ ok: true, isNew, user: publicUser(user, env) }, 200, { 'set-cookie': await startSession(env, req, user) });
}

async function googleAuthToken(req, env) {
  if (!env.GOOGLE_CLIENT_ID) throw new HttpError(503, 'google_not_configured', 'Google sign-in is not configured yet.');
  if (!env.SESSION_SECRET) throw new HttpError(503, 'server_not_configured', 'Server secret missing.');
  const b = await body(req);
  const claims = await verifyGoogleIdToken(b.credential, env.GOOGLE_CLIENT_ID, env.__fetch || fetch);
  if (claims.email_verified === false || claims.email_verified === 'false')
    throw new HttpError(403, 'email_unverified', 'Your Google email is not verified.');
  const email = claims.email.toLowerCase();
  const isTester = b.is_tester === true || b.is_tester === 'true' || b.tester === true;
  const locale = ['en', 'ar'].includes(b.locale) ? b.locale : null;
  let user = await env.DB.prepare('SELECT * FROM users WHERE google_sub=? OR email=?').bind(claims.sub, email).first();
  let isNew = false;
  if (!user) {
    isNew = true;
    await env.DB.prepare(`INSERT INTO users (google_sub,email,email_verified,name,picture,signup_method,locale,signup_country,is_tester,created_at)
      VALUES (?,?,1,?,?,'google',?,?,?,?)`)
      .bind(claims.sub, email, clean(claims.name || email.split('@')[0], 120), clean(claims.picture, 300) || null,
        locale, req.cf?.country || null, isTester ? 1 : 0, nowIso()).run();
  } else {
    await env.DB.prepare(`UPDATE users SET google_sub=?, email_verified=1, picture=COALESCE(?,picture),
      name=CASE WHEN name='' THEN ? ELSE name END, is_tester=CASE WHEN ? THEN 1 ELSE is_tester END WHERE id=?`)
      .bind(claims.sub, clean(claims.picture, 300) || null, clean(claims.name, 120), isTester ? 1 : 0, user.id).run();
  }
  user = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  await recordLogin(env, req, user, 'google_app');
  return json({ ok: true, isNew, access_token: await appTokenFor(user, env), token_type: 'bearer', user: publicUser(user, env) });
}

function validateProfile(b, strict) {
  const p = {
    role: ROLES.includes(b.role) ? b.role : '',
    org: clean(b.org, 120),
    orgType: ORG_TYPES.includes(b.orgType) ? b.orgType : '',
    country: clean(b.country, 80),
    city: clean(b.city, 80),
    interest: clean(b.interest, 600),
    university: clean(b.university, 160),
    universityId: clean(b.universityId, 60),
    department: clean(b.department, 160),
    academicYear: clean(b.academicYear, 30),
    degreeLevel: clean(b.degreeLevel, 60),
    employer: clean(b.employer, 160),
    jobTitle: clean(b.jobTitle, 120),
  };
  if (strict) {
    if (!p.role) throw new HttpError(400, 'missing_fields', 'Please choose who you are.');
    if (!p.country) throw new HttpError(400, 'missing_fields', 'Please add your country.');
    if (p.role === 'Student' && (!p.university || !p.universityId || !p.department || !p.academicYear || !p.degreeLevel))
      throw new HttpError(400, 'missing_fields', 'Please add your university, student ID, department, academic year and degree level.');
    if ((p.role === 'Organization / institution' || p.role === 'Donor / international partner') && (!p.org || !p.orgType))
      throw new HttpError(400, 'missing_fields', 'Please add your organization and its type.');
    if ((p.role === 'Professional' || p.role === 'Journalist / media') && (!p.employer || !p.jobTitle))
      throw new HttpError(400, 'missing_fields', 'Please add your employer and job title.');
    if (p.role === 'Academic / researcher' && (!p.university || !p.jobTitle))
      throw new HttpError(400, 'missing_fields', 'Please add your university and academic title.');
    if ((p.role === 'Volunteer / individual' || p.role === 'Other') && !p.interest)
      throw new HttpError(400, 'missing_fields', 'Please tell us how you would like to be involved.');
    if (b.consent !== true) throw new HttpError(400, 'consent_required', 'Please accept the privacy note to continue.');
  }
  return p;
}

async function saveProfile(req, env) {
  const user = await currentUser(req, env);
  if (!user) throw new HttpError(401, 'not_signed_in', 'Please sign in first.');
  const b = await body(req);
  const p = validateProfile(b, true);
  const name = clean(b.name, 120) || user.name;
  await env.DB.prepare(`UPDATE users SET name=?, role=?, org=?, org_type=?, country=?, city=?, interest=?,
      university=?, university_id=?, department=?, academic_year=?, degree_level=?, employer=?, job_title=?,
      consent_at=COALESCE(consent_at,?), profile_complete=1 WHERE id=?`)
    .bind(name, p.role, p.org, p.orgType, p.country, p.city, p.interest, p.university, p.universityId,
      p.department, p.academicYear, p.degreeLevel, p.employer, p.jobTitle, nowIso(), user.id).run();
  const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(user.id).first();
  return json({ ok: true, user: publicUser(u, env) });
}

// Registration by email (no Google): stored as unverified so the team can tell them apart.
async function emailRegister(req, env) {
  const b = await body(req);
  if (clean(b.website, 50)) return json({ ok: true }); // honeypot
  const name = clean(b.name, 120), email = clean(b.email, 254).toLowerCase();
  if (!name || !isEmail(email)) throw new HttpError(400, 'bad_input', 'Please add your name and a valid email.');
  const p = validateProfile(b, true);
  const ih = await ipHash(req, env);
  const recent = await env.DB.prepare('SELECT COUNT(*) c FROM users WHERE signup_method=\'email\' AND created_at>? AND signup_country IS ?').bind(new Date(Date.now() - 3600_000).toISOString(), req.cf?.country || null).first();
  if (recent && recent.c > 60) throw new HttpError(429, 'rate_limited', 'Too many sign-ups right now. Try later.');
  const existing = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
  if (existing) return json({ ok: true, alreadyRegistered: true });
  const res = await env.DB.prepare(`INSERT INTO users (email,email_verified,name,role,org,org_type,country,city,interest,
      university,university_id,department,academic_year,degree_level,employer,job_title,
      consent_at,profile_complete,signup_method,locale,signup_country,created_at)
    VALUES (?,0,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,'email',?,?,?)`)
    .bind(email, name, p.role, p.org, p.orgType, p.country, p.city, p.interest, p.university, p.universityId,
      p.department, p.academicYear, p.degreeLevel, p.employer, p.jobTitle, nowIso(),
      ['en', 'ar'].includes(b.locale) ? b.locale : null, req.cf?.country || null, nowIso()).run();
  try {
    const uid = res?.meta?.last_row_id;
    const user = uid ? await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(uid).first() : { email, name };
    const ctx = env.__ctx;
    if (ctx && ctx.waitUntil) ctx.waitUntil(sendWelcomeEmail(env, user));
    else sendWelcomeEmail(env, user);
  } catch {}
  return json({ ok: true, alreadyRegistered: false, verified: false });
}

async function contact(req, env, ctx) {
  const b = await body(req);
  if (clean(b.website, 50)) return json({ ok: true });
  const name = clean(b.name, 120), email = clean(b.email, 254).toLowerCase(), message = clean(b.message, 1500);
  if (!name || !isEmail(email) || !message) throw new HttpError(400, 'bad_input', 'Please add your name, a valid email and a message.');
  const ih = await ipHash(req, env);
  const c = await env.DB.prepare('SELECT COUNT(*) c FROM contact_messages WHERE ip_hash=? AND created_at>?').bind(ih, new Date(Date.now() - 3600_000).toISOString()).first();
  if (c && c.c >= 5) throw new HttpError(429, 'rate_limited', 'Too many messages. Please try again later.');
  const user = await currentUser(req, env);
  await env.DB.prepare('INSERT INTO contact_messages (name,email,org,org_type,message,user_id,created_at,ip_hash) VALUES (?,?,?,?,?,?,?,?)')
    .bind(name, email, clean(b.org, 120), ORG_TYPES.includes(b.orgType) ? b.orgType : null, message, user ? user.id : null, nowIso(), ih).run();
  const mailData = { name, email, org: clean(b.org, 120), orgType: ORG_TYPES.includes(b.orgType) ? b.orgType : null, message };
  (ctx && ctx.waitUntil ? ctx.waitUntil(notifyContact(env, mailData)) : notifyContact(env, mailData));
  return json({ ok: true });
}

/* ---------- admin (CEO dashboard data) ---------- */
async function requireAdmin(req, env) {
  const u = await currentUser(req, env);
  if (!u) throw new HttpError(401, 'not_signed_in', 'Sign in with Google.');
  if (!admins(env).includes(u.email.toLowerCase()) || !u.email_verified) throw new HttpError(403, 'not_admin', 'This account is not an admin.');
  return u;
}
const daysAgo = (n) => new Date(Date.now() - n * 86400_000).toISOString();

async function adminStats(env) {
  const one = async (sql, ...a) => (await env.DB.prepare(sql).bind(...a).first()) || {};
  const total = await one('SELECT COUNT(*) c FROM users');
  const google = await one("SELECT COUNT(*) c FROM users WHERE signup_method='google'");
  const complete = await one('SELECT COUNT(*) c FROM users WHERE profile_complete=1');
  const s7 = await one('SELECT COUNT(*) c FROM users WHERE created_at>?', daysAgo(7));
  const s30 = await one('SELECT COUNT(*) c FROM users WHERE created_at>?', daysAgo(30));
  const l24 = await one('SELECT COUNT(*) c FROM login_events WHERE at>?', daysAgo(1));
  const l7 = await one('SELECT COUNT(*) c FROM login_events WHERE at>?', daysAgo(7));
  const active7 = await one('SELECT COUNT(DISTINCT user_id) c FROM login_events WHERE at>?', daysAgo(7));
  const msgs = await one('SELECT COUNT(*) c FROM contact_messages');
  const testers = await one('SELECT COUNT(*) c FROM testers');
  const testersInvited = await one("SELECT COUNT(*) c FROM testers WHERE status IN ('invited','active')");
  const posts = await one('SELECT COUNT(*) c FROM posts WHERE hidden=0');
  const votes = await one('SELECT COUNT(*) c FROM post_impact_votes');
  const byType = (await env.DB.prepare("SELECT COALESCE(org_type,'Unknown') k, COUNT(*) c FROM users GROUP BY 1 ORDER BY c DESC").all()).results || [];
  const byRole = (await env.DB.prepare("SELECT COALESCE(NULLIF(role,''),'Not specified') k, COUNT(*) c FROM users GROUP BY 1 ORDER BY c DESC").all()).results || [];
  const byCountry = (await env.DB.prepare("SELECT COALESCE(country,'Unknown') k, COUNT(*) c FROM users GROUP BY 1 ORDER BY c DESC LIMIT 10").all()).results || [];
  const su = (await env.DB.prepare('SELECT substr(created_at,1,10) d, COUNT(*) c FROM users WHERE created_at>? GROUP BY 1').bind(daysAgo(30)).all()).results || [];
  const lo = (await env.DB.prepare('SELECT substr(at,1,10) d, COUNT(*) c FROM login_events WHERE at>? GROUP BY 1').bind(daysAgo(30)).all()).results || [];
  const series = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400_000).toISOString().slice(0, 10);
    series.push({ date: d, signups: (su.find((x) => x.d === d) || {}).c || 0, logins: (lo.find((x) => x.d === d) || {}).c || 0 });
  }
  return { totals: { users: total.c || 0, google: google.c || 0, profileComplete: complete.c || 0, signups7d: s7.c || 0, signups30d: s30.c || 0, logins24h: l24.c || 0, logins7d: l7.c || 0, activeUsers7d: active7.c || 0, messages: msgs.c || 0, testers: testers.c || 0, testersInvited: testersInvited.c || 0, posts: posts.c || 0, impactVotes: votes.c || 0 }, byType, byRole, byCountry, series };
}
function page(url, def = 50, max = 200) {
  const limit = Math.min(max, Math.max(1, parseInt(url.searchParams.get('limit') || def, 10) || def));
  const offset = Math.max(0, parseInt(url.searchParams.get('offset') || '0', 10) || 0);
  return { limit, offset };
}
const csvCell = (v) => { let s = v == null ? '' : String(v); if (/^[=+\-@\t\r]/.test(s)) s = "'" + s; return '"' + s.replace(/"/g, '""') + '"'; };
const USER_COLUMNS = ['id', 'email', 'email_verified', 'name', 'role', 'org', 'org_type', 'country', 'city', 'interest',
  'university', 'university_id', 'department', 'academic_year', 'degree_level', 'employer', 'job_title',
  'signup_method', 'created_at', 'last_login_at', 'login_count'];

/* ---------- email (Resend) ---------- */
async function sendEmail(env, msg) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  try {
    const r = await (env.__fetch || fetch)('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(msg),
    });
    if (!r.ok) {
      const t = await r.text().catch(() => '');
      console.error('resend_error', r.status, t.slice(0, 200));
      return { ok: false, status: r.status };
    }
    return { ok: true, ...(await r.json().catch(() => ({}))) };
  } catch (e) {
    console.error('resend_exception', e);
    return { ok: false };
  }
}

function masareenEmailLayout({ preheader, title, bodyHtml, ctaText, ctaUrl, footerExtra = '' }) {
  const logoUrl = `${SITE_URL}/assets/mark.png`;
  const bg = '#f7f9fc';
  const card = '#ffffff';
  const primary = '#0f3d3e';
  const accent = '#1fb8b8';
  const gold = '#b9a06c';
  const text = '#1f2937';
  const muted = '#6b7280';
  const border = '#e5e7eb';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${title}</title><style>body{margin:0;background:${bg};font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif;color:${text}}.pre{display:none!important;max-height:0;overflow:hidden;opacity:0}.wrap{max-width:640px;margin:0 auto;padding:24px}.header{background:linear-gradient(135deg,${primary} 0%,#123d3e 60%,${accent} 140%);border-radius:16px 16px 0 0;padding:28px 32px;text-align:center}.logo{width:72px;height:72px;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.18)}.card{background:${card};border:1px solid ${border};border-top:none;border-radius:0 0 16px 16px;padding:36px 32px;box-shadow:0 30px 60px rgba(15,61,62,.08)}h1{margin:0 0 12px;font-size:26px;line-height:1.25}.lead{color:${muted};font-size:16px;line-height:1.7;margin:0 0 24px}.body{font-size:16px;line-height:1.8}.cta{display:inline-block;background:linear-gradient(90deg,${accent} 0%,#22d3ee 100%);color:#fff;text-decoration:none;padding:14px 28px;border-radius:999px;font-weight:600;box-shadow:0 18px 40px rgba(31,184,184,.18)}.divider{height:1px;background:${border};margin:32px 0}.footer{max-width:640px;margin:16px auto 40px;text-align:center;color:${muted};font-size:13px;line-height:1.8}.tag{display:inline-block;margin-top:12px;padding:6px 14px;border-radius:999px;border:1px solid rgba(185,160,108,.45);color:${gold};font-size:12px;letter-spacing:.18em;text-transform:uppercase}@media(max-width:520px){.card,.header{padding:24px}}</style></head><body><span class="pre">${preheader || ''}</span><div class="wrap"><div class="header"><img class="logo" src="${logoUrl}" alt="MASAREEN"></div><div class="card"><h1>${title}</h1>${bodyHtml}<div style="text-align:center;margin-top:32px">${ctaText && ctaUrl ? `<a class="cta" href="${ctaUrl}">${ctaText}</a>` : ''}</div><div class="divider"></div><div class="body" style="color:${muted};font-size:15px"><p style="margin:0">With gratitude,<br><strong style="color:${text}">The MASAREEN Team</strong></p></div></div></div><div class="footer"><div>MASAREEN • https://masareen.com</div><div class="tag">Building trusted knowledge for a connected future</div>${footerExtra ? `<div>${footerExtra}</div>` : ''}</div></body></html>`;
}

async function sendWelcomeEmail(env, user) {
  if (!env.RESEND_API_KEY) return;
  const first = (user.name || '').split(/\s+/)[0] || 'there';
  const subject = 'Welcome to MASAREEN — your pilot access is ready';
  const bodyHtml = `<p class="lead">Assalamu Alaikum ${first}, and a warm welcome to MASAREEN.</p><div class="body"><p>Thank you for joining our pilot. You are now part of a growing community of students, researchers, institutions and changemakers working to make credible knowledge easier to verify, share and act on.</p><p>Here's what happens next:</p><ul><li><strong>Complete your profile</strong> — help us tailor the experience to your goals.</li><li><strong>Stay in the loop</strong> — we'll share pilot updates and early opportunities as they go live.</li><li><strong>Shape the platform</strong> — your feedback truly matters.</li></ul><p>If you ever need help, just reply to this message and our team will get back to you.</p></div>`;
  const html = masareenEmailLayout({ preheader: 'Welcome to the MASAREEN pilot', title: 'Welcome to MASAREEN', bodyHtml, ctaText: 'Visit your dashboard', ctaUrl: SITE_URL });
  await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to: [user.email], subject, html, reply_to: env.MAIL_REPLY_TO || undefined });
}

async function notifyContact(env, data) {
  if (!env.RESEND_API_KEY) return;
  const to = (env.CONTACT_TO || env.ADMIN_EMAILS || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!to.length) return;
  const subject = `New contact message — ${data.name}`;
  const bodyHtml = `<p class="lead">A new message came through the MASAREEN contact form.</p><div class="body"><table style="width:100%;border-collapse:collapse"><tr><td style="padding:10px 0;color:${'#6b7280'}">Name</td><td style="padding:10px 0"><strong>${data.name}</strong></td></tr><tr><td style="padding:10px 0;color:${'#6b7280'}">Email</td><td style="padding:10px 0"><a href="mailto:${data.email}">${data.email}</a></td></tr>${data.org ? `<tr><td style="padding:10px 0;color:${'#6b7280'}">Organization</td><td style="padding:10px 0">${data.org}${data.orgType ? ` • ${data.orgType}` : ''}</td></tr>` : ''}</table><div style="margin-top:18px;padding:18px 22px;background:#f7f9fc;border-radius:12px;border:1px solid #e5e7eb;white-space:pre-wrap">${data.message.replace(/</g,'&lt;')}</div></div>`;
  const html = masareenEmailLayout({ preheader: 'New contact message', title: 'Contact form submission', bodyHtml, ctaText: 'Reply to this lead', ctaUrl: `mailto:${data.email}` });
  await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to, subject, html, reply_to: data.email });
  if ((env.CONTACT_COPY_USER || '').toLowerCase() === 'true') {
    const copyHtml = masareenEmailLayout({ preheader: 'We received your message', title: 'Thanks for reaching out', bodyHtml: `<p class="lead">Hi ${data.name.split(/\s+/)[0]}, thanks for getting in touch.</p><div class="body"><p>We've received your message and our team will review it and get back to you soon.</p><div style="margin-top:18px;padding:18px 22px;background:#f7f9fc;border-radius:12px;border:1px solid #e5e7eb;white-space:pre-wrap">${data.message.replace(/</g,'&lt;')}</div></div>`, ctaText: 'Back to MASAREEN', ctaUrl: SITE_URL });
    await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to: [data.email], subject: 'We received your message — MASAREEN', html: copyHtml, reply_to: env.MAIL_REPLY_TO || undefined });
  }
}

async function adminRoutes(req, env, url) {
  await requireAdmin(req, env);
  const path = url.pathname;
  if (path === '/api/admin/stats') return json({ ok: true, ...(await adminStats(env)) });
  if (path === '/api/admin/users') {
    const { limit, offset } = page(url); const q = clean(url.searchParams.get('q'), 80);
    const like = `%${q.replace(/[%_]/g, '')}%`;
    const where = q ? 'WHERE email LIKE ? OR name LIKE ? OR org LIKE ? OR university LIKE ? OR employer LIKE ?' : '';
    const args = q ? [like, like, like, like, like] : [];
    const rows = (await env.DB.prepare(`SELECT id,email,email_verified,name,role,org,org_type,country,city,interest,
        university,university_id,department,academic_year,degree_level,employer,job_title,
        signup_method,profile_complete,created_at,last_login_at,login_count FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).bind(...args, limit, offset).all()).results;
    const total = (await env.DB.prepare(`SELECT COUNT(*) c FROM users ${where}`).bind(...args).first()).c;
    return json({ ok: true, total, rows });
  }
  if (path === '/api/admin/logins') {
    const { limit, offset } = page(url);
    const rows = (await env.DB.prepare('SELECT id,user_id,email,method,at,country FROM login_events ORDER BY at DESC LIMIT ? OFFSET ?').bind(limit, offset).all()).results;
    return json({ ok: true, rows });
  }
  if (path === '/api/admin/messages') {
    const { limit, offset } = page(url);
    const rows = (await env.DB.prepare('SELECT id,name,email,org,org_type,message,created_at FROM contact_messages ORDER BY created_at DESC LIMIT ? OFFSET ?').bind(limit, offset).all()).results;
    return json({ ok: true, rows });
  }
  if (path === '/api/admin/export/users.csv') {
    const rows = (await env.DB.prepare(`SELECT ${USER_COLUMNS.join(',')} FROM users ORDER BY created_at DESC`).all()).results;
    const csv = [USER_COLUMNS.join(',')].concat(rows.map((r) => USER_COLUMNS.map((c) => csvCell(r[c])).join(','))).join('\n');
    return new Response(csv, { headers: { 'content-type': 'text/csv; charset=utf-8', 'content-disposition': 'attachment; filename="masareen-users.csv"', 'cache-control': 'no-store' } });
  }
  if (path === '/api/admin/testers') {
    const { limit, offset } = page(url);
    const rows = (await env.DB.prepare('SELECT * FROM testers ORDER BY created_at DESC LIMIT ? OFFSET ?').bind(limit, offset).all()).results;
    const total = (await env.DB.prepare('SELECT COUNT(*) c FROM testers').first()).c || 0;
    return json({ ok: true, total, rows });
  }
  if (path === '/api/admin/testers.csv') {
    const cols = ['name', 'email', 'country', 'device', 'android_version', 'source', 'status', 'created_at'];
    const rows = (await env.DB.prepare(`SELECT ${cols.join(',')} FROM testers ORDER BY created_at DESC`).all()).results;
    const csv = [cols.join(',')].concat(rows.map((r) => cols.map((c) => csvCell(r[c])).join(','))).join('\n');
    return new Response(csv, { headers: { 'content-type': 'text/csv; charset=utf-8', 'content-disposition': 'attachment; filename="masareen-testers.csv"', 'cache-control': 'no-store' } });
  }
  const testerStatus = /^\/api\/admin\/testers\/(\d+)\/status$/.exec(path);
  if (testerStatus && req.method === 'POST') {
    const b = await req.json().catch(() => ({}));
    const status = ['pending', 'invited', 'active', 'declined'].includes(b.status) ? b.status : null;
    if (!status) throw new HttpError(400, 'invalid_status', 'Choose pending, invited, active or declined.');
    await env.DB.prepare("UPDATE testers SET status=?, invited_at=CASE WHEN ?='invited' THEN ? ELSE invited_at END WHERE id=?")
      .bind(status, status, nowIso(), Number(testerStatus[1])).run();
    return json({ ok: true });
  }
  if (path === '/api/admin/social') {
    const one = async (sql) => (await env.DB.prepare(sql).first()) || {};
    const p = await one('SELECT COUNT(*) c FROM posts WHERE hidden=0');
    const l = await one('SELECT COUNT(*) c FROM post_likes');
    const cm = await one('SELECT COUNT(*) c FROM post_comments WHERE hidden=0');
    const v = await one('SELECT COUNT(*) c FROM post_impact_votes');
    const avg = await one('SELECT COALESCE(AVG(impact_value),0) a, COALESCE(AVG(confidence_score),0) c FROM posts WHERE hidden=0');
    const top = (await env.DB.prepare('SELECT id, text, impact_value, confidence_score FROM posts WHERE hidden=0 ORDER BY impact_value DESC LIMIT 10').all()).results;
    return json({ ok: true, totals: { posts: p.c || 0, likes: l.c || 0, comments: cm.c || 0, impactVotes: v.c || 0, avgImpact: Number((avg.a || 0).toFixed(2)), avgConfidence: Math.round(avg.c || 0) }, top });
  }
  throw new HttpError(404, 'not_found', 'Unknown admin route.');
}

/* ---------- router ---------- */
async function route(req, env, ctx) {
  const url = new URL(req.url);
  const p = url.pathname, m = req.method;
  try {
    if (!['GET', 'HEAD', 'OPTIONS'].includes(m)) {
      const origin = req.headers.get('origin');
      if (origin && !allowedOrigin(origin, req, env))
        throw new HttpError(403, 'bad_origin', 'Cross-site requests are not allowed.');
    }
    if (p === '/api/health') return json({ ok: true, service: 'masareen-api', time: nowIso(), googleConfigured: !!env.GOOGLE_CLIENT_ID });
    if (p === '/api/v1/auth/google' && m === 'POST') return await googleAuthToken(req, env);
    if (p.startsWith('/api/v1/') || p === '/api/testers' || p === '/api/testers/stats')
      return await socialRoutes(req, env, ctx);
    if (p === '/api/config' && m === 'GET') return json({ ok: true, googleClientId: env.GOOGLE_CLIENT_ID || '', orgTypes: ORG_TYPES, roles: ROLES });
    if (p === '/api/me' && m === 'GET') { const u = await currentUser(req, env); return json({ ok: true, user: publicUser(u, env) || null }); }
    if (p === '/api/auth/google' && m === 'POST') return await googleAuth(req, env, ctx);
    if (p === '/api/auth/register' && m === 'POST') { env.__ctx = ctx; return await emailRegister(req, env); }
    if (p === '/api/auth/logout' && m === 'POST') return json({ ok: true }, 200, { 'set-cookie': sessionCookie('', req, 0, env) });
    if (p === '/api/profile' && m === 'POST') return await saveProfile(req, env);
    if (p === '/api/contact' && m === 'POST') return await contact(req, env, ctx);
    if (p.startsWith('/api/admin/') && (m === 'GET' || m === 'POST')) return await adminRoutes(req, env, url);
    throw new HttpError(404, 'not_found', 'Unknown API route.');
  } catch (e) {
    if (e instanceof HttpError) return err(e.status, e.code, e.message);
    console.error('api_error', e && e.stack || e);
    return err(500, 'server_error', 'Something went wrong. Please try again.');
  }
}

export async function handle(req, env, ctx) {
  const cors = corsHeaders(req, env);
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  const res = await route(req, env, ctx);
  if (!Object.keys(cors).length) return res;
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(cors)) headers.set(k, v);
  return new Response(res.body, { status: res.status, headers });
}

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    if (url.pathname.startsWith('/api/')) return handle(req, env, ctx);
    // Landing page lives in the R2 bucket. If a copy is also bound as static
    // assets on this Worker, serve it; otherwise answer with a short hint.
    if (env.ASSETS) return env.ASSETS.fetch(req);
    return json({ ok: true, service: 'masareen-api', message: 'API only. The site is served from the R2 bucket.' }, 200);
  },
};
