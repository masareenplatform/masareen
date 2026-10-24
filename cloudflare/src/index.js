// MASAREEN API: Cloudflare Worker + D1. Free tier friendly (no paid services).
// Routes: /api/* handled here, everything else served from static assets.

const enc = new TextEncoder();
const dec = new TextDecoder();
const SESSION_DAYS = 14;
const GOOGLE_CERTS = 'https://www.googleapis.com/oauth2/v3/certs';
const ORG_TYPES = ['Ministry / government', 'University', 'NGO / civil society', 'Company / CSR',
  'Donor / international partner', 'Student / volunteer', 'Journalist / media', 'Other'];

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
function sessionCookie(value, req, maxAge) {
  const secure = new URL(req.url).protocol === 'https:' ? '; Secure' : '';
  return `masareen_session=${encodeURIComponent(value)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${secure}`;
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
  const r = await fetcher(GOOGLE_CERTS);
  if (!r.ok) throw new Error('certs_unavailable');
  certCache = { at: Date.now(), keys: (await r.json()).keys };
  return certCache.keys;
}
export async function verifyGoogleIdToken(idToken, clientId, fetcher = fetch) {
  const parts = String(idToken || '').split('.');
  if (parts.length !== 3) throw new HttpError(401, 'bad_token', 'Invalid Google token.');
  const header = JSON.parse(dec.decode(b64u.dec(parts[0])));
  const claims = JSON.parse(dec.decode(b64u.dec(parts[1])));
  if (header.alg !== 'RS256') throw new HttpError(401, 'bad_token', 'Unsupported token algorithm.');
  let jwk = (await googleKeys(fetcher)).find((k) => k.kid === header.kid);
  if (!jwk) { certCache.keys = null; jwk = (await googleKeys(fetcher)).find((k) => k.kid === header.kid); }
  if (!jwk) throw new HttpError(401, 'bad_token', 'Unknown signing key.');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64u.dec(parts[2]), enc.encode(parts[0] + '.' + parts[1]));
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
  country: u.country, profileComplete: !!u.profile_complete, signupMethod: u.signup_method,
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
  return sessionCookie(token, req, SESSION_DAYS * 86400);
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
  return json({ ok: true, isNew, user: publicUser(user, env) }, 200, { 'set-cookie': await startSession(env, req, user) });
}

function validateProfile(b, strict) {
  const org = clean(b.org, 120), country = clean(b.country, 80), interest = clean(b.interest, 600);
  const orgType = ORG_TYPES.includes(b.orgType) ? b.orgType : '';
  if (strict && (!org || !orgType || !country)) throw new HttpError(400, 'missing_fields', 'Please add your organization, type and country.');
  if (strict && b.consent !== true) throw new HttpError(400, 'consent_required', 'Please accept the privacy note to continue.');
  return { org, country, interest, orgType };
}

async function saveProfile(req, env) {
  const user = await currentUser(req, env);
  if (!user) throw new HttpError(401, 'not_signed_in', 'Please sign in first.');
  const b = await body(req);
  const p = validateProfile(b, true);
  const name = clean(b.name, 120) || user.name;
  await env.DB.prepare('UPDATE users SET name=?, org=?, org_type=?, country=?, interest=?, consent_at=COALESCE(consent_at,?), profile_complete=1 WHERE id=?')
    .bind(name, p.org, p.orgType, p.country, p.interest, nowIso(), user.id).run();
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
  await env.DB.prepare(`INSERT INTO users (email,email_verified,name,org,org_type,country,interest,consent_at,profile_complete,signup_method,locale,signup_country,created_at)
    VALUES (?,0,?,?,?,?,?,?,1,'email',?,?,?)`).bind(email, name, p.org, p.orgType, p.country, p.interest, nowIso(), ['en', 'ar'].includes(b.locale) ? b.locale : null, req.cf?.country || null, nowIso()).run();
  return json({ ok: true, alreadyRegistered: false, verified: false });
}

