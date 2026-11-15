import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { handle } from '../src/index.js';
import { makeDb } from './d1-shim.mjs';

const CLIENT = 'test-client.apps.googleusercontent.com';
const b64u = (b) => Buffer.from(b).toString('base64url');
const kp = await webcrypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
const jwk = { ...(await webcrypto.subtle.exportKey('jwk', kp.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
async function idToken(over = {}, kid = 'k1') {
  const h = b64u(JSON.stringify({ alg: 'RS256', kid, typ: 'JWT' }));
  const c = b64u(JSON.stringify({ iss: 'https://accounts.google.com', aud: CLIENT, sub: 'g-123', email: 'Nour@Example.com', email_verified: true, name: 'Nour Hassan', picture: 'https://x/p.png', exp: Math.floor(Date.now() / 1000) + 600, ...over }));
  const sig = await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5', kp.privateKey, new TextEncoder().encode(h + '.' + c));
  return `${h}.${c}.${b64u(sig)}`;
}
const mkEnv = (extra = {}) => ({ DB: makeDb(), GOOGLE_CLIENT_ID: CLIENT, SESSION_SECRET: 's3cret-s3cret', ADMIN_EMAILS: 'ceo@example.com', __fetch: async () => new Response(JSON.stringify({ keys: [jwk] })), ...extra });
const call = (env, method, path, body, cookie) => handle(new Request('https://masareen.test' + path, { method, headers: { 'content-type': 'application/json', ...(cookie ? { cookie } : {}) }, body: body ? JSON.stringify(body) : undefined }), env, {});
const sess = (res) => (res.headers.get('set-cookie') || '').split(';')[0];

test('health and config', async () => {
  const env = mkEnv();
  assert.equal((await (await call(env, 'GET', '/api/health')).json()).googleConfigured, true);
  const cfg = await (await call(env, 'GET', '/api/config')).json();
  assert.equal(cfg.googleClientId, CLIENT);
  assert.ok(cfg.roles.includes('Student'));
  assert.ok(cfg.orgTypes.includes('University'));
});

test('app update manifest exposes the latest Android build and OTA settings', async () => {
  const env = mkEnv();
  const r = await call(env, 'GET', '/api/app/version');
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.android.version, '0.4.3');
  assert.equal(j.android.build, 8);
  assert.match(j.android.url, /downloads\/masareen\.apk$/);
  assert.equal(j.minimumBuild, 7);
  assert.equal(j.ota.provider, 'shorebird');
});

test('google sign up creates user, logs login, sets session; profile completes registration', async () => {
  const env = mkEnv();
  const r = await call(env, 'POST', '/api/auth/google', { credential: await idToken(), locale: 'ar' });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.isNew, true); assert.equal(j.user.email, 'nour@example.com'); assert.equal(j.user.profileComplete, false);
  const cookie = sess(r); assert.match(cookie, /^masareen_session=/);
  assert.equal((await (await call(env, 'GET', '/api/me', null, cookie)).json()).user.name, 'Nour Hassan');
  // profile requires consent + fields
  assert.equal((await call(env, 'POST', '/api/profile', { org: 'X' }, cookie)).status, 400);
  const p = await call(env, 'POST', '/api/profile', {
    role: 'Student', university: 'Cairo University', universityId: '2023001',
    department: 'Computer Science', academicYear: 'Year 3', degreeLevel: 'Bachelor',
    country: 'Egypt', consent: true,
  }, cookie);
  const pj = await p.json();
  assert.equal(pj.user.profileComplete, true);
  assert.equal(pj.user.role, 'Student'); assert.equal(pj.user.universityId, '2023001');
  // second login: not new, count increments, event logged
  const r2 = await call(env, 'POST', '/api/auth/google', { credential: await idToken() });
  assert.equal((await r2.json()).isNew, false);
  const row = env.DB.raw.prepare('SELECT login_count c FROM users').get();
  assert.equal(row.c, 2);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) c FROM login_events').get().c, 2);
});

test('rejects forged, wrong-audience and expired tokens', async () => {
  const env = mkEnv();
  const good = await idToken();
  const forged = good.slice(0, -4) + 'AAAA';
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: forged })).status, 401);
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: await idToken({ aud: 'other' }) })).status, 401);
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: await idToken({ exp: 1 }) })).status, 401);
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: await idToken({}, 'nokid') })).status, 401);
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: await idToken({ email_verified: false }) })).status, 403);
  assert.equal((await call(env, 'POST', '/api/v1/auth/google', { credential: 'fake.token.value' })).status, 401);
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) c FROM users').get().c, 0);
});

