// Firebase Cloud Messaging (FCM) HTTP v1 push notification dispatcher for Cloudflare Workers.
// Uses WebCrypto (RSASSA-PKCS1-v1_5 SHA-256) to sign Service Account JWTs and exchange
// them for short-lived Google OAuth2 access tokens with zero external dependencies.

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const DEFAULT_PROJECT_ID = 'masareen-82196';

const enc = new TextEncoder();

let tokenCache = {
  accessToken: null,
  expiresAt: 0,
  cacheKey: null,
};

function b64uEncodeBytes(bytes) {
  let binary = '';
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) binary += String.fromCharCode(arr[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64uEncodeJson(obj) {
  return b64uEncodeBytes(enc.encode(JSON.stringify(obj)));
}

function pemToArrayBuffer(pem) {
  const normalized = String(pem || '')
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export function resolveFirebaseCredentials(env) {
  if (!env) return null;
  if (env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const parsed = typeof env.FIREBASE_SERVICE_ACCOUNT === 'string'
        ? JSON.parse(env.FIREBASE_SERVICE_ACCOUNT)
        : env.FIREBASE_SERVICE_ACCOUNT;
      if (parsed && parsed.client_email && parsed.private_key) {
        return {
          projectId: parsed.project_id || env.FIREBASE_PROJECT_ID || DEFAULT_PROJECT_ID,
          clientEmail: parsed.client_email,
          privateKey: parsed.private_key,
        };
      }
    } catch {
      // Fall through to individual env vars
    }
  }
  if (env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
    return {
      projectId: env.FIREBASE_PROJECT_ID || DEFAULT_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY,
    };
  }
  return null;
}

export async function getFcmAccessToken(env, fetcher = fetch) {
  const creds = resolveFirebaseCredentials(env);
  if (!creds) return null;

  const nowSec = Math.floor(Date.now() / 1000);
  const cacheKey = `${creds.projectId}:${creds.clientEmail}`;
  if (
    tokenCache.accessToken &&
    tokenCache.cacheKey === cacheKey &&
    tokenCache.expiresAt > nowSec + 60
  ) {
    return { accessToken: tokenCache.accessToken, projectId: creds.projectId };
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: creds.clientEmail,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: nowSec,
    exp: nowSec + 3600,
  };

  const unsignedJwt = `${b64uEncodeJson(header)}.${b64uEncodeJson(claimSet)}`;
  const keyData = pemToArrayBuffer(creds.privateKey);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    enc.encode(unsignedJwt)
  );
  const assertion = `${unsignedJwt}.${b64uEncodeBytes(signature)}`;

  const res = await fetcher(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }).toString(),
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    throw new Error(`FCM OAuth token exchange failed (${res.status}): ${errText}`);
  }

  const data = await res.json();
  tokenCache = {
    accessToken: data.access_token,
    expiresAt: nowSec + Number(data.expires_in || 3600),
    cacheKey,
  };
  return { accessToken: data.access_token, projectId: creds.projectId };
}

export async function ensureDeviceTokensTable(env) {
  if (!env?.DB) return;
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS device_tokens (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      INTEGER NOT NULL,
    token        TEXT NOT NULL,
    platform     TEXT NOT NULL,
    created_at   TEXT NOT NULL,
    last_seen_at TEXT NOT NULL,
    UNIQUE (user_id, token)
  )`).run().catch(() => {});
}

export async function sendFcmMessageToToken(env, deviceToken, payload, fetcher = fetch) {
  const auth = await getFcmAccessToken(env, fetcher);
  if (!auth) return { ok: false, skipped: true, reason: 'fcm_not_configured' };

  const type = String(payload.type || 'system');
  const title = String(payload.title || 'MASAREEN').slice(0, 140);
  const body = String(payload.body || '').slice(0, 300);
  const routePayload =
    type === 'message'
      ? 'messages'
      : type.startsWith('opportunity')
      ? 'opportunities'
      : 'notifications';

  const message = {
    token: deviceToken,
    notification: {
      title,
      body,
    },
    data: {
      type,
      title,
      body,
      payload: routePayload,
      actor_id: payload.actorId == null ? '' : String(payload.actorId),
      post_id: payload.postId == null ? '' : String(payload.postId),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: type === 'message' ? 'HIGH' : 'NORMAL',
      notification: {
        channel_id: type === 'message' ? 'masaren_messages' : 'masaren_notifications',
        sound: 'default',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      headers: {
        'apns-priority': type === 'message' ? '10' : '5',
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          'mutable-content': 1,
        },
      },
    },
  };

  const url = `https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`;
  const res = await fetcher(url, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${auth.accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ message }),
  });

  if (res.ok) {
    const data = await res.json().catch(() => ({}));
    return { ok: true, name: data.name || null };
  }

  const errData = await res.json().catch(() => ({}));
  const errCode =
    errData?.error?.details?.find((d) => d.errorCode)?.errorCode ||
    errData?.error?.status ||
    'UNKNOWN';
  const unregister =
    res.status === 404 ||
    errCode === 'UNREGISTERED' ||
    (res.status === 400 && errCode === 'INVALID_ARGUMENT' &&
      String(errData?.error?.message || '').toLowerCase().includes('registration token'));

  return {
    ok: false,
    status: res.status,
    errorCode: errCode,
    message: errData?.error?.message || 'FCM send failed',
    unregister,
  };
}

export async function sendFcmPushForUser(env, userId, payload, fetcher = fetch) {
  if (!env?.DB || !userId) return { sent: 0, failed: 0, skipped: true };
  if (!resolveFirebaseCredentials(env)) return { sent: 0, failed: 0, skipped: true };

  try {
    // Respect user_settings.push_enabled if the table exists
    try {
      const settings = await env.DB
        .prepare('SELECT push_enabled FROM user_settings WHERE user_id=?')
        .bind(userId)
        .first();
      if (settings && Number(settings.push_enabled) === 0) {
        return { sent: 0, failed: 0, skipped: true, reason: 'push_disabled' };
      }
    } catch {
      // user_settings table may not exist in older schemas
    }

    const rows =
      (
        await env.DB
          .prepare('SELECT token, platform FROM device_tokens WHERE user_id=? ORDER BY last_seen_at DESC LIMIT 10')
          .bind(userId)
          .all()
      ).results || [];

    if (!rows.length) return { sent: 0, failed: 0, skipped: false };

    let sent = 0;
    let failed = 0;
    await Promise.all(
      rows.map(async (row) => {
        const res = await sendFcmMessageToToken(env, row.token, payload, fetcher);
        if (res.ok) {
          sent++;
        } else {
          failed++;
          if (res.unregister) {
            await env.DB
              .prepare('DELETE FROM device_tokens WHERE user_id=? AND token=?')
              .bind(userId, row.token)
              .run()
              .catch(() => {});
          }
        }
      })
    );
    return { sent, failed, skipped: false };
  } catch {
    return { sent: 0, failed: 0, skipped: false };
  }
}
