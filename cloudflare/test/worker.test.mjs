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
  assert.equal((await (await call(env, 'GET', '/api/config')).json()).googleClientId, CLIENT);
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
  const p = await call(env, 'POST', '/api/profile', { org: 'Cairo Univ', orgType: 'University', country: 'Egypt', consent: true }, cookie);
  assert.equal((await p.json()).user.profileComplete, true);
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
  assert.equal(env.DB.raw.prepare('SELECT COUNT(*) c FROM users').get().c, 0);
});

test('tampered session cookie is rejected', async () => {
  const env = mkEnv();
  const cookie = sess(await call(env, 'POST', '/api/auth/google', { credential: await idToken() }));
  const bad = cookie.replace(/.$/, (c) => (c === 'A' ? 'B' : 'A'));
  assert.equal((await (await call(env, 'GET', '/api/me', null, bad)).json()).user, null);
});

test('email registration, duplicates, validation, honeypot', async () => {
  const env = mkEnv();
  const ok = { name: 'Ali', email: 'ali@x.org', org: 'NGO One', orgType: 'NGO / civil society', country: 'Egypt', consent: true };
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

test('google not configured returns 503', async () => {
  const env = mkEnv({ GOOGLE_CLIENT_ID: '' });
  assert.equal((await call(env, 'POST', '/api/auth/google', { credential: 'x' })).status, 503);
});