test('a member-uploaded avatar survives a later Google sign-in', async () => {
  const env = mkEnv();
  const first = await call(env, 'POST', '/api/auth/google', { credential: await idToken() });
  assert.equal(first.status, 200);
  env.DB.raw.prepare("UPDATE users SET picture='https://masareen.com/media/avatars/1-x.jpg' WHERE email='nour@example.com'").run();
  const again = await call(env, 'POST', '/api/auth/google', {
    credential: await idToken({ picture: 'https://lh3.googleusercontent.com/new.png' }),
  });
  assert.equal(again.status, 200);
  const row = env.DB.raw.prepare('SELECT picture FROM users').get();
  assert.equal(row.picture, 'https://masareen.com/media/avatars/1-x.jpg');

  const fresh = mkEnv();
  await call(fresh, 'POST', '/api/auth/google', { credential: await idToken() });
  await call(fresh, 'POST', '/api/auth/google', {
    credential: await idToken({ picture: 'https://lh3.googleusercontent.com/new.png' }),
  });
  assert.equal(fresh.DB.raw.prepare('SELECT picture FROM users').get().picture,
      'https://lh3.googleusercontent.com/new.png');
});

test('tampered session cookie is rejected', async () => {
  const env = mkEnv();
  const cookie = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken() }));
  const [body, sig] = cookie.split('.');
  // Flip a signature byte. Changing the final base64 character can be a
  // no-op when it only carries padding bits, so tamper the first one.
  const bad = `${body}.${sig[0] === 'A' ? 'B' : 'A'}${sig.slice(1)}`;
  assert.equal((await (await call(env, 'GET', '/api/me', null, bad)).json()).user, null);
});

test('email registration, duplicates, validation, honeypot', async () => {
  const env = mkEnv();
  const ok = { name: 'Ali', email: 'ali@x.org', role: 'Organization / institution', org: 'NGO One', orgType: 'NGO / civil society', country: 'Egypt', consent: true };
  assert.equal((await call(env, 'POST', '/api/auth/register', ok)).status, 200);
  assert.equal((await (await call(env, 'POST', '/api/auth/register', ok)).json()).alreadyRegistered, true);
  assert.equal((await call(env, 'POST', '/api/auth/register', { ...ok, email: 'bad' })).status, 400);
  assert.equal((await call(env, 'POST', '/api/auth/register', { ...ok, email: 'b@x.org', consent: false })).status, 400);
  await call(env, 'POST', '/api/auth/register', { ...ok, email: 'bot@x.org', website: 'spam' });
  const u = env.DB.raw.prepare('SELECT * FROM users').all();
  assert.equal(u.length, 1); assert.equal(u[0].email_verified, 0); assert.equal(u[0].signup_method, 'email');
});

test('contact messages are stored and rate limited', async () => {
  const env = mkEnv();
  const m = { name: 'Mona', email: 'mona@gov.eg', message: 'Interested in the pilot.' };
  for (let i = 0; i < 5; i++) assert.equal((await call(env, 'POST', '/api/contact', m)).status, 200);
  assert.equal((await call(env, 'POST', '/api/contact', m)).status, 429);
  assert.equal((await call(env, 'POST', '/api/contact', { ...m, message: '' })).status, 400);
});

test('admin API: only configured admin emails; stats, users, logins, csv', async () => {
  const env = mkEnv();
  // non admin
  const nour = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken() }));
  assert.equal((await call(env, 'GET', '/api/admin/stats', null, nour)).status, 403);
  assert.equal((await call(env, 'GET', '/api/admin/stats')).status, 401);
  // admin
  const ceo = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken({ sub: 'g-ceo', email: 'ceo@example.com', name: '=CEO' }) }));
  const s = await (await call(env, 'GET', '/api/admin/stats', null, ceo)).json();
  assert.equal(s.totals.users, 2); assert.equal(s.totals.logins24h, 2); assert.equal(s.series.length, 30);
  const u = await (await call(env, 'GET', '/api/admin/users?q=nour', null, ceo)).json();
  assert.equal(u.total, 1);
  assert.equal((await (await call(env, 'GET', '/api/admin/logins', null, ceo)).json()).rows.length, 2);
  const csv = await (await call(env, 'GET', '/api/admin/export/users.csv', null, ceo)).text();
  assert.match(csv, /"'=CEO"/); // formula injection neutralised
});

test('cross-origin POST blocked, unknown route 404, logout clears cookie', async () => {
  const env = mkEnv();
  const r = await handle(new Request('https://masareen.test/api/contact', { method: 'POST', headers: { 'content-type': 'application/json', origin: 'https://evil.com' }, body: '{}' }), env, {});
  assert.equal(r.status, 403);
  assert.equal((await call(env, 'GET', '/api/nope')).status, 404);
  assert.match((await call(env, 'POST', '/api/auth/logout')).headers.get('set-cookie'), /Max-Age=0/);
});