async function contact(req, env) {
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
  const byType = (await env.DB.prepare("SELECT COALESCE(org_type,'Unknown') k, COUNT(*) c FROM users GROUP BY 1 ORDER BY c DESC").all()).results || [];
  const byCountry = (await env.DB.prepare("SELECT COALESCE(country,'Unknown') k, COUNT(*) c FROM users GROUP BY 1 ORDER BY c DESC LIMIT 10").all()).results || [];
  const su = (await env.DB.prepare('SELECT substr(created_at,1,10) d, COUNT(*) c FROM users WHERE created_at>? GROUP BY 1').bind(daysAgo(30)).all()).results || [];
  const lo = (await env.DB.prepare('SELECT substr(at,1,10) d, COUNT(*) c FROM login_events WHERE at>? GROUP BY 1').bind(daysAgo(30)).all()).results || [];
  const series = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400_000).toISOString().slice(0, 10);
    series.push({ date: d, signups: (su.find((x) => x.d === d) || {}).c || 0, logins: (lo.find((x) => x.d === d) || {}).c || 0 });
  }
  return { totals: { users: total.c || 0, google: google.c || 0, profileComplete: complete.c || 0, signups7d: s7.c || 0, signups30d: s30.c || 0, logins24h: l24.c || 0, logins7d: l7.c || 0, activeUsers7d: active7.c || 0, messages: msgs.c || 0 }, byType, byCountry, series };
}
function page(url, def = 50, max = 200) {
  const limit = Math.min(max, Math.max(1, parseInt(url.searchParams.get('limit') || def, 10) || def));
  const offset = Math.max(0, parseInt(url.searchParams.get('offset') || '0', 10) || 0);
  return { limit, offset };
}
const csvCell = (v) => { let s = v == null ? '' : String(v); if (/^[=+\-@\t\r]/.test(s)) s = "'" + s; return '"' + s.replace(/"/g, '""') + '"'; };

async function adminRoutes(req, env, url) {
  await requireAdmin(req, env);
  const path = url.pathname;
  if (path === '/api/admin/stats') return json({ ok: true, ...(await adminStats(env)) });
  if (path === '/api/admin/users') {
    const { limit, offset } = page(url); const q = clean(url.searchParams.get('q'), 80);
    const like = `%${q.replace(/[%_]/g, '')}%`;
    const where = q ? 'WHERE email LIKE ? OR name LIKE ? OR org LIKE ?' : '';
    const args = q ? [like, like, like] : [];
    const rows = (await env.DB.prepare(`SELECT id,email,email_verified,name,org,org_type,country,signup_method,profile_complete,created_at,last_login_at,login_count FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).bind(...args, limit, offset).all()).results;
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
    const rows = (await env.DB.prepare('SELECT id,email,email_verified,name,org,org_type,country,interest,signup_method,created_at,last_login_at,login_count FROM users ORDER BY created_at DESC').all()).results;
    const cols = ['id', 'email', 'email_verified', 'name', 'org', 'org_type', 'country', 'interest', 'signup_method', 'created_at', 'last_login_at', 'login_count'];
    const csv = [cols.join(',')].concat(rows.map((r) => cols.map((c) => csvCell(r[c])).join(','))).join('\n');
    return new Response(csv, { headers: { 'content-type': 'text/csv; charset=utf-8', 'content-disposition': 'attachment; filename="masareen-users.csv"', 'cache-control': 'no-store' } });
  }
  throw new HttpError(404, 'not_found', 'Unknown admin route.');
}

/* ---------- router ---------- */
export async function handle(req, env, ctx) {
  const url = new URL(req.url);
  const p = url.pathname, m = req.method;
  try {
    if (m === 'POST' && req.headers.get('origin') && new URL(req.headers.get('origin')).host !== url.host)
      throw new HttpError(403, 'bad_origin', 'Cross-site requests are not allowed.');
    if (p === '/api/health') return json({ ok: true, service: 'masareen-api', time: nowIso(), googleConfigured: !!env.GOOGLE_CLIENT_ID });
    if (p === '/api/config' && m === 'GET') return json({ ok: true, googleClientId: env.GOOGLE_CLIENT_ID || '', orgTypes: ORG_TYPES });
    if (p === '/api/me' && m === 'GET') { const u = await currentUser(req, env); return json({ ok: true, user: publicUser(u, env) || null }); }
    if (p === '/api/auth/google' && m === 'POST') return await googleAuth(req, env, ctx);
    if (p === '/api/auth/register' && m === 'POST') return await emailRegister(req, env);
    if (p === '/api/auth/logout' && m === 'POST') return json({ ok: true }, 200, { 'set-cookie': sessionCookie('', req, 0) });
    if (p === '/api/profile' && m === 'POST') return await saveProfile(req, env);
    if (p === '/api/contact' && m === 'POST') return await contact(req, env);
    if (p.startsWith('/api/admin/') && m === 'GET') return await adminRoutes(req, env, url);
    throw new HttpError(404, 'not_found', 'Unknown API route.');
  } catch (e) {
    if (e instanceof HttpError) return err(e.status, e.code, e.message);
    console.error('api_error', e && e.stack || e);
    return err(500, 'server_error', 'Something went wrong. Please try again.');
  }
}

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    if (url.pathname.startsWith('/api/')) return handle(req, env, ctx);
    return env.ASSETS ? env.ASSETS.fetch(req) : new Response('Not found', { status: 404 });
  },
};
