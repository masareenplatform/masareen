// MASAREEN API: Cloudflare Worker + D1. Free tier friendly (no paid services).
// The landing page is served from the R2 bucket; this Worker only answers /api/*.
// It works either same-origin (Worker route masareen.com/api/*) or on a subdomain
// (api.masareen.com) thanks to the CORS handling below.

import { socialRoutes, appTokenFor, runRecognitionSweep, appUpdateManifest, adminAlert } from './social.js';

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
const ROLE_TO_CODE = {
  'Student': 'STUDENT',
  'Academic / researcher': 'ACADEMIC',
  'Organization / institution': 'ORGANIZATION',
  'Professional': 'PROFESSIONAL',
  'Volunteer / individual': 'INDIVIDUAL',
  'Journalist / media': 'MEDIA',
  'Donor / international partner': 'DONOR',
  'Other': 'INDIVIDUAL',
};
const ROLE_LABELS = Object.fromEntries(Object.entries(ROLE_TO_CODE).map(([k, v]) => [v, k]));
const roleCode = (label) => ROLE_TO_CODE[label] || (typeof label === 'string' && label === label.toUpperCase() ? label : null);
const roleLabel = (code) => ROLE_LABELS[code] || code || 'Individual';
const escapeHtml = (s) => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
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
  if (!secret) throw new HttpError(500, 'not_configured', 'Session signing is not configured.');
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
    if (p.typ && p.typ !== 'session') return null;
    const expMs = p.exp > 1e12 ? p.exp : p.exp * 1000;
    return expMs > Date.now() ? p : null;
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
  if (!certCache.keys && Date.now() - certCache.at < 60_000) return null;
  try {
    const r = await fetcher(GOOGLE_CERTS_URL);
    if (!r.ok) return null;
    certCache = { at: Date.now(), keys: (await r.json()).keys };
    return certCache.keys;
  } catch { return null; }
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
  const keys = await googleKeys(fetcher);
  let jwk = keys ? keys.find((k) => k.kid === header.kid) : null;
  if (!jwk && Date.now() - certCache.at > 60_000) {
    const refreshed = await googleKeys(fetcher);
    jwk = refreshed ? refreshed.find((k) => k.kid === header.kid) : null;
  }
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
  country: u.country, city: u.city, interest: u.interest, role: roleLabel(u.role),
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
  const token = await signSession({ uid: user.id, typ: 'session', exp }, env.SESSION_SECRET);
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
    // Keep an avatar the member uploaded in-app; only fill in the Google photo
    // when there is no uploaded media avatar yet.
    await env.DB.prepare(`UPDATE users SET google_sub=?, email_verified=1,
      picture=CASE WHEN COALESCE(picture,'') LIKE '%/media/avatars/%' THEN picture
        ELSE COALESCE(?,picture) END,
      name=CASE WHEN name='' THEN ? ELSE name END WHERE id=?`)
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
    await env.DB.prepare(`UPDATE users SET google_sub=?, email_verified=1,
      picture=CASE WHEN COALESCE(picture,'') LIKE '%/media/avatars/%' THEN picture
        ELSE COALESCE(?,picture) END,
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
  const storedRole = roleCode(p.role) || user.role || 'INDIVIDUAL';
  await env.DB.prepare(`UPDATE users SET name=?, role=?, org=?, org_type=?, country=?, city=?, interest=?,
      university=?, university_id=?, department=?, academic_year=?, degree_level=?, employer=?, job_title=?,
      consent_at=COALESCE(consent_at,?), profile_complete=1 WHERE id=?`)
    .bind(name, storedRole, p.org, p.orgType, p.country, p.city, p.interest, p.university, p.universityId,
      p.department, p.academicYear, p.degreeLevel, p.employer, p.jobTitle, nowIso(), user.id).run();
  const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(user.id).first();
  return json({ ok: true, user: publicUser(u, env) });
}

// Registration by email (no Google): stored as unverified until confirmed via magic link.
async function emailRegister(req, env, ctx) {
  const b = await body(req);
  if (clean(b.website, 50)) return json({ ok: true }); // honeypot
  const name = clean(b.name, 120), email = clean(b.email, 254).toLowerCase();
  if (!name || !isEmail(email)) throw new HttpError(400, 'bad_input', 'Please add your name and a valid email.');
  const p = validateProfile(b, true);
  const storedRole = roleCode(p.role) || 'INDIVIDUAL';
  const ih = await ipHash(req, env);
  const rlKey = `email_reg:${ih}`;
  const recent = await env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?')
    .bind(rlKey, new Date(Date.now() - 3600_000).toISOString()).first();
  if (recent && recent.c >= 10) throw new HttpError(429, 'rate_limited', 'Too many sign-ups from this network right now. Try later.');
  await env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?, ?)').bind(rlKey, nowIso()).run();
  const existing = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
  if (existing) return json({ ok: true, alreadyRegistered: true });
  const res = await env.DB.prepare(`INSERT INTO users (email,email_verified,name,role,org,org_type,country,city,interest,
      university,university_id,department,academic_year,degree_level,employer,job_title,
      consent_at,profile_complete,signup_method,locale,signup_country,created_at)
    VALUES (?,0,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,'email',?,?,?)`)
    .bind(email, name, storedRole, p.org, p.orgType, p.country, p.city, p.interest, p.university, p.universityId,
      p.department, p.academicYear, p.degreeLevel, p.employer, p.jobTitle, nowIso(),
      ['en', 'ar'].includes(b.locale) ? b.locale : null, req.cf?.country || null, nowIso()).run();
  try {
    const uid = res?.meta?.last_row_id;
    const user = uid ? await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(uid).first() : { email, name };
    if (ctx && ctx.waitUntil) ctx.waitUntil(sendWelcomeEmail(env, user));
    else sendWelcomeEmail(env, user);
  } catch {}
  return json({ ok: true, alreadyRegistered: false, verified: false });
}

async function requestMagicLink(req, env, ctx) {
  if (!env.SESSION_SECRET) throw new HttpError(503, 'server_not_configured', 'Server secret missing.');
  const b = await body(req);
  if (clean(b.website, 50)) return json({ ok: true, sent: true });
  const email = clean(b.email, 254).toLowerCase();
  if (!isEmail(email)) throw new HttpError(400, 'bad_input', 'Please enter a valid email address.');
  const ih = await ipHash(req, env);
  const since = new Date(Date.now() - 3600_000).toISOString();
  const ipKey = `magic_ip:${ih}`;
  const emailKey = `magic_email:${email}`;
  const [ipCount, emailCount] = await Promise.all([
    env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?').bind(ipKey, since).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?').bind(emailKey, since).first(),
  ]);
  if ((ipCount && ipCount.c >= 10) || (emailCount && emailCount.c >= 4)) {
    throw new HttpError(429, 'rate_limited', 'Too many sign-in link requests. Please wait a few minutes and try again.');
  }
  const at = nowIso();
  await env.DB.batch([
    env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?, ?)').bind(ipKey, at),
    env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?, ?)').bind(emailKey, at),
  ]);
  const user = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (!user) return json({ ok: true, sent: true });
  const rawBytes = crypto.getRandomValues(new Uint8Array(32));
  const rawToken = b64u.enc(rawBytes);
  const tokenHash = await sha256Hex(rawToken);
  const expiresAt = new Date(Date.now() + 30 * 60_000).toISOString();
  await env.DB.prepare('INSERT INTO auth_tokens (user_id, kind, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
    .bind(user.id, 'web_magic_link', tokenHash, expiresAt, at).run();
  const reqOrigin = new URL(req.url).origin;
  const baseOrigin = env.SITE_URL || (reqOrigin.includes('localhost') || reqOrigin.includes('.test') ? reqOrigin : SITE_URL);
  const magicUrl = `${baseOrigin}/api/auth/magic-link?token=${encodeURIComponent(rawToken)}`;
  const sendTask = sendMagicLinkEmail(env, user, magicUrl);
  if (ctx && ctx.waitUntil) ctx.waitUntil(sendTask);
  else await sendTask;
  return json({ ok: true, sent: true });
}

async function verifyMagicLink(req, env) {
  if (!env.SESSION_SECRET) throw new HttpError(503, 'server_not_configured', 'Server secret missing.');
  const url = new URL(req.url);
  const rawToken = clean(url.searchParams.get('token'), 200);
  const invalidHtml = () => new Response(
    `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Sign-in link expired — MASAREEN</title></head><body style="font-family:Inter,system-ui,sans-serif;background:#f7f9fc;color:#1f2937;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:24px"><div style="max-width:440px;background:#fff;padding:32px;border-radius:16px;border:1px solid #e5e7eb;text-align:center"><h1 style="margin:0 0 12px;font-size:22px">This sign-in link has expired</h1><p style="color:#6b7280;line-height:1.6;margin:0 0 24px">Sign-in links are valid for 30 minutes and can only be used once. Request a fresh link on MASAREEN.</p><a href="/#join" style="display:inline-block;background:#0f3d3e;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-weight:600">Back to MASAREEN</a></div></body></html>`,
    { status: 400, headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } }
  );
  if (!rawToken || rawToken.length < 20) return invalidHtml();
  const tokenHash = await sha256Hex(rawToken);
  const row = await env.DB.prepare('SELECT * FROM auth_tokens WHERE token_hash=? AND kind=?')
    .bind(tokenHash, 'web_magic_link').first();
  if (!row || row.used_at || row.expires_at <= nowIso()) return invalidHtml();
  const used = await env.DB.prepare('UPDATE auth_tokens SET used_at=? WHERE id=? AND used_at IS NULL')
    .bind(nowIso(), row.id).run();
  if (!used?.meta?.changes) return invalidHtml();
  await env.DB.prepare('UPDATE users SET email_verified=1 WHERE id=?').bind(row.user_id).run();
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(row.user_id).first();
  if (!user) return invalidHtml();
  await recordLogin(env, req, user, 'magic_link');
  const cookieHeader = await startSession(env, req, user);
  const targetOrigin = env.SITE_URL || (url.origin.includes('localhost') || url.origin.includes('.test') ? url.origin : SITE_URL);
  return new Response(null, {
    status: 302,
    headers: {
      location: `${targetOrigin}/#join`,
      'set-cookie': cookieHeader,
      'cache-control': 'no-store',
    },
  });
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
  const org = clean(b.org, 120);
  const orgType = ORG_TYPES.includes(b.orgType) ? b.orgType : null;
  const ins = await env.DB.prepare('INSERT INTO contact_messages (name,email,org,org_type,message,user_id,created_at,ip_hash) VALUES (?,?,?,?,?,?,?,?)')
    .bind(name, email, org, orgType, message, user ? user.id : null, nowIso(), ih).run();
  const mailData = { name, email, org, orgType, message };
  (ctx && ctx.waitUntil ? ctx.waitUntil(notifyContact(env, mailData)) : notifyContact(env, mailData));
  const alertWork = adminAlert(env, {
    type: 'admin_contact',
    severity: 'high',
    title: `New contact message from ${name}`,
    body: `${email}${org ? ` · ${org}` : ''} · ${message.slice(0, 180)}`,
    link: 'admin:inbox',
    entityType: 'contact_message',
    entityId: String(ins.meta.last_row_id),
    dedupeKey: `contact:${ins.meta.last_row_id}`,
  }).catch(() => {});
  if (ctx && ctx.waitUntil) ctx.waitUntil(alertWork);
  else await alertWork;
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
  const realUsers = await one('SELECT COUNT(*) c FROM users WHERE COALESCE(is_demo,0)=0');
  const demoUsers = await one('SELECT COUNT(*) c FROM users WHERE COALESCE(is_demo,0)=1');
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
  return { totals: { users: total.c || 0, realUsers: realUsers.c || 0, demoUsers: demoUsers.c || 0, google: google.c || 0, profileComplete: complete.c || 0, signups7d: s7.c || 0, signups30d: s30.c || 0, logins24h: l24.c || 0, logins7d: l7.c || 0, activeUsers7d: active7.c || 0, messages: msgs.c || 0, testers: testers.c || 0, testersInvited: testersInvited.c || 0, posts: posts.c || 0, impactVotes: votes.c || 0 }, byType, byRole, byCountry, series };
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
  const first = escapeHtml((user.name || '').split(/\s+/)[0] || 'there');
  const subject = 'Welcome to MASAREEN — your pilot access is ready';
  const bodyHtml = `<p class="lead">Assalamu Alaikum ${first}, and a warm welcome to MASAREEN.</p><div class="body"><p>Thank you for joining our pilot. You are now part of a growing community of students, researchers, institutions and changemakers working to make credible knowledge easier to verify, share and act on.</p><p>Here's what happens next:</p><ul><li><strong>Complete your profile</strong> — help us tailor the experience to your goals.</li><li><strong>Stay in the loop</strong> — we'll share pilot updates and early opportunities as they go live.</li><li><strong>Shape the platform</strong> — your feedback truly matters.</li></ul><p>If you ever need help, just reply to this message and our team will get back to you.</p></div>`;
  const html = masareenEmailLayout({ preheader: 'Welcome to the MASAREEN pilot', title: 'Welcome to MASAREEN', bodyHtml, ctaText: 'Visit your dashboard', ctaUrl: SITE_URL });
  await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to: [user.email], subject, html, reply_to: env.MAIL_REPLY_TO || undefined });
}

