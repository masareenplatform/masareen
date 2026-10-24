// Local full-stack harness: landing page + Worker API on node:sqlite. Used by the browser test.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { webcrypto } from 'node:crypto';
import { extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { handle } from '../src/index.js';
import { makeDb } from './d1-shim.mjs';

export const CLIENT = 'local-test.apps.googleusercontent.com';
const b64u = (b) => Buffer.from(b).toString('base64url');
const kp = await webcrypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
const jwk = { ...(await webcrypto.subtle.exportKey('jwk', kp.publicKey)), kid: 'k1', alg: 'RS256' };
export async function fakeGoogleToken(claims) {
  const h = b64u(JSON.stringify({ alg: 'RS256', kid: 'k1' }));
  const c = b64u(JSON.stringify({ iss: 'https://accounts.google.com', aud: CLIENT, exp: Math.floor(Date.now() / 1000) + 600, email_verified: true, ...claims }));
  const sig = await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5', kp.privateKey, new TextEncoder().encode(h + '.' + c));
  return `${h}.${c}.${b64u(sig)}`;
}
const MIME = { '.html': 'text/html', '.png': 'image/png', '.ico': 'image/x-icon', '.js': 'text/javascript', '.css': 'text/css' };
export function start(port, admins = 'ceo@example.com') {
  const env = { DB: makeDb(), GOOGLE_CLIENT_ID: CLIENT, SESSION_SECRET: 'local-secret', ADMIN_EMAILS: admins, __fetch: async () => new Response(JSON.stringify({ keys: [jwk] })) };
  const root = fileURLToPath(new URL('../../landing/', import.meta.url));
  const server = http.createServer(async (req, res) => {
    const chunks = []; for await (const c of req) chunks.push(c);
    const url = `http://localhost:${port}${req.url}`;
    if (req.url.startsWith('/api/')) {
      const r = await handle(new Request(url, { method: req.method, headers: req.headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(chunks) }), env, {});
      const h = {}; r.headers.forEach((v, k) => { h[k] = v; });
      res.writeHead(r.status, h); res.end(Buffer.from(await r.arrayBuffer())); return;
    }
    let p = req.url.split('?')[0]; if (p === '/') p = '/index.html';
    try { const f = await readFile(join(root, p)); res.writeHead(200, { 'content-type': MIME[extname(p)] || 'application/octet-stream' }); res.end(f); }
    catch { res.writeHead(404); res.end('nf'); }
  });
  return new Promise((r) => server.listen(port, () => r({ server, env })));
}