test('role-aware profile asks for the details that match the role', async () => {
  const env = mkEnv();
  const cookie = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken() }));
  const base = { country: 'Egypt', consent: true };
  assert.equal((await call(env, 'POST', '/api/profile', { ...base, role: 'Student', university: 'Cairo University' }, cookie)).status, 400);
  const student = { ...base, role: 'Student', university: 'Cairo University', universityId: '2023001', department: 'CS', academicYear: 'Year 3', degreeLevel: 'Bachelor' };
  const r = await call(env, 'POST', '/api/profile', student, cookie);
  assert.equal(r.status, 200);
  const u = (await r.json()).user;
  assert.equal(u.role, 'Student'); assert.equal(u.universityId, '2023001'); assert.equal(u.department, 'CS'); assert.equal(u.degreeLevel, 'Bachelor');
  // professional needs employer + job title
  const c2 = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken({ sub: 'g-pro', email: 'pro@example.com' }) }));
  assert.equal((await call(env, 'POST', '/api/profile', { ...base, role: 'Professional', employer: 'Acme' }, c2)).status, 400);
  assert.equal((await call(env, 'POST', '/api/profile', { ...base, role: 'Professional', employer: 'Acme', jobTitle: 'Engineer' }, c2)).status, 200);
});

test('CORS allows the configured R2 site, handles preflight, blocks other origins', async () => {
  const env = mkEnv({ ALLOWED_ORIGINS: 'https://masareen.com' });
  const ok = await handle(new Request('https://api.masareen.test/api/config', { headers: { origin: 'https://masareen.com' } }), env, {});
  assert.equal(ok.headers.get('access-control-allow-origin'), 'https://masareen.com');
  assert.equal(ok.headers.get('access-control-allow-credentials'), 'true');
  const pre = await handle(new Request('https://api.masareen.test/api/contact', { method: 'OPTIONS', headers: { origin: 'https://masareen.com' } }), env, {});
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get('access-control-allow-methods'), 'GET, POST, PATCH, DELETE, OPTIONS');
  const evil = await handle(new Request('https://api.masareen.test/api/contact', { method: 'POST', headers: { 'content-type': 'application/json', origin: 'https://evil.com' }, body: '{}' }), env, {});
  assert.equal(evil.status, 403);
});

test('google not configured returns 503', async () => {
  const env = mkEnv({ GOOGLE_CLIENT_ID: '' });
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: 'x' })).status, 503);
});

test('web magic-link signs in email-registered users once and marks email verified', async () => {
  const sent = [];
  const env = mkEnv({
    RESEND_API_KEY: 're_test_key',
    __fetch: async (url, init) => {
      if (String(url).includes('resend.com')) {
        sent.push(JSON.parse(init.body));
        return new Response(JSON.stringify({ id: 'mail_1' }), { status: 200 });
      }
      return new Response(JSON.stringify({ keys: [jwk] }));
    },
  });
  const reg = { name: 'Salma', email: 'salma@example.org', role: 'Professional', employer: 'Nile Lab', jobTitle: 'Lead', country: 'Egypt', consent: true };
  assert.equal((await call(env, 'POST', '/api/auth/register', reg)).status, 200);
  sent.length = 0;

  const reqLink = await call(env, 'POST', '/api/auth/magic-link', { email: 'salma@example.org' });
  assert.equal(reqLink.status, 200);
  assert.equal(sent.length, 1);
  const match = /\/api\/auth\/magic-link\?token=([A-Za-z0-9_-]+)/.exec(sent[0].html);
  assert.ok(match, 'magic link token must be present in email HTML');

  const verify = await call(env, 'GET', `/api/auth/magic-link?token=${match[1]}`);
  assert.equal(verify.status, 302);
  const cookie = sess(verify);
  assert.match(cookie, /^masareen_session=/);

  const me = await (await call(env, 'GET', '/api/me', null, cookie)).json();
  assert.equal(me.user.email, 'salma@example.org');
  const dbUser = env.DB.raw.prepare('SELECT email_verified FROM users WHERE email=?').get('salma@example.org');
  assert.equal(dbUser.email_verified, 1);

  // Replay of single-use magic link must fail
  const replay = await call(env, 'GET', `/api/auth/magic-link?token=${match[1]}`);
  assert.equal(replay.status, 400);
});

test('email signup rate limiting is scoped per IP rather than blocking an entire country', async () => {
  const env = mkEnv();
  const base = { name: 'User', role: 'Professional', employer: 'Lab', jobTitle: 'Researcher', country: 'Egypt', consent: true };
  const postFromIp = (ip, email) => handle(new Request('https://masareen.test/api/auth/register', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': ip },
    body: JSON.stringify({ ...base, email }),
  }), env, {});

  for (let i = 0; i < 10; i++) {
    assert.equal((await postFromIp('203.0.113.10', `ip1-${i}@example.org`)).status, 200);
  }
  assert.equal((await postFromIp('203.0.113.10', 'ip1-over@example.org')).status, 429);
  // Another IP in the same country must still succeed
  assert.equal((await postFromIp('203.0.113.11', 'ip2-ok@example.org')).status, 200);
});