async function sendMagicLinkEmail(env, user, magicUrl) {
  if (!env.RESEND_API_KEY) return;
  const first = escapeHtml((user.name || '').split(/\s+/)[0] || 'there');
  const safeUrl = escapeHtml(magicUrl);
  const subject = 'Your MASAREEN sign-in link';
  const bodyHtml = `<p class="lead">Assalamu Alaikum ${first}, use the button below to sign in to MASAREEN.</p><div class="body"><p>This single-use link expires in 30 minutes and confirms your email address.</p><p>If you did not request this link, you can safely ignore this email.</p></div>`;
  const html = masareenEmailLayout({ preheader: 'Sign in to MASAREEN', title: 'Sign in to MASAREEN', bodyHtml, ctaText: 'Sign in to MASAREEN', ctaUrl: safeUrl });
  await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to: [user.email], subject, html, reply_to: env.MAIL_REPLY_TO || undefined });
}

async function notifyContact(env, data) {
  if (!env.RESEND_API_KEY) return;
  const to = (env.CONTACT_TO || env.ADMIN_EMAILS || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!to.length) return;
  const safeName = escapeHtml(data.name);
  const safeEmail = escapeHtml(data.email);
  const safeOrg = escapeHtml(data.org || '');
  const safeOrgType = escapeHtml(data.orgType || '');
  const subject = `New contact message — ${data.name}`;
  const bodyHtml = `<p class="lead">A new message came through the MASAREEN contact form.</p><div class="body"><table style="width:100%;border-collapse:collapse"><tr><td style="padding:10px 0;color:${'#6b7280'}">Name</td><td style="padding:10px 0"><strong>${safeName}</strong></td></tr><tr><td style="padding:10px 0;color:${'#6b7280'}">Email</td><td style="padding:10px 0"><a href="mailto:${safeEmail}">${safeEmail}</a></td></tr>${data.org ? `<tr><td style="padding:10px 0;color:${'#6b7280'}">Organization</td><td style="padding:10px 0">${safeOrg}${data.orgType ? ` • ${safeOrgType}` : ''}</td></tr>` : ''}</table><div style="margin-top:18px;padding:18px 22px;background:#f7f9fc;border-radius:12px;border:1px solid #e5e7eb;white-space:pre-wrap">${escapeHtml(data.message)}</div></div>`;
  const html = masareenEmailLayout({ preheader: 'New contact message', title: 'Contact form submission', bodyHtml, ctaText: 'Reply to this lead', ctaUrl: `mailto:${data.email}` });
  await sendEmail(env, { from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>', to, subject, html, reply_to: data.email });
  if ((env.CONTACT_COPY_USER || '').toLowerCase() === 'true') {
    const copyHtml = masareenEmailLayout({ preheader: 'We received your message', title: 'Thanks for reaching out', bodyHtml: `<p class="lead">Hi ${escapeHtml((data.name || '').split(/\s+/)[0] || 'there')}, thanks for getting in touch.</p><div class="body"><p>We've received your message and our team will review it and get back to you soon.</p><div style="margin-top:18px;padding:18px 22px;background:#f7f9fc;border-radius:12px;border:1px solid #e5e7eb;white-space:pre-wrap">${escapeHtml(data.message)}</div></div>`, ctaText: 'Back to MASAREEN', ctaUrl: SITE_URL });
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
        signup_method,profile_complete,is_demo,created_at,last_login_at,login_count FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).bind(...args, limit, offset).all()).results;
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
  if (path === '/api/admin/testers/invite' && req.method === 'POST') {
    const b = await body(req);
    let testingUrl = clean(b.testing_url, 500);
    try {
      const u = new URL(testingUrl);
      if (u.protocol !== 'https:' || !/(^|\.)play\.google\.com$/.test(u.hostname)) {
        throw new Error('bad');
      }
      testingUrl = u.toString();
    } catch {
      throw new HttpError(400, 'invalid_testing_url',
        'Paste the https://play.google.com/apps/testing/... opt-in link from Play Console.');
    }
    const ids = Array.isArray(b.ids)
      ? b.ids.map((id) => Number(id)).filter((id) => Number.isFinite(id)).slice(0, 500)
      : [];
    const rows = ids.length
      ? (await env.DB.prepare(`SELECT * FROM testers WHERE id IN (${ids.map(() => '?').join(',')})`)
          .bind(...ids).all()).results
      : (await env.DB.prepare("SELECT * FROM testers WHERE status IN ('pending','invited') ORDER BY created_at ASC LIMIT 500").all()).results;
    let sent = 0;
    let skipped = 0;
    for (const tester of rows || []) {
      const first = escapeHtml((tester.name || '').split(/\s+/)[0] || 'there');
      const safeUrl = escapeHtml(testingUrl);
      const html = masareenEmailLayout({
        preheader: 'Your MASAREEN Android closed-test link',
        title: 'You are invited to test MASAREEN',
        bodyHtml: `<p class="lead">Assalamu Alaikum ${first}, thank you for joining the MASAREEN pilot.</p><div class="body"><p>Use the button below to open the Google Play closed test, then install MASAREEN with the same Google account that received this email.</p><p><strong>Please keep the app installed for 14 days and use it at least once every few days.</strong> Google Play requires active testers before the public release.</p><p>If you have any issue, reply to this email and our team will help.</p></div>`,
        ctaText: 'Open the Play closed test',
        ctaUrl: safeUrl,
      });
      const result = await sendEmail(env, {
        from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>',
        to: [tester.email],
        subject: 'You are invited to test MASAREEN on Android',
        html,
        reply_to: env.MAIL_REPLY_TO || undefined,
      });
      if (result.ok) {
        sent += 1;
        await env.DB.prepare("UPDATE testers SET status='invited', invited_at=?, notes=? WHERE id=?")
          .bind(nowIso(), testingUrl, tester.id).run();
      } else {
        skipped += 1;
      }
    }
    return json({ ok: true, sent, skipped, total: (rows || []).length, testing_url: testingUrl });
  }  const testerStatus = /^\/api\/admin\/testers\/(\d+)\/status$/.exec(path);
  if (testerStatus && req.method === 'POST') {
    const b = await body(req);
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
function rewriteLivePlaylist(text, session) {
  if (!session) return text;
  return text.split('\n').map((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return line;
    const separator = trimmed.includes('?') ? '&' : '?';
    return `${trimmed}${separator}mtx=${encodeURIComponent(session)}`;
  }).join('\n');
}

async function liveProxy(req, env, ctx) {
  const url = new URL(req.url);
  if (!/^\/live\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9._\/-]+$/.test(url.pathname) ||
      url.pathname.includes('..')) {
    return new Response('Not found', { status: 404 });
  }
  const isPlaylist = url.pathname.endsWith('.m3u8');
  const originBase = (env.LIVE_ORIGIN || 'https://media.masareen.com').replace(/\/+$/, '');
  const targetParams = new URLSearchParams(url.search);
  targetParams.delete('mtx');
  const targetQuery = targetParams.toString();
  const target = new URL(
    url.pathname + (targetQuery ? `?${targetQuery}` : ''), originBase);
  const cache = caches.default;
  const cacheKey = new Request(url.toString(), { method: 'GET' });
  if (!isPlaylist) {
    const hit = await cache.match(cacheKey);
    if (hit) {
      const h = new Headers(hit.headers);
      h.set('x-masareen-cache', 'HIT');
      return new Response(hit.body, { status: hit.status, headers: h });
    }
  }
  const clientCookie = req.headers.get('cookie') || '';
  const mtx = url.searchParams.get('mtx') || '';
  const cookieHeader = [clientCookie, mtx ? `hlsSession=${mtx}` : '']
    .filter(Boolean).join('; ');
  const headers = {
    'User-Agent': 'MASAREEN-Live-Edge/1.0',
    'Accept': '*/*',
    ...(cookieHeader ? { Cookie: cookieHeader } : {}),
  };
  let upstream = await fetch(target.toString(), {
    headers, redirect: 'manual', cf: { cacheEverything: false },
  });
  if ([301, 302, 303, 307, 308].includes(upstream.status)) {
    const location = upstream.headers.get('location');
    const cookie = (upstream.headers.get('set-cookie') || 'cookieCheck=1').split(';')[0];
    if (location) {
      upstream = await fetch(new URL(location, target).toString(), {
        headers: {
          ...headers,
          Cookie: [cookieHeader, cookie].filter(Boolean).join('; '),
        },
        redirect: 'follow',
        cf: { cacheEverything: false },
      });
    }
  }
  if (!upstream.ok) {
    return new Response('Live stream unavailable', {
      status: upstream.status === 404 ? 404 : 502,
      headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' },
    });
  }
  const outHeaders = new Headers();
  outHeaders.set('content-type',
    upstream.headers.get('content-type') || (isPlaylist
      ? 'application/vnd.apple.mpegurl' : 'video/mp2t'));
  outHeaders.set('access-control-allow-origin', '*');
  outHeaders.set('cache-control', isPlaylist
    ? 'no-store, max-age=0' : 'public, max-age=120');
  if (isPlaylist) outHeaders.set('x-masareen-live', '1');
  else outHeaders.set('x-masareen-cache', 'MISS');
  const setCookies = upstream.headers.getSetCookie
    ? upstream.headers.getSetCookie() : [];
  let session = mtx;
  for (const cookieValue of setCookies) {
    outHeaders.append('set-cookie', cookieValue);
    const match = /(?:^|;\s*)hlsSession=([^;]+)/.exec(cookieValue);
    if (match) session = match[1];
  }
  let body = upstream.body;
  if (isPlaylist) {
    body = rewriteLivePlaylist(await upstream.text(), session);
  }
  const out = new Response(body, { status: 200, headers: outHeaders });
  if (!isPlaylist) ctx.waitUntil(cache.put(cacheKey, out.clone()));
  return out;
}


/* ---------- podcast audio CORS proxy (seed/external clips) ---------- */
const AUDIO_PROXY_HOSTS = new Set(['www.soundhelix.com', 'soundhelix.com']);

async function audioProxy(req) {
  const url = new URL(req.url);
  const raw = url.searchParams.get('url') || '';
  let target;
  try { target = new URL(raw); } catch { throw new HttpError(400, 'bad_url', 'Invalid audio URL.'); }
  if (target.protocol !== 'https:' || !AUDIO_PROXY_HOSTS.has(target.hostname)) {
    throw new HttpError(403, 'host_not_allowed', 'This audio host is not proxied.');
  }
  const upstreamHeaders = {};
  const range = req.headers.get('range');
  if (range) upstreamHeaders.range = range;
  const upstream = await fetch(target.toString(), { headers: upstreamHeaders });
  const headers = new Headers();
  for (const name of ['content-type', 'content-length', 'content-range', 'accept-ranges', 'etag', 'last-modified']) {
    const value = upstream.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (!headers.has('content-type')) headers.set('content-type', 'audio/mpeg');
  headers.set('access-control-allow-origin', '*');
  headers.set('cache-control', 'public, max-age=86400');
  return new Response(upstream.body, { status: upstream.status, headers });
}
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
    if (p === '/api/media/audio' && m === 'GET') return await audioProxy(req);
    if (p.startsWith('/live/')) return await liveProxy(req, env, ctx);
    if (p === '/api/app/version' && m === 'GET') {
      // Public update manifest. Release values are editable by admins/agents
      // in platform_settings, falling back to the Worker vars.
      return json(await appUpdateManifest(env));
    }
    if (p === '/api/v1/auth/google' && m === 'POST') return await googleAuthToken(req, env);
    if (p.startsWith('/api/v1/') || p === '/api/testers' || p === '/api/testers/stats')
      return await socialRoutes(req, env, ctx);
    if (p === '/api/config' && m === 'GET') return json({ ok: true, googleClientId: env.GOOGLE_CLIENT_ID || '', orgTypes: ORG_TYPES, roles: ROLES });
    if (p === '/api/me' && m === 'GET') { const u = await currentUser(req, env); return json({ ok: true, user: publicUser(u, env) || null }); }
    if (p === '/api/auth/google' && m === 'POST') return await googleAuth(req, env, ctx);
    if (p === '/api/auth/register' && m === 'POST') return await emailRegister(req, env, ctx);
    if (p === '/api/auth/magic-link' && m === 'POST') return await requestMagicLink(req, env, ctx);
    if (p === '/api/auth/magic-link' && m === 'GET') return await verifyMagicLink(req, env);
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
    if (url.pathname.startsWith('/api/') ||
        url.pathname.startsWith('/live/')) return handle(req, env, ctx);
    // Landing page lives in the R2 bucket. If a copy is also bound as static
    // assets on this Worker, serve it; otherwise answer with a short hint.
    if (env.ASSETS) return env.ASSETS.fetch(req);
    return json({ ok: true, service: 'masareen-api', message: 'API only. The site is served from the R2 bucket.' }, 200);
  },
  async scheduled(event, env, ctx) {
    // Daily recognition sweep: one official post per member per milestone.
    ctx.waitUntil(runRecognitionSweep(env).catch(() => {}));
  },
};
