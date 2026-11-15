// MASAREEN social + impact API (v1), served by the same Worker as the landing API.
// Auth here is email+password with PBKDF2 hashing and HMAC bearer tokens, so the
// mobile app never depends on an external server. All data lives in D1.

import {
  SITE_URL,
  sendEmail,
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendWelcomeEmail,
  sendPasswordChangedEmail,
  escapeHtml,
} from './email.js';
import { sendFcmPushForUser, sendFcmMessageToToken } from './fcm.js';

const enc = new TextEncoder();
const TOKEN_DAYS = 30;
const PBKDF2_ITERATIONS = 100000;
const ROLES = new Set(['INDIVIDUAL', 'STUDENT', 'ACADEMIC', 'RESEARCHER', 'ORGANIZATION',
  'PROFESSIONAL', 'VOLUNTEER', 'JOURNALIST', 'DONOR', 'MEDIA', 'SPORTS', 'ATHLETE',
  'CLUB', 'FEDERATION', 'INSTITUTION', 'UNIVERSITY']);
const RESTRICTED_SIGNUP_ROLES = new Set(['ADMIN', 'PLATFORM', 'GOVERNMENT']);
const IMPACT_CATEGORIES = new Set(['verified_evidence', 'community_voice', 'policy_change',
  'innovation', 'scale', 'transparency']);
const SDG_NAMES = {
  1: 'No poverty', 2: 'Zero hunger', 3: 'Good health', 4: 'Quality education',
  5: 'Gender equality', 6: 'Clean water', 7: 'Clean energy', 8: 'Decent work',
  9: 'Industry & innovation', 10: 'Reduced inequalities', 11: 'Sustainable cities',
  12: 'Responsible consumption', 13: 'Climate action', 14: 'Life below water',
  15: 'Life on land', 16: 'Peace & justice', 17: 'Partnerships',
};
const AUTH_TOKEN_TTL = { verify_email: 24 * 60 * 60 * 1000, reset_password: 60 * 60 * 1000 };
const DEFAULT_DAILY_REWARD_MRC = 10;
const MAX_DAILY_REWARD_MRC = 500;
const PROFILE_VISIBILITY = new Set(['public', 'followers', 'private']);
const MESSAGE_PRIVACY = new Set(['everyone', 'followers', 'nobody']);
const DIGEST_FREQUENCIES = new Set(['instant', 'daily', 'weekly', 'off']);
// Admin-facing alerts are never suppressed by member notification categories.
// They always land in the admin inbox; push is reserved for important events.
const ADMIN_ALERT_TYPES = new Set([
  'report', 'entity_review', 'admin_payment', 'admin_inquiry', 'admin_contact',
  'admin_alert', 'mrc_transaction', 'feedback', 'leaderboard', 'moderation',
]);
const SETTINGS_DEFAULTS = {
  push_enabled: true,
  email_enabled: true,
  opportunity_alerts: true,
  social_alerts: true,
  message_alerts: true,
  digest_frequency: 'instant',
  quiet_start: null,
  quiet_end: null,
  profile_visibility: 'public',
  message_privacy: 'everyone',
  show_email: false,
};

class HttpError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
const json = (data, status = 200, headers = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers },
  });
const htmlResponse = (body, status = 200) =>
  new Response(body, {
    status,
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' },
  });
const boolValue = (value, fallback) => {
  if (typeof value === 'boolean') return value;
  if (value === 1 || value === '1' || value === 'true') return true;
  if (value === 0 || value === '0' || value === 'false') return false;
  return fallback;
};
const clean = (v, max) => (typeof v === 'string' ? v.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max) : '');
const isEmail = (v) => typeof v === 'string' && /^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$/.test(v) && v.length <= 254;
const nowIso = () => new Date().toISOString();
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
const num = (v) => (v == null || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null);

async function readJson(req, fallback = {}, maxBytes = 65536) {
  const declared = Number(req.headers.get('content-length') || 0);
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new HttpError(413, 'too_large', 'Request body is too large.');
  }
  const raw = await req.text().catch(() => '');
  if (raw.length > maxBytes) {
    throw new HttpError(413, 'too_large', 'Request body is too large.');
  }
  if (!raw) return fallback;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : fallback;
  } catch {
    return fallback;
  }
}

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
  if (!secret || typeof secret !== 'string') {
    throw new HttpError(500, 'not_configured', 'Authentication is not configured for this environment.');
  }
  const body = b64u.enc(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body));
  return body + '.' + b64u.enc(sig);
}
export async function appTokenFor(user, env) {
  if (!env.SESSION_SECRET) throw new HttpError(500, 'not_configured', 'Authentication is not configured for this environment.');
  return signToken({ uid: user.id, typ: 'bearer', exp: Date.now() + TOKEN_DAYS * 86400000 }, env.SESSION_SECRET);
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
    if (payload.typ && payload.typ !== 'bearer') return null;
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

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest('SHA-256', enc.encode(String(value)));
  return hex(digest);
}

async function createAuthToken(env, userId, kind, ttlMs = AUTH_TOKEN_TTL[kind]) {
  const raw = b64u.enc(crypto.getRandomValues(new Uint8Array(32)));
  const tokenHash = await sha256Hex(raw);
  await env.DB.prepare('INSERT INTO auth_tokens (user_id,kind,token_hash,expires_at,created_at) VALUES (?,?,?,?,?)')
    .bind(userId, kind, tokenHash, new Date(Date.now() + ttlMs).toISOString(), nowIso()).run();
  return raw;
}

async function findAuthToken(env, raw, kind) {
  if (!raw || typeof raw !== 'string') return null;
  const tokenHash = await sha256Hex(raw.trim());
  return env.DB.prepare('SELECT * FROM auth_tokens WHERE token_hash=? AND kind=?').bind(tokenHash, kind).first();
}

async function consumeAuthToken(env, row) {
  await env.DB.prepare('UPDATE auth_tokens SET used_at=? WHERE id=?').bind(nowIso(), row.id).run();
}

async function tokenRateLimited(env, userId, kind, max, windowMs) {
  const since = new Date(Date.now() - windowMs).toISOString();
  const row = await env.DB.prepare('SELECT COUNT(*) c FROM auth_tokens WHERE user_id=? AND kind=? AND created_at>?')
    .bind(userId, kind, since).first();
  return Number(row?.c || 0) >= max;
}

function settingsJson(row) {
  return {
    push_enabled: boolValue(row?.push_enabled, SETTINGS_DEFAULTS.push_enabled),
    email_enabled: boolValue(row?.email_enabled, SETTINGS_DEFAULTS.email_enabled),
    opportunity_alerts: boolValue(row?.opportunity_alerts, SETTINGS_DEFAULTS.opportunity_alerts),
    social_alerts: boolValue(row?.social_alerts, SETTINGS_DEFAULTS.social_alerts),
    message_alerts: boolValue(row?.message_alerts, SETTINGS_DEFAULTS.message_alerts),
    digest_frequency: DIGEST_FREQUENCIES.has(row?.digest_frequency) ? row.digest_frequency : SETTINGS_DEFAULTS.digest_frequency,
    quiet_start: row?.quiet_start == null ? null : Number(row.quiet_start),
    quiet_end: row?.quiet_end == null ? null : Number(row.quiet_end),
    profile_visibility: PROFILE_VISIBILITY.has(row?.profile_visibility) ? row.profile_visibility : SETTINGS_DEFAULTS.profile_visibility,
    message_privacy: MESSAGE_PRIVACY.has(row?.message_privacy) ? row.message_privacy : SETTINGS_DEFAULTS.message_privacy,
    show_email: boolValue(row?.show_email, SETTINGS_DEFAULTS.show_email),
  };
}

async function getSettings(env, userId) {
  try {
    const row = await env.DB.prepare('SELECT * FROM user_settings WHERE user_id=?').bind(userId).first();
    return settingsJson(row);
  } catch {
    return settingsJson(null);
  }
}

async function saveSettings(env, userId, input) {
  const current = await getSettings(env, userId);
  const next = {
    push_enabled: boolValue(input.push_enabled, current.push_enabled),
    email_enabled: boolValue(input.email_enabled, current.email_enabled),
    opportunity_alerts: boolValue(input.opportunity_alerts, current.opportunity_alerts),
    social_alerts: boolValue(input.social_alerts, current.social_alerts),
    message_alerts: boolValue(input.message_alerts, current.message_alerts),
    digest_frequency: DIGEST_FREQUENCIES.has(String(input.digest_frequency || '').toLowerCase())
      ? String(input.digest_frequency).toLowerCase() : current.digest_frequency,
    quiet_start: input.quiet_start === null ? null : num(input.quiet_start) == null ? current.quiet_start : clamp(Math.round(num(input.quiet_start)), 0, 1439),
    quiet_end: input.quiet_end === null ? null : num(input.quiet_end) == null ? current.quiet_end : clamp(Math.round(num(input.quiet_end)), 0, 1439),
    profile_visibility: PROFILE_VISIBILITY.has(String(input.profile_visibility || '').toLowerCase())
      ? String(input.profile_visibility).toLowerCase() : current.profile_visibility,
    message_privacy: MESSAGE_PRIVACY.has(String(input.message_privacy || '').toLowerCase())
      ? String(input.message_privacy).toLowerCase() : current.message_privacy,
    show_email: boolValue(input.show_email, current.show_email),
  };
  await env.DB.prepare(`INSERT INTO user_settings
    (user_id,push_enabled,email_enabled,opportunity_alerts,social_alerts,message_alerts,
     digest_frequency,quiet_start,quiet_end,profile_visibility,message_privacy,show_email,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(user_id) DO UPDATE SET
      push_enabled=excluded.push_enabled, email_enabled=excluded.email_enabled,
      opportunity_alerts=excluded.opportunity_alerts, social_alerts=excluded.social_alerts,
      message_alerts=excluded.message_alerts, digest_frequency=excluded.digest_frequency,
      quiet_start=excluded.quiet_start, quiet_end=excluded.quiet_end,
      profile_visibility=excluded.profile_visibility, message_privacy=excluded.message_privacy,
      show_email=excluded.show_email, updated_at=excluded.updated_at`)
    .bind(userId, next.push_enabled ? 1 : 0, next.email_enabled ? 1 : 0,
      next.opportunity_alerts ? 1 : 0, next.social_alerts ? 1 : 0, next.message_alerts ? 1 : 0,
      next.digest_frequency, next.quiet_start, next.quiet_end, next.profile_visibility,
      next.message_privacy, next.show_email ? 1 : 0, nowIso()).run();
  return next;
}

const IMPORTANT_PUSH_TYPES = new Set([
  'message', 'verification', 'moderation', 'task', 'event', 'booth_lead', 'funding',
  'announcement', 'entity_review', 'admin_payment', 'admin_inquiry', 'admin_contact',
  'admin_alert', 'mrc_transaction', 'feedback', 'leaderboard', 'opportunity_match',
  'opportunity', 'inquiry', 'recognition',
]);
const HIGH_PRIORITY_TYPES = new Set([
  'message', 'verification', 'moderation', 'task', 'event', 'booth_lead', 'funding',
  'announcement', 'mrc_transaction', 'admin_alert',
]);
function notificationCategory(type) {
  if (ADMIN_ALERT_TYPES.has(type)) return null;
  if (type === 'message') return 'message_alerts';
  if (type === 'opportunity_match') return 'opportunity_alerts';
  if (type === 'opportunity' || type === 'system' || type === 'account') return null;
  return 'social_alerts';
}

async function canMessageUser(env, viewer, targetId) {
  if (!viewer || !targetId || Number(viewer.id) === Number(targetId)) return false;
  if (await blockedBetween(env, viewer.id, targetId)) return false;
  const settings = await getSettings(env, targetId);
  if (settings.message_privacy === 'nobody') return false;
  if (settings.message_privacy === 'followers') {
    const follows = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
      .bind(targetId, viewer.id).first();
    return !!follows;
  }
  return true;
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

async function touchPresence(env, user) {
  if (!user) return;
  const at = Date.now();
  const previous = user.last_active_at ? Date.parse(user.last_active_at) : 0;
  if (previous && at - previous < 5 * 60000) return;
  await env.DB.prepare('UPDATE users SET last_active_at=? WHERE id=?')
    .bind(new Date(at).toISOString(), user.id).run().catch(() => {});
}

async function currentUser(req, env) {
  const token = bearer(req);
  const payload = await readToken(token, env.SESSION_SECRET);
  if (!payload) return null;
  const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(payload.uid).first();
  if (u) await touchPresence(env, u);
  return u || null;
}
async function requireUser(req, env) {
  const u = await currentUser(req, env);
  if (!u) throw new HttpError(401, 'not_signed_in', 'Please sign in to continue.');
  return u;
}
function isAdminUser(env, u) {
  if (!u || !u.email) return false;
  const list = (env.ADMIN_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  return !!u.email_verified && list.includes(u.email.toLowerCase());
}

const MODERATOR_PERMISSIONS = new Set([
  'remove_comments', 'remove_posts', 'verify_contributions', 'remove_event', 'manage_booths',
]);
async function entityOwnerId(env, type, id) {
  const tables = {
    POST: ['posts', 'author_id'], EVENT: ['events', 'author_id'],
    PROGRAM: ['programs', 'author_id'], PROJECT: ['projects', 'author_id'],
    OPPORTUNITY: ['opportunities', 'author_id'], PODCAST: ['podcast_shows', 'owner_id'],
    VOD: ['vod_videos', 'owner_id'],
  };
  const target = tables[String(type || '').toUpperCase()];
  if (!target) return null;
  const row = await env.DB.prepare(`SELECT ${target[1]} owner_id FROM ${target[0]} WHERE id=?`)
    .bind(Number(id)).first();
  return row ? Number(row.owner_id) : null;
}
async function isEntityModerator(env, user, type, id, permission = null) {
  if (!user || !type || !id) return false;
  let row;
  try {
    row = await env.DB.prepare(`SELECT permissions_json FROM entity_moderators
      WHERE entity_type=? AND entity_id=? AND user_id=?`)
      .bind(String(type).toUpperCase(), String(id), user.id).first();
  } catch (_) { return false; }
  if (!row) return false;
  if (!permission) return true;
  return parseJsonValue(row.permissions_json, []).includes(permission);
}
async function moderatorRoutes(req, env, url) {
  const path = url.pathname;
  const method = req.method;
  const match = /^\/api\/v1\/entities\/([A-Za-z_]+)\/(\d+)\/moderators(?:\/(\d+))?$/.exec(path);
  if (!match) return null;
  const viewer = await requireUser(req, env);
  const type = match[1].toUpperCase();
  const entityId = match[2];
  const targetUser = match[3] ? Number(match[3]) : null;
  const ownerId = await entityOwnerId(env, type, entityId);
  if (ownerId == null) throw new HttpError(404, 'entity_not_found', 'Entity not found.');
  const owner = Number(ownerId) === Number(viewer.id) || isAdminUser(env, viewer);
  if (method === 'GET') {
    if (!owner && !(await isEntityModerator(env, viewer, type, entityId))) {
      throw new HttpError(403, 'forbidden', 'Only the owner or moderators can view this team.');
    }
    const rows = (await env.DB.prepare(`SELECT m.*,u.name user_name,u.picture user_picture,u.handle
      FROM entity_moderators m JOIN users u ON u.id=m.user_id
      WHERE m.entity_type=? AND m.entity_id=? ORDER BY m.created_at ASC`)
      .bind(type, entityId).all()).results || [];
    return json(rows.map((r) => ({
      id: String(r.id), user_id: String(r.user_id), name: r.user_name,
      avatar_url: r.user_picture || null, handle: r.handle || null,
      permissions: parseJsonValue(r.permissions_json, []), created_at: r.created_at,
    })));
  }
  if (!owner) throw new HttpError(403, 'forbidden', 'Only the owner can manage moderators.');
  if (method === 'POST' && !targetUser) {
    const b = await readJson(req);
    const userId = Number(b.user_id);
    if (!Number.isInteger(userId) || userId <= 0) {
      throw new HttpError(400, 'invalid_user', 'Choose a member to moderate this entity.');
    }
    if (userId === Number(ownerId)) {
      throw new HttpError(400, 'owner_is_moderator', 'The owner already controls this entity.');
    }
    const member = await env.DB.prepare('SELECT id,name FROM users WHERE id=?').bind(userId).first();
    if (!member) throw new HttpError(404, 'user_not_found', 'Member not found.');
    const requested = Array.isArray(b.permissions) ? b.permissions : [];
    const permissions = requested.map((p) => String(p).toLowerCase())
      .filter((p) => MODERATOR_PERMISSIONS.has(p));
    if (!permissions.length) permissions.push('remove_comments', 'verify_contributions');
    const at = nowIso();
    await env.DB.prepare(`INSERT INTO entity_moderators
      (entity_type,entity_id,user_id,permissions_json,assigned_by,created_at)
      VALUES (?,?,?,?,?,?)
      ON CONFLICT(entity_type,entity_id,user_id) DO UPDATE SET
        permissions_json=excluded.permissions_json, assigned_by=excluded.assigned_by`)
      .bind(type, entityId, userId, JSON.stringify(permissions), viewer.id, at).run();
    await notify(env, userId, 'moderation',
      `You are now a moderator for ${type.toLowerCase()} #${entityId}`,
      'You can review reports and remove content within this entity only.', viewer.id, null,
      { link: `${type.toLowerCase()}:${entityId}`, entityType: type.toLowerCase(),
        entityId, dedupeKey: `moderator:${type}:${entityId}:${userId}` }).catch(() => {});
    return json({ ok: true, user_id: String(userId), permissions });
  }
  if (method === 'DELETE' && targetUser) {
    await env.DB.prepare(`DELETE FROM entity_moderators
      WHERE entity_type=? AND entity_id=? AND user_id=?`)
      .bind(type, entityId, targetUser).run();
    return json({ ok: true, removed: true });
  }
  return null;
}
function clientIp(req) {
  const cf = req.headers.get('cf-connecting-ip');
  if (cf) return String(cf).trim().slice(0, 64);
  const xff = req.headers.get('x-forwarded-for');
  if (xff) return String(xff).split(',')[0].trim().slice(0, 64);
  return null;
}

async function ipRateLimited(env, req, kind, max, windowMs) {
  const ip = clientIp(req);
  if (!ip) return false;
  const since = new Date(Date.now() - windowMs).toISOString();
  const key = `${kind}:${ip}`;
  const row = await env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?')
    .bind(key, since).first();
  if (Number(row?.c || 0) >= max) return true;
  await env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?,?)').bind(key, nowIso()).run();
  return false;
}

async function emailRateLimited(env, kind, email, max, windowMs) {
  const since = new Date(Date.now() - windowMs).toISOString();
  const key = `${kind}:${email}`;
  const row = await env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?')
    .bind(key, since).first();
  if (Number(row?.c || 0) >= max) return true;
  await env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?,?)').bind(key, nowIso()).run();
  return false;
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
  let blockedByMe = false;
  let blocksMe = false;
  if (viewer && viewer.id !== u.id) {
    const [f, b1, b2] = await Promise.all([
      env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?').bind(viewer.id, u.id).first(),
      env.DB.prepare('SELECT 1 x FROM user_blocks WHERE blocker_id=? AND blocked_id=?').bind(viewer.id, u.id).first(),
      env.DB.prepare('SELECT 1 x FROM user_blocks WHERE blocker_id=? AND blocked_id=?').bind(u.id, viewer.id).first(),
    ]);
    isFollowing = !!f;
    blockedByMe = !!b1;
    blocksMe = !!b2;
  }
  const settings = await getSettings(env, u.id);
  const isSelf = !!(viewer && Number(viewer.id) === Number(u.id));
  const isAdmin = isAdminUser(env, viewer);
  const canViewProfile = isSelf || isAdmin || settings.profile_visibility === 'public' || isFollowing;
  const canSeeEmail = isSelf || isAdmin || settings.show_email;
  let canMessage = false;
  if (viewer && !isSelf && !blockedByMe && !blocksMe && settings.message_privacy !== 'nobody') {
    if (settings.message_privacy === 'everyone') {
      canMessage = true;
    } else {
      const followsViewer = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
        .bind(u.id, viewer.id).first();
      canMessage = !!followsViewer;
    }
  }
  const name = u.name || (u.email ? u.email.split('@')[0] : 'Member');
  return {
    id: String(u.id),
    email: canSeeEmail ? (u.email || '') : '',
    full_name: name,
    name,
    phone: canViewProfile ? (u.phone || null) : null,
    role: u.role || 'INDIVIDUAL',
    handle: u.handle || handleFor(name, u.id),
    verified: !!u.email_verified,
    pms_score: Number((posts.total || 0).toFixed(1)),
    impact_score: Number((posts.total || 0).toFixed(1)),
    email_verified: !!u.email_verified,
    skills: [],
    bio: canViewProfile ? (u.bio || '') : '',
    country: canViewProfile ? (u.country || null) : null,
    city: canViewProfile ? (u.city || null) : null,
    is_tester: !!u.is_tester,
    created_at: u.created_at,
    profile_private: !canViewProfile,
    profile: {
      bio: canViewProfile ? (u.bio || '') : '',
      avatar_url: u.picture || null,
      country: canViewProfile ? (u.country || null) : null,
      city: canViewProfile ? (u.city || null) : null,
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
    blocked_by_me: blockedByMe,
    blocks_me: blocksMe,
    can_message: canMessage,
    is_me: isSelf,
    is_admin: isAdminUser(env, viewer),
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
  if (/^https?:\/\//i.test(s)) return s;
  if (s.startsWith('/media/')) return `${SITE_URL}${s}`;
  return null;
}

function csvCell(v) {
  let s = v == null ? '' : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return `"${s.replace(/"/g, '""')}"`;
}

function csvResponse(filename, columns, rows) {
  const csv = [columns.join(',')]
    .concat(rows.map((r) => columns.map((c) => csvCell(r[c])).join(',')))
    .join('\n');
  return new Response(csv, {
    headers: {
      'content-type': 'text/csv; charset=utf-8',
      'content-disposition': `attachment; filename="${filename}"`,
      'cache-control': 'no-store',
    },
  });
}

function mediaKind(url, type) {
  const t = String(type || '').toUpperCase();
  if (t === 'VIDEO' || t === 'IMAGE' || t === 'AUDIO') return t;
  if (/\.(m4a|mp3|aac|ogg|wav|opus)(\?|#|$)/i.test(url || '')) return 'AUDIO';
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
    if (type === 'AUDIO' && out.some((m) => m.type === 'AUDIO')) continue;
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

function normalizeFilesInput(b) {
  const raw = Array.isArray(b.files) ? b.files : (b.files ? [b.files] : []);
  const out = [];
  for (const item of raw.slice(0, 8)) {
    const src = typeof item === 'string' ? { url: item } : (item || {});
    const url = safeMediaUrl(src.url || src.file_url);
    if (!url) continue;
    out.push({
      url,
      name: clean(src.name || src.file_name, 180) || 'Attachment',
      size: Number.isFinite(Number(src.size)) ? Math.max(0, Number(src.size)) : null,
      content_type: clean(src.content_type || src.mime_type, 120) || null,
    });
  }
  return out;
}

function postFiles(r) {
  if (!r.files_json) return [];
  try {
    const parsed = JSON.parse(r.files_json);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((f) => f && safeMediaUrl(f.url)).slice(0, 8).map((f) => ({
      url: safeMediaUrl(f.url),
      name: clean(f.name, 180) || 'Attachment',
      size: Number.isFinite(Number(f.size)) ? Number(f.size) : null,
      content_type: clean(f.content_type, 120) || null,
    }));
  } catch { return []; }
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
  if (hls) {
    const existing = out.find((m) => m.type === 'VIDEO');
    if (existing) {
      if (!existing.hls_url) existing.hls_url = hls;
      if (!existing.poster_url && r.video_poster_url) existing.poster_url = safeMediaUrl(r.video_poster_url);
      if (existing.duration_seconds == null && r.video_duration_seconds != null) {
        existing.duration_seconds = Number(r.video_duration_seconds);
      }
    } else {
      out.push({ url: legacy || hls, type: 'VIDEO', caption: null, hls_url: hls,
        poster_url: safeMediaUrl(r.video_poster_url), duration_seconds: r.video_duration_seconds == null ? null : Number(r.video_duration_seconds) });
    }
  }
  return out;
}

function postJson(r, likedByMe, ranking, bookmarkedByMe = false, followingAuthor = false) {
  let factors = null;
  if (r.confidence_factors) { try { factors = JSON.parse(r.confidence_factors); } catch { factors = null; } }
  const media = postMedia(r);
  const video = media.find((m) => m.type === 'VIDEO');
  return {
    id: String(r.id),
    author: {
      ...authorJson(r),
      is_following: !!followingAuthor,
    },
    text: r.text,
    kind: r.kind,
    type: r.kind,
    programTag: r.sdg ? SDG_NAMES[r.sdg] || null : null,
    sdg: r.sdg == null ? null : Number(r.sdg),
    impactValue: r.impact_value == null ? null : Number(r.impact_value),
    impactLabel: r.impact_label || null,
    isa_score: r.isa_score == null ? null : Number(r.isa_score),
    impact_domains: parseJsonValue(r.impact_domains_json, null),
    impact_metrics: parseJsonValue(r.impact_metrics_json, null),
    impact_method: factors ? factors.method : null,
    geo_verified: !!r.geo_adjusted,
    geo_level: r.geo_adjusted == null ? 0 : Number(r.geo_adjusted),
    location_claim: r.location_claim || null,
    actor_factor: r.actor_factor == null ? null : Number(r.actor_factor),
    consistency_factor: r.consistency_factor == null ? null : Number(r.consistency_factor),
    promoted: !!(r.boosted_until && Date.parse(r.boosted_until) > Date.now()),
    boosted_until: r.boosted_until || null,
    boost_weight: r.boost_weight == null ? 0 : Number(r.boost_weight),
    paid_mrc: r.paid_mrc == null ? 0 : Number(r.paid_mrc),
    deepfake_score: Number(r.deepfake_score || 0),
    deepfake_verdict: r.deepfake_verdict || 'UNSCANNED',
    deepfake_signals: parseJsonValue(r.deepfake_signals_json, null),
    content_url: r.media_url || null,
    url: r.link_url || null,
    media,
    files: postFiles(r),
    media_count: media.length,
    media_type: r.media_type || (video ? 'VIDEO' : media.length ? 'GALLERY' : 'TEXT'),
    structured: parseJsonArray(r.structured_json)[0] || (() => {
      try { return r.structured_json ? JSON.parse(r.structured_json) : null; } catch (_) { return null; }
    })(),
    moderation_status: r.moderation_status || 'APPROVED',
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
    bookmarkedByMe: !!bookmarkedByMe,
    edited_at: r.edited_at || null,
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

const IMPACT_METRIC_DEFS = {
  environmental: {
    co2_kg: { k: 5000, log: true, label: 'CO₂ avoided/sequestered (kg)' },
    water_liters: { k: 100000, log: true, label: 'Water saved (litres)' },
    trees: { k: 1000, log: true, label: 'Trees planted' },
    biodiversity: { k: 1, label: 'Biodiversity score (0–1)' },
  },
  social: {
    people_reached: { k: 10000, log: true, label: 'People reached' },
    volunteer_hours: { k: 500, log: true, label: 'Volunteer hours' },
    lives_improved: { k: 1000, log: true, label: 'Lives improved' },
    inclusion: { k: 1, label: 'Inclusion score (0–1)' },
  },
  economic: {
    income_egp: { k: 1000000, log: true, label: 'Income generated (EGP)' },
    jobs: { k: 100, log: true, label: 'Jobs created' },
    local_gdp_egp: { k: 10000000, log: true, label: 'Local GDP contribution (EGP)' },
  },
  governance: {
    transparency: { k: 100, label: 'Transparency score (0–100)' },
    policy_adherence: { k: 100, label: 'Policy adherence (%)' },
    community_engagement: { k: 1, label: 'Community engagement (0–1)' },
  },
  educational: {
    students_reached: { k: 5000, log: true, label: 'Students reached' },
    learning_hours: { k: 2000, log: true, label: 'Learning hours' },
    curriculum: { k: 100, label: 'Curriculum coverage (%)' },
    retention: { k: 100, label: 'Knowledge retention (%)' },
  },
  infrastructure: {
    facilities: { k: 50, log: true, label: 'Facilities built' },
    maintenance_hours: { k: 1000, log: true, label: 'Maintenance hours' },
    access: { k: 10000, log: true, label: 'People with new access' },
  },
};
const IMPACT_DOMAIN_WEIGHTS = {
  environmental: 0.20, social: 0.24, economic: 0.16,
  governance: 0.10, educational: 0.16, infrastructure: 0.14,
};
const IMPACT_DOMAIN_ICONS = {
  environmental: 'ENV', social: 'SOC', economic: 'ECO',
  governance: 'GOV', educational: 'EDU', infrastructure: 'INF',
};

function normalizeImpactMetrics(input) {
  if (!input || typeof input !== 'object') return null;
  const out = {};
  let count = 0;
  for (const [domain, defs] of Object.entries(IMPACT_METRIC_DEFS)) {
    const rawDomain = input[domain];
    if (!rawDomain || typeof rawDomain !== 'object') continue;
    for (const [metric, def] of Object.entries(defs)) {
      const value = Number(rawDomain[metric]);
      if (!Number.isFinite(value) || value <= 0) continue;
      if (!out[domain]) out[domain] = {};
      out[domain][metric] = clamp(value, 0, metric === 'biodiversity' || metric === 'inclusion' || metric === 'community_engagement' ? 1 : 1e12);
      count += 1;
    }
  }
  return count ? out : null;
}

function impactNormalize(value, def) {
  if (!Number.isFinite(value) || value <= 0) return 0;
  const scaled = def.log ? Math.log1p(value) : value;
  const ceiling = def.log ? Math.log1p(def.k) : def.k;
  return clamp(1 - Math.exp(-scaled / Math.max(ceiling, 0.0001)), 0, 1);
}

function impactDecay(domain, days) {
  const d = Math.max(0, days);
  switch (domain) {
    case 'environmental': return Math.exp(-0.05 * d);
    case 'social': return Math.max(0, 1 - Math.pow(Math.min(d, 365) / 365, 2));
    case 'governance': return 1 / (1 + Math.exp(-0.05 * (d - 180)));
    case 'economic': return Math.exp(-0.1 * d);
    case 'educational': return Math.exp(-0.03 * d);
    case 'infrastructure': return Math.max(0.5, 1 - 0.02 * d);
    default: return 1;
  }
}

function computeIsaScore(post, metrics, ratingStats = { n: 0, avg: 0 }, verifiedActions = 0) {
  if (!metrics) return null;
  const created = Date.parse(post.created_at || nowIso());
  const days = Number.isFinite(created) ? Math.max(0, (Date.now() - created) / 86400000) : 0;
  const domains = {};
  const detail = {};
  let weighted = 0;
  let activeDomains = 0;
  for (const [domain, defs] of Object.entries(IMPACT_METRIC_DEFS)) {
    const supplied = metrics[domain] || {};
    let domainTotal = 0;
    let domainWeight = 0;
    let suppliedCount = 0;
    for (const [metric, def] of Object.entries(defs)) {
      const raw = Number(supplied[metric]);
      if (!Number.isFinite(raw) || raw <= 0) continue;
      const normalized = impactNormalize(raw, def);
      const mWeight = 1 / Object.keys(defs).length;
      domainTotal += normalized * mWeight;
      domainWeight += mWeight;
      suppliedCount += 1;
      detail[`${domain}.${metric}`] = { raw, normalized: Number(normalized.toFixed(3)) };
    }
    if (!suppliedCount) continue;
    activeDomains += 1;
    const domainScore = domainWeight ? domainTotal / domainWeight : 0;
    const decay = impactDecay(domain, days);
    domains[domain] = {
      score: Number((domainScore * 100).toFixed(1)),
      decay: Number(decay.toFixed(3)),
      weight: IMPACT_DOMAIN_WEIGHTS[domain],
      code: IMPACT_DOMAIN_ICONS[domain],
    };
    weighted += domainScore * IMPACT_DOMAIN_WEIGHTS[domain] * decay;
  }
  if (!activeDomains) return null;
  const metricKeys = Object.keys(detail).length;
  const totalMetrics = Object.values(IMPACT_METRIC_DEFS)
    .reduce((sum, defs) => sum + Object.keys(defs).length, 0);
  const coverage = clamp(metricKeys / totalMetrics, 0, 1);
  const domainValues = Object.values(domains).map((d) => d.score / 100);
  const mean = domainValues.reduce((a, b) => a + b, 0) / domainValues.length;
  const variance = domainValues.reduce((a, b) => a + Math.pow(b - mean, 2), 0) /
    domainValues.length;
  const consistency = (1 - 0.25 * Math.tanh(variance * 6)) *
    (0.72 + 0.28 * clamp(activeDomains / 6, 0, 1));
  const hasGps = Number.isFinite(Number(post.latitude)) && Number.isFinite(Number(post.longitude));
  const hasClaim = String(post.location_claim || '').trim().length > 0;
  const geoLevel = hasGps ? (hasClaim ? 2 : 1) : 0;
  const geoFactor = hasGps ? (hasClaim ? 1.12 : 1.06) : 1.0;
  const actorFactor = 1 + 0.5 * Math.exp(-Math.max(0, Number(verifiedActions) || 0) / 50);
  const n = Math.max(0, Number(ratingStats.n) || 0);
  const avg = Math.max(0, Number(ratingStats.avg) || 0);
  const bayesRating = (avg * n + 3 * 2) / (n + 2) / 5;
  const engRaw = (post.like_count || 0) * 2 + (post.comment_count || 0) * 2.5 +
    (post.share_count || 0) * 3;
  const engagement = Math.tanh(Math.log1p(engRaw) / Math.log(61));
  const community = 0.65 * bayesRating + 0.35 * engagement;
  const raw = weighted * geoFactor * actorFactor * consistency * (0.82 + 0.18 * community);
  const impact = clamp(10 * (1 - Math.exp(-2.4 * raw)), 0, 10);
  const confidence = clamp(22 + coverage * 35 + Math.min(15, n * 3) +
    (post.author_verified ? 15 : 0) + (hasGps ? 5 : 0) + engagement * 8, 5, 99);
  return {
    impact_value: Number(impact.toFixed(2)),
    impact_label: impactLabelFor(impact, confidence),
    confidence_score: Math.round(confidence),
    confidence_label: confidence >= 75 ? 'High confidence' :
      confidence >= 50 ? 'Moderate confidence' : 'Low confidence',
    isa_score: Math.round(impact * 100),
    domains,
    metric_detail: detail,
    coverage: Number(coverage.toFixed(3)),
    geo_adjusted: geoLevel,
    actor_factor: Number(actorFactor.toFixed(3)),
    consistency_factor: Number(consistency.toFixed(3)),
    method: 'ISA v2 · non-linear multi-domain (diminishing returns, domain decay, geo evidence, actor normalization, consistency penalty)',
  };
}

async function verifiedActionCount(env, userId) {
  const row = await env.DB.prepare(`SELECT COUNT(*) c FROM posts
    WHERE author_id=? AND hidden=0 AND confidence_score>=70`).bind(userId).first();
  return Number(row?.c || 0);
}

async function recomputeImpact(env, postId) {
  const post = await env.DB.prepare(`${POST_SELECT} WHERE p.id=?`).bind(postId).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const agg = await env.DB.prepare('SELECT COUNT(*) n, COALESCE(AVG(stars),0) avg FROM post_impact_votes WHERE post_id=?')
    .bind(postId).first();
  const n = Number(agg.n || 0);
  const avg = Number(agg.avg || 0);
  const metrics = parseJsonValue(post.impact_metrics_json, null);
  const isa = computeIsaScore(post, metrics, { n, avg },
    await verifiedActionCount(env, post.author_id));
  if (isa) {
    const factors = {
      ratings: n, average_stars: Number(avg.toFixed(2)),
      domains: isa.domains, metric_detail: isa.metric_detail,
      coverage: isa.coverage, geo_adjusted: isa.geo_adjusted,
      actor_factor: isa.actor_factor, consistency: isa.consistency_factor,
      author_verified: !!post.author_verified, confidence: isa.confidence_score,
      voters: n, method: isa.method,
    };
    await env.DB.prepare(`UPDATE posts SET impact_value=?,impact_label=?,confidence_score=?,
      confidence_label=?,confidence_factors=?,isa_score=?,impact_domains_json=?,
      geo_adjusted=?,actor_factor=?,consistency_factor=? WHERE id=?`)
      .bind(isa.impact_value, isa.impact_label, isa.confidence_score,
        isa.confidence_label, JSON.stringify(factors), isa.isa_score,
        JSON.stringify(isa.domains), isa.geo_adjusted ? 1 : 0, isa.actor_factor,
        isa.consistency_factor, postId).run();
    return { impact_value: isa.impact_value, impact_label: isa.impact_label,
      confidence_score: isa.confidence_score, confidence_factors: factors,
      isa_score: isa.isa_score, impact_domains: isa.domains };
  }
  const engagement = Math.log1p((post.like_count || 0) * 2 + (post.comment_count || 0) * 2.5 + (post.share_count || 0) * 3) /
    Math.log(61);
  const confidence = clamp(40 + Math.min(30, n * 6) + (post.author_verified ? 16 : 0) +
    Math.min(12, engagement * 12), 5, 99);
  const score = n === 0 ? (post.impact_value || 0) : clamp(
    10 * (0.55 * (avg / 5) + 0.20 * Math.min(1, engagement) + 0.15 * Math.min(1, n / 5) + 0.10 * (confidence / 100)),
    0, 10);
  const factors = {
    ratings: n, average_stars: Number(avg.toFixed(2)), engagement: Number(Math.min(1, engagement).toFixed(3)),
    author_verified: !!post.author_verified, confidence: Math.round(confidence),
    voters: n, method: 'weighted ratings + engagement + author trust',
  };
  await env.DB.prepare('UPDATE posts SET impact_value=?, impact_label=?, isa_score=?, confidence_score=?, confidence_label=?, confidence_factors=? WHERE id=?')
    .bind(Number(score.toFixed(2)), impactLabelFor(score, confidence), Math.round(score * 100),
      Math.round(confidence),
      confidence >= 75 ? 'High confidence' : confidence >= 50 ? 'Moderate confidence' : 'Low confidence',
      JSON.stringify(factors), postId).run();
  return { impact_value: Number(score.toFixed(2)), impact_label: impactLabelFor(score, confidence),
    confidence_score: Math.round(confidence), confidence_factors: factors,
    isa_score: Math.round(score * 100) };
}

async function notify(env, userId, type, title, body, actorId, postId, opts = {}) {
  if (!userId || Number(userId) === Number(actorId)) return false;
  try {
    const settings = await getSettings(env, userId);
    const category = notificationCategory(type);
    if (category && !settings[category]) return false;
    const defaultDedupe = ['like', 'comment_like', 'follow'].includes(type)
      ? `${type}:${actorId || 0}:${postId || 0}` : '';
    const dedupeKey = clean(opts.dedupeKey || defaultDedupe, 160);
    if (dedupeKey) {
      const log = await env.DB.prepare('INSERT OR IGNORE INTO notification_log (user_id,kind,ref_id,channel,created_at) VALUES (?,?,?,?,?)')
        .bind(userId, type, dedupeKey, 'in_app', nowIso()).run();
      if (!log.meta?.changes) return false;
    }
    const cleanTitle = clean(title, 140);
    const cleanBody = clean(body, 300) || null;
    await env.DB.prepare(`INSERT INTO notifications
      (user_id,type,title,body,actor_id,post_id,link,entity_type,entity_id,read,created_at)
      VALUES (?,?,?,?,?,?,?,?,?,0,?)`)
      .bind(userId, type, cleanTitle, cleanBody, actorId || null,
        postId || null, clean(opts.link, 400) || null,
        clean(opts.entityType, 60) || null, clean(opts.entityId, 80) || null,
        nowIso()).run();
    const instant = !settings.digest_frequency || settings.digest_frequency === 'instant';
    const wantsPush = opts.push === true ||
      (opts.push !== false && IMPORTANT_PUSH_TYPES.has(type));
    if (settings.push_enabled && instant && wantsPush) {
      const recent = await env.DB.prepare(`SELECT COUNT(*) c FROM notification_log
        WHERE user_id=? AND channel='push' AND created_at>?`).bind(userId,
        new Date(Date.now() - 10 * 60000).toISOString()).first();
      if (Number(recent?.c || 0) < 4) {
        await env.DB.prepare(`INSERT OR IGNORE INTO notification_log
          (user_id,kind,ref_id,channel,created_at) VALUES (?,?,?,?,?)`).bind(
          userId, 'push', `${type}:${postId || 0}:${Date.now()}`, 'push', nowIso()).run();
        await sendFcmPushForUser(env, userId, {
          type, title: cleanTitle, body: cleanBody || '', actorId, postId,
          link: opts.link, entityType: opts.entityType, entityId: opts.entityId,
          priority: HIGH_PRIORITY_TYPES.has(type) ? 'high' : 'normal',
        });
      }
    }
    return true;
  } catch {
    return false;
  }
}

async function adminRecipientIds(env) {
  const emails = String(env.ADMIN_EMAILS || '')
    .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (!emails.length) return [];
  try {
    const rows = (await env.DB.prepare(
      `SELECT id FROM users WHERE lower(email) IN (${emails.map(() => '?').join(',')})`)
      .bind(...emails).all()).results || [];
    return rows.map((r) => Number(r.id));
  } catch (_) {
    return [];
  }
}

async function notifyAdmins(env, type, title, body, opts = {}) {
  const ids = await adminRecipientIds(env);
  for (const id of ids) {
    if (opts.excludeId && Number(id) === Number(opts.excludeId)) continue;
    await notify(env, id, type, title, body, opts.actorId || null, null, {
      link: opts.link,
      entityType: opts.entityType,
      entityId: opts.entityId,
      dedupeKey: opts.dedupeKey,
      push: opts.push,
    }).catch(() => {});
  }
}

function adminPushMin(env) {
  const value = Number(env.ADMIN_PUSH_MIN_MRC);
  return Number.isFinite(value) && value >= 0 ? value : 100;
}

// One entry point for platform alerts. Every alert is written to the admin
// inbox; only critical or high-value events trigger a push, so a busy day of
// transactions does not turn into notification spam.
export async function adminAlert(env, opts = {}) {
  const ids = await adminRecipientIds(env);
  if (!ids.length) return;
  const type = clean(opts.type, 40) || 'admin_alert';
  const severity = String(opts.severity || 'normal').toLowerCase();
  const amount = Number(opts.amount);
  const threshold = adminPushMin(env);
  const forcedPush = severity === 'critical' ||
    (severity === 'high' && (!Number.isFinite(amount) || amount >= threshold));
  const title = clean(opts.title, 140) || 'Platform alert';
  const body = clean(opts.body, 300) || null;
  const dedupeKey = clean(opts.dedupeKey, 160) || '';
  for (const id of ids) {
    if (opts.excludeId && Number(id) === Number(opts.excludeId)) continue;
    await notify(env, id, type, title, body, opts.actorId || null, null, {
      link: clean(opts.link, 400) || 'admin:inbox',
      entityType: clean(opts.entityType, 60) || null,
      entityId: clean(opts.entityId, 80) || null,
      dedupeKey: dedupeKey ? `${type}:${dedupeKey}` : '',
      push: severity === 'normal' ? false : forcedPush,
    }).catch(() => {});
  }
}

async function alertEntityReview(env, kind, id, title, actor) {
  if (!id) return;
  await adminAlert(env, {
    type: 'entity_review',
    severity: 'high',
    title: `${kind} needs review`,
    body: `${actor?.name || 'A member'} submitted "${title}".`,
    link: 'admin:entities',
    entityType: kind.toLowerCase(),
    entityId: String(id),
    actorId: actor?.id || null,
    dedupeKey: `${kind}:${id}`,
  }).catch(() => {});
}

function hash01(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return (h >>> 0) / 4294967295;
}

function rankCandidates(rows, opts) {
  const { viewer, liked, following, seen, mode, offset, limit, seed } = opts;
  const rotationKey = seed ? `seed:${seed}` : `viewer:${viewer ? viewer.id : 'guest'}`;
  const rotationWeight = seed ? 0.30 : 0.10;
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
    const promoted = !!(r.boosted_until && Date.parse(r.boosted_until) > now);
    const paidBoost = promoted ? clamp(Number(r.boost_weight || 0), 0, 0.38) : 0;
    const explore = hash01(rotationKey + ':a:' + r.id) * rotationWeight;
    const exploreB = hash01(rotationKey + ':b:' + r.id) * (seed ? 0.14 : 0);
    // Ranking must not depend on posts already returned on earlier pages.
    // A per-page seen penalty reorders the list and breaks offset pagination
    // (the client would see duplicates and skip posts). Views are still
    // recorded for analytics, but they do not change the order.
    const score = 0.34 * impact + 0.18 * verifiedContent + 0.18 * recency +
      0.14 * Math.min(1.4, velocity) + 0.08 * (isFollow ? 1 : 0) + 0.05 * interest +
      0.03 * hasMedia + paidBoost * 1.4 + explore + exploreB + (isSelf ? 0.02 : 0);
    const reasons = [];
    if (impact >= 0.6) reasons.push({ key: 'impact', label: 'High verified impact', weight: 0.34 * impact });
    if (verifiedContent) reasons.push({ key: 'verified', label: 'Verified source', weight: 0.18 });
    if (isFollow) reasons.push({ key: 'following', label: 'From a profile you follow', weight: 0.08 });
    if (velocity >= 0.5) reasons.push({ key: 'trending', label: 'Trending in the community', weight: 0.14 * velocity });
    if (hasMedia) reasons.push({ key: 'media', label: 'Visual evidence attached', weight: 0.03 });
    if (interest) reasons.push({ key: 'interest', label: 'Matches your interests', weight: 0.05 });
    if (ageH < 6) reasons.push({ key: 'fresh', label: 'Fresh update', weight: 0.18 * recency });
    if (promoted) reasons.push({ key: 'promoted', label: 'Promoted with MRC', weight: paidBoost * 1.4 });
    reasons.sort((a, b) => b.weight - a.weight);
    if (!reasons.length) reasons.push({ key: 'explore', label: 'Worth discovering', weight: 0.05 });
    return { row: r, score, promoted, reason: reasons[0].label, reasons: reasons.slice(0, 3).map((x) => x.label) };
  });

  if (mode === 'latest') {
    items.sort((a, b) => Date.parse(b.row.created_at) - Date.parse(a.row.created_at));
    return items.slice(offset, offset + limit);
  }
  if (mode === 'impact') {
    items.sort((a, b) => (b.row.impact_value || 0) - (a.row.impact_value || 0) || Date.parse(b.row.created_at) - Date.parse(a.row.created_at));
    return items.slice(offset, offset + limit);
  }
  items.sort((a, b) => b.score - a.score ||
    Date.parse(b.row.created_at) - Date.parse(a.row.created_at) ||
    Number(b.row.id) - Number(a.row.id));

  // Author-diversity pass: avoid one voice dominating the top of the feed.
  const picked = [];
  const remaining = items.slice();
  const authorSeen = new Map();
  const want = Math.min(remaining.length, offset + limit + 8);
  while (picked.length < want && remaining.length) {
    let bestI = 0; let best = -Infinity;
    for (let i = 0; i < remaining.length; i++) {
      const a = remaining[i].row.author_id;
      const adj = remaining[i].score - (authorSeen.get(a) || 0) * 0.22;
      if (adj > best) { best = adj; bestI = i; }
    }
    const item = remaining.splice(bestI, 1)[0];
    authorSeen.set(item.row.author_id, (authorSeen.get(item.row.author_id) || 0) + 1);
    picked.push(item);
  }
  const page = picked.slice(offset, offset + limit);
  const promotedItems = page.filter((x) => x.promoted);
  if (!promotedItems.length) return page;
  const slots = Math.min(promotedItems.length, Math.max(1, Math.round(limit * 0.15)));
  const reserved = promotedItems.slice(0, slots);
  return [...reserved, ...page.filter((x) => !reserved.includes(x))].slice(0, limit);
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
  const b = await readJson(req);
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
  const b = await readJson(req);
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
  const role = ROLES.has(requestedRole) && !RESTRICTED_SIGNUP_ROLES.has(requestedRole) ? requestedRole : 'INDIVIDUAL';
  if (!isEmail(email)) throw new HttpError(400, 'invalid_email', 'Please enter a valid email address.');
  if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Please enter your full name.');
  if (name.length > 90) throw new HttpError(400, 'invalid_name', 'Name is too long.');
  if (password.length < 8) throw new HttpError(400, 'weak_password', 'Password must be at least 8 characters.');
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password))
    throw new HttpError(400, 'weak_password', 'Password must include letters and numbers.');
  if (password.length > 200) throw new HttpError(400, 'weak_password', 'Password is too long.');
  if (await ipRateLimited(env, req, 'register', 10, 3600000)) {
    throw new HttpError(429, 'rate_limited', 'Too many signup attempts from this network. Please try again later.');
  }
  const existing = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (existing) {
    throw new HttpError(409, 'email_taken', 'An account with this email already exists. Please sign in.');
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
  const verification = await sendVerificationForUser(env, u).catch(() => ({ sent: false }));
  return json({ ok: true, access_token: await appTokenFor(u, env), token_type: 'bearer', user: await userJson(env, u, u), email_verification_required: !u.email_verified, verification_email_sent: !!verification.sent }, 201);
}

async function login(req, env) {
  const b = await readJson(req);
  const email = clean(b.email, 254).toLowerCase();
  const password = typeof b.password === 'string' ? b.password : '';
  if (await emailRateLimited(env, 'login', email || 'unknown', 10, 900000) ||
      await ipRateLimited(env, req, 'login', 20, 900000)) {
    throw new HttpError(429, 'rate_limited', 'Too many login attempts. Please try again later.');
  }
  const u = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
  if (!u || !u.password_hash) throw new HttpError(401, 'invalid_credentials', 'Incorrect email or password.');
  if (!(await verifyPassword(password, u.password_salt, u.password_hash)))
    throw new HttpError(401, 'invalid_credentials', 'Incorrect email or password.');
  await env.DB.prepare('UPDATE users SET last_login_at=?, login_count=login_count+1 WHERE id=?').bind(nowIso(), u.id).run();
  await env.DB.prepare('INSERT INTO login_events (user_id,email,method,at) VALUES (?,?,?,?)')
    .bind(u.id, u.email, 'password_app', nowIso()).run();
  return json({ ok: true, access_token: await appTokenFor(u, env),
    token_type: 'bearer', user: await userJson(env, u, u), email_verification_required: !u.email_verified });
}

async function sendVerificationForUser(env, user) {
  if (!user) throw new HttpError(404, 'user_not_found', 'Account not found.');
  if (user.email_verified) return { ok: true, alreadyVerified: true, sent: false };
  if (await tokenRateLimited(env, user.id, 'verify_email', 4, 3600000))
    throw new HttpError(429, 'rate_limited', 'Please wait before requesting another confirmation email.');
  const token = await createAuthToken(env, user.id, 'verify_email');
  const verifyUrl = `${SITE_URL}/api/v1/auth/verify-email?token=${encodeURIComponent(token)}`;
  const mail = await sendVerificationEmail(env, user, verifyUrl, 24);
  return { ok: true, alreadyVerified: false, sent: !mail.skipped && !!mail.ok };
}

async function verifyEmailWithToken(env, token) {
  const row = await findAuthToken(env, token, 'verify_email');
  if (!row || row.used_at || row.expires_at < nowIso()) return null;
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(row.user_id).first();
  if (!user) return null;
  await env.DB.batch([
    env.DB.prepare('UPDATE users SET email_verified=1 WHERE id=?').bind(user.id),
    env.DB.prepare('UPDATE auth_tokens SET used_at=? WHERE id=?').bind(nowIso(), row.id),
  ]);
  const fresh = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(user.id).first();
  await sendWelcomeEmail(env, fresh).catch(() => {});
  return fresh;
}

async function sendResetForUser(env, user) {
  if (!user || !user.password_hash) return { ok: true, sent: false };
  if (await tokenRateLimited(env, user.id, 'reset_password', 3, 3600000)) return { ok: true, sent: false };
  const token = await createAuthToken(env, user.id, 'reset_password');
  const resetUrl = `${SITE_URL}/api/v1/auth/reset-password?token=${encodeURIComponent(token)}`;
  const mail = await sendPasswordResetEmail(env, user, resetUrl, 60);
  return { ok: true, sent: !mail.skipped && !!mail.ok };
}

function validPassword(password) {
  return typeof password === 'string' && password.length >= 8 && password.length <= 200 &&
    /[A-Za-z]/.test(password) && /[0-9]/.test(password);
}

async function resetPasswordWithToken(env, token, password) {
  if (!validPassword(password))
    throw new HttpError(400, 'weak_password', 'Password must be at least 8 characters and include letters and numbers.');
  const row = await findAuthToken(env, token, 'reset_password');
  if (!row || row.used_at || row.expires_at < nowIso())
    throw new HttpError(400, 'invalid_token', 'This reset link is invalid or has expired. Request a new one.');
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(row.user_id).first();
  if (!user) throw new HttpError(404, 'user_not_found', 'Account not found.');
  const { salt, hash } = await hashPassword(password);
  await env.DB.batch([
    env.DB.prepare('UPDATE users SET password_hash=?, password_salt=? WHERE id=?').bind(hash, salt, user.id),
    env.DB.prepare('UPDATE auth_tokens SET used_at=? WHERE user_id=? AND kind=? AND used_at IS NULL')
      .bind(nowIso(), user.id, 'reset_password'),
  ]);
  await sendPasswordChangedEmail(env, user, new Date().toUTCString()).catch(() => {});
  return user;
}

function authPage({ title, message, ctaText = 'Open MASAREEN', ctaUrl = 'masaren://auth/verified', ok = true }) {
  const color = ok ? '#0f766e' : '#b91c1c';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${escapeHtml(title)}</title><style>body{margin:0;background:#f4f7f6;font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif;color:#1f2937}.wrap{max-width:520px;margin:0 auto;padding:48px 20px}.card{background:#fff;border:1px solid #e5e7eb;border-radius:20px;padding:36px 28px;box-shadow:0 24px 60px rgba(15,61,62,.10);text-align:center}.logo{width:72px;height:72px;border-radius:18px;margin-bottom:18px}h1{font-size:24px;margin:0 0 12px;color:${color}}p{line-height:1.7;color:#6b7280}.cta{display:inline-block;margin-top:18px;background:#0f3d3e;color:#fff;text-decoration:none;padding:13px 26px;border-radius:999px;font-weight:700}.small{margin-top:16px;font-size:12px;color:#9ca3af}</style></head><body><div class="wrap"><div class="card"><img class="logo" src="${SITE_URL}/assets/mark.png" alt="MASAREEN"><h1>${escapeHtml(title)}</h1><p>${message}</p><a class="cta" href="${escapeHtml(ctaUrl)}">${escapeHtml(ctaText)}</a><div class="small">MASAREEN Â· https://masareen.com</div></div></div></body></html>`;
}

function resetPasswordPage(token) {
  const safeToken = escapeHtml(token || '');
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Reset your MASAREEN password</title><style>body{margin:0;background:#f4f7f6;font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif;color:#1f2937}.wrap{max-width:520px;margin:0 auto;padding:48px 20px}.card{background:#fff;border:1px solid #e5e7eb;border-radius:20px;padding:36px 28px;box-shadow:0 24px 60px rgba(15,61,62,.10)}.logo{width:72px;height:72px;border-radius:18px;display:block;margin:0 auto 18px}h1{font-size:24px;margin:0 0 10px;text-align:center}p{line-height:1.7;color:#6b7280;text-align:center}label{display:block;font-size:13px;font-weight:700;margin:18px 0 8px}input{width:100%;box-sizing:border-box;border:1px solid #d1d5db;border-radius:12px;padding:13px 14px;font-size:16px}button{width:100%;margin-top:22px;border:0;background:#0f3d3e;color:#fff;padding:14px;border-radius:999px;font-size:16px;font-weight:700;cursor:pointer}button:disabled{opacity:.6}.msg{margin-top:16px;font-size:14px;text-align:center;min-height:20px}.ok{color:#0f766e}.err{color:#b91c1c}</style></head><body><div class="wrap"><div class="card"><img class="logo" src="${SITE_URL}/assets/mark.png" alt="MASAREEN"><h1>Choose a new password</h1><p>Your new password must be at least 8 characters and include letters and numbers.</p><form id="f"><label for="p">New password</label><input id="p" type="password" minlength="8" autocomplete="new-password" required><label for="c">Confirm password</label><input id="c" type="password" minlength="8" autocomplete="new-password" required><input id="token" type="hidden" value="${safeToken}"><button id="b" type="submit">Reset password</button><div id="m" class="msg" role="status" aria-live="polite"></div></form></div></div><script>var f=document.getElementById('f'),m=document.getElementById('m'),b=document.getElementById('b');f.addEventListener('submit',function(e){e.preventDefault();var p=document.getElementById('p').value,c=document.getElementById('c').value;if(p!==c){m.className='msg err';m.textContent='Passwords do not match.';return}b.disabled=true;m.className='msg';m.textContent='Saving...';fetch('/api/v1/auth/reset-password',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({token:document.getElementById('token').value,password:p})}).then(function(r){return r.json().then(function(j){return {ok:r.ok,j:j}})}).then(function(x){if(!x.ok)throw new Error(x.j.message||'Could not reset password.');m.className='msg ok';m.textContent='Password updated. You can now sign in to MASAREEN.';f.reset();b.disabled=true}).catch(function(err){m.className='msg err';m.textContent=err.message;b.disabled=false})});</script></body></html>`;
}

async function authRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (path === '/api/v1/auth/verify-email' && req.method === 'GET') {
    const token = url.searchParams.get('token') || '';
    const user = await verifyEmailWithToken(env, token);
    if (!user) {
      return htmlResponse(authPage({
        title: 'Link expired',
        message: 'This confirmation link is invalid or has expired. Open MASAREEN and request a new confirmation email from Settings.',
        ctaText: 'Open MASAREEN',
        ok: false,
      }), 400);
    }
    return htmlResponse(authPage({
      title: 'Email confirmed',
      message: `Thank you, ${escapeHtml((user.name || '').split(/\s+/)[0] || 'there')}. Your email is confirmed and your MASAREEN account is ready.`,
      ctaText: 'Open MASAREEN',
    }));
  }
  if (path === '/api/v1/auth/verify-email' && req.method === 'POST') {
    const b = await readJson(req);
    const user = await verifyEmailWithToken(env, b.token);
    if (!user) throw new HttpError(400, 'invalid_token', 'This confirmation link is invalid or has expired.');
    return json({ ok: true, verified: true, user: await userJson(env, user, user) });
  }
  if (path === '/api/v1/auth/resend-verification' && req.method === 'POST') {
    const u = await requireUser(req, env);
    const result = await sendVerificationForUser(env, u);
    return json({ ok: true, ...result });
  }
  if (path === '/api/v1/auth/verification-status' && req.method === 'GET') {
    const u = await requireUser(req, env);
    return json({ ok: true, email_verified: !!u.email_verified, email: u.email });
  }
  if (path === '/api/v1/auth/forgot-password' && req.method === 'POST') {
    const b = await readJson(req);
    const email = clean(b.email, 254).toLowerCase();
    if (isEmail(email)) {
      const user = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
      if (user) await sendResetForUser(env, user).catch(() => {});
    }
    return json({ ok: true, message: 'If an account exists for that email, a reset link is on its way.' });
  }
  if (path === '/api/v1/auth/reset-password' && req.method === 'GET') {
    const token = url.searchParams.get('token') || '';
    return htmlResponse(resetPasswordPage(token));
  }
  if (path === '/api/v1/auth/reset-password' && req.method === 'POST') {
    const b = await readJson(req);
    await resetPasswordWithToken(env, b.token, b.password);
    return json({ ok: true, message: 'Password updated. You can sign in now.' });
  }
  if (path === '/api/v1/users/me/settings' && req.method === 'GET') {
    const u = await requireUser(req, env);
    return json({ ok: true, settings: await getSettings(env, u.id), email_verified: !!u.email_verified, email: u.email, name: u.name });
  }
  if (path === '/api/v1/users/me/settings' && (req.method === 'PATCH' || req.method === 'POST')) {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    return json({ ok: true, settings: await saveSettings(env, u.id, b), email_verified: !!u.email_verified });
  }
  if (path === '/api/v1/users/me/password' && req.method === 'POST') {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    if (!u.password_hash || !(await verifyPassword(String(b.current_password || ''), u.password_salt, u.password_hash)))
      throw new HttpError(401, 'invalid_credentials', 'Your current password is incorrect.');
    if (!validPassword(b.new_password))
      throw new HttpError(400, 'weak_password', 'Password must be at least 8 characters and include letters and numbers.');
    const { salt, hash } = await hashPassword(b.new_password);
    await env.DB.prepare('UPDATE users SET password_hash=?, password_salt=? WHERE id=?').bind(hash, salt, u.id).run();
    await sendPasswordChangedEmail(env, u, new Date().toUTCString()).catch(() => {});
    return json({ ok: true, message: 'Password updated.' });
  }
  if (path === '/api/v1/users/me/delete' && req.method === 'POST') {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    if (!u.password_hash || !(await verifyPassword(String(b.password || ''), u.password_salt, u.password_hash)))
      throw new HttpError(401, 'invalid_credentials', 'Your password is incorrect.');
    const at = nowIso();
    const anonymous = `deleted+${u.id}@masareen.invalid`;
    const id = u.id;
    await env.DB.batch([
      env.DB.prepare(`UPDATE users SET email=?, name='Deleted member', handle=?, password_hash=NULL, password_salt=NULL,
        bio=NULL, phone=NULL, national_id=NULL, picture=NULL, cover_url=NULL, email_verified=0, profile_complete=0 WHERE id=?`)
        .bind(anonymous, `deleted-${id}`, id),
      env.DB.prepare('DELETE FROM device_tokens WHERE user_id=?').bind(id),
      env.DB.prepare('UPDATE auth_tokens SET used_at=? WHERE user_id=? AND used_at IS NULL').bind(at, id),
      env.DB.prepare('DELETE FROM user_settings WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM user_profiles WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM coin_wallets WHERE owner_id=?').bind(id),
      env.DB.prepare('DELETE FROM coin_transactions WHERE owner_id=?').bind(id),
      env.DB.prepare('DELETE FROM daily_claims WHERE owner_id=?').bind(id),
      env.DB.prepare('DELETE FROM payments WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM pro_subscriptions WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM follows WHERE follower_id=? OR followee_id=?').bind(id, id),
      env.DB.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_id=?').bind(id, id),
      env.DB.prepare('DELETE FROM notifications WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM notification_log WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM post_likes WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM post_bookmarks WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM post_views WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM post_impact_votes WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM course_enrollments WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM event_attendees WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM program_members WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM project_members WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM opportunity_applications WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM organization_members WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM profile_endorsements WHERE user_id=? OR endorser_id=?').bind(id, id),
      env.DB.prepare('DELETE FROM profile_recommendations WHERE user_id=? OR author_id=?').bind(id, id),
      env.DB.prepare('DELETE FROM profile_analytics WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM profile_achievements WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM evidence WHERE owner_id=?').bind(id),
      env.DB.prepare('DELETE FROM submissions WHERE owner_id=?').bind(id),
      env.DB.prepare('DELETE FROM gps_records WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM ad_campaigns WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM login_events WHERE user_id=?').bind(id),
      env.DB.prepare('DELETE FROM conversations WHERE user_a=? OR user_b=?').bind(id, id),
      env.DB.prepare('DELETE FROM messages WHERE sender_id=?').bind(id),
      env.DB.prepare('DELETE FROM reports WHERE reporter_id=? OR (target_type=\'user\' AND target_id=?)').bind(id, id),
    ]);
    return json({ ok: true, message: 'Your account has been closed.' });
  }
  if (path === '/api/v1/users/me/device-token' && req.method === 'POST') {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    const token = clean(b.token, 4096);
    const platform = clean(b.platform || 'android', 20).toLowerCase();
    if (!token || !['android', 'ios', 'web'].includes(platform))
      throw new HttpError(400, 'bad_input', 'A device token and platform are required.');
    await env.DB.prepare(`INSERT INTO device_tokens (user_id,token,platform,created_at,last_seen_at)
      VALUES (?,?,?,?,?) ON CONFLICT(user_id,token) DO UPDATE SET platform=excluded.platform, last_seen_at=excluded.last_seen_at`)
      .bind(u.id, token, platform, nowIso(), nowIso()).run();
    return json({ ok: true });
  }
  if (path === '/api/v1/users/me/device-token' && req.method === 'DELETE') {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    const token = clean(b.token, 4096);
    if (token) await env.DB.prepare('DELETE FROM device_tokens WHERE user_id=? AND token=?').bind(u.id, token).run();
    else await env.DB.prepare('DELETE FROM device_tokens WHERE user_id=?').bind(u.id).run();
    return json({ ok: true });
  }
  return null;
}

/* ---------------- feed ---------------- */
async function discoveryFeed(req, env, url) {
  const limit = clamp(parseInt(url.searchParams.get('limit') || '12', 10) || 12, 1, 30);
  const offset = clamp(parseInt(url.searchParams.get('offset') || '0', 10) || 0, 0, 100000);
  const seed = clean(url.searchParams.get('seed'), 80) || 'discover';
  const [events, programs, projects, opportunities, shows, videos] = await Promise.all([
    env.DB.prepare(`SELECT id,title,description,starts_at,location,cover_url,event_type,sdg,
      activity_verified_at FROM events WHERE status='PUBLISHED' ORDER BY starts_at DESC LIMIT 60`).all(),
    env.DB.prepare(`SELECT id,title,description,organization,category,cover_url,verification_status,
      sdg FROM programs WHERE status='ACTIVE' ORDER BY created_at DESC LIMIT 60`).all(),
    env.DB.prepare(`SELECT id,title,description,category,cover,verification_status,sdg
      FROM projects ORDER BY created_at DESC LIMIT 60`).all(),
    env.DB.prepare(`SELECT id,title,description,type,location,cover_url,is_remote,deadline,sdg
      FROM opportunities WHERE status='OPEN' ORDER BY created_at DESC LIMIT 60`).all(),
    env.DB.prepare(`SELECT id,title,description,category,cover_url,verification_status,sdg
      FROM podcast_shows WHERE status='ACTIVE' ORDER BY created_at DESC LIMIT 40`).all(),
    env.DB.prepare(`SELECT id,title,description,category,cover_url,verification_status,sdg
      FROM vod_videos WHERE status='PUBLISHED' ORDER BY created_at DESC LIMIT 40`).all(),
  ]);
  const items = [];
  for (const e of (events.results || [])) items.push({
    entity_type: 'EVENT', entity_id: String(e.id), title: e.title || 'Event',
    subtitle: [e.event_type, e.location, e.starts_at ? String(e.starts_at).slice(0, 10) : null]
      .filter(Boolean).join(' · '),
    image_url: e.cover_url || null, impact_percent: e.activity_verified_at ? 88 : 62,
    verified: !!e.activity_verified_at, created_at: e.starts_at, meta: { sdg: e.sdg },
  });
  for (const p of (programs.results || [])) items.push({
    entity_type: 'PROGRAM', entity_id: String(p.id), title: p.title || 'Programme',
    subtitle: [p.organization, p.category].filter(Boolean).join(' · '),
    image_url: p.cover_url || null,
    impact_percent: p.verification_status === 'APPROVED' ? 80 : 50,
    verified: p.verification_status === 'APPROVED', created_at: null, meta: { sdg: p.sdg },
  });
  for (const p of (projects.results || [])) items.push({
    entity_type: 'PROJECT', entity_id: String(p.id), title: p.title || 'Project',
    subtitle: p.category || 'Project', image_url: p.cover || null,
    impact_percent: p.verification_status === 'APPROVED' ? 76 : 46,
    verified: p.verification_status === 'APPROVED', created_at: null, meta: { sdg: p.sdg },
  });
  for (const o of (opportunities.results || [])) items.push({
    entity_type: 'OPPORTUNITY', entity_id: String(o.id), title: o.title || 'Opportunity',
    subtitle: [o.type, o.is_remote ? 'Remote' : o.location, o.deadline ? String(o.deadline).slice(0, 10) : null]
      .filter(Boolean).join(' · '),
    image_url: o.cover_url || null, impact_percent: 60, verified: false,
    created_at: null, meta: { sdg: o.sdg },
  });
  for (const s of (shows.results || [])) items.push({
    entity_type: 'PODCAST', entity_id: String(s.id), title: s.title || 'Podcast',
    subtitle: s.category || 'Podcast', image_url: s.cover_url || null,
    impact_percent: s.verification_status === 'APPROVED' ? 72 : 44,
    verified: s.verification_status === 'APPROVED', created_at: null, meta: { sdg: s.sdg },
  });
  for (const v of (videos.results || [])) items.push({
    entity_type: 'VOD', entity_id: String(v.id), title: v.title || 'Video',
    subtitle: v.category || 'VOD', image_url: v.cover_url || null,
    impact_percent: v.verification_status === 'APPROVED' ? 68 : 42,
    verified: v.verification_status === 'APPROVED', created_at: null, meta: { sdg: v.sdg },
  });
  const hash = (value) => {
    let h = 2166136261;
    for (let i = 0; i < value.length; i++) {
      h ^= value.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  };
  items.sort((a, b) => hash(`${seed}:${a.entity_type}:${a.entity_id}`) -
    hash(`${seed}:${b.entity_type}:${b.entity_id}`));
  const buckets = new Map();
  for (const item of items) {
    if (!buckets.has(item.entity_type)) buckets.set(item.entity_type, []);
    buckets.get(item.entity_type).push(item);
  }
  const mixed = [];
  let added = true;
  while (added) {
    added = false;
    for (const type of ['EVENT', 'PROGRAM', 'PROJECT', 'OPPORTUNITY', 'PODCAST', 'VOD']) {
      const bucket = buckets.get(type);
      if (bucket && bucket.length) {
        mixed.push(bucket.shift());
        added = true;
      }
    }
  }
  const slice = mixed.slice(offset, offset + limit);
  return json({
    ok: true, items: slice, has_more: offset + limit < mixed.length,
    next_offset: offset + slice.length, total: mixed.length,
  });
}
async function listPosts(req, env, url) {
  const viewer = await currentUser(req, env);
  const limit = clamp(parseInt(url.searchParams.get('limit') || '40', 10) || 40, 1, 60);
  const offset = Math.max(0, parseInt(url.searchParams.get('offset') || '0', 10) || 0);
  const mode = (url.searchParams.get('mode') || 'for_you').toLowerCase();
  const authorId = num(url.searchParams.get('author_id'));
  const kind = clean(url.searchParams.get('kind'), 40);
  const sdg = num(url.searchParams.get('sdg'));
  const seed = clean(url.searchParams.get('seed'), 80);

  const where = ['p.hidden=0'];
  const args = [];
  if (authorId) { where.push('p.author_id=?'); args.push(authorId); }
  if (kind) { where.push('p.kind=?'); args.push(kind); }
  if (sdg) { where.push('p.sdg=?'); args.push(sdg); }
  if (viewer) {
    where.push(`NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
      (b.blocker_id=? AND b.blocked_id=p.author_id) OR (b.blocker_id=p.author_id AND b.blocked_id=?))`);
    args.push(viewer.id, viewer.id);
  }
  const rows = (await env.DB.prepare(`${POST_SELECT} WHERE ${where.join(' AND ')} ORDER BY p.created_at DESC LIMIT 400`)
    .bind(...args).all()).results || [];

  const liked = new Set();
  const bookmarked = new Set();
  const following = new Set();
  const seen = new Set();
  if (viewer) {
    const [likes, marks, follows, views] = await Promise.all([
      env.DB.prepare('SELECT post_id FROM post_likes WHERE user_id=?').bind(viewer.id).all(),
      env.DB.prepare('SELECT post_id FROM post_bookmarks WHERE user_id=?').bind(viewer.id).all(),
      env.DB.prepare('SELECT followee_id FROM follows WHERE follower_id=?').bind(viewer.id).all(),
      env.DB.prepare('SELECT post_id FROM post_views WHERE user_id=? AND seen_at>?')
        .bind(viewer.id, new Date(Date.now() - 2 * 86400000).toISOString()).all(),
    ]);
    for (const x of likes.results || []) liked.add(Number(x.post_id));
    for (const x of marks.results || []) bookmarked.add(Number(x.post_id));
    for (const x of follows.results || []) following.add(Number(x.followee_id));
    for (const x of views.results || []) seen.add(Number(x.post_id));
    viewer.__interests = new Set((viewer.interest || '').split(/[,\s]+/).map((s) => parseInt(s, 10)).filter((n) => n >= 1 && n <= 17));
  }

  let list = rows;
  if (mode === 'following') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Sign in to see people you follow.');
    list = rows.filter((r) => following.has(Number(r.author_id)) || Number(r.author_id) === viewer.id);
  }

  if (offset >= list.length) return json([]);
  const ranked = rankCandidates(list, { viewer, liked, following, seen, mode, offset, limit, seed });
  const out = ranked.map((item) => postJson(item.row,
    liked.has(Number(item.row.id)),
    { score: item.score, reason: item.reason, reasons: item.reasons },
    bookmarked.has(Number(item.row.id)),
    following.has(Number(item.row.author_id))));

  // Two leading comments per post so the feed can show a conversation preview
  // without opening the post.
  if (out.length) {
    const marks = out.map(() => '?').join(',');
    const comments = (await env.DB.prepare(`SELECT c.id,c.post_id,c.text,c.like_count,
      c.created_at,u.id author_id,u.name author_name,u.picture author_picture
      FROM post_comments c JOIN users u ON u.id=c.user_id
      WHERE c.hidden=0 AND c.post_id IN (${marks})
      ORDER BY c.like_count DESC, c.created_at DESC`)
      .bind(...out.map((p) => Number(p.id))).all()).results || [];
    const byPost = new Map();
    for (const c of comments) {
      const key = Number(c.post_id);
      const list = byPost.get(key) || [];
      if (list.length < 2) {
        list.push({
          id: String(c.id),
          text: c.text,
          like_count: Number(c.like_count || 0),
          created_at: c.created_at,
          author_id: String(c.author_id),
          author_name: c.author_name || 'Member',
          author_picture: c.author_picture || null,
        });
      }
      byPost.set(key, list);
    }
    for (const post of out) {
      post.top_comments = byPost.get(Number(post.id)) || [];
    }
  }

  if (viewer && out.length) {
    const at = nowIso();
    const stmts = out.map((p) => env.DB.prepare('INSERT OR IGNORE INTO post_views (user_id,post_id,seen_at) VALUES (?,?,?)')
      .bind(viewer.id, Number(p.id), at));
    if (ctxSafe(env)) await env.DB.batch(stmts);
  }
  return json(out);
}
const ctxSafe = () => true;

async function liveInteractions(req, env, url) {
  const viewer = await requireUser(req, env);
  const ids = [...new Set(String(url.searchParams.get('post_ids') || '')
    .split(',').map((x) => Number(x)).filter((n) => Number.isInteger(n) && n > 0))].slice(0, 60);
  const [messageRow, notificationRow] = await Promise.all([
    env.DB.prepare(`SELECT COUNT(*) c FROM messages m JOIN conversations c ON c.id=m.conversation_id
      WHERE (c.user_a=? OR c.user_b=?) AND m.sender_id<>? AND m.read_at IS NULL`)
      .bind(viewer.id, viewer.id, viewer.id).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM notifications WHERE user_id=? AND read=0')
      .bind(viewer.id).first(),
  ]);
  const meta = {
    unread_messages: Number(messageRow?.c || 0),
    unread_notifications: Number(notificationRow?.c || 0),
    server_time: nowIso(),
  };
  if (!ids.length) return json({ posts: [], ...meta });

  const placeholders = ids.map(() => '?').join(',');
  const rows = (await env.DB.prepare(`SELECT p.id,p.like_count,p.comment_count,p.share_count,
      p.impact_value,p.confidence_score,p.updated_at,
      (SELECT MAX(c.id) FROM post_comments c WHERE c.post_id=p.id AND c.hidden=0) latest_comment_id
    FROM posts p WHERE p.hidden=0 AND p.id IN (${placeholders})`).bind(...ids).all()).results || [];
  const [likeRows, bookmarkRows] = await Promise.all([
    env.DB.prepare(`SELECT post_id FROM post_likes WHERE user_id=? AND post_id IN (${placeholders})`)
      .bind(viewer.id, ...ids).all(),
    env.DB.prepare(`SELECT post_id FROM post_bookmarks WHERE user_id=? AND post_id IN (${placeholders})`)
      .bind(viewer.id, ...ids).all(),
  ]);
  const liked = new Set((likeRows.results || []).map((x) => Number(x.post_id)));
  const bookmarked = new Set((bookmarkRows.results || []).map((x) => Number(x.post_id)));
  return json({
    posts: rows.map((r) => ({
      id: String(r.id),
      likes: Number(r.like_count || 0),
      comments: Number(r.comment_count || 0),
      shares: Number(r.share_count || 0),
      impact_value: r.impact_value == null ? null : Number(r.impact_value),
      confidence_score: r.confidence_score == null ? null : Number(r.confidence_score),
      latest_comment_id: r.latest_comment_id == null ? null : String(r.latest_comment_id),
      liked_by_me: liked.has(Number(r.id)),
      bookmarked_by_me: bookmarked.has(Number(r.id)),
    })),
    ...meta,
  });
}

async function gpsRecords(req, env) {
  const viewer = await requireUser(req, env);
  if (req.method === 'GET') {
    const rows = (await env.DB.prepare(`SELECT * FROM gps_records WHERE user_id=?
      ORDER BY created_at DESC LIMIT 100`).bind(viewer.id).all()).results || [];
    return json(rows.map(gpsJson));
  }
  const b = await readJson(req);
  const latitude = Number(b.latitude ?? b.lat);
  const longitude = Number(b.longitude ?? b.lng);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpError(400, 'invalid_coordinates', 'Send a valid latitude and longitude.');
  }
  const numeric = (v, min, max) => {
    const n = Number(v);
    return Number.isFinite(n) && n >= min && n <= max ? n : null;
  };
  const captured = b.captured_at ? new Date(String(b.captured_at)) : new Date();
  const capturedAt = Number.isNaN(captured.getTime()) ? nowIso() : captured.toISOString();
  const r = await env.DB.prepare(`INSERT INTO gps_records
    (user_id,latitude,longitude,accuracy,altitude,speed,heading,captured_at,created_at)
    VALUES (?,?,?,?,?,?,?,?,?)`).bind(viewer.id, latitude, longitude,
    numeric(b.accuracy, 0, 100000), numeric(b.altitude, -1000, 100000),
    numeric(b.speed, 0, 10000), numeric(b.heading, 0, 360), capturedAt, nowIso()).run();
  const row = await env.DB.prepare('SELECT * FROM gps_records WHERE id=?').bind(r.meta.last_row_id).first();
  return json(gpsJson(row), 201);
}

function gpsJson(r) {
  return {
    id: String(r.id), latitude: Number(r.latitude), longitude: Number(r.longitude),
    accuracy: r.accuracy == null ? null : Number(r.accuracy),
    altitude: r.altitude == null ? null : Number(r.altitude),
    speed: r.speed == null ? null : Number(r.speed),
    heading: r.heading == null ? null : Number(r.heading),
    captured_at: r.captured_at, created_at: r.created_at,
  };
}

const AI_TEXT_MARKERS = [
  'in conclusion', 'furthermore', 'moreover', 'it is important to note', 'delve into',
  'tapestry', 'landscape of', 'underscores', 'pivotal', 'seamless', 'robust framework',
  'leverage', 'foster', 'navigate the', 'realm of', 'testament to', 'meticulous',
  'intricate', 'showcasing', 'underscoring', 'notably', 'overall,', 'in summary',
  '?? ??????', '???????? ??? ???', '?? ????? ??????', '???? ???????', '???? ?????',
  '????', '????', '???? ????', '??? ?????', '?????', '????? ?????', '?? ???????',
];
const NSFW_TEXT_MARKERS = [
  'porn', 'pornography', 'nude', 'nudity', 'explicit sex', 'onlyfans', 'xxx',
  'sexual content', 'adult video', 'nsfw', '?????', '????', '???', '??? ????',
  '????? ????', '????? ?????',
];
const AI_MEDIA_MARKERS = [
  'midjourney', 'dall-e', 'dalle', 'stable-diffusion', 'stable diffusion', 'sdxl',
  'comfyui', 'automatic1111', 'invokeai', 'adobe-firefly', 'runway', 'sora',
  'nano-banana', 'ai-generated', 'generated-by-ai', 'c2pa', 'synthid',
  'content-credentials', 'thispersondoesnotexist',
];
const NSFW_HOSTS = ['pornhub.com', 'xvideos.com', 'xnxx.com', 'onlyfans.com',
  'chaturbate.com', 'xhamster.com', 'redtube.com', 'youporn.com', 'stripchat.com',
  'brazzers.com'];

function safeRemoteUrl(raw) {
  try {
    const url = new URL(String(raw || ''));
    if (!['http:', 'https:'].includes(url.protocol)) return null;
    const host = url.hostname.toLowerCase();
    if (host === 'localhost' || host.endsWith('.local') || host === '::1' ||
        /^127\./.test(host) || /^10\./.test(host) || /^192\.168\./.test(host) ||
        /^169\.254\./.test(host) || /^172\.(1[6-9]|2\d|3[01])\./.test(host)) {
      return null;
    }
    return url;
  } catch {
    return null;
  }
}

function textAiSignals(text) {
  const value = String(text || '').toLowerCase();
  const words = value.split(/\s+/).filter(Boolean);
  if (!words.length) return { score: 0, signals: [] };
  const sentences = value.split(/[.!?]+/).map((s) => s.trim()).filter(Boolean);
  const lengths = sentences.map((s) => s.split(/\s+/).length);
  const mean = lengths.reduce((a, b) => a + b, 0) / Math.max(1, lengths.length);
  const variance = lengths.reduce((a, b) => a + Math.pow(b - mean, 2), 0) /
    Math.max(1, lengths.length);
  const hits = AI_TEXT_MARKERS.filter((m) => value.includes(m));
  const formalPunctuation = (value.match(/[;:��]/g) || []).length;
  const perfectEnding = sentences.length >= 3 &&
    sentences.filter((s) => /[.!?]$/.test(s)).length / sentences.length > 0.9;
  let score = 0.05;
  score += Math.min(0.48, hits.length * 0.09);
  score += variance < 16 && words.length > 80 ? 0.14 : 0;
  score += perfectEnding ? 0.08 : 0;
  score += Math.min(0.10, formalPunctuation / Math.max(1, sentences.length) * 0.08);
  score += words.length > 120 && hits.length >= 2 ? 0.08 : 0;
  const signals = [];
  if (hits.length) signals.push({ type: 'formulaic_language', detail: hits.slice(0, 6), weight: Math.min(0.48, hits.length * 0.09) });
  if (variance < 16 && words.length > 80) signals.push({ type: 'low_sentence_burstiness', detail: 'Uniform sentence length', weight: 0.14 });
  if (perfectEnding) signals.push({ type: 'perfect_punctuation', detail: 'Every sentence cleanly terminated', weight: 0.08 });
  return { score: Math.min(1, score), signals };
}

function textNsfwSignals(text) {
  const value = String(text || '').toLowerCase();
  const hits = NSFW_TEXT_MARKERS.filter((m) => value.includes(m));
  if (!hits.length) return { score: 0, signals: [] };
  const healthContext = /sex education|sexual health/.test(value);
  const score = healthContext ? Math.min(0.45, 0.18 + hits.length * 0.06)
    : Math.min(0.99, 0.45 + hits.length * 0.18);
  return { score, signals: hits.map((h) => ({ type: 'nsfw_text', detail: h })) };
}

function mediaUrlSignals(url) {
  const lower = String(url || '').toLowerCase();
  const host = (() => { try { return new URL(lower).hostname; } catch { return ''; } })();
  const ai = AI_MEDIA_MARKERS.filter((m) => lower.includes(m));
  const nsfw = NSFW_HOSTS.filter((h) => host === h || host.endsWith('.' + h));
  const reasons = [];
  if (ai.length) reasons.push({ type: 'generator_marker', detail: ai });
  if (nsfw.length) reasons.push({ type: 'adult_host', detail: nsfw });
  return {
    aiScore: ai.length ? Math.min(0.98, 0.72 + ai.length * 0.10) : 0,
    nsfwScore: nsfw.length ? 0.98 : 0,
    signals: reasons,
  };
}

async function fetchMediaMarkers(url) {
  const safe = safeRemoteUrl(url);
  if (!safe) return { aiScore: 0, nsfwScore: 0, signals: [] };
  try {
    const res = await fetch(safe.toString(), { headers: { Range: 'bytes=0-131071' } });
    if (!res.ok) return { aiScore: 0, nsfwScore: 0, signals: [] };
    const buffer = await res.arrayBuffer();
    const text = new TextDecoder().decode(buffer.slice(0, 131072)).toLowerCase();
    const ai = AI_MEDIA_MARKERS.filter((m) => text.includes(m));
    const nsfw = NSFW_TEXT_MARKERS.filter((m) => text.includes(m));
    return {
      aiScore: ai.length ? Math.min(0.98, 0.7 + ai.length * 0.08) : 0,
      nsfwScore: nsfw.length ? Math.min(0.9, 0.4 + nsfw.length * 0.15) : 0,
      signals: [
        ...ai.map((x) => ({ type: 'embedded_generator_marker', detail: x })),
        ...nsfw.map((x) => ({ type: 'embedded_nsfw_marker', detail: x })),
      ],
    };
  } catch (_) {
    return { aiScore: 0, nsfwScore: 0, signals: [] };
  }
}

async function cloudAiScan(env, text, imageUrl) {
  if (!env.AI) return null;
  const out = { aiScore: 0, nsfwScore: 0, signals: [], provider: 'cloudflare-workers-ai' };
  try {
    const guard = await env.AI.run('@cf/meta/llama-guard-3-8b', {
      messages: [{ role: 'user', content: String(text || '').slice(0, 6000) }],
    });
    const guardText = JSON.stringify(guard || {}).toLowerCase();
    if (guardText.includes('unsafe')) {
      out.nsfwScore = Math.max(out.nsfwScore, 0.96);
      out.signals.push({ type: 'llama_guard_unsafe', detail: guardText.slice(0, 200) });
    }
  } catch (_) {}
  if (imageUrl) {
    try {
      const safe = safeRemoteUrl(imageUrl);
      if (safe) {
        const res = await fetch(safe.toString());
        if (res.ok) {
          const bytes = new Uint8Array((await res.arrayBuffer()).slice(0, 1800000));
          const vision = await env.AI.run('@cf/meta/llama-3.2-11b-vision-instruct', {
            prompt: 'Analyze this image for two risks. Reply ONLY with JSON: {"nsfw":0..1,"ai_generated":0..1,"reason":"short"}. nsfw means explicit nudity or sexual content. ai_generated means synthetic/deepfake artifacts.',
            image: [...bytes],
          });
          const raw = JSON.stringify(vision || {});
          const match = raw.match(/\{[^}]+\}/);
          if (match) {
            const parsed = JSON.parse(match[0]);
            out.nsfwScore = Math.max(out.nsfwScore, clamp(Number(parsed.nsfw) || 0, 0, 1));
            out.aiScore = Math.max(out.aiScore, clamp(Number(parsed.ai_generated) || 0, 0, 1));
            if (parsed.reason) out.signals.push({ type: 'vision_classification', detail: String(parsed.reason).slice(0, 180) });
          }
        }
      }
    } catch (_) {}
  }
  return out;
}

async function deepfakeScan(env, { text = '', urls = [], title = '' } = {}) {
  const aiText = textAiSignals(`${title}\n${text}`);
  const nsfwText = textNsfwSignals(`${title}\n${text}`);
  let aiScore = aiText.score;
  let nsfwScore = nsfwText.score;
  const signals = [...aiText.signals, ...nsfwText.signals];
  let provider = 'local-forensics-v1';
  for (const url of [...new Set(urls.filter(Boolean))].slice(0, 6)) {
    const marker = mediaUrlSignals(url);
    aiScore = Math.max(aiScore, marker.aiScore);
    nsfwScore = Math.max(nsfwScore, marker.nsfwScore);
    signals.push(...marker.signals);
    if (marker.aiScore || marker.nsfwScore) provider = 'local-media-forensics-v1';
  }
  const firstImage = urls.find((u) => /\.(png|jpe?g|webp|gif|avif)(\?|$)/i.test(String(u || '')));
  if (firstImage) {
    const remote = await fetchMediaMarkers(firstImage);
    aiScore = Math.max(aiScore, remote.aiScore);
    nsfwScore = Math.max(nsfwScore, remote.nsfwScore);
    signals.push(...remote.signals);
  }
  const cloud = await cloudAiScan(env, `${title}\n${text}`, firstImage);
  if (cloud) {
    aiScore = Math.max(aiScore, cloud.aiScore);
    nsfwScore = Math.max(nsfwScore, cloud.nsfwScore);
    signals.push(...cloud.signals);
    provider = cloud.provider;
  }
  const aiVerdict = aiScore >= 0.8 ? 'LIKELY_AI' : aiScore >= 0.55 ? 'SUSPICIOUS' : 'LIKELY_AUTHENTIC';
  const nsfwVerdict = nsfwScore >= 0.8 ? 'BLOCKED' : nsfwScore >= 0.5 ? 'REVIEW' : 'SAFE';
  return {
    score: Number(aiScore.toFixed(3)), verdict: aiVerdict,
    nsfw_score: Number(nsfwScore.toFixed(3)), nsfw_verdict: nsfwVerdict,
    signals: signals.slice(0, 20), provider,
    scanned_at: nowIso(),
  };
}
async function createPost(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const text = clean(b.text, 2000);
  if (text.length < 2) throw new HttpError(400, 'empty_post', 'Write something before posting.');
  const moderation = moderateText(text);
  if (moderation.status === 'BLOCKED') {
    throw new HttpError(400, 'moderation_blocked', moderation.reason);
  }
  const kind = clean(b.kind || b.type, 30).toUpperCase() || 'UPDATE';
  const sdg = num(b.sdg);
  const media = normalizeMediaInput(b);
  const files = normalizeFilesInput(b);
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
  if (kind === 'EVIDENCE' && !link && !media.length && !files.length) {
    throw new HttpError(400, 'evidence_required',
      'Add a proof link, image, file or video to publish evidence.');
  }
  const at = nowIso();
  const impactMetrics = normalizeImpactMetrics(b.impact_metrics);
  if (impactMetrics && (latitude == null || longitude == null)) {
    throw new HttpError(400, 'gps_required',
      'GPS is required for structured impact so the claimed place can be checked.');
  }
  const locationClaim = clean(b.location_claim, 200);
  const isa = impactMetrics ? computeIsaScore({
    created_at: at, latitude, longitude, location_claim: locationClaim,
    author_verified: !!u.email_verified,
    like_count: 0, comment_count: 0, share_count: 0,
  }, impactMetrics, { n: 0, avg: 0 }, await verifiedActionCount(env, u.id)) : null;
  const finalImpactValue = isa ? isa.impact_value : impactValue;
  const impactLabel = isa ? isa.impact_label
    : clean(b.impact_label, 80) ||
      (impactValue == null ? 'Awaiting ratings' : impactLabelFor(impactValue, 0));
  const confidenceScore = isa ? isa.confidence_score : 0;
  const confidenceLabel = isa ? isa.confidence_label : 'Low confidence';
  const deepfake = await deepfakeScan(env, {
    text, title: text.slice(0, 120),
    urls: [...media.map((m) => m.url), link, legacyMedia].filter(Boolean),
  });
  if (deepfake.nsfw_verdict === 'BLOCKED') {
    throw new HttpError(400, 'nsfw_blocked',
      'This content contains explicit material and cannot be published.');
  }
  const moderationStatus = (moderation.status === 'REVIEW' ||
    deepfake.verdict !== 'LIKELY_AUTHENTIC' || deepfake.nsfw_verdict === 'REVIEW')
    ? 'REVIEW' : 'APPROVED';
  const confidenceFactors = isa ? {
    domains: isa.domains, metric_detail: isa.metric_detail, coverage: isa.coverage,
    geo_adjusted: isa.geo_adjusted, actor_factor: isa.actor_factor,
    consistency: isa.consistency_factor, ratings: 0,
    author_verified: !!u.email_verified, confidence: isa.confidence_score,
    method: isa.method,
  } : { ratings: 0, method: 'weighted ratings + engagement + author trust' };
  const embedding = JSON.stringify(embeddingFor(text));
  const r = await env.DB.prepare(`INSERT INTO posts (author_id,text,kind,sdg,impact_value,impact_label,
      isa_score,impact_domains_json,impact_metrics_json,geo_adjusted,actor_factor,consistency_factor,
      location_claim,deepfake_score,deepfake_verdict,deepfake_signals_json,confidence_score,confidence_label,confidence_factors,
      media_url,link_url,media_json,media_type,video_hls_url,video_poster_url,video_duration_seconds,
      latitude,longitude,files_json,source,
      embedding_json,embedding_status,moderation_status,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'USER',?,'local-hash',?,?,?)`)
    .bind(u.id, text, kind, sdg && sdg >= 1 && sdg <= 17 ? sdg : null,
      finalImpactValue, impactLabel, isa ? isa.isa_score : (finalImpactValue == null ? null : Math.round(finalImpactValue * 100)),
      isa ? JSON.stringify(isa.domains) : null,
      impactMetrics ? JSON.stringify(impactMetrics) : null,
      isa?.geo_adjusted || 0, isa?.actor_factor || null, isa?.consistency_factor || null,
      locationClaim || null, deepfake.score, deepfake.verdict,
      JSON.stringify({ nsfw_score: deepfake.nsfw_score,
        nsfw_verdict: deepfake.nsfw_verdict, signals: deepfake.signals,
        provider: deepfake.provider, scanned_at: deepfake.scanned_at }),
      confidenceScore, confidenceLabel, JSON.stringify(confidenceFactors),
      legacyMedia, link, media.length ? JSON.stringify(media) : null, mediaType,
      videoHls, videoPoster, videoDuration, latitude, longitude,
      files.length ? JSON.stringify(files) : null, embedding,
      moderationStatus, at, at).run();
  const postId = r.meta.last_row_id;
  if (job) {
    await env.DB.prepare('UPDATE video_jobs SET post_id=?, updated_at=? WHERE id=?').bind(postId, at, job.id).run();
  }
  if (moderation.status === 'REVIEW') {
    await adminAlert(env, {
      type: 'moderation', severity: 'normal',
      title: 'A post was flagged for review',
      body: text.slice(0, 200),
      link: 'admin:moderation', entityType: 'post', entityId: String(postId),
      actorId: u.id, dedupeKey: `post_review:${postId}`,
    }).catch(() => {});
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
  }
  await recomputeImpact(env, id);
  const row = await getPostRow(env, id);
  return json({ ok: true, liked: !has, likes: row.like_count });
}

async function addComment(req, env, id) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const text = clean(b.text, 800);
  if (!text) throw new HttpError(400, 'empty_comment', 'Write a comment first.');
  assertModerated(text);
  const post = await env.DB.prepare('SELECT id, author_id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  let parentId = num(b.parent_id || b.parentId);
  let parent = null;
  if (parentId) {
    parent = await env.DB.prepare('SELECT id,user_id,post_id FROM post_comments WHERE id=? AND post_id=? AND hidden=0')
      .bind(parentId, id).first();
    if (!parent) throw new HttpError(404, 'comment_not_found', 'That comment no longer exists.');
    parentId = Number(parent.id);
  } else {
    parentId = null;
  }
  const at = nowIso();
  const r = await env.DB.prepare('INSERT INTO post_comments (post_id,user_id,parent_id,text,created_at) VALUES (?,?,?,?,?)')
    .bind(id, u.id, parentId, text, at).run();
  await env.DB.prepare('UPDATE posts SET comment_count=comment_count+1 WHERE id=?').bind(id).run();
  await notify(env, post.author_id, 'comment', `${u.name || 'Someone'} commented on your update`, text, u.id, id);
  if (parent && Number(parent.user_id) !== Number(post.author_id))
    await notify(env, parent.user_id, 'reply', `${u.name || 'Someone'} replied to your comment`, text, u.id, id);
  await recomputeImpact(env, id);
  return json({ id: String(r.meta.last_row_id), text, parent_id: parentId == null ? null : String(parentId),
    author_id: String(u.id), author_name: u.name, author_handle: u.handle || handleFor(u.name, u.id),
    like_count: 0, liked_by_me: false, created_at: at }, 201);
}

async function listComments(req, env, id) {
  const viewer = await currentUser(req, env);
  const rows = (await env.DB.prepare(`SELECT c.*, u.name author_name, u.handle author_handle, u.picture author_picture,
      u.email_verified author_verified
    FROM post_comments c JOIN users u ON u.id=c.user_id WHERE c.post_id=? AND c.hidden=0
    ORDER BY c.created_at ASC LIMIT 300`).bind(id).all()).results || [];
  const liked = new Set();
  if (viewer && rows.length) {
    const marks = (await env.DB.prepare(`SELECT comment_id FROM post_comment_likes WHERE user_id=? AND comment_id IN (${rows.map(() => '?').join(',')})`)
      .bind(viewer.id, ...rows.map((c) => c.id)).all()).results || [];
    for (const m of marks) liked.add(Number(m.comment_id));
  }
  return json(rows.map((c) => ({ id: String(c.id), text: c.text, parent_id: c.parent_id == null ? null : String(c.parent_id),
    author_id: String(c.user_id), author_name: c.author_name, author_handle: c.author_handle,
    author_picture: c.author_picture || null, author_verified: !!c.author_verified,
    like_count: Number(c.like_count || 0), liked_by_me: liked.has(Number(c.id)), created_at: c.created_at })));
}

async function toggleCommentLike(req, env, id) {
  const u = await requireUser(req, env);
  const comment = await env.DB.prepare('SELECT * FROM post_comments WHERE id=? AND hidden=0').bind(id).first();
  if (!comment) throw new HttpError(404, 'comment_not_found', 'That comment no longer exists.');
  const has = await env.DB.prepare('SELECT 1 x FROM post_comment_likes WHERE comment_id=? AND user_id=?').bind(id, u.id).first();
  if (has) {
    await env.DB.prepare('DELETE FROM post_comment_likes WHERE comment_id=? AND user_id=?').bind(id, u.id).run();
    await env.DB.prepare('UPDATE post_comments SET like_count=MAX(0,like_count-1) WHERE id=?').bind(id).run();
  } else {
    await env.DB.prepare('INSERT INTO post_comment_likes (comment_id,user_id,created_at) VALUES (?,?,?)')
      .bind(id, u.id, nowIso()).run();
    await env.DB.prepare('UPDATE post_comments SET like_count=like_count+1 WHERE id=?').bind(id).run();
    await notify(env, comment.user_id, 'comment_like', `${u.name || 'Someone'} liked your comment`, comment.text, u.id, comment.post_id);
  }
  const row = await env.DB.prepare('SELECT like_count FROM post_comments WHERE id=?').bind(id).first();
  return json({ ok: true, liked: !has, likes: Number(row.like_count || 0) });
}

async function deleteComment(req, env, id) {
  const u = await requireUser(req, env);
  const comment = await env.DB.prepare('SELECT * FROM post_comments WHERE id=? AND hidden=0').bind(id).first();
  if (!comment) throw new HttpError(404, 'comment_not_found', 'That comment no longer exists.');
  const post = await env.DB.prepare('SELECT author_id FROM posts WHERE id=?')
    .bind(comment.post_id).first();
  const allowed = Number(comment.user_id) === Number(u.id) ||
    Number(post?.author_id) === Number(u.id) || isAdminUser(env, u) ||
    (await isEntityModerator(env, u, 'POST', comment.post_id, 'remove_comments'));
  if (!allowed)
    throw new HttpError(403, 'forbidden', 'Only the author, post owner or a moderator can remove this comment.');
  await env.DB.prepare('UPDATE post_comments SET hidden=1 WHERE id=?').bind(id).run();
  await env.DB.prepare('UPDATE post_comments SET hidden=1 WHERE parent_id=?').bind(id).run();
  await env.DB.prepare(`UPDATE posts SET comment_count=(SELECT COUNT(*) FROM post_comments
    WHERE post_id=? AND hidden=0) WHERE id=?`).bind(comment.post_id, comment.post_id).run();
  await recomputeImpact(env, comment.post_id);
  return json({ ok: true, deleted: true });
}

async function toggleBookmark(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT id FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const has = await env.DB.prepare('SELECT 1 x FROM post_bookmarks WHERE user_id=? AND post_id=?').bind(u.id, id).first();
  if (has) await env.DB.prepare('DELETE FROM post_bookmarks WHERE user_id=? AND post_id=?').bind(u.id, id).run();
  else await env.DB.prepare('INSERT INTO post_bookmarks (user_id,post_id,created_at) VALUES (?,?,?)')
    .bind(u.id, id, nowIso()).run();
  return json({ ok: true, bookmarked: !has });
}

async function listBookmarks(req, env, url) {
  const u = await requireUser(req, env);
  const limit = clamp(parseInt(url.searchParams.get('limit') || '40', 10) || 40, 1, 60);
  const offset = Math.max(0, parseInt(url.searchParams.get('offset') || '0', 10) || 0);
  const rows = (await env.DB.prepare(`SELECT p.*, u.name author_name, u.handle author_handle, u.picture author_picture,
      u.role author_role, u.email_verified author_verified, b.created_at bookmarked_at
    FROM post_bookmarks b JOIN posts p ON p.id=b.post_id JOIN users u ON u.id=p.author_id
    WHERE b.user_id=? AND p.hidden=0
      AND NOT EXISTS (SELECT 1 FROM user_blocks bl WHERE
        (bl.blocker_id=? AND bl.blocked_id=p.author_id) OR (bl.blocker_id=p.author_id AND bl.blocked_id=?))
    ORDER BY b.created_at DESC LIMIT ? OFFSET ?`)
    .bind(u.id, u.id, u.id, limit, offset).all()).results || [];
  const liked = new Set((await env.DB.prepare('SELECT post_id FROM post_likes WHERE user_id=?').bind(u.id).all()).results
    .map((x) => Number(x.post_id)));
  return json(rows.map((r) => postJson(r, liked.has(Number(r.id)), null, true)));
}

async function editPost(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT * FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  if (Number(post.author_id) !== Number(u.id) && !isAdminUser(env, u))
    throw new HttpError(403, 'forbidden', 'You can only edit your own post.');
  const b = await readJson(req);
  const text = clean(b.text, 2000);
  if (text.length < 2) throw new HttpError(400, 'empty_post', 'Write something before saving.');
  const moderation = moderateText(text);
  if (moderation.status === 'BLOCKED') {
    throw new HttpError(400, 'moderation_blocked', moderation.reason);
  }
  const kind = clean(b.kind || b.type, 30).toUpperCase() || post.kind;
  const sdg = b.sdg === undefined ? post.sdg : num(b.sdg);
  const impactLabel = b.impact_label !== undefined ? clean(b.impact_label, 80) : post.impact_label;
  const impactValue = b.impact_value === undefined ? post.impact_value
    : (Number.isFinite(Number(b.impact_value)) ? clamp(Number(b.impact_value), 0, 10) : post.impact_value);
  await env.DB.prepare(`UPDATE posts SET text=?, kind=?, sdg=?, impact_value=?, impact_label=?,
    moderation_status=?, edited_at=?, updated_at=? WHERE id=?`)
    .bind(text, kind, sdg && sdg >= 1 && sdg <= 17 ? sdg : null, impactValue,
      impactLabel, moderation.status === 'REVIEW' ? 'REVIEW' : (post.moderation_status || 'APPROVED'),
      nowIso(), nowIso(), id).run();
  if (moderation.status === 'REVIEW') {
    await adminAlert(env, {
      type: 'moderation', severity: 'normal',
      title: 'An edited post was flagged for review',
      body: text.slice(0, 200),
      link: 'admin:moderation', entityType: 'post', entityId: String(id),
      actorId: u.id, dedupeKey: `post_edit_review:${id}:${nowIso()}`,
    }).catch(() => {});
  }
  const row = await getPostRow(env, id);
  const liked = await env.DB.prepare('SELECT 1 x FROM post_likes WHERE post_id=? AND user_id=?').bind(id, u.id).first();
  const marked = await env.DB.prepare('SELECT 1 x FROM post_bookmarks WHERE post_id=? AND user_id=?').bind(id, u.id).first();
  return json(postJson(row, !!liked, null, !!marked));
}

async function deletePost(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT * FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  const allowed = Number(post.author_id) === Number(u.id) || isAdminUser(env, u) ||
    (await isEntityModerator(env, u, 'POST', id, 'remove_posts'));
  if (!allowed)
    throw new HttpError(403, 'forbidden', 'Only the author or a moderator can remove this post.');
  await env.DB.prepare('UPDATE posts SET hidden=1, updated_at=? WHERE id=?').bind(nowIso(), id).run();
  return json({ ok: true, deleted: true });
}

async function deleteEvent(req, env, id) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT id,author_id,title FROM events WHERE id=?').bind(id).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const allowed = Number(event.author_id) === Number(u.id) || isAdminUser(env, u) ||
    (await isEntityModerator(env, u, 'EVENT', id, 'remove_event'));
  if (!allowed) throw new HttpError(403, 'forbidden', 'Only the owner or a moderator can remove this event.');
  await env.DB.prepare("UPDATE events SET status='CANCELLED' WHERE id=?").bind(id).run();
  await notify(env, event.author_id, 'moderation',
    `Event removed: ${event.title}`, 'An owner or moderator removed this event from public discovery.',
    u.id, null, { link: `event:${id}`, dedupeKey: `event_removed:${id}` }).catch(() => {});
  return json({ ok: true, deleted: true });
}
const REPORT_REASONS = new Set(['spam', 'harassment', 'misinformation', 'violence', 'self_harm', 'other']);

async function reportTarget(req, env, targetType, targetId) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const reason = clean(b.reason, 40).toLowerCase();
  if (!REPORT_REASONS.has(reason)) throw new HttpError(400, 'invalid_reason', 'Choose a valid report reason.');
  const table = targetType === 'post' ? 'posts' : targetType === 'comment' ? 'post_comments' : 'users';
  const target = await env.DB.prepare(`SELECT id FROM ${table} WHERE id=?`).bind(targetId).first();
  if (!target) throw new HttpError(404, 'target_not_found', 'The reported content no longer exists.');
  const details = clean(b.details, 500) || null;
  const ins = await env.DB.prepare('INSERT INTO reports (reporter_id,target_type,target_id,reason,details,status,created_at) VALUES (?,?,?,?,?,?,?)')
    .bind(u.id, targetType, targetId, reason, details, 'OPEN', nowIso()).run();
  await adminAlert(env, {
    type: 'report',
    severity: 'high',
    title: `New ${targetType} report: ${reason}`,
    body: `${u.name || 'A member'} reported ${targetType} #${targetId}${details ? ` · ${details}` : ''}`,
    link: 'admin:reports',
    entityType: 'report',
    entityId: String(ins.meta.last_row_id),
    actorId: u.id,
    excludeId: u.id,
    dedupeKey: `report:${ins.meta.last_row_id}`,
  }).catch(() => {});
  return json({ ok: true, reported: true }, 201);
}

function embeddingFor(text) {
  const dim = 128;
  const vec = new Array(dim).fill(0);
  const tokens = String(text || '').toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter((t) => t.length > 1);
  const add = (token, weight) => {
    let h = 2166136261 >>> 0;
    for (let i = 0; i < token.length; i++) {
      h ^= token.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    vec[h % dim] += weight;
  };
  for (const token of tokens.slice(0, 400)) add(token, 1);
  for (let i = 0; i + 1 < tokens.length; i++) add(tokens[i] + '_' + tokens[i + 1], 0.5);
  let norm = 0;
  for (const v of vec) norm += v * v;
  norm = Math.sqrt(norm) || 1;
  return vec.map((v) => Math.round((v / norm) * 10000) / 10000);
}

function cosineSimilarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return 0;
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += Number(a[i] || 0) * Number(b[i] || 0);
  return dot;
}

const HATE_PATTERNS = [
  /\b(?:kill|exterminate|gas)\s+(?:all\s+)?(?:jews|muslims|christians|arabs|blacks|whites|asians)\b/i,
  /\b(?:death|murder)\s+to\s+(?:all\s+)?\w+/i,
  /\b(?:nigger|faggot|kike|chink|spic)\b/i,
  // Arabic: calls to kill or dehumanise a group.
  /(?:اقتلوا|اذبحوا|نحر(?:وا)?)\s+(?:كل\s+)?(?:ال)?(?:يهود|مسلمين|مسيحيين|عرب|أجانب|اجانب|لاجئين)/,
  /الموت\s+ل(?:كل\s+)?(?:ال)?(?:يهود|مسلمين|مسيحيين|عرب|أجانب|اجانب|لاجئين)/,
  /(?:يهود|مسلمين|مسيحيين|عرب|أجانب|اجانب)\s+(?:كلاب|قردة|خنازير|حشرات|جرذان)/,
];
const THREAT_PATTERNS = [
  /\b(?:i will|we will|going to)\s+(?:kill|shoot|bomb|stab)\b/i,
  // Arabic first-person and plural threats.
  /(?:سأقتل|ساقتل|سوف\s+أقتل|سوف\s+اقتل|سأذبح|ساذبح|سوف\s+أذبح|سوف\s+اذبح|سنقتل|سنذبح)/,
  /(?:سأفجر|سافجر|سوف\s+أفجر|سوف\s+افجر|سنفجر)\s+(?:ال)?(?:مبنى|مكان|مسجد|كنيسة|كنيسه|مدرسة|مدرسه|مستشفى)/,
];
const SPAM_PATTERNS = [
  /\b(?:free|cheap)\s+(?:crypto|bitcoin|followers|money)\b/i,
  /\b(?:click here|whatsapp|telegram)\s*\+?\d{7,}\b/i,
  /(?:اربح|ربح)\s+(?:فلوس|أموال|اموال|دولارات)\s+(?:سريع|بسرعة|بسرعه)/,
];

function moderationText(text) {
  return String(text || '')
    .normalize('NFKC')
    .replace(/[\u064B-\u0652\u0670\u0640]/g, '')
    .replace(/[إأآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .toLowerCase();
}

function moderateText(text) {
  const value = moderationText(text);
  if (HATE_PATTERNS.some((re) => re.test(value)) ||
      THREAT_PATTERNS.some((re) => re.test(value))) {
    return { status: 'BLOCKED', reason: 'Hate speech or threats are not allowed.' };
  }
  if (SPAM_PATTERNS.some((re) => re.test(value))) {
    return { status: 'REVIEW', reason: 'This looks like promotional spam.' };
  }
  return { status: 'APPROVED', reason: null };
}

function assertModerated(...values) {
  const text = values.filter(Boolean).join('\n');
  const moderation = moderateText(text);
  if (moderation.status === 'BLOCKED') {
    throw new HttpError(400, 'moderation_blocked', moderation.reason);
  }
  return moderation;
}

function leaderboardScope(scope) {
  const allowed = new Set(['institutions', 'governments', 'programs',
    'opportunities', 'events', 'courses', 'projects']);
  const value = String(scope || '').toLowerCase();
  if (!allowed.has(value)) {
    throw new HttpError(400, 'invalid_scope', 'Choose a valid leaderboard type.');
  }
  return value;
}

async function listLeaderboardOptions(req, env) {
  const viewer = await requireUser(req, env);
  const tables = [
    ['programs', 'title'], ['opportunities', 'title'], ['events', 'title'],
    ['courses', 'title'], ['projects', 'title'],
  ];
  const out = {};
  for (const [table, titleCol] of tables) {
    const rows = (await env.DB.prepare(
      `SELECT id,${titleCol} title FROM ${table} WHERE author_id=? ORDER BY created_at DESC LIMIT 100`)
      .bind(viewer.id).all()).results || [];
    out[table] = rows.map((r) => ({ id: String(r.id), name: r.title }));
  }
  if (isAdminUser(env, viewer)) {
    const orgRows = (await env.DB.prepare(`SELECT id,name FROM users
      WHERE role IN ('ORGANIZATION','INSTITUTION','ACADEMIC') ORDER BY name LIMIT 100`).all()).results || [];
    const govRows = (await env.DB.prepare(`SELECT id,name FROM users
      WHERE role='GOVERNMENT' ORDER BY name LIMIT 100`).all()).results || [];
    out.institutions = orgRows.map((r) => ({ id: String(r.id), name: r.name }));
    out.governments = govRows.map((r) => ({ id: String(r.id), name: r.name }));
  }
  return json({ ok: true, entities: out, scopes: Object.keys(out),
    admin_only: ['institutions', 'governments'] });
}

async function buildLeaderboardRankings(env, scope, metric, days, entityIds) {
  const since = new Date(Date.now() - days * 86400000).toISOString();
  if (scope === 'institutions' || scope === 'governments') {
    const roles = scope === 'institutions'
      ? ['ORGANIZATION', 'INSTITUTION', 'ACADEMIC'] : ['GOVERNMENT'];
    const marks = roles.map(() => '?').join(',');
    const rows = (await env.DB.prepare(`SELECT id,name,picture,role,
      COALESCE((SELECT SUM(impact_value) FROM posts WHERE author_id=users.id AND hidden=0),0) impact_score,
      COALESCE((SELECT COUNT(*) FROM posts WHERE author_id=users.id AND hidden=0),0) pms_score,
      (SELECT COUNT(*) FROM posts WHERE author_id=users.id AND hidden=0) posts
      FROM users WHERE role IN (${marks}) AND name<>'Deleted member'
      ORDER BY ${metric === 'posts' ? 'posts' : metric === 'pms' ? 'pms_score' : 'impact_score'} DESC,
        impact_score DESC LIMIT 10`)
      .bind(...roles).all()).results || [];
    return { rankings: rows.map((r, i) => ({
      id: String(r.id), name: r.name, subtitle: r.role,
      score: Number(metric === 'posts' ? r.posts :
        metric === 'pms' ? r.pms_score : r.impact_score),
      avatar_url: r.picture || null, rank: i + 1,
    })) };
  }
  const table = scope;
  const join = {
    programs: ['program_members', 'program_id'],
    opportunities: ['opportunity_applications', 'opportunity_id'],
    events: ['event_attendees', 'event_id'],
    courses: ['course_enrollments', 'course_id'],
    projects: ['project_members', 'project_id'],
  }[table];
  if (!join) throw new HttpError(400, 'invalid_scope', 'Unknown leaderboard type.');
  const [memberTable, memberCol] = join;
  const filters = [];
  const args = [];
  if (entityIds.length) {
    filters.push(`t.id IN (${entityIds.map(() => '?').join(',')})`);
    args.push(...entityIds);
  }
  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
  const rows = (await env.DB.prepare(`SELECT t.id,t.title name,t.author_id,
    (SELECT COUNT(*) FROM ${memberTable} m WHERE m.${memberCol}=t.id) score,
    t.created_at FROM ${table} t ${where}
    ORDER BY score DESC, t.created_at DESC LIMIT 10`).bind(...args).all()).results || [];
  return { rankings: rows.map((r, i) => ({
    id: String(r.id), name: r.name, subtitle: `${r.score} participants`,
    score: Number(r.score || 0), rank: i + 1,
  })) };
}

async function createLeaderboard(req, env) {
  const viewer = await requireUser(req, env);
  const b = await readJson(req);
  const scope = leaderboardScope(b.scope);
  if (!isAdminUser(env, viewer) && (scope === 'institutions' || scope === 'governments')) {
    throw new HttpError(403, 'not_allowed', 'Only platform admins can build institution or government leaderboards.');
  }
  const metric = ['impact', 'posts', 'pms'].includes(String(b.metric || '')) ?
    String(b.metric) : scope === 'institutions' || scope === 'governments' ?
      'impact' : 'participants';
  const period = ['week', 'month', 'all'].includes(String(b.period || '')) ?
    String(b.period) : 'month';
  const days = period === 'week' ? 7 : period === 'all' ? 3650 : 30;
  let entityIds = Array.isArray(b.entity_ids) ?
    b.entity_ids.map(Number).filter((n) => Number.isInteger(n) && n > 0).slice(0, 50) : [];
  if (!isAdminUser(env, viewer) && entityIds.length) {
    const table = scope;
    if (!['programs', 'opportunities', 'events', 'courses', 'projects'].includes(table)) {
      throw new HttpError(403, 'not_allowed', 'Only admins can build that leaderboard.');
    }
    const rows = (await env.DB.prepare(
      `SELECT id FROM ${table} WHERE author_id=? AND id IN (${entityIds.map(() => '?').join(',')})`)
      .bind(viewer.id, ...entityIds).all()).results || [];
    entityIds = rows.map((r) => Number(r.id));
    if (!entityIds.length) throw new HttpError(403, 'not_allowed',
      'Choose entities you own to appear in this leaderboard.');
  }
  const { rankings } = await buildLeaderboardRankings(env, scope, metric, days, entityIds);
  if (!rankings.length) throw new HttpError(400, 'empty_leaderboard',
    'No entities are available for this leaderboard yet.');
  const title = clean(b.title, 140) || `${scope} leaderboard`;
  const audience = clean(b.audience, 100) || 'all';
  const text = `${title}\n${period === 'week' ? 'This week' : period === 'all' ? 'All time' : 'This month'} · ${scope}\n` +
    rankings.slice(0, 3).map((r) => `#${r.rank} ${r.name} — ${r.score}`).join('\n');
  const admin = isAdminUser(env, viewer);
  const at = nowIso();
  const structured = { scope, metric, period, entity_ids: entityIds, rankings };
  const ins = await env.DB.prepare(`INSERT INTO posts
    (author_id,text,kind,structured_json,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
    VALUES (?,?, 'LEADERBOARD', ?,?,?, 'local-hash', 'USER', ?,?)`)
    .bind(viewer.id, text, JSON.stringify(structured),
      admin ? 'APPROVED' : 'PENDING', JSON.stringify(embeddingFor(text)), at, at).run();
  const id = ins.meta.last_row_id;
  if (!admin) {
    await notifyAdmins(env, 'leaderboard', 'Leaderboard needs review',
      `${viewer.name || 'A member'} submitted ${title}.`, {
        link: 'admin:leaderboards', entityType: 'leaderboard',
        entityId: String(id), actorId: viewer.id,
        dedupeKey: `leaderboard_review:${id}`,
      }).catch(() => {});
  }
  const row = await getPostRow(env, id);
  return json({ ...postJson(row, false, null), moderation_status: row.moderation_status }, 201);
}
async function searchSocial(req, env, url) {
  const q = clean(url.searchParams.get('q'), 80);
  if (q.length < 2) throw new HttpError(400, 'missing_query', 'Type at least two characters to search.');
  const viewer = await currentUser(req, env);
  const like = `%${q.replace(/[%_]/g, '')}%`;
  const users = (await env.DB.prepare(`SELECT id,name,handle,picture,role,bio,country,city,email_verified
    FROM users WHERE (name LIKE ? OR handle LIKE ? OR bio LIKE ? OR country LIKE ? OR city LIKE ?)
      AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
        (b.blocker_id=? AND b.blocked_id=users.id) OR (b.blocker_id=users.id AND b.blocked_id=?))
    ORDER BY email_verified DESC, name ASC LIMIT 20`)
    .bind(like, like, like, like, like, viewer ? viewer.id : -1, viewer ? viewer.id : -1).all()).results || [];
  const postWhere = ['p.hidden=0',
    '(p.text LIKE ? OR p.transcript LIKE ?)',
    `(p.moderation_status IS NULL OR p.moderation_status='APPROVED')`];
  const postArgs = [like, like];
  if (viewer) {
    postWhere.push(`NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
      (b.blocker_id=? AND b.blocked_id=p.author_id) OR (b.blocker_id=p.author_id AND b.blocked_id=?))`);
    postArgs.push(viewer.id, viewer.id);
  }
  const posts = (await env.DB.prepare(`${POST_SELECT} WHERE ${postWhere.join(' AND ')}
    ORDER BY p.created_at DESC LIMIT 30`).bind(...postArgs).all()).results || [];
  const qVec = embeddingFor(q);
  posts.sort((a, b) => {
    let av = 0, bv = 0;
    try { av = cosineSimilarity(qVec, JSON.parse(a.embedding_json || '[]')); } catch (_) {}
    try { bv = cosineSimilarity(qVec, JSON.parse(b.embedding_json || '[]')); } catch (_) {}
    return bv - av;
  });
  const liked = new Set();
  const marked = new Set();
  if (viewer && posts.length) {
    const ids = posts.map((p) => p.id);
    const ph = ids.map(() => '?').join(',');
    const [l, m] = await Promise.all([
      env.DB.prepare(`SELECT post_id FROM post_likes WHERE user_id=? AND post_id IN (${ph})`).bind(viewer.id, ...ids).all(),
      env.DB.prepare(`SELECT post_id FROM post_bookmarks WHERE user_id=? AND post_id IN (${ph})`).bind(viewer.id, ...ids).all(),
    ]);
    for (const x of l.results || []) liked.add(Number(x.post_id));
    for (const x of m.results || []) marked.add(Number(x.post_id));
  }
  const recent = (await env.DB.prepare("SELECT text FROM posts WHERE hidden=0 AND text LIKE '%#%' ORDER BY created_at DESC LIMIT 300").all()).results || [];
  const counts = new Map();
  for (const r of recent) for (const m of String(r.text || '').matchAll(/#([\p{L}\p{N}_]{2,40})/gu)) {
    const tag = m[1].toLowerCase();
    counts.set(tag, (counts.get(tag) || 0) + 1);
  }
  return json({
    query: q,
    users: users.map((u) => ({ id: String(u.id), name: u.name, full_name: u.name, handle: u.handle || handleFor(u.name, u.id),
      avatar_url: u.picture || null, role: u.role, bio: u.bio || '', country: u.country || null, city: u.city || null,
      verified: !!u.email_verified })),
    posts: posts.map((p) => postJson(p, liked.has(Number(p.id)), null, marked.has(Number(p.id)))),
    hashtags: [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12)
      .map(([tag, count]) => ({ tag, count })),
  });
}

async function trendingHashtags(env) {
  const rows = (await env.DB.prepare("SELECT text, created_at FROM posts WHERE hidden=0 AND text LIKE '%#%' ORDER BY created_at DESC LIMIT 500").all()).results || [];
  const counts = new Map();
  for (const r of rows) for (const m of String(r.text || '').matchAll(/#([\p{L}\p{N}_]{2,40})/gu)) {
    const tag = m[1].toLowerCase();
    const cur = counts.get(tag) || { tag, count: 0, latest: r.created_at };
    cur.count += 1;
    if (String(r.created_at) > String(cur.latest)) cur.latest = r.created_at;
    counts.set(tag, cur);
  }
  return json([...counts.values()].sort((a, b) => b.count - a.count).slice(0, 20));
}

async function castImpactVote(req, env, id) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
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
  const u = await requireUser(req, env);
  const post = await env.DB.prepare(`SELECT p.id,p.confidence_score,u.email_verified author_verified
    FROM posts p JOIN users u ON u.id=p.author_id WHERE p.id=? AND p.hidden=0`)
    .bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  if (!post.author_verified || Number(post.confidence_score || 0) < 60) {
    throw new HttpError(403, 'verified_only',
      'Only verified impact can be shared outside MASAREEN.');
  }
  const shareKey = `share:${u.id}`;
  const since = new Date(Date.now() - 3600000).toISOString();
  const recent = await env.DB.prepare('SELECT COUNT(*) c FROM rate_limits WHERE key=? AND created_at>?')
    .bind(shareKey, since).first();
  if (Number(recent?.c || 0) >= 60) {
    throw new HttpError(429, 'rate_limited', 'You are sharing too quickly. Please slow down.');
  }
  await env.DB.prepare('INSERT INTO rate_limits (key, created_at) VALUES (?,?)').bind(shareKey, nowIso()).run();
  await env.DB.prepare('UPDATE posts SET share_count=share_count+1 WHERE id=?').bind(id).run();
  await recomputeImpact(env, id);
  const row = await getPostRow(env, id);
  return json({ ok: true, shares: row.share_count });
}

async function boostPost(req, env, id) {
  const u = await requireUser(req, env);
  const post = await env.DB.prepare('SELECT * FROM posts WHERE id=? AND hidden=0').bind(id).first();
  if (!post) throw new HttpError(404, 'post_not_found', 'This post no longer exists.');
  if (Number(post.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the author can boost this post.');
  }
  const b = await readJson(req);
  const amount = Math.round(clamp(Number(b.amount) || 25, 5, 5000) * 100) / 100;
  const days = clamp(Math.ceil(amount / 25), 1, 30);
  await debitCoins(env, u.id, amount, `Post boost #${id} · ${days} days`);
  const until = new Date(Date.now() + days * 86400000).toISOString();
  const weight = clamp(amount / 150, 0.06, 0.38);
  await env.DB.prepare(`UPDATE posts SET boosted_until=?,boost_weight=?,
    paid_mrc=paid_mrc+?,updated_at=? WHERE id=?`)
    .bind(until, weight, amount, nowIso(), id).run();
  const row = await getPostRow(env, id);
  return json({ ok: true, boosted_until: until, boost_weight: weight,
    amount, days, post: postJson(row, false, null) });
}

async function blockedBetween(env, a, b) {
  return !!(await env.DB.prepare(`SELECT 1 x FROM user_blocks WHERE
    (blocker_id=? AND blocked_id=?) OR (blocker_id=? AND blocked_id=?)`).bind(a, b, b, a).first());
}

function messageJson(m, viewerId) {
  return {
    id: String(m.id), conversation_id: String(m.conversation_id),
    sender_id: String(m.sender_id), body: m.body,
    read: !!m.read_at, read_at: m.read_at || null,
    mine: Number(m.sender_id) === Number(viewerId),
    created_at: m.created_at,
  };
}

async function conversationSummary(env, c, viewerId) {
  const peerId = Number(c.user_a) === Number(viewerId) ? Number(c.user_b) : Number(c.user_a);
  const [peer, last, unread] = await Promise.all([
    env.DB.prepare('SELECT id,name,handle,picture,role,email_verified FROM users WHERE id=?').bind(peerId).first(),
    env.DB.prepare('SELECT * FROM messages WHERE conversation_id=? ORDER BY created_at DESC LIMIT 1').bind(c.id).first(),
    env.DB.prepare('SELECT COUNT(*) c FROM messages WHERE conversation_id=? AND sender_id<>? AND read_at IS NULL')
      .bind(c.id, viewerId).first(),
  ]);
  if (!peer) return null;
  return {
    id: String(c.id),
    peer: { id: String(peer.id), name: peer.name, full_name: peer.name,
      handle: peer.handle || handleFor(peer.name, peer.id), avatar_url: peer.picture || null,
      role: peer.role, verified: !!peer.email_verified },
    last_message: last ? last.body : null,
    last_message_at: last ? last.created_at : (c.last_message_at || c.created_at),
    last_sender_id: last ? String(last.sender_id) : null,
    unread_count: Number(unread.c || 0),
    created_at: c.created_at,
  };
}

async function messagesRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in to use messages.');
  if (path === '/api/v1/messages/unread' && req.method === 'GET') {
    const row = await env.DB.prepare(`SELECT COUNT(*) c FROM messages m JOIN conversations c ON c.id=m.conversation_id
      WHERE (c.user_a=? OR c.user_b=?) AND m.sender_id<>? AND m.read_at IS NULL`).bind(viewer.id, viewer.id, viewer.id).first();
    return json({ count: Number(row.c || 0) });
  }
  if (path === '/api/v1/messages/conversations' && req.method === 'GET') {
    const [convRes, blockRes] = await Promise.all([
      env.DB.prepare(`SELECT c.*,
          u.id peer_id, u.name peer_name, u.handle peer_handle, u.picture peer_picture,
          u.role peer_role, u.email_verified peer_verified,
          (SELECT m.body FROM messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC, m.id DESC LIMIT 1) last_body,
          (SELECT m.created_at FROM messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC, m.id DESC LIMIT 1) last_msg_at,
          (SELECT m.sender_id FROM messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC, m.id DESC LIMIT 1) last_sender_id,
          (SELECT COUNT(*) FROM messages m WHERE m.conversation_id=c.id AND m.sender_id<>? AND m.read_at IS NULL) unread_count
        FROM conversations c
        JOIN users u ON u.id = CASE WHEN c.user_a=? THEN c.user_b ELSE c.user_a END
        WHERE c.user_a=? OR c.user_b=?
        ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
        LIMIT 100`).bind(viewer.id, viewer.id, viewer.id, viewer.id).all(),
      env.DB.prepare(`SELECT CASE WHEN blocker_id=? THEN blocked_id ELSE blocker_id END peer_id
        FROM user_blocks WHERE blocker_id=? OR blocked_id=?`).bind(viewer.id, viewer.id, viewer.id).all(),
    ]);
    const blockedPeers = new Set((blockRes.results || []).map((r) => Number(r.peer_id)));
    const summaries = (convRes.results || [])
      .filter((r) => !blockedPeers.has(Number(r.peer_id)))
      .map((r) => ({
        id: String(r.id),
        peer: {
          id: String(r.peer_id),
          name: r.peer_name,
          full_name: r.peer_name,
          handle: r.peer_handle || handleFor(r.peer_name, r.peer_id),
          avatar_url: r.peer_picture || null,
          role: r.peer_role,
          verified: !!r.peer_verified,
        },
        last_message: r.last_body != null ? r.last_body : null,
        last_message_at: r.last_msg_at != null ? r.last_msg_at : (r.last_message_at || r.created_at),
        last_sender_id: r.last_sender_id != null ? String(r.last_sender_id) : null,
        unread_count: Number(r.unread_count || 0),
        created_at: r.created_at,
      }));
    return json(summaries);
  }
  if (path === '/api/v1/messages/conversations' && req.method === 'POST') {
    const b = await readJson(req);
    const target = num(b.user_id || b.userId);
    if (!target) throw new HttpError(400, 'missing_user', 'Choose someone to message.');
    if (target === viewer.id) throw new HttpError(400, 'self_message', 'You cannot message yourself.');
    const peer = await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(target).first();
    if (!peer) throw new HttpError(404, 'user_not_found', 'Profile not found.');
    if (await blockedBetween(env, viewer.id, target))
      throw new HttpError(403, 'blocked', 'Messaging is unavailable with this account.');
    if (!isAdminUser(env, viewer) && !(await canMessageUser(env, viewer, target)))
      throw new HttpError(403, 'messaging_restricted', 'This member only accepts messages from people they follow.');
    const [a, bId] = [Math.min(viewer.id, target), Math.max(viewer.id, target)];
    let c = await env.DB.prepare('SELECT * FROM conversations WHERE user_a=? AND user_b=?').bind(a, bId).first();
    if (!c) {
      await env.DB.prepare('INSERT INTO conversations (user_a,user_b,last_message_at,created_at) VALUES (?,?,?,?)')
        .bind(a, bId, null, nowIso()).run();
      c = await env.DB.prepare('SELECT * FROM conversations WHERE user_a=? AND user_b=?').bind(a, bId).first();
    }
    return json(await conversationSummary(env, c, viewer.id), 201);
  }
  const match = /^\/api\/v1\/messages\/conversations\/(\d+)(\/read)?$/.exec(path);
  if (!match) return null;
  const conversationId = Number(match[1]);
  const c = await env.DB.prepare('SELECT * FROM conversations WHERE id=?').bind(conversationId).first();
  if (!c) throw new HttpError(404, 'conversation_not_found', 'Conversation not found.');
  if (Number(c.user_a) !== Number(viewer.id) && Number(c.user_b) !== Number(viewer.id))
    throw new HttpError(403, 'forbidden', 'This conversation is private.');
  const peerId = Number(c.user_a) === Number(viewer.id) ? Number(c.user_b) : Number(c.user_a);
  if (match[2] === '/read' && req.method === 'POST') {
    await env.DB.prepare('UPDATE messages SET read_at=? WHERE conversation_id=? AND sender_id<>? AND read_at IS NULL')
      .bind(nowIso(), conversationId, viewer.id).run();
    return json({ ok: true });
  }
  if (req.method === 'GET') {
    await env.DB.prepare('UPDATE messages SET read_at=? WHERE conversation_id=? AND sender_id<>? AND read_at IS NULL')
      .bind(nowIso(), conversationId, viewer.id).run();
    const rows = (await env.DB.prepare('SELECT * FROM messages WHERE conversation_id=? ORDER BY created_at ASC LIMIT 300')
      .bind(conversationId).all()).results || [];
    const summary = await conversationSummary(env, c, viewer.id);
    return json({ conversation: summary, messages: rows.map((m) => messageJson(m, viewer.id)) });
  }
  if (req.method === 'POST') {
    if (await blockedBetween(env, viewer.id, peerId))
      throw new HttpError(403, 'blocked', 'Messaging is unavailable with this account.');
    const b = await readJson(req);
    const body = clean(b.text || b.body, 2000);
    if (!body) throw new HttpError(400, 'empty_message', 'Write a message first.');
    assertModerated(body);
    const at = nowIso();
    const r = await env.DB.prepare('INSERT INTO messages (conversation_id,sender_id,body,created_at) VALUES (?,?,?,?)')
      .bind(conversationId, viewer.id, body, at).run();
    await env.DB.prepare('UPDATE conversations SET last_message_at=? WHERE id=?').bind(at, conversationId).run();
    await notify(env, peerId, 'message',
      `${viewer.name || 'Someone'} sent you a message`, body, viewer.id, null,
      { link: `conversation:${conversationId}`, entityType: 'conversation',
        entityId: String(conversationId) });
    return json({ id: String(r.meta.last_row_id), conversation_id: String(conversationId),
      sender_id: String(viewer.id), body, read: false, read_at: null, mine: true, created_at: at }, 201);
  }
  return null;
}


/* ---------------- ads manager ---------------- */
const AD_PLACEMENTS = new Set(['feed', 'search', 'profile']);
const AD_OBJECTIVES = new Set(['awareness', 'traffic', 'engagement', 'leads', 'donations']);
const AD_MEDIA_TYPES = new Set(['image', 'video', 'text']);
const AD_STATUSES = new Set(['DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'REJECTED']);
const AD_MIN_BUDGET = 50;
const AD_MAX_BUDGET = 100000;
const AD_MAX_CREATIVES = 5;
const AD_MAX_ACTIVE_PER_USER = 3;
const AD_IMPRESSION_COST = 0.2;
const AD_CLICK_COST = 2;
const AD_USER_DAILY_IMPRESSIONS = 8;
const AD_CAMPAIGN_FREQUENCY_HOURS = 12;

function adTargeting(value) {
  const src = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  const list = (v, max = 12) => Array.isArray(v)
    ? v.map((x) => clean(x, 50)).filter(Boolean).slice(0, max) : [];
  const sdgs = Array.isArray(src.sdgs)
    ? [...new Set(src.sdgs.map(Number).filter((n) => Number.isInteger(n) && n >= 1 && n <= 17))].slice(0, 17)
    : [];
  return {
    countries: list(src.countries),
    roles: list(src.roles).map((x) => x.toUpperCase()),
    sdgs,
    languages: list(src.languages),
    keywords: list(src.keywords, 20),
  };
}

function adDate(value) {
  if (value == null || value === '') return null;
  const d = new Date(String(value));
  if (Number.isNaN(d.getTime())) throw new HttpError(400, 'invalid_date', 'Use a valid date for the campaign schedule.');
  return d.toISOString();
}

function adCreativeJson(c) {
  return {
    id: String(c.id), campaign_id: String(c.campaign_id), title: c.title,
    body: c.body || null, media_url: c.media_url || null, media_type: c.media_type || 'image',
    cta_label: c.cta_label || null, cta_url: c.cta_url || null,
    sort_order: Number(c.sort_order || 0), created_at: c.created_at, updated_at: c.updated_at,
  };
}

function adCampaignJson(c, creatives = [], metrics = {}, ownerName = null) {
  let targeting = {};
  try { targeting = JSON.parse(c.targeting_json || '{}'); } catch { targeting = {}; }
  const budget = Number(c.budget_coins || 0);
  const spent = Number(c.spent_coins || 0);
  const impressions = Number(metrics.impressions || 0);
  const clicks = Number(metrics.clicks || 0);
  return {
    id: String(c.id), user_id: String(c.user_id), owner_name: ownerName || null,
    name: c.name, objective: c.objective || 'awareness', placement: c.placement || 'feed',
    status: c.status || 'DRAFT', budget_coins: budget, funded_coins: Number(c.funded_coins || 0),
    spent_coins: spent, remaining_coins: Math.max(0, Math.round((budget - spent) * 100) / 100),
    currency: c.currency || 'MRC', start_at: c.start_at || null, end_at: c.end_at || null,
    targeting, creatives: creatives.map(adCreativeJson), impressions, clicks,
    ctr: impressions ? clicks / impressions : 0,
    ctr_percent: impressions ? Math.round((clicks / impressions) * 10000) / 100 : 0,
    cpc: clicks ? Math.round((spent / clicks) * 100) / 100 : 0,
    created_at: c.created_at, updated_at: c.updated_at,
  };
}

async function hydrateAdCampaigns(env, rows, withOwner = false) {
  if (!rows.length) return [];
  const ids = rows.map((r) => Number(r.id));
  const marks = ids.map(() => '?').join(',');
  const creatives = (await env.DB.prepare(
    `SELECT * FROM ad_creatives WHERE campaign_id IN (${marks}) ORDER BY sort_order, id`
  ).bind(...ids).all()).results || [];
  const metrics = (await env.DB.prepare(
    `SELECT campaign_id,
       SUM(CASE WHEN type='impression' THEN 1 ELSE 0 END) impressions,
       SUM(CASE WHEN type='click' THEN 1 ELSE 0 END) clicks,
       COALESCE(SUM(cost_coins),0) spend
     FROM ad_events WHERE campaign_id IN (${marks}) GROUP BY campaign_id`
  ).bind(...ids).all()).results || [];
  const owners = withOwner ? ((await env.DB.prepare(
    `SELECT id,name,email FROM users WHERE id IN (${marks})`
  ).bind(...ids).all()).results || []) : [];
  const byCreative = new Map();
  for (const c of creatives) {
    const key = Number(c.campaign_id);
    if (!byCreative.has(key)) byCreative.set(key, []);
    byCreative.get(key).push(c);
  }
  const byMetric = new Map(metrics.map((m) => [Number(m.campaign_id), m]));
  const byOwner = new Map(owners.map((u) => [Number(u.id), u]));
  return rows.map((c) => {
    const owner = byOwner.get(Number(c.user_id));
    return adCampaignJson(c, byCreative.get(Number(c.id)) || [], byMetric.get(Number(c.id)) || {},
      owner ? (owner.name || owner.email) : null);
  });
}

function normalizeAdCreative(body, existing = null) {
  const title = clean(body.title !== undefined ? body.title : existing && existing.title, 120);
  if (title.length < 2) throw new HttpError(400, 'invalid_title', 'Give the ad a clear title.');
  const bodyText = clean(body.body !== undefined ? body.body : existing && existing.body, 1000) || null;
  const mediaType = String(body.media_type !== undefined ? body.media_type : existing && existing.media_type || 'image').toLowerCase();
  if (!AD_MEDIA_TYPES.has(mediaType)) throw new HttpError(400, 'invalid_media_type', 'Choose image, video or text.');
  const mediaUrl = clean(body.media_url !== undefined ? body.media_url : existing && existing.media_url, 1000) || null;
  if (mediaType !== 'text' && !mediaUrl) throw new HttpError(400, 'media_required', 'Add an image or video URL.');
  if (mediaUrl && !/^https?:\/\//i.test(mediaUrl)) throw new HttpError(400, 'invalid_media_url', 'Media URL must start with http:// or https://.');
  const ctaLabel = clean(body.cta_label !== undefined ? body.cta_label : existing && existing.cta_label, 40) || null;
  const ctaUrl = clean(body.cta_url !== undefined ? body.cta_url : existing && existing.cta_url, 1000) || null;
  if (ctaUrl && !/^https?:\/\//i.test(ctaUrl)) throw new HttpError(400, 'invalid_cta_url', 'Call-to-action URL must start with http:// or https://.');
  return { title, body: bodyText, media_type: mediaType, media_url: mediaUrl, cta_label: ctaLabel, cta_url: ctaUrl };
}

async function adCampaignForViewer(env, id, viewer) {
  const row = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(id).first();
  if (!row) throw new HttpError(404, 'campaign_not_found', 'Campaign not found.');
  if (Number(row.user_id) !== Number(viewer.id) && !isAdminUser(env, viewer)) {
    throw new HttpError(403, 'not_allowed', 'This campaign belongs to another member.');
  }
  return row;
}

async function debitCoins(env, ownerId, amount, reference) {
  const value = Math.round(Number(amount) * 100) / 100;
  if (!Number.isFinite(value) || value <= 0) throw new HttpError(400, 'invalid_amount', 'Enter a valid coin amount.');
  await ensureWallet(env, ownerId);
  const at = nowIso();
  const upd = await env.DB.prepare(
    'UPDATE coin_wallets SET balance=balance-?,updated_at=? WHERE owner_id=? AND balance>=?'
  ).bind(value, at, ownerId, value).run();
  if (!upd.meta.changes) throw new HttpError(400, 'insufficient_balance', 'You do not have enough MASAREEN Coins for this transaction.');
  await recordCoinTx(env, ownerId, 'SPEND', value, reference || 'Ads Manager', null);
}

async function creditCoins(env, ownerId, amount, reference) {
  const value = Math.round(Number(amount) * 100) / 100;
  if (!Number.isFinite(value) || value <= 0) return;
  await ensureWallet(env, ownerId);
  const at = nowIso();
  await env.DB.prepare('UPDATE coin_wallets SET balance=balance+?,updated_at=? WHERE owner_id=?')
    .bind(value, at, ownerId).run();
  await recordCoinTx(env, ownerId, 'EARN', value, reference || 'Ads refund', null);
}

async function completeAdCampaign(env, campaign, status = 'COMPLETED') {
  const at = nowIso();
  const settlement = await env.DB.prepare(`UPDATE ad_campaigns SET status=?,funded_coins=spent_coins,updated_at=?
    WHERE id=? AND funded_coins>spent_coins`)
    .bind(status, at, campaign.id).run();
  if (settlement.meta.changes) {
    const refund = Math.max(0, Math.round((Number(campaign.funded_coins || 0) - Number(campaign.spent_coins || 0)) * 100) / 100);
    if (refund > 0) {
      await creditCoins(env, campaign.user_id, refund, `Ad campaign #${campaign.id} unused budget`);
    }
  } else {
    await env.DB.prepare('UPDATE ad_campaigns SET status=?,updated_at=? WHERE id=?')
      .bind(status, at, campaign.id).run();
  }
}

async function setAdCampaignStatus(env, campaign, requested) {
  const status = String(requested || '').toUpperCase();
  if (!AD_STATUSES.has(status)) throw new HttpError(400, 'invalid_status', 'Choose a valid campaign status.');
  if (status === campaign.status) return campaign;
  if (status === 'ACTIVE') {
    if (!['DRAFT', 'PAUSED'].includes(campaign.status)) {
      throw new HttpError(400, 'invalid_transition', 'Only draft or paused campaigns can be activated.');
    }
    const creativeCount = Number((await env.DB.prepare('SELECT COUNT(*) c FROM ad_creatives WHERE campaign_id=?')
      .bind(campaign.id).first()).c || 0);
    if (!creativeCount) throw new HttpError(400, 'creative_required', 'Add at least one creative before activating.');
    const budget = Number(campaign.budget_coins || 0);
    if (budget < AD_MIN_BUDGET) throw new HttpError(400, 'budget_too_small', `The minimum ad budget is ${AD_MIN_BUDGET} MRC.`);
    if (campaign.end_at && new Date(campaign.end_at).getTime() < Date.now()) {
      throw new HttpError(400, 'campaign_ended', 'This campaign end date has already passed.');
    }
    const funded = Number(campaign.funded_coins || 0);
    if (budget > funded) await debitCoins(env, campaign.user_id, budget - funded, `Ad campaign #${campaign.id} budget`);
    if (budget < funded) await creditCoins(env, campaign.user_id, funded - budget, `Ad campaign #${campaign.id} budget adjustment`);
    const at = nowIso();
    await env.DB.prepare(`UPDATE ad_campaigns SET status='ACTIVE',funded_coins=?,start_at=COALESCE(start_at,?),updated_at=? WHERE id=?`)
      .bind(budget, at, at, campaign.id).run();
  } else if (status === 'PAUSED') {
    if (campaign.status !== 'ACTIVE') throw new HttpError(400, 'invalid_transition', 'Only active campaigns can be paused.');
    await env.DB.prepare("UPDATE ad_campaigns SET status='PAUSED',updated_at=? WHERE id=?").bind(nowIso(), campaign.id).run();
  } else if (status === 'COMPLETED' || status === 'REJECTED') {
    await completeAdCampaign(env, campaign, status);
  } else if (status === 'DRAFT') {
    if (campaign.status !== 'DRAFT') throw new HttpError(400, 'invalid_transition', 'Completed campaigns cannot return to draft.');
  }
  return await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(campaign.id).first();
}

function adMatchesTargeting(campaign, viewer) {
  let t = {};
  try { t = JSON.parse(campaign.targeting_json || '{}'); } catch { t = {}; }
  const country = String(viewer.country || '').toLowerCase();
  const role = String(viewer.role || '').toUpperCase();
  if (Array.isArray(t.countries) && t.countries.length &&
      !t.countries.some((x) => String(x).toLowerCase() === country)) return false;
  if (Array.isArray(t.roles) && t.roles.length &&
      !t.roles.some((x) => String(x).toUpperCase() === role)) return false;
  return true;
}

async function adsRoutes(req, env, url, viewer) {
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
  const path = url.pathname;
  const method = req.method;

  if (path === '/api/v1/ads/feed' && method === 'GET') {
    const placement = AD_PLACEMENTS.has(String(url.searchParams.get('placement') || 'feed'))
      ? String(url.searchParams.get('placement') || 'feed') : 'feed';
    const limit = clamp(parseInt(url.searchParams.get('limit') || '2', 10) || 2, 1, 3);
    const at = nowIso();
    const dayStart = new Date(Date.now() - 86400000).toISOString();
    const freqStart = new Date(Date.now() - AD_CAMPAIGN_FREQUENCY_HOURS * 3600000).toISOString();
    const daily = Number((await env.DB.prepare(
      "SELECT COUNT(*) c FROM ad_events WHERE user_id=? AND type='impression' AND created_at>=?"
    ).bind(viewer.id, dayStart).first()).c || 0);
    let slots = Math.max(0, AD_USER_DAILY_IMPRESSIONS - daily);
    if (!slots) return json([]);
    const rows = (await env.DB.prepare(`SELECT c.* FROM ad_campaigns c
      WHERE c.status='ACTIVE' AND c.placement=? AND c.user_id<>?
        AND (c.start_at IS NULL OR c.start_at<=?) AND (c.end_at IS NULL OR c.end_at>=?)
        AND c.spent_coins < c.budget_coins
      ORDER BY RANDOM() LIMIT 30`).bind(placement, viewer.id, at, at).all()).results || [];
    const me = await env.DB.prepare('SELECT country,role FROM users WHERE id=?').bind(viewer.id).first() || {};
    const out = [];
    for (const campaign of rows) {
      if (slots <= 0 || out.length >= limit) break;
      if (!adMatchesTargeting(campaign, me)) continue;
      const seen = await env.DB.prepare(`SELECT 1 x FROM ad_events
        WHERE user_id=? AND campaign_id=? AND type='impression' AND created_at>=?`)
        .bind(viewer.id, campaign.id, freqStart).first();
      if (seen) continue;
      const creative = await env.DB.prepare('SELECT * FROM ad_creatives WHERE campaign_id=? ORDER BY sort_order,id LIMIT 1')
        .bind(campaign.id).first();
      if (!creative) continue;
      const item = adCampaignJson(campaign, [creative]);
      item.creative = adCreativeJson(creative);
      out.push(item);
      slots -= 1;
    }
    return json(out);
  }

  if ((path === '/api/v1/ads/campaigns' || path === '/api/v1/campaigns' ||
      path === '/api/v1/campaigns/') && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase();
    const where = status && AD_STATUSES.has(status) ? 'AND status=?' : '';
    const rows = (await env.DB.prepare(`SELECT * FROM ad_campaigns WHERE user_id=? ${where} ORDER BY updated_at DESC LIMIT 100`)
      .bind(...(status && AD_STATUSES.has(status) ? [viewer.id, status] : [viewer.id])).all()).results || [];
    return json(await hydrateAdCampaigns(env, rows));
  }

  if (path === '/api/v1/ads/campaigns' && method === 'POST') {
    const b = await readJson(req);
    const name = clean(b.name, 120);
    if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Give the campaign a clear name.');
    const objective = AD_OBJECTIVES.has(String(b.objective || 'awareness')) ? String(b.objective || 'awareness') : 'awareness';
    const placement = AD_PLACEMENTS.has(String(b.placement || 'feed')) ? String(b.placement || 'feed') : 'feed';
    const budget = Number(b.budget_coins || 0);
    if (!Number.isFinite(budget) || budget < 0 || budget > AD_MAX_BUDGET) {
      throw new HttpError(400, 'invalid_budget', `Choose a budget between 0 and ${AD_MAX_BUDGET} MRC.`);
    }
    const startAt = adDate(b.start_at);
    const endAt = adDate(b.end_at);
    if (startAt && endAt && new Date(endAt) <= new Date(startAt)) {
      throw new HttpError(400, 'invalid_schedule', 'The end date must be after the start date.');
    }
    const active = Number((await env.DB.prepare(
      "SELECT COUNT(*) c FROM ad_campaigns WHERE user_id=? AND status IN ('ACTIVE','PAUSED')"
    ).bind(viewer.id).first()).c || 0);
    if (active >= AD_MAX_ACTIVE_PER_USER) {
      throw new HttpError(429, 'campaign_limit', `You can have ${AD_MAX_ACTIVE_PER_USER} active or paused campaigns at once.`);
    }
    const at = nowIso();
    const ins = await env.DB.prepare(`INSERT INTO ad_campaigns
      (user_id,name,objective,placement,status,budget_coins,funded_coins,spent_coins,currency,start_at,end_at,targeting_json,created_at,updated_at)
      VALUES (?,?,?,?,'DRAFT',?,0,0,'MRC',?,?,?,?,?)`)
      .bind(viewer.id, name, objective, placement, budget, startAt, endAt,
        JSON.stringify(adTargeting(b.targeting)), at, at).run();
    const row = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(ins.meta.last_row_id).first();
    return json((await hydrateAdCampaigns(env, [row]))[0], 201);
  }

  const campaignMatch = /^\/api\/v1\/ads\/campaigns\/(\d+)(?:\/(status|creatives|stats|events))?$/.exec(path);
  if (campaignMatch) {
    const id = Number(campaignMatch[1]);
    const sub = campaignMatch[2] || '';
    const campaign = sub === 'events'
      ? await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(id).first()
      : await adCampaignForViewer(env, id, viewer);
    if (!campaign) throw new HttpError(404, 'campaign_not_found', 'Campaign not found.');
    if (!sub && method === 'GET') return json((await hydrateAdCampaigns(env, [campaign]))[0]);
    if (!sub && method === 'PATCH') {
      const b = await readJson(req);
      if (campaign.status === 'COMPLETED' || campaign.status === 'REJECTED') {
        throw new HttpError(400, 'campaign_locked', 'Completed or rejected campaigns cannot be edited.');
      }
      const name = b.name === undefined ? campaign.name : clean(b.name, 120);
      if (name.length < 2) throw new HttpError(400, 'invalid_name', 'Give the campaign a clear name.');
      const objective = b.objective === undefined ? campaign.objective
        : (AD_OBJECTIVES.has(String(b.objective)) ? String(b.objective) : campaign.objective);
      const placement = b.placement === undefined ? campaign.placement
        : (AD_PLACEMENTS.has(String(b.placement)) ? String(b.placement) : campaign.placement);
      const budget = b.budget_coins === undefined ? Number(campaign.budget_coins || 0) : Number(b.budget_coins);
      if (!Number.isFinite(budget) || budget < 0 || budget > AD_MAX_BUDGET) {
        throw new HttpError(400, 'invalid_budget', `Choose a budget between 0 and ${AD_MAX_BUDGET} MRC.`);
      }
      const startAt = b.start_at === undefined ? campaign.start_at : adDate(b.start_at);
      const endAt = b.end_at === undefined ? campaign.end_at : adDate(b.end_at);
      if (startAt && endAt && new Date(endAt) <= new Date(startAt)) {
        throw new HttpError(400, 'invalid_schedule', 'The end date must be after the start date.');
      }
      const spent = Number(campaign.spent_coins || 0);
      if (budget < spent) throw new HttpError(400, 'budget_below_spend', 'The budget cannot be lower than the amount already spent.');
      let funded = Number(campaign.funded_coins || 0);
      if (['ACTIVE', 'PAUSED'].includes(campaign.status)) {
        if (budget > funded) await debitCoins(env, campaign.user_id, budget - funded, `Ad campaign #${campaign.id} budget increase`);
        if (budget < funded) await creditCoins(env, campaign.user_id, funded - budget, `Ad campaign #${campaign.id} budget decrease`);
        funded = budget;
      }
      const targeting = b.targeting === undefined
        ? campaign.targeting_json : JSON.stringify(adTargeting(b.targeting));
      await env.DB.prepare(`UPDATE ad_campaigns SET name=?,objective=?,placement=?,budget_coins=?,funded_coins=?,
        start_at=?,end_at=?,targeting_json=?,updated_at=? WHERE id=?`)
        .bind(name, objective, placement, budget, funded, startAt, endAt, targeting, nowIso(), campaign.id).run();
      const row = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(campaign.id).first();
      return json((await hydrateAdCampaigns(env, [row]))[0]);
    }
    if (!sub && method === 'DELETE') {
      if (campaign.status !== 'DRAFT') throw new HttpError(400, 'campaign_locked', 'Only draft campaigns can be deleted.');
      await env.DB.prepare('DELETE FROM ad_creatives WHERE campaign_id=?').bind(campaign.id).run();
      await env.DB.prepare('DELETE FROM ad_campaigns WHERE id=?').bind(campaign.id).run();
      return json({ ok: true });
    }
    if (sub === 'status' && (method === 'PATCH' || method === 'POST')) {
      const b = await readJson(req);
      const updated = await setAdCampaignStatus(env, campaign, b.status);
      return json((await hydrateAdCampaigns(env, [updated]))[0]);
    }
    if (sub === 'creatives' && method === 'POST') {
      const count = Number((await env.DB.prepare('SELECT COUNT(*) c FROM ad_creatives WHERE campaign_id=?')
        .bind(campaign.id).first()).c || 0);
      if (count >= AD_MAX_CREATIVES) throw new HttpError(400, 'creative_limit', `A campaign can have up to ${AD_MAX_CREATIVES} creatives.`);
      const b = await readJson(req);
      const v = normalizeAdCreative(b);
      const at = nowIso();
      const ins = await env.DB.prepare(`INSERT INTO ad_creatives
        (campaign_id,title,body,media_url,media_type,cta_label,cta_url,sort_order,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?)`)
        .bind(campaign.id, v.title, v.body, v.media_url, v.media_type, v.cta_label, v.cta_url,
          Number(b.sort_order || count), at, at).run();
      await env.DB.prepare('UPDATE ad_campaigns SET updated_at=? WHERE id=?').bind(at, campaign.id).run();
      const row = await env.DB.prepare('SELECT * FROM ad_creatives WHERE id=?').bind(ins.meta.last_row_id).first();
      return json(adCreativeJson(row), 201);
    }
    if (sub === 'stats' && method === 'GET') {
      const days = clamp(parseInt(url.searchParams.get('days') || '30', 10) || 30, 1, 90);
      const since = new Date(Date.now() - days * 86400000).toISOString();
      const series = (await env.DB.prepare(`SELECT substr(created_at,1,10) d, type, COUNT(*) c,
        COALESCE(SUM(cost_coins),0) spend FROM ad_events WHERE campaign_id=? AND created_at>=?
        GROUP BY d,type ORDER BY d`).bind(campaign.id, since).all()).results || [];
      const byDay = {};
      for (const row of series) {
        const key = row.d;
        if (!byDay[key]) byDay[key] = { date: key, impressions: 0, clicks: 0, spend: 0 };
        if (row.type === 'impression') byDay[key].impressions += Number(row.c || 0);
        if (row.type === 'click') byDay[key].clicks += Number(row.c || 0);
        byDay[key].spend += Number(row.spend || 0);
      }
      const hydrated = (await hydrateAdCampaigns(env, [campaign]))[0];
      return json({ ok: true, campaign: hydrated, series: Object.values(byDay) });
    }
    if (sub === 'events' && method === 'POST') {
      const b = await readJson(req);
      const type = String(b.type || '').toLowerCase();
      if (!['impression', 'click'].includes(type)) throw new HttpError(400, 'invalid_event', 'Unknown ad event.');
      if (Number(campaign.user_id) === Number(viewer.id)) throw new HttpError(400, 'own_ad', 'You cannot interact with your own ad.');
      const at = nowIso();
      if (campaign.status !== 'ACTIVE' || campaign.spent_coins >= campaign.budget_coins) {
        throw new HttpError(409, 'campaign_inactive', 'This campaign is not accepting events.');
      }
      if (campaign.start_at && new Date(campaign.start_at).getTime() > Date.now()) {
        throw new HttpError(409, 'campaign_not_started', 'This campaign has not started yet.');
      }
      if (campaign.end_at && new Date(campaign.end_at).getTime() < Date.now()) {
        throw new HttpError(409, 'campaign_ended', 'This campaign has ended.');
      }
      const creative = await env.DB.prepare('SELECT * FROM ad_creatives WHERE campaign_id=? ORDER BY sort_order,id LIMIT 1')
        .bind(campaign.id).first();
      if (!creative) throw new HttpError(409, 'creative_missing', 'This campaign has no creative.');
      if (type === 'impression') {
        const dayStart = new Date(Date.now() - 86400000).toISOString();
        const daily = Number((await env.DB.prepare(
          "SELECT COUNT(*) c FROM ad_events WHERE user_id=? AND type='impression' AND created_at>=?"
        ).bind(viewer.id, dayStart).first()).c || 0);
        if (daily >= AD_USER_DAILY_IMPRESSIONS) throw new HttpError(429, 'ad_limit', 'Daily ad limit reached.');
        const freqStart = new Date(Date.now() - AD_CAMPAIGN_FREQUENCY_HOURS * 3600000).toISOString();
        const seen = await env.DB.prepare(`SELECT 1 x FROM ad_events
          WHERE user_id=? AND campaign_id=? AND type='impression' AND created_at>=?`)
          .bind(viewer.id, campaign.id, freqStart).first();
        if (seen) throw new HttpError(429, 'ad_frequency', 'You have already seen this ad recently.');
      } else {
        const seen = await env.DB.prepare(`SELECT 1 x FROM ad_events
          WHERE user_id=? AND campaign_id=? AND type='impression' AND created_at>=?`)
          .bind(viewer.id, campaign.id, new Date(Date.now() - 86400000).toISOString()).first();
        if (!seen) throw new HttpError(400, 'impression_required', 'An impression is required before a click.');
      }
      const cost = type === 'click' ? AD_CLICK_COST : AD_IMPRESSION_COST;
      const upd = await env.DB.prepare(`UPDATE ad_campaigns SET spent_coins=spent_coins+?,updated_at=?
        WHERE id=? AND status='ACTIVE' AND spent_coins+?<=budget_coins`)
        .bind(cost, at, campaign.id, cost).run();
      if (!upd.meta.changes) {
        const latest = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(campaign.id).first();
        if (latest && Number(latest.spent_coins) >= Number(latest.budget_coins)) {
          await completeAdCampaign(env, latest, 'COMPLETED');
        }
        throw new HttpError(409, 'budget_exhausted', 'This campaign budget is exhausted.');
      }
      await env.DB.prepare(`INSERT INTO ad_events (campaign_id,creative_id,user_id,type,cost_coins,created_at)
        VALUES (?,?,?,?,?,?)`).bind(campaign.id, creative.id, viewer.id, type, cost, at).run();
      const after = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(campaign.id).first();
      if (Number(after.spent_coins) >= Number(after.budget_coins)) await completeAdCampaign(env, after, 'COMPLETED');
      return json({ ok: true, type, cost_coins: cost, spent_coins: Number(after.spent_coins || 0),
        remaining_coins: Math.max(0, Number(after.budget_coins || 0) - Number(after.spent_coins || 0)) });
    }
  }

  const creativeMatch = /^\/api\/v1\/ads\/creatives\/(\d+)$/.exec(path);
  if (creativeMatch) {
    const id = Number(creativeMatch[1]);
    const row = await env.DB.prepare('SELECT * FROM ad_creatives WHERE id=?').bind(id).first();
    if (!row) throw new HttpError(404, 'creative_not_found', 'Creative not found.');
    const campaign = await adCampaignForViewer(env, row.campaign_id, viewer);
    if (campaign.status === 'COMPLETED' || campaign.status === 'REJECTED') {
      throw new HttpError(400, 'campaign_locked', 'Completed or rejected campaigns cannot be edited.');
    }
    if (method === 'PATCH') {
      const b = await readJson(req);
      const v = normalizeAdCreative(b, row);
      const at = nowIso();
      await env.DB.prepare(`UPDATE ad_creatives SET title=?,body=?,media_url=?,media_type=?,cta_label=?,cta_url=?,
        sort_order=?,updated_at=? WHERE id=?`)
        .bind(v.title, v.body, v.media_url, v.media_type, v.cta_label, v.cta_url,
          b.sort_order === undefined ? row.sort_order : Number(b.sort_order || 0), at, id).run();
      await env.DB.prepare('UPDATE ad_campaigns SET updated_at=? WHERE id=?').bind(at, campaign.id).run();
      return json(adCreativeJson(await env.DB.prepare('SELECT * FROM ad_creatives WHERE id=?').bind(id).first()));
    }
    if (method === 'DELETE') {
      await env.DB.prepare('DELETE FROM ad_creatives WHERE id=?').bind(id).run();
      await env.DB.prepare('UPDATE ad_campaigns SET updated_at=? WHERE id=?').bind(nowIso(), campaign.id).run();
      return json({ ok: true });
    }
  }

  return null;
}

/* ---------------- admin ---------------- */
async function adminReportRows(env, status, targetType, limit) {
  const clauses = [];
  const args = [];
  if (status && status !== 'ALL') { clauses.push('r.status=?'); args.push(status); }
  if (targetType) { clauses.push('r.target_type=?'); args.push(targetType); }
  const where = clauses.length ? 'WHERE ' + clauses.join(' AND ') : '';
  const rows = (await env.DB.prepare(`SELECT r.*, u.name reporter_name, u.email reporter_email,
    p.text post_text, p.hidden post_hidden, p.author_id post_author_id,
    pc.text comment_text, pc.hidden comment_hidden,
    tu.name target_user_name, tu.email target_user_email
    FROM reports r
    LEFT JOIN users u ON u.id=r.reporter_id
    LEFT JOIN posts p ON r.target_type='post' AND p.id=r.target_id
    LEFT JOIN post_comments pc ON r.target_type='comment' AND pc.id=r.target_id
    LEFT JOIN users tu ON r.target_type='user' AND tu.id=r.target_id
    ${where} ORDER BY r.created_at DESC LIMIT ?`).bind(...args, limit).all()).results || [];
  return rows.map((r) => ({
    ...r,
    id: String(r.id), reporter_id: String(r.reporter_id), target_id: String(r.target_id),
    reporter_name: r.reporter_name || null, reporter_email: r.reporter_email || null,
    target_preview: {
      type: r.target_type,
      text: r.post_text || r.comment_text || r.target_user_name || null,
      hidden: r.target_type === 'post' ? !!r.post_hidden
        : r.target_type === 'comment' ? !!r.comment_hidden : false,
    },
  }));
}

async function adminRoutes(req, env, url) {
  const admin = await requireAdmin(req, env);
  const path = url.pathname;
  const method = req.method;
  const one = async (sql, ...a) => (await env.DB.prepare(sql).bind(...a).first()) || {};
  const grouped = async (sql, since) => (await env.DB.prepare(sql).bind(since).all()).results || [];

  if (path === '/api/v1/admin/stats' && method === 'GET') {
    const days = clamp(parseInt(url.searchParams.get('days') || '14', 10) || 14, 7, 30);
    const now = Date.now();
    const dayStart = new Date(now - 86400000).toISOString();
    const weekStart = new Date(now - 7 * 86400000).toISOString();
    const monthStart = new Date(now - 30 * 86400000).toISOString();
    const seriesStartDate = new Date(now - (days - 1) * 86400000);
    seriesStartDate.setUTCHours(0, 0, 0, 0);
    const seriesSince = seriesStartDate.toISOString();

    const [users, posts, comments, likes, votes, testers, invited, hiddenPosts, hiddenComments,
      dau, wau, mau, reportsOpen, reportsTotal, inquiriesOpen, inquiriesTotal,
      campaignsTotal, campaignsActive, impressions, clicks, adSpend, coinSupply,
      coinEarned, coinSpent, proActive, paymentsSuccess, paymentsPending,
      submissionsTotal, submissionsPending, submissionsVerified] = await Promise.all([
      one('SELECT COUNT(*) c FROM users'),
      one('SELECT COUNT(*) c FROM posts WHERE hidden=0'),
      one('SELECT COUNT(*) c FROM post_comments WHERE hidden=0'),
      one('SELECT COUNT(*) c FROM post_likes'),
      one('SELECT COUNT(*) c FROM post_impact_votes'),
      one('SELECT COUNT(*) c FROM testers'),
      one("SELECT COUNT(*) c FROM testers WHERE status IN ('invited','active')"),
      one('SELECT COUNT(*) c FROM posts WHERE hidden=1'),
      one('SELECT COUNT(*) c FROM post_comments WHERE hidden=1'),
      one(`SELECT COUNT(DISTINCT user_id) c FROM (
        SELECT user_id FROM login_events WHERE at>?
        UNION SELECT id AS user_id FROM users WHERE last_active_at>?
      )`, dayStart, dayStart),
      one(`SELECT COUNT(DISTINCT user_id) c FROM (
        SELECT user_id FROM login_events WHERE at>?
        UNION SELECT id AS user_id FROM users WHERE last_active_at>?
      )`, weekStart, weekStart),
      one(`SELECT COUNT(DISTINCT user_id) c FROM (
        SELECT user_id FROM login_events WHERE at>?
        UNION SELECT id AS user_id FROM users WHERE last_active_at>?
      )`, monthStart, monthStart),
      one("SELECT COUNT(*) c FROM reports WHERE status='OPEN'"),
      one('SELECT COUNT(*) c FROM reports'),
      one("SELECT COUNT(*) c FROM inquiries WHERE status='OPEN'"),
      one('SELECT COUNT(*) c FROM inquiries'),
      one('SELECT COUNT(*) c FROM ad_campaigns'),
      one("SELECT COUNT(*) c FROM ad_campaigns WHERE status='ACTIVE'"),
      one("SELECT COUNT(*) c FROM ad_events WHERE type='impression'"),
      one("SELECT COUNT(*) c FROM ad_events WHERE type='click'"),
      one('SELECT COALESCE(SUM(cost_coins),0) s FROM ad_events'),
      one('SELECT COALESCE(SUM(balance),0) s FROM coin_wallets'),
      one("SELECT COALESCE(SUM(amount),0) s FROM coin_transactions WHERE type IN ('EARN','TRANSFER_IN')"),
      one("SELECT COALESCE(SUM(amount),0) s FROM coin_transactions WHERE type IN ('SPEND','TRANSFER_OUT','CONVERT')"),
      one("SELECT COUNT(*) c FROM pro_subscriptions WHERE status='ACTIVE' AND expires_at>?", nowIso()),
      one("SELECT COALESCE(SUM(amount_egp),0) s FROM payments WHERE status='SUCCESS'"),
      one("SELECT COUNT(*) c FROM payments WHERE status='PENDING'"),
      one('SELECT COUNT(*) c FROM submissions'),
      one("SELECT COUNT(*) c FROM submissions WHERE status IN ('SUBMITTED','AI_REVIEW','HUMAN_REVIEW')"),
      one("SELECT COUNT(*) c FROM submissions WHERE status='VERIFIED'"),
    ]);
    const bySdg = (await env.DB.prepare('SELECT sdg, COUNT(*) c FROM posts WHERE hidden=0 AND sdg IS NOT NULL GROUP BY sdg ORDER BY c DESC LIMIT 17').all()).results || [];
    const top = (await env.DB.prepare(`${POST_SELECT} WHERE p.hidden=0 ORDER BY p.impact_value DESC LIMIT 5`).all()).results || [];
    const recent = (await env.DB.prepare(`${POST_SELECT} WHERE p.hidden=0 ORDER BY p.created_at DESC LIMIT 5`).all()).results || [];
    const avg = (await env.DB.prepare('SELECT COALESCE(AVG(impact_value),0) a, COALESCE(AVG(confidence_score),0) c FROM posts WHERE hidden=0').first()) || {};
    const [signupRows, postRows, reportRows, impRows, clickRows, spendRows, paymentRows] = await Promise.all([
      grouped('SELECT substr(created_at,1,10) d, COUNT(*) c FROM users WHERE created_at>=? GROUP BY d', seriesSince),
      grouped('SELECT substr(created_at,1,10) d, COUNT(*) c FROM posts WHERE hidden=0 AND created_at>=? GROUP BY d', seriesSince),
      grouped('SELECT substr(created_at,1,10) d, COUNT(*) c FROM reports WHERE created_at>=? GROUP BY d', seriesSince),
      grouped("SELECT substr(created_at,1,10) d, COUNT(*) c FROM ad_events WHERE type='impression' AND created_at>=? GROUP BY d", seriesSince),
      grouped("SELECT substr(created_at,1,10) d, COUNT(*) c FROM ad_events WHERE type='click' AND created_at>=? GROUP BY d", seriesSince),
      grouped("SELECT substr(created_at,1,10) d, COALESCE(SUM(amount),0) c FROM coin_transactions WHERE type='SPEND' AND created_at>=? GROUP BY d", seriesSince),
      grouped("SELECT substr(created_at,1,10) d, COALESCE(SUM(amount_egp),0) c FROM payments WHERE status='SUCCESS' AND created_at>=? GROUP BY d", seriesSince),
    ]);
    const dayMap = (rows) => new Map(rows.map((r) => [r.d, Number(r.c || 0)]));
    const signupMap = dayMap(signupRows), postMap = dayMap(postRows), reportMap = dayMap(reportRows);
    const impMap = dayMap(impRows), clickMap = dayMap(clickRows), spendMap = dayMap(spendRows), payMap = dayMap(paymentRows);
    const series = [];
    for (let i = 0; i < days; i++) {
      const d = new Date(seriesStartDate.getTime() + i * 86400000).toISOString().slice(0, 10);
      series.push({
        date: d, signups: signupMap.get(d) || 0, posts: postMap.get(d) || 0,
        reports: reportMap.get(d) || 0, ad_impressions: impMap.get(d) || 0,
        ad_clicks: clickMap.get(d) || 0, coin_spend: spendMap.get(d) || 0,
        payments_egp: payMap.get(d) || 0,
      });
    }
    const topCampaignRows = (await env.DB.prepare('SELECT * FROM ad_campaigns ORDER BY spent_coins DESC LIMIT 8').all()).results || [];
    const topCampaigns = await hydrateAdCampaigns(env, topCampaignRows, true);
    const recentReports = await adminReportRows(env, 'ALL', null, 5);
    const recentPayments = (await env.DB.prepare(`SELECT p.*, u.name user_name, u.email user_email FROM payments p
      LEFT JOIN users u ON u.id=p.user_id ORDER BY p.created_at DESC LIMIT 6`).all()).results || [];
    const recentInquiries = (await env.DB.prepare(`SELECT i.*, u.name user_name, u.email user_email,
      o.name org_name FROM inquiries i LEFT JOIN users u ON u.id=i.user_id LEFT JOIN users o ON o.id=i.org_id
      ORDER BY i.created_at DESC LIMIT 6`).all()).results || [];
    const recentUsers = (await env.DB.prepare(`SELECT id,name,email,role,country,created_at FROM users
      ORDER BY created_at DESC LIMIT 6`).all()).results || [];
    return json({ ok: true, generated_at: nowIso(),
      totals: {
        users: users.c || 0, posts: posts.c || 0, comments: comments.c || 0, likes: likes.c || 0,
        impact_votes: votes.c || 0, testers: testers.c || 0, testers_invited: invited.c || 0,
        hidden_posts: hiddenPosts.c || 0, hidden_comments: hiddenComments.c || 0,
        active_users_24h: dau.c || 0, active_users_7d: wau.c || 0, active_users_30d: mau.c || 0,
        reports_open: reportsOpen.c || 0, reports_total: reportsTotal.c || 0,
        inquiries_open: inquiriesOpen.c || 0, inquiries_total: inquiriesTotal.c || 0,
        campaigns_total: campaignsTotal.c || 0, campaigns_active: campaignsActive.c || 0,
        ad_impressions: impressions.c || 0, ad_clicks: clicks.c || 0,
        ad_spend_mrc: Number((adSpend.s || 0).toFixed(2)),
        ad_ctr: Number(impressions.c || 0) ? Math.round((Number(clicks.c || 0) / Number(impressions.c)) * 10000) / 100 : 0,
        coin_supply_mrc: Number((coinSupply.s || 0).toFixed(2)),
        coin_earned_mrc: Number((coinEarned.s || 0).toFixed(2)),
        coin_spent_mrc: Number((coinSpent.s || 0).toFixed(2)),
        pro_active: proActive.c || 0, payments_success_egp: Number((paymentsSuccess.s || 0).toFixed(2)),
        payments_pending: paymentsPending.c || 0,
        submissions_total: submissionsTotal.c || 0, submissions_pending: submissionsPending.c || 0,
        submissions_verified: submissionsVerified.c || 0,
        avg_impact: Number((avg.a || 0).toFixed(2)), avg_confidence: Math.round(avg.c || 0),
      },
      by_sdg: bySdg.map((r) => ({ sdg: r.sdg, name: SDG_NAMES[r.sdg] || null, count: r.c })),
      series, top_posts: top.map((r) => postJson(r, false, null)),
      recent_posts: recent.map((r) => postJson(r, false, null)),
      top_campaigns: topCampaigns, recent_reports: recentReports,
      recent_payments: recentPayments.map(paymentJson), recent_inquiries: recentInquiries.map(inquiryJson),
      recent_users: recentUsers.map((u) => ({ ...u, id: String(u.id) })),
    });
  }

  if (path === '/api/v1/admin/ads' && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase();
    const where = status && AD_STATUSES.has(status) ? 'WHERE status=?' : '';
    const rows = (await env.DB.prepare(`SELECT * FROM ad_campaigns ${where} ORDER BY updated_at DESC LIMIT 200`)
      .bind(...(status && AD_STATUSES.has(status) ? [status] : [])).all()).results || [];
    return json(await hydrateAdCampaigns(env, rows, true));
  }
  const adminAdStatus = /^\/api\/v1\/admin\/ads\/(\d+)\/status$/.exec(path);
  if (adminAdStatus && (method === 'POST' || method === 'PATCH')) {
    const b = await readJson(req);
    const campaign = await env.DB.prepare('SELECT * FROM ad_campaigns WHERE id=?').bind(Number(adminAdStatus[1])).first();
    if (!campaign) throw new HttpError(404, 'campaign_not_found', 'Campaign not found.');
    const updated = await setAdCampaignStatus(env, campaign, b.status);
    return json((await hydrateAdCampaigns(env, [updated], true))[0]);
  }

  if (path === '/api/v1/admin/reports' && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase() || 'OPEN';
    const targetType = clean(url.searchParams.get('target_type'), 20).toLowerCase();
    const limit = clamp(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 1, 300);
    const counts = await Promise.all([
      one("SELECT COUNT(*) c FROM reports WHERE status='OPEN'"),
      one("SELECT COUNT(*) c FROM reports WHERE status='RESOLVED'"),
      one("SELECT COUNT(*) c FROM reports WHERE status='DISMISSED'"),
      one('SELECT COUNT(*) c FROM reports'),
    ]);
    const items = await adminReportRows(env, status, targetType || null, limit);
    const summary = { open: counts[0].c || 0, resolved: counts[1].c || 0,
      dismissed: counts[2].c || 0, total: counts[3].c || 0 };
    if (url.searchParams.get('with_counts') === '1') return json({ items, counts: summary });
    return json(items);
  }
  const reportMatch = /^\/api\/v1\/admin\/reports\/(\d+)\/resolve$/.exec(path);
  if (reportMatch && method === 'POST') {
    const b = await readJson(req);
    const status = ['RESOLVED', 'DISMISSED'].includes(String(b.status || '').toUpperCase())
      ? String(b.status).toUpperCase() : 'RESOLVED';
    const report = await env.DB.prepare('SELECT * FROM reports WHERE id=?').bind(Number(reportMatch[1])).first();
    if (!report) throw new HttpError(404, 'report_not_found', 'Report not found.');
    let hidden = false;
    if (String(b.action || '').toUpperCase() === 'HIDE') {
      if (report.target_type === 'post') {
        await env.DB.prepare('UPDATE posts SET hidden=1 WHERE id=?').bind(report.target_id).run();
        hidden = true;
      } else if (report.target_type === 'comment') {
        await env.DB.prepare('UPDATE post_comments SET hidden=1 WHERE id=?').bind(report.target_id).run();
        hidden = true;
      }
    }
    await env.DB.prepare('UPDATE reports SET status=?, resolved_at=? WHERE id=?')
      .bind(status, nowIso(), report.id).run();
    return json({ ok: true, status, hidden });
  }

  if (path === '/api/v1/admin/inquiries' && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase();
    const where = ['OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED'].includes(status) ? 'WHERE i.status=?' : '';
    const rows = (await env.DB.prepare(`SELECT i.*, u.name user_name, u.email user_email, u.picture user_picture,
      o.name org_name, o.email org_email FROM inquiries i
      LEFT JOIN users u ON u.id=i.user_id LEFT JOIN users o ON o.id=i.org_id
      ${where} ORDER BY i.created_at DESC LIMIT 200`)
      .bind(...(where ? [status] : [])).all()).results || [];
    return json(rows.map((r) => ({ ...inquiryJson(r), user_name: r.user_name || null,
      user_email: r.user_email || null, org_name: r.org_name || null, org_email: r.org_email || null })));
  }
  const adminInquiry = /^\/api\/v1\/admin\/inquiries\/(\d+)$/.exec(path);
  if (adminInquiry && (method === 'PATCH' || method === 'POST')) {
    const b = await readJson(req);
    const status = String(b.status || '').toUpperCase();
    if (!['OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose OPEN, IN_REVIEW, RESOLVED or CLOSED.');
    }
    const row = await env.DB.prepare('SELECT * FROM inquiries WHERE id=?').bind(Number(adminInquiry[1])).first();
    if (!row) throw new HttpError(404, 'inquiry_not_found', 'Inquiry not found.');
    await env.DB.prepare('UPDATE inquiries SET status=?,updated_at=? WHERE id=?')
      .bind(status, nowIso(), row.id).run();
    return json({ ok: true, status });
  }

  if ((path === '/api/v1/admin/submissions' || path === '/api/v1/admin/review-queue') && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase();
    const where = status ? 'WHERE s.status=?' : '';
    const rows = (await env.DB.prepare(`SELECT s.*, u.name owner_name, u.email owner_email,
      e.title evidence_title, e.url evidence_url, e.kind evidence_kind,\n      e.target_type evidence_target_type, e.target_id evidence_target_id,\n      e.deepfake_verdict evidence_deepfake_verdict, e.deepfake_score evidence_deepfake_score,
      (SELECT p.id FROM verification_pipelines p WHERE p.submission_id=s.id ORDER BY p.id DESC LIMIT 1) pipeline_id
      FROM submissions s LEFT JOIN users u ON u.id=s.owner_id LEFT JOIN evidence e ON e.id=s.evidence_id
      ${where} ORDER BY s.created_at DESC LIMIT 200`)
      .bind(...(status ? [status] : [])).all()).results || [];
    return json(rows.map((s) => ({ ...submissionJson(s), owner_name: s.owner_name || null,
      owner_email: s.owner_email || null, evidence_title: s.evidence_title || null,
      evidence_url: s.evidence_url || null, evidence_kind: s.evidence_kind || null,
      evidence_target_type: s.evidence_target_type || null,
      evidence_target_id: s.evidence_target_id == null ? null : String(s.evidence_target_id),
      evidence_deepfake_verdict: s.evidence_deepfake_verdict || null,
      evidence_deepfake_score: Number(s.evidence_deepfake_score || 0) })));
  }
  const adminSubmission = /^\/api\/v1\/admin\/submissions\/(\d+)\/verdict$/.exec(path);
  if (adminSubmission && method === 'POST') {
    const b = await readJson(req);
    const status = String(b.status || b.verdict || '').toUpperCase();
    if (!['VERIFIED', 'REJECTED', 'HUMAN_REVIEW'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose VERIFIED, REJECTED or HUMAN_REVIEW.');
    }
    const row = await env.DB.prepare('SELECT * FROM submissions WHERE id=?').bind(Number(adminSubmission[1])).first();
    if (!row) throw new HttpError(404, 'submission_not_found', 'Submission not found.');
    if (status === 'VERIFIED' && row.deepfake_verdict === 'LIKELY_AI' &&
        b.override_deepfake !== true) {
      throw new HttpError(409, 'deepfake_review_required',
        'Deepfake detection flagged this evidence. Re-scan or explicitly override before verifying.');
    }
    const confidence = status === 'VERIFIED' ? Math.max(Number(row.confidence || 0), 80)
      : status === 'REJECTED' ? 0 : Number(row.confidence || 0);
    await env.DB.prepare('UPDATE submissions SET status=?,confidence=?,reviewer_id=? WHERE id=?')
      .bind(status, confidence, admin.id, row.id).run();
    if (row.evidence_id != null) {
      await env.DB.prepare('UPDATE evidence SET status=? WHERE id=?')
        .bind(status === 'VERIFIED' ? 'VERIFIED' : status === 'REJECTED' ? 'REJECTED' : 'UNDER_REVIEW', row.evidence_id).run();
    }
    const pipeline = await env.DB.prepare('SELECT * FROM verification_pipelines WHERE submission_id=? ORDER BY id DESC LIMIT 1')
      .bind(row.id).first();
    if (pipeline) {
      let steps = [];
      try { steps = JSON.parse(pipeline.steps || '[]'); } catch { steps = []; }
      const at = nowIso();
      steps.push({ stage: status === 'VERIFIED' ? 'VERIFIED' : status, status: 'COMPLETE', at, reviewer_id: Number(admin.id) });
      const stageMap = { VERIFIED: 3, HUMAN_REVIEW: 2, REJECTED: 2 };
      await env.DB.prepare('UPDATE verification_pipelines SET status=?,stage=?,confidence=?,steps=?,updated_at=? WHERE id=?')
        .bind(status, stageMap[status] ?? Number(pipeline.stage || 0), confidence, JSON.stringify(steps), at, pipeline.id).run();
    }
    return json({ ok: true, status, confidence });
  }

  if (path === '/api/v1/admin/payments' && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20).toUpperCase();
    const where = status ? 'WHERE p.status=?' : '';
    const rows = (await env.DB.prepare(`SELECT p.*, u.name user_name, u.email user_email FROM payments p
      LEFT JOIN users u ON u.id=p.user_id ${where} ORDER BY p.created_at DESC LIMIT 200`)
      .bind(...(status ? [status] : [])).all()).results || [];
    return json(rows.map((p) => ({ ...paymentJson(p), user_name: p.user_name || null, user_email: p.user_email || null })));
  }

  if (path === '/api/v1/admin/users' && method === 'GET') {
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

  if (path === '/api/v1/admin/testers' && method === 'GET') {
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
    const b = await readJson(req);
    const status = ['pending', 'invited', 'active', 'declined'].includes(b.status) ? b.status : null;
    if (!status) throw new HttpError(400, 'invalid_status', 'Choose pending, invited, active or declined.');
    await env.DB.prepare('UPDATE testers SET status=?, invited_at=CASE WHEN ?=\'invited\' THEN ? ELSE invited_at END WHERE id=?')
      .bind(status, status, nowIso(), Number(statusMatch[1])).run();
    return json({ ok: true });
  }
  const hideMatch = /^\/api\/v1\/admin\/posts\/(\d+)\/hide$/.exec(path);
  if (hideMatch && req.method === 'POST') {
    const b = await readJson(req);
    await env.DB.prepare('UPDATE posts SET hidden=? WHERE id=?').bind(b.hidden === false ? 0 : 1, Number(hideMatch[1])).run();
    return json({ ok: true });
  }
  if (path === '/api/v1/admin/entities' && method === 'GET') {
    const status = (clean(url.searchParams.get('status'), 20) || 'PENDING').toUpperCase();
    const st = ['PENDING', 'APPROVED', 'REJECTED'].includes(status) ? status : 'PENDING';
    const out = [];
    for (const [kind, table] of Object.entries(ENTITY_TABLES)) {
      const rows = (await env.DB.prepare(`SELECT x.id,x.title,x.author_id,x.verification_status,
        x.rejection_reason,x.creation_fee_mrc,x.created_at,u.name author_name,u.role author_role
        FROM ${table} x LEFT JOIN users u ON u.id=x.author_id
        WHERE x.verification_status=? ORDER BY x.created_at DESC LIMIT 100`).bind(st).all()).results || [];
      for (const r of rows) {
        out.push({
          type: kind.toLowerCase(), table, id: String(r.id), title: r.title,
          author_id: String(r.author_id), author_name: r.author_name || 'MASAREEN',
          author_role: r.author_role || null,
          verification_status: r.verification_status,
          rejection_reason: r.rejection_reason || null,
          creation_fee_mrc: Number(r.creation_fee_mrc || 0),
          created_at: r.created_at,
        });
      }
    }
    out.sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
    return json(out);
  }
  const entityVerdict = /^\/api\/v1\/admin\/entities\/(courses|events|programs|projects|opportunities)\/(\d+)\/verdict$/.exec(path);
  if (entityVerdict && method === 'POST') {
    const table = entityVerdict[1];
    const kind = Object.keys(ENTITY_TABLES).find((k) => ENTITY_TABLES[k] === table);
    const id = Number(entityVerdict[2]);
    const b = await readJson(req);
    const status = String(b.status || '').toUpperCase();
    if (!['APPROVED', 'REJECTED'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose approved or rejected.');
    }
    const row = await env.DB.prepare(`SELECT * FROM ${table} WHERE id=?`).bind(id).first();
    if (!row) throw new HttpError(404, 'entity_not_found', 'Entity not found.');
    const reason = clean(b.reason, 300) || null;
    if (status === 'REJECTED' && Number(row.creation_fee_mrc) > 0) {
      await refundCreationFee(env, row.author_id, row.creation_fee_mrc, kind, row.title)
        .catch(() => {});
    }
    await env.DB.prepare(`UPDATE ${table} SET verification_status=?, rejection_reason=?,
      reviewed_at=?, reviewed_by=? WHERE id=?`)
      .bind(status, status === 'REJECTED' ? reason : null, nowIso(), admin.id, id).run();
    if (status === 'APPROVED' && table === 'opportunities') {
      await notifyOpportunityMatches(env, row).catch(() => {});
    }
    if (status === 'APPROVED' && table === 'events') {
      await announceEvent(env, row).catch(() => {});
    }
    await notify(env, row.author_id, 'verification',
      status === 'APPROVED'
        ? `Your ${kind.toLowerCase()} was approved`
        : `Your ${kind.toLowerCase()} needs changes`,
      status === 'APPROVED'
        ? `${row.title} is now live on MASAREEN.`
        : (reason || 'Review the feedback and submit again.'),
      admin.id, null);
    return json({
      ok: true, type: kind.toLowerCase(), id: String(id),
      verification_status: status,
    });
  }
  if (path === '/api/v1/admin/recognition/sweep' && method === 'POST') {
    return json(await runRecognitionSweep(env));
  }
  if (path === '/api/v1/admin/transactions' && method === 'GET') {
    const limit = clamp(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 1, 300);
    const rows = (await env.DB.prepare(`SELECT t.*,u.name user_name,u.email user_email
      FROM coin_transactions t LEFT JOIN users u ON u.id=t.owner_id
      ORDER BY t.created_at DESC LIMIT ?`).bind(limit).all()).results || [];
    return json(rows.map((r) => ({
      id: String(r.id), user_id: String(r.owner_id),
      user_name: r.user_name || 'Member', user_email: r.user_email || null,
      type: r.type, amount: Number(r.amount || 0),
      balance_after: Number(r.balance_after || 0),
      reference: r.reference || null,
      counterparty_id: r.counterparty_id == null ? null : String(r.counterparty_id),
      created_at: r.created_at,
    })));
  }
  if (path === '/api/v1/admin/analytics' && method === 'GET') {
    const days = clamp(parseInt(url.searchParams.get('days') || '30', 10) || 30, 1, 365);
    const since = new Date(Date.now() - days * 86400000).toISOString();
    const [eventRows, topPosts, views, scroll, impressions, dwell, watch, topUsers, scrollUsers] = await Promise.all([
      env.DB.prepare(`SELECT event_type, COUNT(*) c, COUNT(DISTINCT user_id) users,
        AVG(duration_ms) avg_ms, SUM(value) total_value
        FROM analytics_events WHERE created_at>=? GROUP BY event_type
        ORDER BY c DESC LIMIT 50`).bind(since).all(),
      env.DB.prepare(`SELECT p.id,p.text,p.kind,p.impact_value,p.like_count,
        p.comment_count,p.share_count,u.name author_name FROM posts p
        JOIN users u ON u.id=p.author_id WHERE p.hidden=0
        ORDER BY (p.like_count*2+p.comment_count*3+p.share_count*4) DESC
        LIMIT 10`).all(),
      env.DB.prepare(`SELECT COUNT(*) c, COUNT(DISTINCT user_id) users
        FROM post_views WHERE seen_at>=?`).bind(since).first(),
      env.DB.prepare(`SELECT AVG(value) depth, COUNT(*) c
        FROM analytics_events WHERE event_type='feed_scroll' AND created_at>=?`).bind(since).first(),
      env.DB.prepare(`SELECT COUNT(*) c,COUNT(DISTINCT user_id) users FROM analytics_events
        WHERE event_type IN ('feed_impression','post_impression','video_impression') AND created_at>=?`)
        .bind(since).first(),
      env.DB.prepare(`SELECT AVG(duration_ms) avg_ms,COUNT(*) c FROM analytics_events
        WHERE event_type IN ('post_dwell','post_view') AND created_at>=?`).bind(since).first(),
      env.DB.prepare(`SELECT COALESCE(SUM(value),0) total,COALESCE(SUM(duration_ms),0) ms,COUNT(*) c
        FROM analytics_events WHERE event_type IN ('video_watch','media_watch','audio_watch') AND created_at>=?`)
        .bind(since).first(),
      env.DB.prepare(`SELECT u.id,u.name,u.role,COUNT(*) events,
        COALESCE(SUM(CASE WHEN e.event_type IN ('video_watch','media_watch','audio_watch','post_dwell')
          THEN e.duration_ms ELSE 0 END),0) watch_ms,
        AVG(CASE WHEN e.event_type='feed_scroll' THEN e.value END) avg_scroll,
        MAX(e.created_at) last_event FROM analytics_events e
        JOIN users u ON u.id=e.user_id WHERE e.created_at>=?
        GROUP BY e.user_id ORDER BY events DESC LIMIT 15`).bind(since).all(),
      env.DB.prepare(`SELECT user_id,AVG(value) avg_depth,COUNT(*) c,MAX(created_at) last_at
        FROM analytics_events WHERE event_type='feed_scroll' AND created_at>=?
        GROUP BY user_id ORDER BY avg_depth DESC LIMIT 15`).bind(since).all(),
    ]);
    return json({
      ok: true, days,
      events: (eventRows.results || []).map((r) => ({
        event_type: r.event_type, count: Number(r.c || 0),
        users: Number(r.users || 0),
        avg_ms: r.avg_ms == null ? null : Math.round(Number(r.avg_ms)),
        total_value: r.total_value == null ? null : Number(r.total_value),
      })),
      top_posts: (topPosts.results || []).map((p) => ({
        id: String(p.id), text: p.text, kind: p.kind,
        impact_value: p.impact_value == null ? null : Number(p.impact_value),
        likes: Number(p.like_count || 0), comments: Number(p.comment_count || 0),
        shares: Number(p.share_count || 0), author_name: p.author_name,
      })),
      post_views: Number(views?.c || 0),
      post_viewers: Number(views?.users || 0),
      avg_scroll_depth: scroll?.depth == null ? null : Number(scroll.depth),
      scroll_events: Number(scroll?.c || 0),
      impressions: Number(impressions?.c || 0),
      impression_users: Number(impressions?.users || 0),
      avg_dwell_ms: dwell?.avg_ms == null ? null : Math.round(Number(dwell.avg_ms)),
      dwell_events: Number(dwell?.c || 0),
      watch_seconds: Math.round(Number(watch?.ms || 0) / 1000),
      watch_value: Number(watch?.total || 0),
      watch_events: Number(watch?.c || 0),
      top_engaged_users: (topUsers.results || []).map((u) => ({
        id: String(u.id), name: u.name, role: u.role || null,
        events: Number(u.events || 0), watch_ms: Number(u.watch_ms || 0),
        avg_scroll: u.avg_scroll == null ? null : Number(u.avg_scroll),
        last_event: u.last_event,
      })),
      scroll_by_user: (scrollUsers.results || []).map((u) => ({
        user_id: String(u.user_id), avg_depth: Number(u.avg_depth || 0),
        scroll_events: Number(u.c || 0), last_at: u.last_at,
      })),
    });
  }
  if (path === '/api/v1/admin/impact-reports' && method === 'GET') {
    const days = clamp(parseInt(url.searchParams.get('days') || '30', 10) || 30, 1, 365);
    const since = new Date(Date.now() - days * 86400000).toISOString();
    const totals = await one(`SELECT
      (SELECT COUNT(*) FROM users) users,
      (SELECT COUNT(*) FROM users WHERE created_at>=?) new_users,
      (SELECT COUNT(*) FROM posts WHERE hidden=0) posts,
      (SELECT COUNT(*) FROM posts WHERE created_at>=?) new_posts,
      (SELECT COALESCE(SUM(impact_value),0) FROM posts WHERE hidden=0) impact,
      (SELECT COUNT(*) FROM evidence) evidence,
      (SELECT COALESCE(SUM(amount),0) FROM coin_transactions WHERE type='SPEND' AND created_at>=?) mrc_spend,
      (SELECT COUNT(*) FROM coin_transactions WHERE created_at>=?) transactions`,
      since, since, since, since);
    const bySdg = (await env.DB.prepare(`SELECT sdg,COUNT(*) c,COALESCE(SUM(impact_value),0) impact
      FROM posts WHERE hidden=0 AND sdg IS NOT NULL GROUP BY sdg ORDER BY c DESC`).all()).results || [];
    const byRole = (await env.DB.prepare(`SELECT role,COUNT(*) c FROM users
      WHERE role IS NOT NULL GROUP BY role ORDER BY c DESC`).all()).results || [];
    const topUsers = (await env.DB.prepare(`SELECT id,name,role,picture,
      COALESCE((SELECT SUM(impact_value) FROM posts WHERE author_id=users.id AND hidden=0),0) impact_score,
      COALESCE((SELECT COUNT(*) FROM posts WHERE author_id=users.id AND hidden=0),0) pms_score,
      (SELECT COUNT(*) FROM posts WHERE author_id=users.id AND hidden=0) posts
      FROM users WHERE name<>'Deleted member'
      ORDER BY impact_score DESC, pms_score DESC, posts DESC LIMIT 20`).all()).results || [];
    const topPosts = (await env.DB.prepare(`SELECT id,text,impact_value,like_count,comment_count
      FROM posts WHERE hidden=0 ORDER BY impact_value DESC, like_count DESC LIMIT 10`).all()).results || [];
    return json({
      ok: true, days,
      totals: {
        users: Number(totals.users || 0), new_users: Number(totals.new_users || 0),
        posts: Number(totals.posts || 0), new_posts: Number(totals.new_posts || 0),
        impact: Number(totals.impact || 0), evidence: Number(totals.evidence || 0),
        mrc_spend: Number(totals.mrc_spend || 0), transactions: Number(totals.transactions || 0),
      },
      by_sdg: bySdg.map((r) => ({ sdg: Number(r.sdg), count: Number(r.c || 0),
        impact: Number(r.impact || 0) })),
      by_role: byRole.map((r) => ({ role: r.role, count: Number(r.c || 0) })),
      top_users: topUsers.map((u) => ({ id: String(u.id), name: u.name, role: u.role,
        avatar_url: u.picture || null, impact_score: Number(u.impact_score || 0),
        pms_score: Number(u.pms_score || 0), posts: Number(u.posts || 0) })),
      top_posts: topPosts.map((p) => ({ id: String(p.id), text: p.text,
        impact_value: Number(p.impact_value || 0), likes: Number(p.like_count || 0),
        comments: Number(p.comment_count || 0) })),
    });
  }
  if (path === '/api/v1/admin/ai/status' && method === 'GET') {
    const [embeddingRows, moderationRows, deepfakeRows, evidenceDeepfakeRows,
      jobRows, failedJobs, queuedTranscriptions] = await Promise.all([
      env.DB.prepare(`SELECT COALESCE(embedding_status,'none') status,COUNT(*) c FROM posts
        WHERE hidden=0 GROUP BY status ORDER BY c DESC`).all(),
      env.DB.prepare(`SELECT COALESCE(moderation_status,'APPROVED') status,COUNT(*) c FROM posts
        GROUP BY status`).all(),
      env.DB.prepare(`SELECT deepfake_verdict status,COUNT(*) c FROM posts GROUP BY status`).all(),
      env.DB.prepare(`SELECT deepfake_verdict status,COUNT(*) c FROM evidence GROUP BY status`).all(),
      env.DB.prepare(`SELECT status,COUNT(*) c FROM video_jobs GROUP BY status`).all(),
      env.DB.prepare(`SELECT id,post_id,original_url,error,attempts,updated_at FROM video_jobs
        WHERE status='error' ORDER BY updated_at DESC LIMIT 20`).all(),
      one("SELECT COUNT(*) c FROM posts WHERE embedding_status='transcription_queued' AND hidden=0"),
    ]);
    return json({
      ok: true,
      transcription_configured: !!env.OPENAI_API_KEY,
      ai_provider: env.OPENAI_API_KEY ? 'openai' : 'local-hash',
      embedding: (embeddingRows.results || []).map((r) => ({ status: r.status, count: Number(r.c || 0) })),
      moderation: (moderationRows.results || []).map((r) => ({ status: r.status, count: Number(r.c || 0) })),
      deepfake: (deepfakeRows.results || []).map((r) => ({ status: r.status || 'UNSCANNED', count: Number(r.c || 0) })),
      evidence_deepfake: (evidenceDeepfakeRows.results || []).map((r) => ({ status: r.status || 'UNSCANNED', count: Number(r.c || 0) })),
      video_jobs: (jobRows.results || []).map((r) => ({ status: r.status, count: Number(r.c || 0) })),
      failed_jobs: (failedJobs.results || []).map((j) => ({
        id: j.id, post_id: j.post_id == null ? null : String(j.post_id),
        original_url: j.original_url, error: j.error || null,
        attempts: Number(j.attempts || 0), updated_at: j.updated_at,
      })),
      transcription_queue: Number(queuedTranscriptions.c || 0),
    });
  }
  if (path === '/api/v1/admin/ai/backfill' && method === 'POST') {
    const b = await readJson(req);
    const limit = clamp(Number(b.limit) || 100, 1, 300);
    let rows;
    if (Array.isArray(b.post_ids) && b.post_ids.length) {
      const ids = b.post_ids.map(Number).filter((n) => Number.isInteger(n) && n > 0).slice(0, limit);
      rows = (await env.DB.prepare(`SELECT id,text,transcript FROM posts WHERE id IN (${ids.map(() => '?').join(',')})`)
        .bind(...ids).all()).results || [];
    } else {
      rows = (await env.DB.prepare(`SELECT id,text,transcript FROM posts WHERE hidden=0
        AND (embedding_json IS NULL OR embedding_json='' OR embedding_json='null')
        ORDER BY created_at DESC LIMIT ?`).bind(limit).all()).results || [];
    }
    const at = nowIso();
    const stmts = rows.map((p) => env.DB.prepare(`UPDATE posts SET embedding_json=?,
      embedding_status='local-hash', updated_at=? WHERE id=?`)
      .bind(JSON.stringify(embeddingFor(`${p.text || ''} ${p.transcript || ''}`)), at, p.id));
    if (stmts.length) await env.DB.batch(stmts);
    return json({ ok: true, updated: stmts.length, status: 'local-hash' });
  }
  if (path === '/api/v1/admin/moderation' && method === 'GET') {
    const status = String(url.searchParams.get('status') || 'REVIEW').toUpperCase();
    const accepted = ['APPROVED', 'REVIEW', 'BLOCKED', 'PENDING'].includes(status) ? status : 'REVIEW';
    const [counts, posts, openReports, hiddenComments] = await Promise.all([
      env.DB.prepare(`SELECT COALESCE(moderation_status,'APPROVED') status,COUNT(*) c FROM posts GROUP BY status`).all(),
      env.DB.prepare(`SELECT p.id,p.text,p.kind,p.moderation_status,p.hidden,p.created_at,p.media_url,
        p.video_hls_url,u.name author_name,u.email author_email FROM posts p
        LEFT JOIN users u ON u.id=p.author_id WHERE COALESCE(p.moderation_status,'APPROVED')=?
        ORDER BY p.created_at DESC LIMIT 100`).bind(accepted).all(),
      env.DB.prepare(`SELECT r.*,u.name reporter_name,(SELECT text FROM posts WHERE id=r.target_id AND r.target_type='post') post_text
        FROM reports r LEFT JOIN users u ON u.id=r.reporter_id WHERE r.status='OPEN'
        ORDER BY r.created_at DESC LIMIT 50`).all(),
      env.DB.prepare(`SELECT c.id,c.text,c.post_id,c.created_at,u.name author_name FROM post_comments c
        LEFT JOIN users u ON u.id=c.user_id WHERE c.hidden=1 ORDER BY c.created_at DESC LIMIT 50`).all(),
    ]);
    return json({
      ok: true, status: accepted,
      counts: (counts.results || []).map((r) => ({ status: r.status, count: Number(r.c || 0) })),
      posts: (posts.results || []).map((p) => ({
        id: String(p.id), text: p.text, kind: p.kind, status: p.moderation_status,
        hidden: !!p.hidden, created_at: p.created_at, media_url: p.media_url || null,
        video_hls_url: p.video_hls_url || null,
        author_name: p.author_name || 'Member', author_email: p.author_email || null,
      })),
      open_reports: (openReports.results || []).map((r) => ({
        id: String(r.id), target_type: r.target_type, target_id: String(r.target_id),
        reason: r.reason, details: r.details || null, reporter_name: r.reporter_name || null,
        post_text: r.post_text || null, created_at: r.created_at,
      })),
      hidden_comments: (hiddenComments.results || []).map((c) => ({
        id: String(c.id), text: c.text, post_id: String(c.post_id),
        author_name: c.author_name || null, created_at: c.created_at,
      })),
    });
  }
  const behaviorMatch = /^\/api\/v1\/admin\/users\/(\d+)\/behavior$/.exec(path);
  if (behaviorMatch && method === 'GET') {
    const userId = Number(behaviorMatch[1]);
    const days = clamp(parseInt(url.searchParams.get('days') || '30', 10) || 30, 1, 365);
    const since = new Date(Date.now() - days * 86400000).toISOString();
    const user = await one('SELECT * FROM users WHERE id=?', userId);
    if (!user || !user.id) throw new HttpError(404, 'user_not_found', 'User not found.');
    const [summary, events, recent, activity] = await Promise.all([
      env.DB.prepare(`SELECT COUNT(*) c,COUNT(DISTINCT event_type) types FROM analytics_events
        WHERE user_id=? AND created_at>=?`).bind(userId, since).first(),
      env.DB.prepare(`SELECT event_type,COUNT(*) c,
        COALESCE(SUM(duration_ms),0) duration_ms,COALESCE(SUM(value),0) total_value
        FROM analytics_events WHERE user_id=? AND created_at>=?
        GROUP BY event_type ORDER BY c DESC LIMIT 50`).bind(userId, since).all(),
      env.DB.prepare(`SELECT event_type,target_type,target_id,post_id,value,duration_ms,metadata_json,created_at
        FROM analytics_events WHERE user_id=? ORDER BY created_at DESC LIMIT 100`).bind(userId).all(),
      env.DB.prepare(`SELECT
        (SELECT COUNT(*) FROM posts WHERE author_id=?) posts,
        (SELECT COUNT(*) FROM post_comments WHERE user_id=?) comments,
        (SELECT COUNT(*) FROM post_likes WHERE user_id=?) likes,
        (SELECT COUNT(*) FROM follows WHERE follower_id=?) follows,
        (SELECT COUNT(*) FROM post_views WHERE user_id=?) post_views,
        (SELECT COALESCE(SUM(duration_ms),0) FROM analytics_events WHERE user_id=?
          AND event_type IN ('video_watch','media_watch','post_dwell')) watch_ms,
        (SELECT COALESCE(SUM(balance),0) FROM coin_wallets WHERE owner_id=?) mrc_balance`)
        .bind(userId, userId, userId, userId, userId, userId, userId).first(),
    ]);
    return json({
      ok: true, days,
      user: { id: String(user.id), name: user.name, email: user.email, role: user.role,
        country: user.country || null, created_at: user.created_at,
        last_active_at: user.last_active_at || null, suspended: !!user.suspended },
      summary: {
        events: Number(summary?.c || 0), event_types: Number(summary?.types || 0),
        posts: Number(activity?.posts || 0), comments: Number(activity?.comments || 0),
        likes: Number(activity?.likes || 0), follows: Number(activity?.follows || 0),
        post_views: Number(activity?.post_views || 0), watch_ms: Number(activity?.watch_ms || 0),
        mrc_balance: Number(activity?.mrc_balance || 0),
      },
      events: (events.results || []).map((r) => ({
        event_type: r.event_type, count: Number(r.c || 0),
        duration_ms: Number(r.duration_ms || 0), total_value: Number(r.total_value || 0),
      })),
      recent: (recent.results || []).map((r) => ({
        event_type: r.event_type, target_type: r.target_type || null,
        target_id: r.target_id || null, post_id: r.post_id == null ? null : String(r.post_id),
        value: r.value == null ? null : Number(r.value),
        duration_ms: r.duration_ms == null ? null : Number(r.duration_ms),
        metadata_json: r.metadata_json || null, created_at: r.created_at,
      })),
    });
  }
  const exportMatch = /^\/api\/v1\/admin\/exports\/([a-z-]+)\.csv$/.exec(path);
  if (exportMatch && method === 'GET') {
    const kind = exportMatch[1];
    if (kind === 'users') {
      const rows = (await env.DB.prepare(`SELECT id,name,email,role,country,city,email_verified,
        suspended,created_at,last_active_at FROM users ORDER BY id LIMIT 10000`).all()).results || [];
      return csvResponse('masareen-users.csv',
        ['id', 'name', 'email', 'role', 'country', 'city', 'email_verified', 'suspended', 'created_at', 'last_active_at'], rows);
    }
    if (kind === 'transactions') {
      const rows = (await env.DB.prepare(`SELECT t.id,t.owner_id,u.name user_name,u.email user_email,
        t.type,t.amount,t.balance_after,t.reference,t.created_at FROM coin_transactions t
        LEFT JOIN users u ON u.id=t.owner_id ORDER BY t.created_at DESC LIMIT 10000`).all()).results || [];
      return csvResponse('masareen-transactions.csv',
        ['id', 'owner_id', 'user_name', 'user_email', 'type', 'amount', 'balance_after', 'reference', 'created_at'], rows);
    }
    if (kind === 'reports') {
      const rows = (await env.DB.prepare(`SELECT r.id,r.target_type,r.target_id,r.reason,r.details,
        r.status,r.created_at,u.name reporter_name,u.email reporter_email FROM reports r
        LEFT JOIN users u ON u.id=r.reporter_id ORDER BY r.created_at DESC LIMIT 10000`).all()).results || [];
      return csvResponse('masareen-reports.csv',
        ['id', 'target_type', 'target_id', 'reason', 'details', 'status', 'created_at', 'reporter_name', 'reporter_email'], rows);
    }
    if (kind === 'impact') {
      const rows = (await env.DB.prepare(`SELECT sdg,COUNT(*) posts,COALESCE(SUM(impact_value),0) impact
        FROM posts WHERE hidden=0 AND sdg IS NOT NULL GROUP BY sdg ORDER BY sdg`).all()).results || [];
      return csvResponse('masareen-impact.csv', ['sdg', 'posts', 'impact'], rows);
    }
    if (kind === 'analytics') {
      const days = clamp(parseInt(url.searchParams.get('days') || '30', 10) || 30, 1, 365);
      const since = new Date(Date.now() - days * 86400000).toISOString();
      const rows = (await env.DB.prepare(`SELECT event_type,COUNT(*) count,COUNT(DISTINCT user_id) users,
        AVG(duration_ms) avg_ms,SUM(value) total_value FROM analytics_events
        WHERE created_at>=? GROUP BY event_type ORDER BY count DESC`).bind(since).all()).results || [];
      return csvResponse('masareen-analytics.csv',
        ['event_type', 'count', 'users', 'avg_ms', 'total_value'], rows);
    }
    throw new HttpError(404, 'unknown_export', 'Unknown export.');
  }
  if (path === '/api/v1/admin/video-jobs' && method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20) || 'all';
    const limit = clamp(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 1, 300);
    const counts = (await env.DB.prepare('SELECT status,COUNT(*) c FROM video_jobs GROUP BY status').all()).results || [];
    const rows = (status === 'all'
      ? await env.DB.prepare(`SELECT * FROM video_jobs ORDER BY created_at DESC LIMIT ?`).bind(limit).all()
      : await env.DB.prepare(`SELECT * FROM video_jobs WHERE status=? ORDER BY created_at DESC LIMIT ?`)
        .bind(status, limit).all()).results || [];
    return json({
      ok: true,
      counts: Object.fromEntries(counts.map((r) => [r.status, Number(r.c || 0)])),
      jobs: rows.map((j) => ({ id: j.id, user_id: String(j.user_id),
        post_id: j.post_id == null ? null : String(j.post_id), status: j.status,
        original_url: j.original_url, hls_url: j.hls_url || null,
        poster_url: j.poster_url || null,
        duration_seconds: j.duration_seconds == null ? null : Number(j.duration_seconds),
        error: j.error || null, attempts: Number(j.attempts || 0),
        created_at: j.created_at, updated_at: j.updated_at })),
    });
  }
  const requeueJob = /^\/api\/v1\/admin\/video-jobs\/([\w-]+)\/requeue$/.exec(path);
  if (requeueJob && method === 'POST') {
    const id = requeueJob[1];
    const job = await one('SELECT * FROM video_jobs WHERE id=?', id);
    if (!job || !job.id) throw new HttpError(404, 'job_not_found', 'Video job not found.');
    await env.DB.prepare(`UPDATE video_jobs SET status='queued',error=NULL,updated_at=? WHERE id=?`)
      .bind(nowIso(), id).run();
    return json({ ok: true, id, status: 'queued' });
  }
  const transcodePost = /^\/api\/v1\/admin\/posts\/(\d+)\/transcode$/.exec(path);
  if (transcodePost && method === 'POST') {
    const postId = Number(transcodePost[1]);
    const post = await one('SELECT * FROM posts WHERE id=?', postId);
    if (!post || !post.id) throw new HttpError(404, 'post_not_found', 'Post not found.');
    const media = parseJsonValue(post.media_json, []);
    const video = Array.isArray(media) ? media.find((m) => String(m?.type || '').toUpperCase() === 'VIDEO') : null;
    const original = safeMediaUrl(video?.url || post.media_url);
    if (!original) throw new HttpError(400, 'no_video', 'This post has no source video to transcode.');
    const latest = await env.DB.prepare(`SELECT * FROM video_jobs WHERE post_id=?
      ORDER BY created_at DESC LIMIT 1`).bind(postId).first();
    const at = nowIso();
    if (latest && ['queued', 'processing'].includes(latest.status)) {
      return json({ ok: true, id: latest.id, status: latest.status, reused: true });
    }
    if (latest) {
      await env.DB.prepare(`UPDATE video_jobs SET status='queued',original_url=?,hls_url=NULL,
        poster_url=NULL,error=NULL,updated_at=? WHERE id=?`)
        .bind(original, at, latest.id).run();
      return json({ ok: true, id: latest.id, status: 'queued', reused: true });
    }
    const id = crypto.randomUUID();
    await env.DB.prepare(`INSERT INTO video_jobs (id,user_id,post_id,status,original_url,created_at,updated_at)
      VALUES (?,?,?,'queued',?,?,?)`).bind(id, post.author_id, postId, original, at, at).run();
    return json({ ok: true, id, status: 'queued', reused: false });
  }
  const userActionMatch = /^\/api\/v1\/admin\/users\/(\d+)\/action$/.exec(path);
  if (userActionMatch && method === 'POST') {
    const userId = Number(userActionMatch[1]);
    const b = await readJson(req);
    const action = String(b.action || '').toLowerCase();
    const target = await one('SELECT * FROM users WHERE id=?', userId);
    if (!target || !target.id) throw new HttpError(404, 'user_not_found', 'User not found.');
    const at = nowIso();
    if (action === 'verify' || action === 'unverify') {
      await env.DB.prepare('UPDATE users SET email_verified=? WHERE id=?')
        .bind(action === 'verify' ? 1 : 0, userId).run();
    } else if (action === 'tester' || action === 'untester') {
      await env.DB.prepare('UPDATE users SET is_tester=? WHERE id=?')
        .bind(action === 'tester' ? 1 : 0, userId).run();
    } else if (action === 'suspend' || action === 'unsuspend') {
      await env.DB.prepare('UPDATE users SET suspended=?,suspension_reason=? WHERE id=?')
        .bind(action === 'suspend' ? 1 : 0,
          action === 'suspend' ? (clean(b.reason, 300) || 'Platform policy review') : null,
          userId).run();
    } else if (action === 'delete') {
      await env.DB.prepare(`UPDATE users SET email=?,name='Deleted member',handle=?,
        password_hash=NULL,password_salt=NULL,bio=NULL,phone=NULL,national_id=NULL,
        picture=NULL,cover_url=NULL,email_verified=0,profile_complete=0,suspended=1 WHERE id=?`)
        .bind(`deleted-${userId}@anonymous.local`, `deleted-${userId}`, userId).run();
    } else {
      throw new HttpError(400, 'bad_action', 'Unknown user action.');
    }
    await env.DB.prepare(`INSERT INTO admin_audit
      (admin_id,action,target_type,target_id,details,created_at)
      VALUES (?,?,'user',?,?,?)`)
      .bind(admin.id, action, String(userId), clean(b.reason, 300) || null, at).run();
    await notify(env, userId, 'account', 'Your account was updated by the platform',
      `Action: ${action}`, admin.id, null, { link: 'notifications' }).catch(() => {});
    return json({ ok: true, action, user_id: String(userId) });
  }
  const postModerateMatch = /^\/api\/v1\/admin\/posts\/(\d+)\/moderate$/.exec(path);
  if (postModerateMatch && method === 'POST') {
    const postId = Number(postModerateMatch[1]);
    const b = await readJson(req);
    const status = String(b.status || '').toUpperCase();
    if (!['APPROVED', 'REJECTED', 'REVIEW'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose approved, rejected or review.');
    }
    const post = await one('SELECT * FROM posts WHERE id=?', postId);
    if (!post || !post.id) throw new HttpError(404, 'post_not_found', 'Post not found.');
    await env.DB.prepare('UPDATE posts SET moderation_status=?,hidden=? WHERE id=?')
      .bind(status, status === 'REJECTED' ? 1 : 0, postId).run();
    await env.DB.prepare(`INSERT INTO admin_audit
      (admin_id,action,target_type,target_id,details,created_at)
      VALUES (?,?,'post',?,?,?)`)
      .bind(admin.id, `moderate_${status.toLowerCase()}`, String(postId),
        clean(b.reason, 300) || null, nowIso()).run();
    await notify(env, post.author_id, 'moderation',
      status === 'APPROVED' ? 'Your post was approved' : 'Your post needs attention',
      status === 'REJECTED' ? (clean(b.reason, 300) || 'It was removed by the platform.') :
        status === 'REVIEW' ? 'A moderator is reviewing your post.' : 'Your post is live.',
      admin.id, postId, { link: `post:${postId}` }).catch(() => {});
    return json({ ok: true, id: String(postId), moderation_status: status });
  }
  if (path === '/api/v1/admin/leaderboards' && method === 'GET') {
    const status = String(url.searchParams.get('status') || 'PENDING').toUpperCase();
    const rows = (await env.DB.prepare(`SELECT p.*,u.name author_name FROM posts p
      LEFT JOIN users u ON u.id=p.author_id WHERE p.kind='LEADERBOARD'
      AND p.moderation_status=? ORDER BY p.created_at DESC LIMIT 100`)
      .bind(status).all()).results || [];
    return json(rows.map((p) => ({ ...postJson(p, false, null),
      author_name: p.author_name, moderation_status: p.moderation_status })));
  }
  const leaderboardVerdict = /^\/api\/v1\/admin\/leaderboards\/(\d+)\/verdict$/.exec(path);
  if (leaderboardVerdict && method === 'POST') {
    const id = Number(leaderboardVerdict[1]);
    const status = String((await readJson(req)).status || '').toUpperCase();
    if (!['APPROVED', 'REJECTED'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose approved or rejected.');
    }
    const post = await one('SELECT * FROM posts WHERE id=? AND kind=?', id, 'LEADERBOARD');
    if (!post || !post.id) throw new HttpError(404, 'not_found', 'Leaderboard not found.');
    await env.DB.prepare('UPDATE posts SET moderation_status=?,hidden=? WHERE id=?')
      .bind(status, status === 'REJECTED' ? 1 : 0, id).run();
    await notify(env, post.author_id, 'leaderboard',
      status === 'APPROVED' ? 'Your leaderboard is live' : 'Your leaderboard was rejected',
      'Open the feed to see the result.', admin.id, id,
      { link: `post:${id}` }).catch(() => {});
    return json({ ok: true, id, moderation_status: status });
  }
  if (path === '/api/v1/admin/settings' && method === 'GET') {
    return json({
      ok: true,
      settings: await readPlatformSettings(env),
      manifest: await appUpdateManifest(env),
    });
  }
  if (path === '/api/v1/admin/settings' &&
      (method === 'PUT' || method === 'POST')) {
    const body = await readJson(req);
    const incoming = body && typeof body.settings === 'object' && body.settings
      ? body.settings : body || {};
    const at = nowIso();
    const updates = [];
    for (const key of OTA_SETTING_KEYS) {
      if (!(key in incoming)) continue;
      let value = incoming[key];
      if (value == null) value = '';
      value = String(value).slice(0, 500);
      if ((key === 'app_android_build' || key === 'app_ios_build' ||
              key === 'app_min_build') && value !== '' &&
          !/^\d{1,9}$/.test(value)) {
        throw new HttpError(400, 'invalid_build', 'Build numbers must be whole numbers.');
      }
      if (key.endsWith('_url') && value !== '' &&
          !/^https:\/\//i.test(value)) {
        throw new HttpError(400, 'invalid_url', 'Use a secure https:// download URL.');
      }
      updates.push(env.DB.prepare(`INSERT INTO platform_settings(key,value,updated_at,updated_by)
        VALUES(?,?,?,?) ON CONFLICT(key) DO UPDATE SET
        value=excluded.value,updated_at=excluded.updated_at,updated_by=excluded.updated_by`)
         .bind(key, value, at, admin.id));
    }
    if (updates.length) await env.DB.batch(updates);
    return json({ ok: true, settings: await readPlatformSettings(env) });
  }
  if (path === '/api/v1/admin/ota' && method === 'POST') {
    const b = await readJson(req);
    const platform = String(b.platform || 'android').toLowerCase();
    if (!['android', 'ios'].includes(platform)) {
      throw new HttpError(400, 'invalid_platform', 'Choose android or ios.');
    }
    const version = String(b.version || '').trim();
    const build = Number(b.build);
    if (!/^\d+\.\d+\.\d+$/.test(version)) {
      throw new HttpError(400, 'invalid_version', 'Use a version like 0.4.4.');
    }
    if (!Number.isInteger(build) || build < 1) {
      throw new HttpError(400, 'invalid_build', 'Build must be a whole number.');
    }
    const url = String(b.url || '').trim();
    if (!/^https:\/\/.+/i.test(url)) {
      throw new HttpError(400, 'invalid_url', 'Use a secure https:// download URL.');
    }
    const at = nowIso();
    const rows = [
      [`app_${platform}_version`, version],
      [`app_${platform}_build`, String(build)],
      [`app_${platform}_url`, url],
      ['app_notes', String(b.notes || '').slice(0, 500)],
      ['app_force', b.force ? '1' : '0'],
    ];
    await env.DB.batch(rows.map(([key, value]) =>
      env.DB.prepare(`INSERT INTO platform_settings(key,value,updated_at,updated_by)
        VALUES(?,?,?,?) ON CONFLICT(key) DO UPDATE SET
        value=excluded.value,updated_at=excluded.updated_at,updated_by=excluded.updated_by`)
         .bind(key, value, at, admin.id)));
    return json({ ok: true, manifest: await appUpdateManifest(env) });
  }
  if (path === '/api/v1/admin/feedback' && method === 'GET') {
    const status = String(url.searchParams.get('status') || '').toUpperCase();
    const where = ['OPEN', 'REVIEWED', 'CLOSED'].includes(status) ? 'WHERE f.status=?' : '';
    const rows = (await env.DB.prepare(`SELECT f.*,u.name user_name,u.email user_email
      FROM feedback f LEFT JOIN users u ON u.id=f.user_id ${where}
      ORDER BY f.created_at DESC LIMIT 200`)
      .bind(...(where ? [status] : [])).all()).results || [];
    return json(rows.map(feedbackJson));
  }
  const feedbackMatch = /^\/api\/v1\/admin\/feedback\/(\d+)$/.exec(path);
  if (feedbackMatch && (method === 'PATCH' || method === 'POST')) {
    const status = String((await readJson(req)).status || '').toUpperCase();
    if (!['OPEN', 'REVIEWED', 'CLOSED'].includes(status)) {
      throw new HttpError(400, 'invalid_status', 'Choose open, reviewed or closed.');
    }
    await env.DB.prepare('UPDATE feedback SET status=? WHERE id=?')
      .bind(status, Number(feedbackMatch[1])).run();
    const row = await env.DB.prepare(`SELECT f.*,u.name user_name,u.email user_email
      FROM feedback f LEFT JOIN users u ON u.id=f.user_id WHERE f.id=?`)
      .bind(Number(feedbackMatch[1])).first();
    return json(feedbackJson(row));
  }
  if (path === '/api/v1/admin/announcements' && method === 'GET') {
    const rows = (await env.DB.prepare(`SELECT a.*,u.name author_name FROM announcements a
      LEFT JOIN users u ON u.id=a.created_by ORDER BY a.created_at DESC LIMIT 100`).all()).results || [];
    return json(rows.map((a) => announcementJson(a)));
  }
  if (path === '/api/v1/admin/announcements' && method === 'POST') {
    return await createAnnouncement(req, env, admin);
  }
  const announcementMatch = /^\/api\/v1\/admin\/announcements\/(\d+)$/.exec(path);
  if (announcementMatch && method === 'DELETE') {
    await env.DB.prepare('DELETE FROM announcement_dismissals WHERE announcement_id=?')
      .bind(Number(announcementMatch[1])).run();
    await env.DB.prepare('DELETE FROM announcements WHERE id=?')
      .bind(Number(announcementMatch[1])).run();
    return json({ ok: true });
  }
  throw new HttpError(404, 'not_found', 'Unknown admin route.');
}

/* ---------------- courses ---------------- */
const COURSE_LEVELS = new Set(['Beginner', 'Intermediate', 'Advanced']);

function courseJson(c, enrolledByMe) {
  return {
    id: String(c.id), title: c.title, description: c.description || null, provider: c.provider || null,
    level: c.level || 'Beginner', sdg: c.sdg == null ? null : Number(c.sdg),
    lessons: Number(c.lessons || 0), duration_min: Number(c.duration_min || 0),
    is_free: c.is_free == null ? true : Number(c.is_free) !== 0,
    price_mrc: Number(c.price_mrc || 0),
    thumbnail: c.thumbnail || null, status: c.status || 'PUBLISHED',
    enrolled_count: Number(c.enrolled_count || 0), enrolled_by_me: !!enrolledByMe,
    verification_status: c.verification_status || 'APPROVED',
    rejection_reason: c.rejection_reason || null,
    creation_fee_mrc: Number(c.creation_fee_mrc || 0),
    members_preview: c.members_preview || [],
    author: { id: String(c.author_id), name: c.author_name || 'MASAREEN', avatar_url: c.author_picture || null }, created_at: c.created_at,
  };
}

async function listCourses(env, viewer) {
  const own = viewer ? ' OR c.author_id=?' : '';
  const rows = (await env.DB.prepare(`SELECT c.*, u.name author_name, u.picture author_picture,
    (SELECT COUNT(*) FROM course_enrollments e WHERE e.course_id=c.id) enrolled_count
    FROM courses c LEFT JOIN users u ON u.id=c.author_id
    WHERE c.status='PUBLISHED' AND (c.verification_status='APPROVED'${own})
    ORDER BY c.created_at DESC LIMIT 100`)
    .bind(...(viewer ? [viewer.id] : [])).all()).results || [];
  const enrolled = new Set();
  if (viewer) {
    const mine = (await env.DB.prepare('SELECT course_id FROM course_enrollments WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const m of mine) enrolled.add(Number(m.course_id));
  }
  const previews = await memberPreviews(env, 'course_enrollments', 'course_id', rows.map((r) => r.id));
  return rows.map((c) => courseJson({ ...c, members_preview: previews.get(Number(c.id)) || [] }, enrolled.has(Number(c.id))));
}

async function createCourse(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 120);
  const description = clean(b.description, 2000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Course title must be at least 3 characters.');
  assertModerated(title, description);
  const level = COURSE_LEVELS.has(b.level) ? b.level : 'Beginner';
  const sdg = num(b.sdg);
  if (sdg != null && (!Number.isInteger(sdg) || sdg < 1 || sdg > 17)) throw new HttpError(400, 'invalid_sdg', 'Choose an SDG from 1 to 17.');
  const lessons = clamp(parseInt(b.lessons, 10) || 0, 0, 500);
  const duration = clamp(parseInt(b.duration_min, 10) || 0, 0, 60000);
  const isFree = b.is_free === false ? 0 : 1;
  const price = isFree
    ? 0
    : Math.round(clamp(Number(b.price_mrc) || 0, 0, 100000) * 100) / 100;
  const fee = await chargeCreationFee(env, u, 'COURSE', title);
  const verification = fee.admin ? 'APPROVED' : 'PENDING';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO courses
    (author_id,title,description,provider,level,sdg,lessons,duration_min,thumbnail,status,
     verification_status,creation_fee_mrc,is_free,price_mrc,reviewed_at,reviewed_by,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,'PUBLISHED',?,?,?,?,?,?,?)`)
    .bind(u.id, title, description || null, clean(b.provider, 120) || u.name || null, level, sdg, lessons, duration,
      clean(b.thumbnail, 500) || null, verification, fee.fee, isFree, price,
      fee.admin ? at : null, fee.admin ? u.id : null, at).run();
  if (verification === 'PENDING') await alertEntityReview(env, 'Course', r.meta.last_row_id, title, u);
  const row = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(r.meta.last_row_id).first();
  return json(courseJson(row, false), 201);
}

async function enrollCourse(req, env, id) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course || !canViewEntity(env, u, course)) {
    throw new HttpError(404, 'course_not_found', 'Course not found.');
  }
  const has = await env.DB.prepare('SELECT 1 x FROM course_enrollments WHERE course_id=? AND user_id=?').bind(id, u.id).first();
  let charged = 0;
  if (!has) {
    const price = Number(course.price_mrc || 0);
    const paid = Number(course.is_free) === 0 && price > 0;
    if (paid && Number(course.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
      await ensureWallet(env, u.id);
      const wallet = await env.DB.prepare('SELECT balance FROM coin_wallets WHERE owner_id=?')
        .bind(u.id).first();
      if (Number(wallet?.balance || 0) < price) {
        throw new HttpError(400, 'insufficient_balance',
          `This course costs ${price} MRC. Top up your wallet to enroll.`);
      }
      await debitCoins(env, u.id, price, `Course: ${course.title}`);
      await creditCoins(env, course.author_id, price,
        `Course sale: ${course.title}`);
      charged = price;
    }
    await env.DB.prepare('INSERT OR IGNORE INTO course_enrollments (course_id,user_id,created_at) VALUES (?,?,?)')
      .bind(id, u.id, nowIso()).run();
  }
  const count = (await env.DB.prepare('SELECT COUNT(*) c FROM course_enrollments WHERE course_id=?').bind(id).first()).c || 0;
  return json({ ok: true, enrolled: true, enrolled_count: count, charged });
}

async function unenrollCourse(req, env, id) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course) throw new HttpError(404, 'course_not_found', 'Course not found.');
  if (Number(course.is_free) === 0 && Number(course.price_mrc || 0) > 0) {
    throw new HttpError(400, 'paid_course_locked',
      'Paid course enrollments cannot be cancelled. Contact support for a refund.');
  }
  await env.DB.prepare('DELETE FROM course_enrollments WHERE course_id=? AND user_id=?').bind(id, u.id).run();
  const count = (await env.DB.prepare('SELECT COUNT(*) c FROM course_enrollments WHERE course_id=?').bind(id).first()).c || 0;
  return json({ ok: true, enrolled: false, enrolled_count: count });
}

function parseJsonArray(value) {
  if (!value) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function lessonJson(l, locked) {
  return {
    id: String(l.id),
    course_id: String(l.course_id),
    title: l.title,
    description: l.description || null,
    content: locked ? null : (l.content || null),
    video_url: locked ? null : (l.video_url || null),
    duration_min: Number(l.duration_min || 0),
    position: Number(l.position || 0),
    is_preview: !!l.is_preview,
    locked: !!locked,
    media: locked ? [] : parseJsonArray(l.media_json),
    files: parseJsonArray(l.files_json),
    links: parseJsonArray(l.links_json),
    created_at: l.created_at,
  };
}

function lessonLinks(value) {
  const raw = Array.isArray(value) ? value : [];
  return raw.slice(0, 20).map((item) => {
    const src = typeof item === 'string' ? { url: item } : (item || {});
    const url = safeMediaUrl(src.url);
    if (!url) return null;
    return { url, label: clean(src.label || src.title, 140) || url };
  }).filter(Boolean);
}

async function listCourseLessons(req, env, id) {
  const viewer = await currentUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course || !canViewEntity(env, viewer, course)) {
    throw new HttpError(404, 'course_not_found', 'Course not found.');
  }
  const enrolled = viewer
    ? !!(await env.DB.prepare('SELECT 1 x FROM course_enrollments WHERE course_id=? AND user_id=?')
        .bind(id, viewer.id).first())
    : false;
  const manager = viewer &&
    (Number(course.author_id) === Number(viewer.id) || isAdminUser(env, viewer));
  const paid = Number(course.is_free) === 0 && Number(course.price_mrc || 0) > 0;
  const rows = (await env.DB.prepare(
      'SELECT * FROM course_lessons WHERE course_id=? ORDER BY position,id')
      .bind(id).all()).results || [];
  return json({
    ok: true,
    enrolled,
    is_free: !paid,
    price_mrc: Number(course.price_mrc || 0),
    lessons: rows.map((l) => lessonJson(l,
      paid && !enrolled && !manager && !l.is_preview)),
  });
}

async function createCourseLesson(req, env, id) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course) throw new HttpError(404, 'course_not_found', 'Course not found.');
  if (Number(course.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the course author can add lessons.');
  }
  const b = await readJson(req);
  const title = clean(b.title, 140);
  if (title.length < 2) {
    throw new HttpError(400, 'invalid_title', 'Lesson title is required.');
  }
  const duration = clamp(parseInt(b.duration_min, 10) || 0, 0, 600);
  const position = clamp(parseInt(b.position, 10) ||
    ((await env.DB.prepare('SELECT COALESCE(MAX(position),-1)+1 p FROM course_lessons WHERE course_id=?')
      .bind(id).first()).p || 0), 0, 999);
  const at = nowIso();
  const media = normalizeMediaInput(b);
  const files = normalizeFilesInput(b);
  const links = lessonLinks(b.links);
  const mediaVideo = media.find((m) => m.type === 'VIDEO');
  const videoUrl = clean(b.video_url, 1000) ||
    mediaVideo?.hls_url || mediaVideo?.url || null;
  const ins = await env.DB.prepare(`INSERT INTO course_lessons
    (course_id,title,description,content,video_url,duration_min,position,is_preview,media_json,files_json,links_json,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(id, title, clean(b.description, 2000) || null,
      clean(b.content, 20000) || null, videoUrl,
      duration, position, b.is_preview ? 1 : 0,
      media.length ? JSON.stringify(media) : null,
      files.length ? JSON.stringify(files) : null,
      links.length ? JSON.stringify(links) : null, at).run();
  const totals = await env.DB.prepare(
    'SELECT COUNT(*) c,COALESCE(SUM(duration_min),0) d FROM course_lessons WHERE course_id=?')
    .bind(id).first();
  await env.DB.prepare('UPDATE courses SET lessons=?,duration_min=? WHERE id=?')
    .bind(Number(totals.c || 0), Number(totals.d || 0), id).run();
  const row = await env.DB.prepare('SELECT * FROM course_lessons WHERE id=?')
    .bind(ins.meta.last_row_id).first();
  return json(lessonJson(row, false), 201);
}

async function updateCourseLesson(req, env, id, lessonId) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course) throw new HttpError(404, 'course_not_found', 'Course not found.');
  if (Number(course.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the course author can edit lessons.');
  }
  const existing = await env.DB.prepare(
    'SELECT * FROM course_lessons WHERE id=? AND course_id=?').bind(lessonId, id).first();
  if (!existing) throw new HttpError(404, 'lesson_not_found', 'Lesson not found.');
  const b = await readJson(req);
  const title = b.title !== undefined ? clean(b.title, 140) : existing.title;
  if (title.length < 2) throw new HttpError(400, 'invalid_title', 'Lesson title is required.');
  const media = b.media !== undefined ? normalizeMediaInput(b) : parseJsonArray(existing.media_json);
  const files = b.files !== undefined ? normalizeFilesInput(b) : parseJsonArray(existing.files_json);
  const links = b.links !== undefined ? lessonLinks(b.links) : parseJsonArray(existing.links_json);
  const mediaVideo = media.find((m) => m.type === 'VIDEO');
  const videoUrl = b.video_url !== undefined
    ? (clean(b.video_url, 1000) || null)
    : (mediaVideo?.hls_url || mediaVideo?.url || existing.video_url || null);
  const duration = b.duration_min !== undefined
    ? clamp(parseInt(b.duration_min, 10) || 0, 0, 600)
    : Number(existing.duration_min || 0);
  const position = b.position !== undefined
    ? clamp(parseInt(b.position, 10) || 0, 0, 999)
    : Number(existing.position || 0);
  await env.DB.prepare(`UPDATE course_lessons SET
    title=?,description=?,content=?,video_url=?,duration_min=?,position=?,is_preview=?,
    media_json=?,files_json=?,links_json=? WHERE id=? AND course_id=?`)
    .bind(title,
      b.description !== undefined ? (clean(b.description, 2000) || null) : existing.description,
      b.content !== undefined ? (clean(b.content, 20000) || null) : existing.content,
      videoUrl, duration, position,
      b.is_preview !== undefined ? (b.is_preview ? 1 : 0) : Number(existing.is_preview || 0),
      media.length ? JSON.stringify(media) : null,
      files.length ? JSON.stringify(files) : null,
      links.length ? JSON.stringify(links) : null, lessonId, id).run();
  const totals = await env.DB.prepare(
    'SELECT COUNT(*) c,COALESCE(SUM(duration_min),0) d FROM course_lessons WHERE course_id=?')
    .bind(id).first();
  await env.DB.prepare('UPDATE courses SET lessons=?,duration_min=? WHERE id=?')
    .bind(Number(totals.c || 0), Number(totals.d || 0), id).run();
  const row = await env.DB.prepare('SELECT * FROM course_lessons WHERE id=?')
    .bind(lessonId).first();
  return json(lessonJson(row, false));
}

async function deleteCourseLesson(req, env, id, lessonId) {
  const u = await requireUser(req, env);
  const course = await env.DB.prepare('SELECT * FROM courses WHERE id=?').bind(id).first();
  if (!course) throw new HttpError(404, 'course_not_found', 'Course not found.');
  if (Number(course.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the course author can remove lessons.');
  }
  await env.DB.prepare('DELETE FROM course_lessons WHERE id=? AND course_id=?')
    .bind(lessonId, id).run();
  const totals = await env.DB.prepare(
    'SELECT COUNT(*) c,COALESCE(SUM(duration_min),0) d FROM course_lessons WHERE course_id=?')
    .bind(id).first();
  await env.DB.prepare('UPDATE courses SET lessons=?,duration_min=? WHERE id=?')
    .bind(Number(totals.c || 0), Number(totals.d || 0), id).run();
  return json({ ok: true });
}

/* ---------------- events ---------------- */
async function announceEvent(env, ev) {
  if (!ev || !ev.id) return;
  const link = `https://masareen.com/app/events/${ev.id}`;
  const dupe = await env.DB.prepare(
    "SELECT 1 x FROM posts WHERE kind='EVENT' AND link_url=? LIMIT 1")
    .bind(link).first();
  if (dupe) return;
  const when = String(ev.starts_at || '').replace('T', ' ').slice(0, 16);
  const place = ev.is_online
    ? 'Online' : (ev.location || 'See event details');
  const text = `EVENT: ${ev.title}\n${when} UTC - ${place}\n\n` +
    `${String(ev.description || '').slice(0, 600)}\n\n` +
    'Open the Events tab to join.';
  await env.DB.prepare(`INSERT INTO posts
    (author_id,text,kind,sdg,media_url,link_url,created_at)
    VALUES (?,?, 'EVENT',?,?,?,?)`)
    .bind(ev.author_id, text, ev.sdg == null ? null : Number(ev.sdg),
      ev.cover_url || null, link, nowIso()).run();
}

function eventJson(e, attending) {
  return {
    id: String(e.id), title: e.title, description: e.description || null,
    starts_at: e.starts_at, ends_at: e.ends_at || null, location: e.location || null,
    is_online: !!e.is_online, link_url: e.link_url || null,
    sdg: e.sdg == null ? null : Number(e.sdg), capacity: e.capacity == null ? null : Number(e.capacity),
    funding_goal: Number(e.funding_goal || 0), funding_raised: Number(e.funding_raised || 0),
    program_id: e.program_id == null ? null : String(e.program_id),
    program_title: e.program_title || null,
    event_type: e.event_type || 'EVENT',
    source_url: e.source_url || null,
    activity_verified: !!e.activity_verified_at,
    activity_verified_at: e.activity_verified_at || null,
    rating_avg: Number(e.rating_avg || 0),
    rating_count: Number(e.rating_count || 0),
    participants_count: Number(e.participants_count || 0),
    booths_count: Number(e.booths_count || 0),
    status: e.status || 'PUBLISHED', attendees_count: Number(e.attendees_count || 0),
    attending: !!attending,
    verification_status: e.verification_status || 'APPROVED',
    rejection_reason: e.rejection_reason || null,
    creation_fee_mrc: Number(e.creation_fee_mrc || 0),
    cover_url: e.cover_url || null,
    members_preview: e.members_preview || [],
    author: { id: String(e.author_id), name: e.author_name || 'MASAREEN', avatar_url: e.author_picture || null },
    created_at: e.created_at,
  };
}

async function listEvents(env, viewer, opts = {}) {
  const own = viewer ? ' OR e.author_id=?' : '';
  const filters = [`e.status='PUBLISHED'`, `(e.verification_status='APPROVED'${own})`];
  const args = viewer ? [viewer.id] : [];
  if (!opts.includePast) filters.push('e.starts_at > ?');
  if (!opts.includePast) args.push(nowIso());
  if (opts.type) {
    filters.push('e.event_type=?');
    args.push(opts.type);
  }
  if (opts.q) {
    filters.push('(e.title LIKE ? OR e.description LIKE ? OR e.location LIKE ?)');
    const like = `%${opts.q}%`;
    args.push(like, like, like);
  }
  const rows = (await env.DB.prepare(`SELECT e.*, u.name author_name, u.picture author_picture,
    p.title program_title,
    (SELECT COUNT(*) FROM event_attendees a WHERE a.event_id=e.id) attendees_count,
    (SELECT COUNT(*) FROM event_participants x WHERE x.event_id=e.id) participants_count,
    (SELECT COUNT(*) FROM event_booths b WHERE b.event_id=e.id AND b.active=1) booths_count,
    (SELECT COALESCE(AVG(r.rating),0) FROM event_ratings r WHERE r.event_id=e.id) rating_avg,
    (SELECT COUNT(*) FROM event_ratings r WHERE r.event_id=e.id) rating_count
    FROM events e LEFT JOIN users u ON u.id=e.author_id
    LEFT JOIN programs p ON p.id=e.program_id
    WHERE ${filters.join(' AND ')}
    ORDER BY CASE WHEN e.starts_at >= ? THEN 0 ELSE 1 END, e.starts_at ASC LIMIT 100`)
    .bind(...args, nowIso()).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const going = (await env.DB.prepare('SELECT event_id FROM event_attendees WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const g of going) mine.add(Number(g.event_id));
  }
  const previews = await memberPreviews(env, 'event_attendees', 'event_id', rows.map((r) => r.id));
  return rows.map((e) => eventJson({
    ...e,
    members_preview: previews.get(Number(e.id)) || [],
  }, mine.has(Number(e.id))));
}

async function createEvent(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 140);
  const description = clean(b.description, 2000);
  const starts = clean(b.starts_at, 40);
  const ends = clean(b.ends_at, 40);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Event title must be at least 3 characters.');
  assertModerated(title, description);
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
  const eventType = String(b.event_type || 'EVENT').toUpperCase();
  if (!EVENT_TYPES.has(eventType)) {
    throw new HttpError(400, 'invalid_event_type', 'Choose a valid event type.');
  }
  let programId = num(b.program_id);
  if (programId != null) {
    const program = await env.DB.prepare('SELECT id FROM programs WHERE id=?').bind(programId).first();
    if (!program) programId = null;
  }
  const fee = await chargeCreationFee(env, u, 'EVENT', title);
  const verification = fee.admin ? 'APPROVED' : 'PENDING';
  const at = nowIso();
  const fundingGoal = Math.max(0, Math.min(1000000, num(b.funding_goal) || 0));
  const r = await env.DB.prepare(`INSERT INTO events
    (author_id,title,description,starts_at,ends_at,location,is_online,link_url,cover_url,sdg,capacity,
     funding_goal,program_id,event_type,source_url,status,verification_status,creation_fee_mrc,
     reviewed_at,reviewed_by,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PUBLISHED',?,?,?,?,?)`)
    .bind(u.id, title, description || null, new Date(t).toISOString(), ends ? new Date(Date.parse(ends)).toISOString() : null,
      location || null, isOnline ? 1 : 0, link || null, clean(b.cover_url, 500) || null, sdg, capacity != null ? clamp(Math.trunc(capacity), 1, 1000000) : null,
      fundingGoal, programId, eventType, safeMediaUrl(b.source_url),
      verification, fee.fee, fee.admin ? at : null, fee.admin ? u.id : null, at).run();
  if (verification === 'PENDING') await alertEntityReview(env, 'Event', r.meta.last_row_id, title, u);
  const row = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(r.meta.last_row_id).first();
  if (verification === 'APPROVED' && b.announce !== false) {
    await announceEvent(env, row).catch(() => {});
  }
  return json(eventJson(row, true), 201);
}

async function joinEvent(req, env, id) {
  const u = await requireUser(req, env);
  const ev = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(id).first();
  if (!ev || !canViewEntity(env, u, ev)) {
    throw new HttpError(404, 'event_not_found', 'Event not found.');
  }
  const has = await env.DB.prepare('SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).first();
  if (has) {
    await env.DB.prepare('DELETE FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).run();
  } else {
    const count = (await env.DB.prepare('SELECT COUNT(*) c FROM event_attendees WHERE event_id=?').bind(id).first()).c || 0;
    if (ev.capacity != null && count >= ev.capacity) throw new HttpError(409, 'event_full', 'This event is full.');
    await env.DB.prepare('INSERT OR IGNORE INTO event_attendees (event_id,user_id,created_at) VALUES (?,?,?)')
      .bind(id, u.id, nowIso()).run();
    if (Number(ev.author_id) !== Number(u.id)) {
      await notify(env, ev.author_id, 'event', `${u.name || 'Someone'} is attending ${ev.title}`, 'A new attendee joined your event.', u.id, null);
    }
  }
  const count = (await env.DB.prepare('SELECT COUNT(*) c FROM event_attendees WHERE event_id=?').bind(id).first()).c || 0;
  return json({ ok: true, attending: !has, attendees_count: count });
}

/* ---------------- persistent event hubs, booths and verified activity ---------------- */
const EVENT_TYPES = new Set(['EVENT', 'EXPO', 'CONFERENCE', 'PODCAST', 'PROGRAM',
  'JOB_FAIR', 'FESTIVAL']);
const EVENT_ROLES = new Set(['ORGANIZER', 'HOST', 'EXHIBITOR', 'SPONSOR', 'SPEAKER',
  'STUDENT', 'MEDIA', 'VISITOR', 'PARTNER']);
const EVENT_MEDIA_TYPES = new Set(['IMAGE', 'VIDEO', 'PODCAST', 'REPORT', 'NEWS']);
const BOOTH_CTA_TYPES = new Set(['QUOTE', 'TRIAL', 'BOOK', 'CONTACT']);
const BOOTH_LEAD_STATUSES = new Set(['NEW', 'CONTACTED', 'QUALIFIED', 'CLOSED']);
const EVENT_ROLE_ORDER = {
  ORGANIZER: 0, HOST: 1, SPONSOR: 2, EXHIBITOR: 3, SPEAKER: 4,
  STUDENT: 5, MEDIA: 6, PARTNER: 7, VISITOR: 8,
};

function eventRole(value) {
  const role = String(value || '').trim().toUpperCase().replace(/[^A-Z_]/g, '_');
  return EVENT_ROLES.has(role) ? role : null;
}

function eventParticipantJson(p) {
  return {
    id: String(p.id), event_id: String(p.event_id),
    user_id: String(p.user_id), name: p.name || 'Member',
    handle: p.handle || null, avatar_url: p.picture || null,
    role: p.role, role_title: p.role_title || null, status: p.status,
    contribution: p.contribution || null,
    evidence: parseJsonValue(p.evidence_json, []),
    verification_note: p.verification_note || null,
    verified_by: p.verified_by == null ? null : String(p.verified_by),
    verifier_name: p.verifier_name || null, verified_at: p.verified_at || null,
    created_at: p.created_at,
  };
}

function eventMediaJson(m) {
  return {
    id: String(m.id), event_id: String(m.event_id), type: m.type,
    title: m.title || null, description: m.description || null,
    url: m.url, thumbnail_url: m.thumbnail_url || null, created_at: m.created_at,
  };
}

function boothJson(b, viewerId) {
  return {
    id: String(b.id), event_id: String(b.event_id),
    owner: { id: String(b.user_id), name: b.owner_name || 'Exhibitor',
      avatar_url: b.owner_picture || null, handle: b.owner_handle || null },
    title: b.title, description: b.description || null,
    logo_url: b.logo_url || null, cover_url: b.cover_url || null,
    video_url: b.video_url || null, cta_type: b.cta_type || 'QUOTE',
    cta_label: b.cta_label || null,
    trial_price_mrc: Number(b.trial_price_mrc || 0),
    products: parseJsonValue(b.products_json, []),
    active: !!b.active, views: Number(b.views || 0),
    interactions: Number(b.interactions || 0),
    leads_count: Number(b.leads_count || 0),
    is_owner: viewerId != null && Number(b.user_id) === Number(viewerId),
    created_at: b.created_at, updated_at: b.updated_at,
  };
}

function eventRatingJson(r) {
  return {
    id: String(r.id), event_id: String(r.event_id), user_id: String(r.user_id),
    name: r.name || 'Member', avatar_url: r.picture || null,
    role: r.role || null, rating: Number(r.rating || 0),
    review: r.review || null, created_at: r.created_at,
  };
}

async function grantEventReward(env, { eventId, userId, boothId = null, kind, amount, reference }) {
  if (!userId || !Number.isFinite(Number(amount)) || Number(amount) <= 0) return 0;
  const value = Math.round(Number(amount) * 100) / 100;
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT OR IGNORE INTO event_rewards
    (event_id,user_id,booth_id,kind,amount,reference,created_at)
    VALUES (?,?,?,?,?,?,?)`)
    .bind(eventId, userId, boothId, kind, value, String(reference), at).run();
  if (!ins.meta?.changes) return 0;
  await creditCoins(env, userId, value,
    `Event reward · ${String(reference).replaceAll('_', ' ')}`);
  return value;
}

async function organizerReputation(env, userId) {
  const user = await env.DB.prepare('SELECT id,name,picture,handle FROM users WHERE id=?')
    .bind(userId).first();
  if (!user) return null;
  const scope = `(e.author_id=? OR EXISTS (SELECT 1 FROM event_participants h
    WHERE h.event_id=e.id AND h.user_id=? AND h.role='HOST'
      AND h.status IN ('CONFIRMED','VERIFIED')))`;
  const total = Number((await env.DB.prepare(
    `SELECT COUNT(*) c FROM events e WHERE ${scope} AND e.status='PUBLISHED'`)
    .bind(userId, userId).first())?.c || 0);
  const verified = Number((await env.DB.prepare(
    `SELECT COUNT(*) c FROM events e WHERE ${scope} AND e.status='PUBLISHED'
      AND e.activity_verified_at IS NOT NULL`)
    .bind(userId, userId).first())?.c || 0);
  const clients = Number((await env.DB.prepare(
    `SELECT COUNT(DISTINCT p.user_id) c FROM event_participants p
      JOIN events e ON e.id=p.event_id
      WHERE ${scope} AND p.role IN ('HOST','SPONSOR','EXHIBITOR','PARTNER')
        AND p.status IN ('CONFIRMED','VERIFIED') AND p.user_id<>?`)
    .bind(userId, userId, userId).first())?.c || 0);
  const ratingRow = await env.DB.prepare(
    `SELECT COUNT(*) c, COALESCE(AVG(r.rating),0) avg FROM event_ratings r
      JOIN events e ON e.id=r.event_id WHERE ${scope}`)
    .bind(userId, userId).first();
  const counts = (await env.DB.prepare(
    `SELECT author_id, SUM(CASE WHEN EXISTS (SELECT 1 FROM event_participants p
      WHERE p.event_id=e.id AND p.role='ORGANIZER' AND p.status='VERIFIED')
      THEN 1 ELSE 0 END) v FROM events e WHERE e.status='PUBLISHED' GROUP BY author_id`)
    .all()).results || [];
  const rank = 1 + counts.filter((c) => Number(c.v || 0) > verified).length;
  return {
    organizer_id: String(user.id), name: user.name,
    handle: user.handle || null, avatar_url: user.picture || null,
    total_events: total, verified_events: verified, clients,
    rating_avg: Math.round(Number(ratingRow?.avg || 0) * 10) / 10,
    rating_count: Number(ratingRow?.c || 0),
    verification_rate: total ? Math.round((verified / total) * 100) : 0,
    rank, badge: verified >= 5 ? 'PLATINUM' : verified >= 2 ? 'GOLD' : verified >= 1 ? 'VERIFIED' : 'EMERGING',
  };
}

async function eventDetailData(req, env, id) {
  const viewer = await currentUser(req, env);
  const row = await env.DB.prepare(`SELECT e.*, u.name author_name, u.picture author_picture,
    p.title program_title,
    (SELECT COUNT(*) FROM event_attendees a WHERE a.event_id=e.id) attendees_count,
    (SELECT COUNT(*) FROM event_participants x WHERE x.event_id=e.id) participants_count,
    (SELECT COUNT(*) FROM event_booths b WHERE b.event_id=e.id AND b.active=1) booths_count,
    (SELECT COALESCE(AVG(r.rating),0) FROM event_ratings r WHERE r.event_id=e.id) rating_avg,
    (SELECT COUNT(*) FROM event_ratings r WHERE r.event_id=e.id) rating_count
    FROM events e LEFT JOIN users u ON u.id=e.author_id
    LEFT JOIN programs p ON p.id=e.program_id WHERE e.id=?`).bind(id).first();
  if (!row) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const isOwner = viewer && Number(row.author_id) === Number(viewer.id);
  if (!['APPROVED', 'PENDING'].includes(row.verification_status) &&
      !isOwner && !isAdminUser(env, viewer)) {
    throw new HttpError(404, 'event_not_found', 'Event not found.');
  }
  const attending = viewer
    ? await env.DB.prepare('SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?')
      .bind(id, viewer.id).first()
    : null;
  const participants = (await env.DB.prepare(`SELECT ep.*, u.name, u.picture, u.handle,
      u.role user_role, v.name verifier_name
    FROM event_participants ep JOIN users u ON u.id=ep.user_id
    LEFT JOIN users v ON v.id=ep.verified_by
    WHERE ep.event_id=? ORDER BY ep.created_at ASC`).bind(id).all()).results || [];
  participants.sort((a, b) =>
    (EVENT_ROLE_ORDER[a.role] ?? 99) - (EVENT_ROLE_ORDER[b.role] ?? 99));
  const media = (await env.DB.prepare(`SELECT * FROM event_media WHERE event_id=?
    ORDER BY created_at DESC LIMIT 100`).bind(id).all()).results || [];
  const booths = (await env.DB.prepare(`SELECT b.*, u.name owner_name, u.picture owner_picture,
      u.handle owner_handle FROM event_booths b JOIN users u ON u.id=b.user_id
    WHERE b.event_id=? AND (b.active=1 OR b.user_id=?)
    ORDER BY b.views DESC, b.created_at DESC LIMIT 100`)
    .bind(id, viewer?.id || 0).all()).results || [];
  const ratings = (await env.DB.prepare(`SELECT r.*, u.name, u.picture FROM event_ratings r
    JOIN users u ON u.id=r.user_id WHERE r.event_id=?
    ORDER BY r.created_at DESC LIMIT 50`).bind(id).all()).results || [];
  const rewardRows = (await env.DB.prepare(`SELECT kind,COUNT(*) c,COALESCE(SUM(amount),0) total
    FROM event_rewards WHERE event_id=? GROUP BY kind`).bind(id).all()).results || [];
  const myParticipation = viewer
    ? participants.find((p) => Number(p.user_id) === Number(viewer.id)) : null;
  const host = participants.find((p) => p.role === 'HOST' &&
    ['CONFIRMED', 'VERIFIED'].includes(p.status));
  const hostId = host ? Number(host.user_id) : null;
  const program = row.program_id
    ? await env.DB.prepare(`SELECT id,title,description,category,organization,cover_url,status
      FROM programs WHERE id=?`).bind(row.program_id).first()
    : null;
  const projects = (await env.DB.prepare(`SELECT id,title,description,category,goal,raised,
      project_type,institution_id,academic_year,student_names,supervisor,status
    FROM projects WHERE verification_status='APPROVED'
      AND (${row.program_id ? 'program_id=?' : 'institution_id=?'})
    ORDER BY created_at DESC LIMIT 20`)
    .bind(row.program_id || hostId || 0).all()).results || [];
  const research = (await env.DB.prepare(`SELECT r.id,r.title,r.stage,r.summary,r.status,
      r.post_id,r.project_id,r.institution_id,r.media_url,r.created_at,u.name researcher_name
    FROM research_stages r LEFT JOIN users u ON u.id=r.researcher_id
    WHERE r.institution_id=? OR r.researcher_id IN
      (SELECT user_id FROM event_participants WHERE event_id=?)
    ORDER BY r.created_at DESC LIMIT 20`).bind(hostId || 0, id).all()).results || [];
  const opportunityAuthors = [...new Set([Number(row.author_id), hostId].filter(Boolean))];
  const opportunities = (await env.DB.prepare(`SELECT id,title,type,location,is_remote,deadline,
      cover_url FROM opportunities WHERE verification_status='APPROVED'
      AND author_id IN (${opportunityAuthors.map(() => '?').join(',')})
      ORDER BY created_at DESC LIMIT 20`).bind(...opportunityAuthors).all()).results || [];
  const podcastEpisodes = (await env.DB.prepare(`SELECT e.*,s.title show_title
    FROM podcast_episodes e JOIN podcast_shows s ON s.id=e.show_id
    WHERE e.event_id=? AND e.status='PUBLISHED'
    ORDER BY e.published_at DESC LIMIT 20`).bind(id).all()).results || [];
  const vodVideos = (await env.DB.prepare(`SELECT v.*,u.name owner_name,u.picture owner_picture
    FROM vod_videos v JOIN users u ON u.id=v.owner_id
    WHERE v.event_id=? AND v.status='PUBLISHED'
    ORDER BY v.created_at DESC LIMIT 20`).bind(id).all()).results || [];
  const isModerator = !!viewer && await isEntityModerator(env, viewer, 'EVENT', id);
  const canVerify = !!viewer && (isOwner || isAdminUser(env, viewer) || isModerator ||
    participants.some((p) => Number(p.user_id) === Number(viewer.id) &&
      p.role === 'HOST' && ['CONFIRMED', 'VERIFIED'].includes(p.status)));
  return {
    ...eventJson({ ...row, members_preview: [] }, !!attending),
    is_owner: !!isOwner,
    can_manage: !!isOwner || isAdminUser(env, viewer),
    can_moderate: !!isOwner || isAdminUser(env, viewer) || isModerator,
    can_remove_event: !!isOwner || isAdminUser(env, viewer) ||
      (!!viewer && await isEntityModerator(env, viewer, 'EVENT', id, 'remove_event')),
    can_verify: canVerify,
    can_create_booth: !!viewer && (isOwner || isAdminUser(env, viewer) ||
      participants.some((p) => Number(p.user_id) === Number(viewer.id) &&
        ['EXHIBITOR', 'SPONSOR', 'PARTNER'].includes(p.role) &&
        ['CONFIRMED', 'VERIFIED'].includes(p.status))),
    my_participation: myParticipation ? eventParticipantJson(myParticipation) : null,
    host: host ? eventParticipantJson(host) : null,
    participants: participants.map(eventParticipantJson),
    media: media.map(eventMediaJson),
    booths: booths.map((b) => boothJson(b, viewer?.id)),
    ratings: ratings.map(eventRatingJson),
    program: program ? {
      id: String(program.id), title: program.title,
      description: program.description || null, category: program.category || null,
      organization: program.organization || null, cover_url: program.cover_url || null,
      status: program.status || 'ACTIVE',
    } : null,
    projects: projects.map((p) => ({
      id: String(p.id), title: p.title, description: p.description || null,
      category: p.category || null, goal: Number(p.goal || 0),
      raised: Number(p.raised || 0), project_type: p.project_type || 'COMMUNITY',
      institution_id: p.institution_id == null ? null : String(p.institution_id),
      academic_year: p.academic_year || null, student_names: p.student_names || null,
      supervisor: p.supervisor || null, status: p.status || 'ACTIVE',
    })),
    research_stages: research.map(researchStageJson),
    opportunities: opportunities.map((o) => ({
      id: String(o.id), title: o.title, type: o.type || null,
      location: o.location || null, is_remote: !!o.is_remote,
      deadline: o.deadline || null, cover_url: o.cover_url || null,
    })),
    podcast_episodes: podcastEpisodes.map(podcastEpisodeJson),
    vod_videos: vodVideos.map((v) => vodJson(v, viewer?.id)),
    reward_summary: rewardRows.map((r) => ({
      kind: r.kind, count: Number(r.c || 0), total: Number(r.total || 0),
    })),
    organizer_reputation: row.author_id
      ? await organizerReputation(env, row.author_id) : null,
  };
}

async function addEventParticipant(req, env, eventId) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(eventId).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  if (Number(event.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the organizer can add contributors.');
  }
  const b = await readJson(req);
  const role = eventRole(b.role);
  if (!role) throw new HttpError(400, 'invalid_role', 'Choose a valid event role.');
  const userId = num(b.user_id);
  const target = userId == null ? null : await env.DB.prepare(
    'SELECT id,name FROM users WHERE id=?').bind(userId).first();
  if (!target) throw new HttpError(400, 'invalid_user', 'Choose a member to add.');
  const at = nowIso();
  const status = Number(userId) === Number(u.id) ? 'CONFIRMED' : 'INVITED';
  await env.DB.prepare(`INSERT INTO event_participants
    (event_id,user_id,role,role_title,status,contribution,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?)
    ON CONFLICT(event_id,user_id,role) DO UPDATE SET role_title=excluded.role_title,
      contribution=excluded.contribution, updated_at=excluded.updated_at`)
    .bind(eventId, userId, role, clean(b.role_title, 120) || null, status,
      clean(b.contribution, 1000) || null, at, at).run();
  await saveEntityLinks(env, 'event', String(eventId),
    [{ target_type: 'user', target_id: String(userId), relation: role }], u);
  await saveEntityLinks(env, 'user', String(userId),
    [{ target_type: 'event', target_id: String(eventId), relation: role }], u);
  if (Number(userId) !== Number(u.id)) {
    await notify(env, userId, 'event', `${u.name || 'An organizer'} invited you to ${event.title}`,
      `Role: ${role}. Open the event to confirm and add evidence.`, u.id, null,
      { link: `event:${eventId}`, entityType: 'event', entityId: String(eventId) }).catch(() => {});
  }
  const row = await env.DB.prepare(`SELECT ep.*,u.name,u.picture,u.handle
    FROM event_participants ep JOIN users u ON u.id=ep.user_id
    WHERE ep.event_id=? AND ep.user_id=? AND ep.role=?`)
    .bind(eventId, userId, role).first();
  return json(eventParticipantJson(row), 201);
}

async function addEventEvidence(req, env, eventId, participantId) {
  const u = await requireUser(req, env);
  const row = await env.DB.prepare(`SELECT ep.*,e.title event_title,e.author_id
    FROM event_participants ep JOIN events e ON e.id=ep.event_id
    WHERE ep.id=? AND ep.event_id=?`).bind(participantId, eventId).first();
  if (!row) throw new HttpError(404, 'participant_not_found', 'Contribution not found.');
  if (Number(row.user_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'You can only document your own contribution.');
  }
  const b = await readJson(req);
  const contribution = clean(b.contribution, 2000);
  const evidence = Array.isArray(b.evidence) ? b.evidence.slice(0, 20).map((item) => {
    if (typeof item === 'string') return { url: safeMediaUrl(item), label: null };
    return {
      url: safeMediaUrl(item?.url),
      label: clean(item?.label, 160) || null,
      type: clean(item?.type, 40) || 'LINK',
    };
  }).filter((item) => item.url) : [];
  if (!contribution && !evidence.length) {
    throw new HttpError(400, 'evidence_required', 'Add a summary or at least one proof link.');
  }
  const scan = await deepfakeScan(env, {
    text: contribution, title: row.event_title,
    urls: evidence.map((e) => e.url).filter(Boolean),
  });
  if (scan.nsfw_verdict === 'BLOCKED') {
    throw new HttpError(400, 'nsfw_blocked',
      'This proof contains explicit material and cannot be submitted.');
  }
  const at = nowIso();
  await env.DB.prepare(`UPDATE event_participants SET contribution=?,evidence_json=?,
    status='SUBMITTED',deepfake_score=?,deepfake_verdict=?,deepfake_signals_json=?,
    updated_at=? WHERE id=?`)
    .bind(contribution || row.contribution || null, JSON.stringify(evidence),
      scan.score, scan.verdict,
      JSON.stringify({ nsfw_score: scan.nsfw_score, nsfw_verdict: scan.nsfw_verdict,
        signals: scan.signals, provider: scan.provider }),
      at, participantId).run();
  const hosts = (await env.DB.prepare(`SELECT user_id FROM event_participants
    WHERE event_id=? AND role='HOST' AND status IN ('CONFIRMED','VERIFIED')`)
    .bind(eventId).all()).results || [];
  const recipients = new Set([Number(row.author_id), ...hosts.map((h) => Number(h.user_id))]);
  for (const recipient of recipients) {
    if (recipient === Number(u.id)) continue;
    await notify(env, recipient, 'event', `${u.name || 'A contributor'} submitted proof`,
      `${row.event_title}: ${contribution || 'Evidence attached'}`.slice(0, 300),
      u.id, null, { link: `event:${eventId}`, entityType: 'event', entityId: String(eventId) })
      .catch(() => {});
  }
  return json({ ok: true, status: 'SUBMITTED' });
}

async function eventParticipantVerdict(req, env, eventId, participantId) {
  const u = await requireUser(req, env);
  const row = await env.DB.prepare(`SELECT ep.*,e.author_id,e.title event_title
    FROM event_participants ep JOIN events e ON e.id=ep.event_id
    WHERE ep.id=? AND ep.event_id=?`).bind(participantId, eventId).first();
  if (!row) throw new HttpError(404, 'participant_not_found', 'Contribution not found.');
  const b = await readJson(req);
  const status = String(b.status || 'VERIFIED').toUpperCase();
  if (!['VERIFIED', 'REJECTED'].includes(status)) {
    throw new HttpError(400, 'invalid_status', 'Verdict must be VERIFIED or REJECTED.');
  }
  const isHost = (await env.DB.prepare(`SELECT 1 x FROM event_participants
    WHERE event_id=? AND user_id=? AND role='HOST' AND status IN ('CONFIRMED','VERIFIED')`)
    .bind(eventId, u.id).first());
  if (Number(row.author_id) !== Number(u.id) && !isHost && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the host, organizer or an admin can verify.');
  }
  if (Number(row.user_id) === Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(400, 'self_verification', 'You cannot verify your own contribution.');
  }
  if (status === 'VERIFIED' && row.deepfake_verdict === 'LIKELY_AI' &&
      b.override_deepfake !== true) {
    throw new HttpError(409, 'deepfake_review_required',
      'Deepfake detection flagged this contribution. Re-scan or explicitly override first.');
  }
  const at = nowIso();
  await env.DB.prepare(`UPDATE event_participants SET status=?,verification_note=?,
    verified_by=?,verified_at=?,updated_at=? WHERE id=?`)
    .bind(status, clean(b.note, 500) || null, u.id, at, at, participantId).run();
  if (status === 'VERIFIED') {
    const organizerId = Number((await env.DB.prepare(`SELECT user_id FROM event_participants
      WHERE event_id=? AND role='ORGANIZER' ORDER BY created_at LIMIT 1`)
      .bind(eventId).first())?.user_id || row.author_id);
    if (row.role === 'ORGANIZER') {
      await env.DB.prepare(`UPDATE events SET activity_verified_at=?,activity_verified_by=?
        WHERE id=?`).bind(at, u.id, eventId).run();
      await grantEventReward(env, { eventId, userId: u.id, kind: 'VERIFY_ORGANIZER',
        amount: 50, reference: `host_${eventId}` });
      await grantEventReward(env, { eventId, userId: organizerId, kind: 'VERIFY_ORGANIZER',
        amount: 50, reference: `organizer_${eventId}` });
    } else {
      await grantEventReward(env, { eventId, userId: u.id, kind: 'VERIFY_CONTRIBUTOR',
        amount: 10, reference: `verifier_${participantId}` });
      await grantEventReward(env, { eventId, userId: organizerId, kind: 'VERIFY_CONTRIBUTOR',
        amount: 10, reference: `organizer_${participantId}` });
      await grantEventReward(env, { eventId, userId: row.user_id, kind: 'VERIFIED_CONTRIBUTOR',
        amount: 10, reference: `participant_${participantId}` });
    }
  }
  await notify(env, row.user_id, 'event',
    status === 'VERIFIED' ? 'Your contribution was verified' : 'Contribution needs attention',
    `${row.event_title} · ${row.role}${b.note ? ` · ${clean(b.note, 180)}` : ''}`,
    u.id, null, { link: `event:${eventId}`, entityType: 'event', entityId: String(eventId) })
    .catch(() => {});
  return json({ ok: true, status });
}

async function confirmEventParticipant(req, env, eventId, participantId) {
  const u = await requireUser(req, env);
  const row = await env.DB.prepare(`SELECT ep.*,e.author_id,e.title event_title
    FROM event_participants ep JOIN events e ON e.id=ep.event_id
    WHERE ep.id=? AND ep.event_id=?`).bind(participantId, eventId).first();
  if (!row) throw new HttpError(404, 'participant_not_found', 'Invitation not found.');
  if (Number(row.user_id) !== Number(u.id)) {
    throw new HttpError(403, 'not_allowed', 'This invitation belongs to another member.');
  }
  await env.DB.prepare(`UPDATE event_participants SET status='CONFIRMED',updated_at=?
    WHERE id=?`).bind(nowIso(), participantId).run();
  await notify(env, row.author_id, 'event', `${u.name || 'A contributor'} confirmed`,
    `${row.event_title} · ${row.role}`, u.id, null,
    { link: `event:${eventId}`, entityType: 'event', entityId: String(eventId) }).catch(() => {});
  return json({ ok: true, status: 'CONFIRMED' });
}

async function addEventMedia(req, env, eventId) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(eventId).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const allowed = Number(event.author_id) === Number(u.id) || isAdminUser(env, u) ||
    await env.DB.prepare(`SELECT 1 x FROM event_participants WHERE event_id=? AND user_id=?
      AND role IN ('HOST','MEDIA','STUDENT','SPEAKER') AND status IN ('CONFIRMED','VERIFIED')`)
      .bind(eventId, u.id).first();
  if (!allowed) throw new HttpError(403, 'not_allowed', 'Only event contributors can add media.');
  const b = await readJson(req);
  const url = safeMediaUrl(b.url);
  if (!url) throw new HttpError(400, 'invalid_url', 'Add a valid image, video or link.');
  const type = String(b.type || 'IMAGE').toUpperCase();
  if (!EVENT_MEDIA_TYPES.has(type)) {
    throw new HttpError(400, 'invalid_media_type', 'Choose a valid media type.');
  }
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO event_media
    (event_id,created_by,type,title,description,url,thumbnail_url,created_at)
    VALUES (?,?,?,?,?,?,?,?)`)
    .bind(eventId, u.id, type, clean(b.title, 160) || null, clean(b.description, 500) || null,
      url, safeMediaUrl(b.thumbnail_url), at).run();
  const row = await env.DB.prepare('SELECT * FROM event_media WHERE id=?')
    .bind(ins.meta.last_row_id).first();
  return json(eventMediaJson(row), 201);
}

async function createEventBooth(req, env, eventId) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(eventId).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const isOwner = Number(event.author_id) === Number(u.id) || isAdminUser(env, u);
  const participant = await env.DB.prepare(`SELECT 1 x FROM event_participants
    WHERE event_id=? AND user_id=? AND role IN ('EXHIBITOR','SPONSOR','PARTNER')
      AND status IN ('CONFIRMED','VERIFIED')`).bind(eventId, u.id).first();
  if (!isOwner && !participant) {
    throw new HttpError(403, 'not_allowed',
      'Only confirmed exhibitors, sponsors or the organizer can open a booth.');
  }
  const b = await readJson(req);
  const title = clean(b.title, 140);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Add a booth title.');
  const ownerId = isOwner && num(b.user_id) ? num(b.user_id) : u.id;
  const ctaType = String(b.cta_type || 'QUOTE').toUpperCase();
  if (!BOOTH_CTA_TYPES.has(ctaType)) {
    throw new HttpError(400, 'invalid_cta', 'Choose a valid booth action.');
  }
  const products = Array.isArray(b.products) ? b.products.slice(0, 20).map((p) => ({
    title: clean(p?.title, 120) || 'Product',
    description: clean(p?.description, 500) || null,
    image_url: safeMediaUrl(p?.image_url),
    price_note: clean(p?.price_note, 80) || null,
  })) : [];
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO event_booths
    (event_id,user_id,title,description,logo_url,cover_url,video_url,cta_type,cta_label,
     trial_price_mrc,products_json,active,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,0,?,?)`)
    .bind(eventId, ownerId, title, clean(b.description, 3000) || null,
      safeMediaUrl(b.logo_url), safeMediaUrl(b.cover_url), safeMediaUrl(b.video_url),
      ctaType, clean(b.cta_label, 80) || null,
      Math.max(0, Math.min(100000, Number(b.trial_price_mrc) || 0)),
      products.length ? JSON.stringify(products) : null, at, at).run();
  if (Number(ownerId) !== Number(u.id)) {
    await notify(env, ownerId, 'event', `${u.name || 'An organizer'} created your booth`,
      `${event.title} · activate it with MRC to go live.`, u.id, null,
      { link: `event:${eventId}`, entityType: 'event', entityId: String(eventId) }).catch(() => {});
  }
  const row = await env.DB.prepare(`SELECT b.*,u.name owner_name,u.picture owner_picture,
    u.handle owner_handle FROM event_booths b JOIN users u ON u.id=b.user_id
    WHERE b.id=?`).bind(ins.meta.last_row_id).first();
  return json(boothJson(row, u.id), 201);
}

async function getBoothDetail(req, env, id) {
  const viewer = await currentUser(req, env);
  const row = await env.DB.prepare(`SELECT b.*,u.name owner_name,u.picture owner_picture,
    u.handle owner_handle,e.title event_title,e.author_id event_author_id,
    e.activity_verified_at event_activity_verified_at
    FROM event_booths b JOIN users u ON u.id=b.user_id
    JOIN events e ON e.id=b.event_id WHERE b.id=?`).bind(id).first();
  if (!row) throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  if (!row.active && Number(row.user_id) !== Number(viewer?.id) &&
      Number(row.event_author_id) !== Number(viewer?.id) && !isAdminUser(env, viewer)) {
    throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  }
  if (viewer && Number(row.user_id) !== Number(viewer.id)) {
    const seen = await env.DB.prepare(`INSERT OR IGNORE INTO booth_views
      (booth_id,user_id,created_at) VALUES (?,?,?)`).bind(id, viewer.id, nowIso()).run();
    if (seen.meta?.changes) {
      await env.DB.prepare('UPDATE event_booths SET views=views+1 WHERE id=?').bind(id).run();
      row.views = Number(row.views || 0) + 1;
    }
  }
  return {
    ...boothJson(row, viewer?.id),
    event: { id: String(row.event_id), title: row.event_title },
    event_activity_verified: !!row.event_activity_verified_at,
    can_manage: Number(row.event_author_id) === Number(viewer?.id) || isAdminUser(env, viewer),
  };
}

async function activateEventBooth(req, env, id) {
  const u = await requireUser(req, env);
  const row = await env.DB.prepare('SELECT * FROM event_booths WHERE id=?').bind(id).first();
  if (!row) throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  if (Number(row.user_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the booth owner can activate it.');
  }
  if (!row.active) {
    await debitCoins(env, u.id, 25, `Booth activation #${id}`);
    await env.DB.prepare('UPDATE event_booths SET active=1,updated_at=? WHERE id=?')
      .bind(nowIso(), id).run();
  }
  const updated = await env.DB.prepare(`SELECT b.*,u.name owner_name,u.picture owner_picture,
    u.handle owner_handle FROM event_booths b JOIN users u ON u.id=b.user_id
    WHERE b.id=?`).bind(id).first();
  return json(boothJson(updated, u.id));
}

async function createBoothLead(req, env, id) {
  const u = await requireUser(req, env);
  const booth = await env.DB.prepare(`SELECT b.*,e.title event_title
    FROM event_booths b JOIN events e ON e.id=b.event_id WHERE b.id=?`).bind(id).first();
  if (!booth || !booth.active) throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  if (Number(booth.user_id) === Number(u.id)) {
    throw new HttpError(400, 'own_booth', 'You cannot submit a lead to your own booth.');
  }
  const b = await readJson(req);
  const type = String(b.type || booth.cta_type || 'QUOTE').toUpperCase();
  if (!BOOTH_CTA_TYPES.has(type)) {
    throw new HttpError(400, 'invalid_type', 'Choose a valid request type.');
  }
  const name = clean(b.name, 120) || u.name || 'Visitor';
  const email = clean(b.email, 160) || u.email || null;
  const phone = clean(b.phone, 40) || null;
  const message = clean(b.message, 2000) || null;
  let charged = 0;
  const price = Number(booth.trial_price_mrc || 0);
  if (type === 'TRIAL' && price > 0) {
    await debitCoins(env, u.id, price, `Booth trial #${id}`);
    await creditCoins(env, booth.user_id, price, `Booth trial #${id}`);
    charged = price;
  }
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO booth_leads
    (booth_id,event_id,user_id,name,email,phone,message,type,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,'NEW',?)`)
    .bind(id, booth.event_id, u.id, name, email, phone, message, type, at).run();
  await env.DB.prepare(`UPDATE event_booths SET leads_count=leads_count+1,
    interactions=interactions+1,updated_at=? WHERE id=?`).bind(at, id).run();
  const reward = await grantEventReward(env, { eventId: booth.event_id, userId: u.id,
    boothId: id, kind: 'EXPERIENCE', amount: 2, reference: `booth_${id}` });
  await notify(env, booth.user_id, 'booth_lead', `${name} requested ${type.toLowerCase()}`,
    `${booth.event_title} · ${booth.title}`, u.id, null,
    { link: `booth:${id}`, entityType: 'event_booth', entityId: String(id) }).catch(() => {});
  return json({ ok: true, lead_id: String(ins.meta.last_row_id), charged,
    reward_mrc: reward, wallet: await walletJson(env, u.id) }, 201);
}

async function listBoothLeads(req, env, id) {
  const u = await requireUser(req, env);
  const booth = await env.DB.prepare(`SELECT b.*,e.author_id FROM event_booths b
    JOIN events e ON e.id=b.event_id WHERE b.id=?`).bind(id).first();
  if (!booth) throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  if (Number(booth.user_id) !== Number(u.id) && Number(booth.author_id) !== Number(u.id) &&
      !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the booth owner can read leads.');
  }
  const rows = (await env.DB.prepare(`SELECT l.*,u.name member_name FROM booth_leads l
    LEFT JOIN users u ON u.id=l.user_id WHERE l.booth_id=?
    ORDER BY l.created_at DESC LIMIT 200`).bind(id).all()).results || [];
  return json(rows.map((r) => ({
    id: String(r.id), booth_id: String(r.booth_id), event_id: String(r.event_id),
    user_id: r.user_id == null ? null : String(r.user_id),
    name: r.name, email: r.email, phone: r.phone, message: r.message,
    type: r.type, status: r.status, member_name: r.member_name || null,
    created_at: r.created_at,
  })));
}

async function updateBoothLeadStatus(req, env, boothId, leadId) {
  const u = await requireUser(req, env);
  const booth = await env.DB.prepare(`SELECT b.*,e.author_id FROM event_booths b
    JOIN events e ON e.id=b.event_id WHERE b.id=?`).bind(boothId).first();
  if (!booth) throw new HttpError(404, 'booth_not_found', 'Booth not found.');
  if (Number(booth.user_id) !== Number(u.id) && Number(booth.author_id) !== Number(u.id) &&
      !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the booth owner can update leads.');
  }
  const b = await readJson(req);
  const status = String(b.status || '').toUpperCase();
  if (!BOOTH_LEAD_STATUSES.has(status)) {
    throw new HttpError(400, 'invalid_status', 'Choose a valid lead status.');
  }
  await env.DB.prepare('UPDATE booth_leads SET status=? WHERE id=? AND booth_id=?')
    .bind(status, leadId, boothId).run();
  return json({ ok: true, status });
}

async function rateEvent(req, env, id) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(id).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const attended = await env.DB.prepare(
    'SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).first();
  const participant = await env.DB.prepare(`SELECT role FROM event_participants
    WHERE event_id=? AND user_id=? AND status IN ('CONFIRMED','VERIFIED')`)
    .bind(id, u.id).first();
  if (!attended && !participant) {
    throw new HttpError(403, 'attendee_only', 'Only attendees and contributors can rate this event.');
  }
  const b = await readJson(req);
  const rating = clamp(parseInt(b.rating, 10) || 0, 1, 5);
  const review = clean(b.review, 1200) || null;
  const at = nowIso();
  await env.DB.prepare(`INSERT INTO event_ratings
    (event_id,user_id,rating,review,role,created_at) VALUES (?,?,?,?,?,?)
    ON CONFLICT(event_id,user_id) DO UPDATE SET rating=excluded.rating,
      review=excluded.review, role=excluded.role, created_at=excluded.created_at`)
    .bind(id, u.id, rating, review, participant?.role || 'VISITOR', at).run();
  if (Number(event.author_id) !== Number(u.id)) {
    await notify(env, event.author_id, 'event', `${u.name || 'Someone'} rated ${event.title}`,
      `${rating}/5${review ? ` · ${review}` : ''}`.slice(0, 300), u.id, null,
      { link: `event:${id}`, entityType: 'event', entityId: String(id) }).catch(() => {});
  }
  return json({ ok: true, rating });
}

async function claimEventAttendance(req, env, id) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(id).first();
  if (!event) throw new HttpError(404, 'event_not_found', 'Event not found.');
  const attended = await env.DB.prepare(
    'SELECT 1 x FROM event_attendees WHERE event_id=? AND user_id=?').bind(id, u.id).first();
  if (!attended) throw new HttpError(400, 'join_first', 'Join the event before claiming attendance.');
  const reward = await grantEventReward(env, { eventId: id, userId: u.id,
    kind: 'ATTENDANCE', amount: 5, reference: `attendance_${id}` });
  return json({ ok: true, reward_mrc: reward, wallet: await walletJson(env, u.id) });
}

async function getManagedEvents(req, env) {
  const u = await requireUser(req, env);
  const admin = isAdminUser(env, u);
  const scope = admin ? '1=1'
    : `(e.author_id=? OR EXISTS (SELECT 1 FROM event_participants x
      WHERE x.event_id=e.id AND x.user_id=? AND x.status IN ('CONFIRMED','VERIFIED')))`;
  const rows = (await env.DB.prepare(`SELECT e.*,u.name author_name,u.picture author_picture,
    p.title program_title,
    (SELECT COUNT(*) FROM event_attendees a WHERE a.event_id=e.id) attendees_count,
    (SELECT COUNT(*) FROM event_participants x WHERE x.event_id=e.id) participants_count,
    (SELECT COUNT(*) FROM event_participants x WHERE x.event_id=e.id AND x.status='VERIFIED') verified_count,
    (SELECT COUNT(*) FROM event_booths b WHERE b.event_id=e.id AND b.active=1) booths_count,
    (SELECT COALESCE(SUM(b.leads_count),0) FROM event_booths b WHERE b.event_id=e.id) leads_count,
    (SELECT COALESCE(AVG(r.rating),0) FROM event_ratings r WHERE r.event_id=e.id) rating_avg,
    (SELECT COUNT(*) FROM event_ratings r WHERE r.event_id=e.id) rating_count,
    (SELECT role FROM event_participants x WHERE x.event_id=e.id AND x.user_id=? LIMIT 1) my_role
    FROM events e LEFT JOIN users u ON u.id=e.author_id
    LEFT JOIN programs p ON p.id=e.program_id
    WHERE ${scope}
    ORDER BY e.starts_at DESC LIMIT 200`)
    .bind(u.id, ...(admin ? [] : [u.id, u.id])).all()).results || [];
  const events = rows.map((e) => ({ ...eventJson(e, false),
    my_role: e.my_role || (Number(e.author_id) === Number(u.id) ? 'ORGANIZER'
      : admin ? 'ADMIN' : null),
    verified_count: Number(e.verified_count || 0),
    leads_count: Number(e.leads_count || 0),
  }));
  return json({
    events,
    reputation: await organizerReputation(env, u.id),
    summary: {
      events: events.length,
      verified_events: events.filter((e) => e.activity_verified).length,
      booths: events.reduce((sum, e) => sum + e.booths_count, 0),
      leads: events.reduce((sum, e) => sum + Number(e.leads_count || 0), 0),
      attendees: events.reduce((sum, e) => sum + e.attendees_count, 0),
      rating_avg: events.length
        ? Math.round((events.reduce((sum, e) => sum + e.rating_avg, 0) / events.length) * 10) / 10
        : 0,
    },
  });
}

async function getEventDashboard(req, env, id) {
  const data = await eventDetailData(req, env, id);
  if (!data.can_manage && !data.can_verify) {
    throw new HttpError(403, 'not_allowed', 'Only event managers can open this dashboard.');
  }
  const booths = (await env.DB.prepare(`SELECT b.*,u.name owner_name,u.picture owner_picture,
    u.handle owner_handle FROM event_booths b JOIN users u ON u.id=b.user_id
    WHERE b.event_id=? ORDER BY b.created_at DESC`).bind(id).all()).results || [];
  const leads = (await env.DB.prepare(`SELECT l.*,b.title booth_title,u.name member_name
    FROM booth_leads l JOIN event_booths b ON b.id=l.booth_id
    LEFT JOIN users u ON u.id=l.user_id WHERE l.event_id=?
    ORDER BY l.created_at DESC LIMIT 200`).bind(id).all()).results || [];
  const rewards = (await env.DB.prepare(`SELECT r.*,u.name FROM event_rewards r
    LEFT JOIN users u ON u.id=r.user_id WHERE r.event_id=?
    ORDER BY r.created_at DESC LIMIT 200`).bind(id).all()).results || [];
  return json({
    ...data,
    booths: booths.map((b) => boothJson(b, null)),
    leads: leads.map((l) => ({
      id: String(l.id), booth_id: String(l.booth_id), booth_title: l.booth_title,
      user_id: l.user_id == null ? null : String(l.user_id), name: l.name,
      email: l.email, phone: l.phone, message: l.message, type: l.type,
      status: l.status, member_name: l.member_name || null, created_at: l.created_at,
    })),
    rewards: rewards.map((r) => ({
      id: String(r.id), user_id: String(r.user_id), user_name: r.name || null,
      booth_id: r.booth_id == null ? null : String(r.booth_id), kind: r.kind,
      amount: Number(r.amount || 0), reference: r.reference, created_at: r.created_at,
    })),
    stats: {
      participants: data.participants.length,
      verified_participants: data.participants.filter((p) => p.status === 'VERIFIED').length,
      pending_verifications: data.participants.filter((p) =>
        ['SUBMITTED', 'UNDER_REVIEW'].includes(p.status)).length,
      booths: booths.length,
      active_booths: booths.filter((b) => b.active).length,
      leads: leads.length,
      new_leads: leads.filter((l) => l.status === 'NEW').length,
      reviews: data.ratings.length,
      reward_total: rewards.reduce((sum, r) => sum + Number(r.amount || 0), 0),
    },
  });
}

/* ---------------- podcasts and VOD entities ---------------- */
function podcastShowJson(s) {
  return {
    id: String(s.id), owner_id: String(s.owner_id),
    owner_name: s.owner_name || null, owner_avatar: s.owner_picture || null,
    title: s.title, slug: s.slug || null, description: s.description || null,
    cover_url: s.cover_url || null, category: s.category || null,
    sdg: s.sdg == null ? null : Number(s.sdg), language: s.language || 'ar',
    status: s.status || 'ACTIVE',
    verification_status: s.verification_status || 'PENDING',
    verified: s.verification_status === 'APPROVED',
    episodes_count: Number(s.episodes_count || 0),
    latest_episode_at: s.latest_episode_at || null,
    created_at: s.created_at,
  };
}

function podcastEpisodeJson(e) {
  return {
    id: String(e.id), show_id: String(e.show_id),
    show_title: e.show_title || null, event_id: e.event_id == null ? null : String(e.event_id),
    event_title: e.event_title || null, title: e.title,
    description: e.description || null, audio_url: e.audio_url || null,
    video_url: e.video_url || null, cover_url: e.cover_url || null,
    duration_sec: Number(e.duration_sec || 0),
    season_number: Number(e.season_number || 1),
    episode_number: Number(e.episode_number || 1),
    transcript: e.transcript || null,
    guests: parseJsonValue(e.guests_json, []),
    published_at: e.published_at || e.created_at,
    status: e.status || 'PUBLISHED',
    verification_status: e.verification_status || 'PENDING',
    verified: e.verification_status === 'APPROVED',
    created_at: e.created_at,
  };
}

function vodJson(v, viewerId) {
  return {
    id: String(v.id), owner_id: String(v.owner_id),
    owner_name: v.owner_name || null, owner_avatar: v.owner_picture || null,
    event_id: v.event_id == null ? null : String(v.event_id),
    event_title: v.event_title || null,
    program_id: v.program_id == null ? null : String(v.program_id),
    title: v.title, description: v.description || null,
    cover_url: v.cover_url || null, video_url: v.video_url || null,
    hls_url: v.hls_url || null, duration_sec: Number(v.duration_sec || 0),
    category: v.category || null, sdg: v.sdg == null ? null : Number(v.sdg),
    views: Number(v.views || 0), status: v.status || 'PUBLISHED',
    verification_status: v.verification_status || 'PENDING',
    verified: v.verification_status === 'APPROVED',
    is_owner: viewerId != null && Number(v.owner_id) === Number(viewerId),
    created_at: v.created_at,
  };
}

async function listPodcastShows(env, url) {
  const q = clean(url.searchParams.get('q'), 80);
  const filters = ["s.status='ACTIVE'"];
  const args = [];
  if (q) {
    filters.push('(s.title LIKE ? OR s.description LIKE ?)');
    args.push(`%${q}%`, `%${q}%`);
  }
  const rows = (await env.DB.prepare(`SELECT s.*,u.name owner_name,u.picture owner_picture,
    (SELECT COUNT(*) FROM podcast_episodes e WHERE e.show_id=s.id AND e.status='PUBLISHED') episodes_count,
    (SELECT MAX(e.published_at) FROM podcast_episodes e WHERE e.show_id=s.id) latest_episode_at
    FROM podcast_shows s JOIN users u ON u.id=s.owner_id
    WHERE ${filters.join(' AND ')} ORDER BY latest_episode_at DESC LIMIT 100`)
    .bind(...args).all()).results || [];
  return rows.map(podcastShowJson);
}

async function getPodcastShow(env, id) {
  const row = await env.DB.prepare(`SELECT s.*,u.name owner_name,u.picture owner_picture,
    (SELECT COUNT(*) FROM podcast_episodes e WHERE e.show_id=s.id AND e.status='PUBLISHED') episodes_count
    FROM podcast_shows s JOIN users u ON u.id=s.owner_id WHERE s.id=?`).bind(id).first();
  if (!row) throw new HttpError(404, 'podcast_not_found', 'Podcast not found.');
  const episodes = (await env.DB.prepare(`SELECT e.*,s.title show_title,ev.title event_title
    FROM podcast_episodes e JOIN podcast_shows s ON s.id=e.show_id
    LEFT JOIN events ev ON ev.id=e.event_id
    WHERE e.show_id=? AND e.status='PUBLISHED'
    ORDER BY e.season_number DESC,e.episode_number DESC LIMIT 200`).bind(id).all()).results || [];
  return { ...podcastShowJson(row), episodes: episodes.map(podcastEpisodeJson) };
}

async function createPodcastShow(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Add a podcast title.');
  const approved = isAdminUser(env, u) ||
    ['ORGANIZATION', 'INSTITUTION', 'UNIVERSITY', 'MEDIA', 'GOVERNMENT'].includes(u.role);
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO podcast_shows
    (owner_id,title,slug,description,cover_url,category,sdg,language,status,verification_status,created_at)
    VALUES (?,?,?,?,?,?,?,?,'ACTIVE',?,?)`)
    .bind(u.id, title, clean(b.slug, 80) || null, clean(b.description, 3000) || null,
      safeMediaUrl(b.cover_url), clean(b.category, 80) || null, validSdg(b.sdg),
      clean(b.language, 10) || 'ar', approved ? 'APPROVED' : 'PENDING', at).run();
  const row = await env.DB.prepare(`SELECT s.*,u.name owner_name,u.picture owner_picture
    FROM podcast_shows s JOIN users u ON u.id=s.owner_id WHERE s.id=?`)
    .bind(ins.meta.last_row_id).first();
  return json(podcastShowJson(row), 201);
}

async function createPodcastEpisode(req, env, showId) {
  const u = await requireUser(req, env);
  const show = await env.DB.prepare('SELECT * FROM podcast_shows WHERE id=?').bind(showId).first();
  if (!show) throw new HttpError(404, 'podcast_not_found', 'Podcast not found.');
  if (Number(show.owner_id) !== Number(u.id) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'not_allowed', 'Only the show owner can publish episodes.');
  }
  const b = await readJson(req);
  const title = clean(b.title, 180);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Add an episode title.');
  const audio = safeMediaUrl(b.audio_url);
  const video = safeMediaUrl(b.video_url);
  if (!audio && !video) throw new HttpError(400, 'media_required', 'Add an audio or video URL.');
  let eventId = num(b.event_id);
  if (eventId != null) {
    const event = await env.DB.prepare('SELECT id FROM events WHERE id=?').bind(eventId).first();
    if (!event) eventId = null;
  }
  const guests = Array.isArray(b.guests) ? b.guests.slice(0, 10).map((g) => clean(g, 120)).filter(Boolean) : [];
  const at = nowIso();
  const verification = show.verification_status === 'APPROVED' ? 'APPROVED' : 'PENDING';
  const ins = await env.DB.prepare(`INSERT INTO podcast_episodes
    (show_id,event_id,title,description,audio_url,video_url,cover_url,duration_sec,
     season_number,episode_number,transcript,guests_json,published_at,status,verification_status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,'PUBLISHED',?,?)`)
    .bind(showId, eventId, title, clean(b.description, 4000) || null, audio, video,
      safeMediaUrl(b.cover_url) || show.cover_url || null,
      clamp(parseInt(b.duration_sec, 10) || 0, 0, 86400),
      Math.max(1, parseInt(b.season_number, 10) || 1),
      Math.max(1, parseInt(b.episode_number, 10) || 1),
      clean(b.transcript, 20000) || null,
      guests.length ? JSON.stringify(guests) : null, at, verification, at).run();
  if (eventId) {
    await saveEntityLinks(env, 'podcast_episode', String(ins.meta.last_row_id),
      [{ target_type: 'event', target_id: String(eventId), relation: 'COVERS' }], u);
  }
  const row = await env.DB.prepare(`SELECT e.*,s.title show_title,ev.title event_title
    FROM podcast_episodes e JOIN podcast_shows s ON s.id=e.show_id
    LEFT JOIN events ev ON ev.id=e.event_id WHERE e.id=?`).bind(ins.meta.last_row_id).first();
  return json(podcastEpisodeJson(row), 201);
}

async function listVod(env, url, viewer) {
  const q = clean(url.searchParams.get('q'), 80);
  const eventId = num(url.searchParams.get('event_id'));
  const filters = ["v.status='PUBLISHED'"];
  const args = [];
  if (q) {
    filters.push('(v.title LIKE ? OR v.description LIKE ?)');
    args.push(`%${q}%`, `%${q}%`);
  }
  if (eventId != null) {
    filters.push('v.event_id=?');
    args.push(eventId);
  }
  const rows = (await env.DB.prepare(`SELECT v.*,u.name owner_name,u.picture owner_picture,
    ev.title event_title FROM vod_videos v JOIN users u ON u.id=v.owner_id
    LEFT JOIN events ev ON ev.id=v.event_id
    WHERE ${filters.join(' AND ')} ORDER BY v.created_at DESC LIMIT 100`)
    .bind(...args).all()).results || [];
  return rows.map((v) => vodJson(v, viewer?.id));
}

async function createVod(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 180);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Add a video title.');
  const videoUrl = safeMediaUrl(b.video_url);
  const hlsUrl = safeMediaUrl(b.hls_url);
  if (!videoUrl && !hlsUrl) throw new HttpError(400, 'media_required', 'Add an MP4 or HLS URL.');
  let eventId = num(b.event_id);
  if (eventId != null) {
    const event = await env.DB.prepare('SELECT id FROM events WHERE id=?').bind(eventId).first();
    if (!event) eventId = null;
  }
  let programId = num(b.program_id);
  if (programId != null) {
    const program = await env.DB.prepare('SELECT id FROM programs WHERE id=?').bind(programId).first();
    if (!program) programId = null;
  }
  const approved = isAdminUser(env, u) ||
    ['ORGANIZATION', 'INSTITUTION', 'UNIVERSITY', 'MEDIA', 'GOVERNMENT'].includes(u.role);
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO vod_videos
    (owner_id,event_id,program_id,title,description,cover_url,video_url,hls_url,duration_sec,
     category,sdg,status,verification_status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,'PUBLISHED',?,?)`)
    .bind(u.id, eventId, programId, title, clean(b.description, 4000) || null,
      safeMediaUrl(b.cover_url), videoUrl, hlsUrl,
      clamp(parseInt(b.duration_sec, 10) || 0, 0, 86400), clean(b.category, 80) || null,
      validSdg(b.sdg), approved ? 'APPROVED' : 'PENDING', at).run();
  if (eventId) {
    await saveEntityLinks(env, 'vod', String(ins.meta.last_row_id),
      [{ target_type: 'event', target_id: String(eventId), relation: 'COVERS' }], u);
  }
  const row = await env.DB.prepare(`SELECT v.*,u.name owner_name,u.picture owner_picture,
    ev.title event_title FROM vod_videos v JOIN users u ON u.id=v.owner_id
    LEFT JOIN events ev ON ev.id=v.event_id WHERE v.id=?`).bind(ins.meta.last_row_id).first();
  return json(vodJson(row, u.id), 201);
}

async function getVodDetail(req, env, id) {
  const viewer = await currentUser(req, env);
  const row = await env.DB.prepare(`SELECT v.*,u.name owner_name,u.picture owner_picture,
    ev.title event_title FROM vod_videos v JOIN users u ON u.id=v.owner_id
    LEFT JOIN events ev ON ev.id=v.event_id WHERE v.id=?`).bind(id).first();
  if (!row || row.status !== 'PUBLISHED') {
    throw new HttpError(404, 'vod_not_found', 'Video not found.');
  }
  await env.DB.prepare('UPDATE vod_videos SET views=views+1 WHERE id=?').bind(id).run();
  return json(vodJson({ ...row, views: Number(row.views || 0) + 1 }, viewer?.id));
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
    verification_status: p.verification_status || 'APPROVED',
    rejection_reason: p.rejection_reason || null,
    creation_fee_mrc: Number(p.creation_fee_mrc || 0),
    cover_url: p.cover_url || null,
    members_preview: p.members_preview || [],
    author: { id: String(p.author_id), name: p.author_name || 'MASAREEN', avatar_url: p.author_picture || null },
    created_at: p.created_at,
  };
}

async function listPrograms(env, viewer) {
  const own = viewer ? ' OR p.author_id=?' : '';
  const rows = (await env.DB.prepare(`SELECT p.*, u.name author_name, u.picture author_picture,
    (SELECT COUNT(*) FROM program_members m WHERE m.program_id=p.id) members_count,
    (SELECT COUNT(*) FROM projects x WHERE x.program_id=p.id) projects_count,
    (SELECT COUNT(*) FROM tasks t WHERE t.program_id=p.id) tasks_count
    FROM programs p LEFT JOIN users u ON u.id=p.author_id
    WHERE (p.verification_status='APPROVED'${own})
    ORDER BY p.created_at DESC LIMIT 100`)
    .bind(...(viewer ? [viewer.id] : [])).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const joined = (await env.DB.prepare('SELECT program_id FROM program_members WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const j of joined) mine.add(Number(j.program_id));
  }
  const previews = await memberPreviews(env, 'program_members', 'program_id', rows.map((r) => r.id));
  return rows.map((p) => programJson({ ...p, members_preview: previews.get(Number(p.id)) || [] }, mine.has(Number(p.id))));
}

function taskJson(t) {
  return {
    id: String(t.id), program_id: t.program_id == null ? null : String(t.program_id),
    project_id: t.project_id == null ? null : String(t.project_id),
    author_id: t.author_id == null ? null : String(t.author_id),
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
  if (!p || !canViewEntity(env, viewer, p)) {
    throw new HttpError(404, 'program_not_found', 'Program not found.');
  }
  const member = viewer ? await env.DB.prepare('SELECT 1 x FROM program_members WHERE program_id=? AND user_id=?')
    .bind(id, viewer.id).first() : null;
  const out = programJson(p, !!member);
  const tasks = (await env.DB.prepare(`SELECT t.*, u.name assignee_name FROM tasks t
    LEFT JOIN users u ON u.id=t.assignee_id WHERE t.program_id=? ORDER BY t.created_at ASC`).bind(id).all()).results || [];
  const projects = (await env.DB.prepare(`SELECT x.*, u.name owner_name,
    (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members
    FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.program_id=? ORDER BY x.created_at DESC`)
    .bind(id).all()).results || [];
  const myProjects = new Set();
  if (viewer) {
    const joined = (await env.DB.prepare('SELECT project_id FROM project_members WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const j of joined) myProjects.add(Number(j.project_id));
  }
  out.tasks = tasks.map(taskJson);
  out.projects = projects.map((x) => ({ ...projectJson(x), joined: myProjects.has(Number(x.id)) }));
  return out;
}

async function listProgramMembers(env, id) {
  const rows = (await env.DB.prepare(`SELECT u.id,u.name,u.picture,u.role,pm.role program_role,pm.created_at
    FROM program_members pm JOIN users u ON u.id=pm.user_id
    WHERE pm.program_id=? ORDER BY pm.created_at ASC LIMIT 200`).bind(id).all()).results || [];
  return rows.map((m) => ({ id: String(m.id), name: m.name || 'MASAREEN member',
    picture: m.picture || null, role: m.role || null, program_role: m.program_role || 'MEMBER',
    joined_at: m.created_at }));
}

async function leaveProgram(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM programs WHERE id=?').bind(id).first();
  if (!p) throw new HttpError(404, 'program_not_found', 'Program not found.');
  const membership = await env.DB.prepare('SELECT role FROM program_members WHERE program_id=? AND user_id=?')
    .bind(id, u.id).first();
  if (!membership) return json(await getProgram(env, u, id));
  if (membership.role === 'OWNER') {
    throw new HttpError(409, 'owner_cannot_leave', 'The program owner cannot leave. Transfer ownership first.');
  }
  await env.DB.prepare('DELETE FROM program_members WHERE program_id=? AND user_id=?').bind(id, u.id).run();
  return json(await getProgram(env, u, id));
}

async function createProgram(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 140);
  const description = clean(b.description, 3000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Program title must be at least 3 characters.');
  assertModerated(title, description);
  const goals = Array.isArray(b.sdg_goals) ? b.sdg_goals : [];
  const sdg = validSdg(b.sdg != null ? b.sdg : goals[0]);
  const status = PROGRAM_STATUSES.has(b.status) ? b.status : 'ACTIVE';
  let organization = clean(b.organization, 140) || null;
  if (!organization && b.organization_id != null) {
    const orgUser = await env.DB.prepare('SELECT name, org FROM users WHERE id=?').bind(Number(b.organization_id)).first();
    organization = (orgUser && (orgUser.org || orgUser.name)) || null;
  }
  organization = organization || u.org || null;
  const fee = await chargeCreationFee(env, u, 'PROGRAM', title);
  const verification = fee.admin ? 'APPROVED' : 'PENDING';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO programs
    (author_id,title,description,category,organization,cover_url,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,
     verification_status,creation_fee_mrc,reviewed_at,reviewed_by,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(u.id, title, description || null, clean(b.category, 80) || null,
      organization, clean(b.cover_url, 500) || null, sdg, status,
      Math.max(0, num(b.budget) || 0), clean(b.currency, 8) || 'EGP',
      clean(b.country, 60) || u.country || null, clean(b.governorate, 80) || null,
      clean(b.start_date, 40) || null, clean(b.end_date, 40) || null,
      Math.max(0, Math.trunc(num(b.target_beneficiaries) || 0)),
      verification, fee.fee, fee.admin ? at : null, fee.admin ? u.id : null, at).run();
  const id = r.meta.last_row_id;
  if (verification === 'PENDING') await alertEntityReview(env, 'Program', id, title, u);
  await env.DB.prepare('INSERT OR IGNORE INTO program_members (program_id,user_id,role,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, 'OWNER', at).run();
  return json(await getProgram(env, u, id), 201);
}

async function enrollProgram(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM programs WHERE id=?').bind(id).first();
  if (!p || !canViewEntity(env, u, p)) {
    throw new HttpError(404, 'program_not_found', 'Program not found.');
  }
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
  const membership = await env.DB.prepare('SELECT role FROM program_members WHERE program_id=? AND user_id=?')
    .bind(programId, u.id).first();
  if (Number(p.author_id) !== Number(u.id) &&
      !(membership && membership.role === 'OWNER') && !isAdminUser(env, u)) {
    throw new HttpError(403, 'forbidden', 'Only the program owner can create tasks.');
  }
  const b = await readJson(req);
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Task title must be at least 3 characters.');
  const projectId = num(b.project_id);
  if (projectId != null) {
    const proj = await env.DB.prepare('SELECT id FROM projects WHERE id=? AND program_id=?').bind(projectId, programId).first();
    if (!proj) throw new HttpError(400, 'invalid_project', 'Project does not belong to this program.');
  }
  const assignee = num(b.assignee_id);
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO tasks
    (program_id,project_id,author_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(programId, projectId, u.id, assignee, title, clean(b.description, 1500) || null,
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
    project_type: x.project_type || 'COMMUNITY',
    institution_id: x.institution_id == null ? null : String(x.institution_id),
    academic_year: x.academic_year || null, student_names: x.student_names || null,
    supervisor: x.supervisor || null,
    status: x.status || 'ACTIVE', owner_name: x.owner_name || 'MASAREEN',
    verification_status: x.verification_status || 'APPROVED',
    rejection_reason: x.rejection_reason || null,
    creation_fee_mrc: Number(x.creation_fee_mrc || 0),
    members_preview: x.members_preview || [],
    author: { id: String(x.author_id), name: x.owner_name || 'MASAREEN', avatar_url: x.owner_picture || null },
    created_at: x.created_at,
  };
}

async function listProjects(env, viewer) {
  const own = viewer ? ' OR x.author_id=?' : '';
  const rows = (await env.DB.prepare(`SELECT x.*, u.name owner_name, u.picture owner_picture,
    (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members
    FROM projects x LEFT JOIN users u ON u.id=x.author_id
    WHERE (x.verification_status='APPROVED'${own})
    ORDER BY x.created_at DESC LIMIT 100`)
    .bind(...(viewer ? [viewer.id] : [])).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const joined = (await env.DB.prepare('SELECT project_id FROM project_members WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const j of joined) mine.add(Number(j.project_id));
  }
  const previews = await memberPreviews(env, 'project_members', 'project_id', rows.map((r) => r.id));
  return rows.map((x) => ({
    ...projectJson({ ...x, members_preview: previews.get(Number(x.id)) || [] }),
    joined: mine.has(Number(x.id)),
  }));
}

async function createProject(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 140);
  const description = clean(b.description, 2000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Project title must be at least 3 characters.');
  assertModerated(title, description);
  const PROJECT_TYPES = new Set(['COMMUNITY', 'UNIVERSITY', 'GRADUATION', 'RESEARCH', 'SCHOOL']);
  const projectType = String(b.project_type || 'COMMUNITY').toUpperCase();
  if (!PROJECT_TYPES.has(projectType)) {
    throw new HttpError(400, 'invalid_project_type', 'Choose a valid project type.');
  }
  let institutionId = num(b.institution_id);
  if (institutionId != null) {
    const inst = await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(institutionId).first();
    if (!inst) institutionId = null;
  }
  if (projectType !== 'COMMUNITY' && institutionId == null) {
    throw new HttpError(400, 'institution_required', 'Link this project to its university or school.');
  }
  const fee = await chargeCreationFee(env, u, 'PROJECT', title);
  const verification = fee.admin ? 'APPROVED' : 'PENDING';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO projects
    (program_id,author_id,title,description,category,sdg,cover,goal,raised,
     project_type,institution_id,academic_year,student_names,supervisor,status,
     verification_status,creation_fee_mrc,reviewed_at,reviewed_by,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,'ACTIVE',?,?,?,?,?)`)
    .bind(num(b.program_id), u.id, title, description || null,
      clean(b.category, 80) || 'Community', validSdg(b.sdg), clean(b.cover, 500) || null,
      Math.max(0, num(b.goal) || 0), Math.max(0, num(b.raised) || 0),
      projectType, institutionId, clean(b.academic_year, 40) || null,
      clean(b.student_names, 500) || null, clean(b.supervisor, 160) || null,
      verification, fee.fee, fee.admin ? at : null, fee.admin ? u.id : null, at).run();
  const id = r.meta.last_row_id;
  if (verification === 'PENDING') await alertEntityReview(env, 'Project', id, title, u);
  await env.DB.prepare('INSERT OR IGNORE INTO project_members (project_id,user_id,role,created_at) VALUES (?,?,?,?)')
    .bind(id, u.id, 'OWNER', at).run();
  const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
    .bind(id).first();
  return json({ ...projectJson(row), joined: true }, 201);
}

async function joinProject(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM projects WHERE id=?').bind(id).first();
  if (!p || !canViewEntity(env, u, p)) {
    throw new HttpError(404, 'project_not_found', 'Project not found.');
  }
  const has = await env.DB.prepare('SELECT 1 x FROM project_members WHERE project_id=? AND user_id=?').bind(id, u.id).first();
  if (!has) {
    await env.DB.prepare('INSERT OR IGNORE INTO project_members (project_id,user_id,role,created_at) VALUES (?,?,?,?)')
      .bind(id, u.id, 'MEMBER', nowIso()).run();
    if (Number(p.author_id) !== Number(u.id)) {
      await notify(env, p.author_id, 'project', `${u.name || 'Someone'} joined ${p.title}`, 'A new member joined your project.', u.id, null);
    }
  }
  const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
    .bind(id).first();
  return json({ ...projectJson(row), joined: true });
}

async function leaveProject(req, env, id) {
  const u = await requireUser(req, env);
  const p = await env.DB.prepare('SELECT * FROM projects WHERE id=?').bind(id).first();
  if (!p) throw new HttpError(404, 'project_not_found', 'Project not found.');
  const membership = await env.DB.prepare('SELECT role FROM project_members WHERE project_id=? AND user_id=?')
    .bind(id, u.id).first();
  if (!membership) {
    const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
      .bind(id).first();
    return json({ ...projectJson(row), joined: false });
  }
  if (membership.role === 'OWNER') {
    throw new HttpError(409, 'owner_cannot_leave', 'The project owner cannot leave.');
  }
  await env.DB.prepare('DELETE FROM project_members WHERE project_id=? AND user_id=?').bind(id, u.id).run();
  const row = await env.DB.prepare('SELECT x.*, u.name owner_name, (SELECT COUNT(*) FROM project_members m WHERE m.project_id=x.id) members FROM projects x LEFT JOIN users u ON u.id=x.author_id WHERE x.id=?')
    .bind(id).first();
  return json({ ...projectJson(row), joined: false });
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
  const singleMatch = /^\/api\/v1\/tasks\/(\d+)$/.exec(path);
  if (singleMatch && req.method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const row = await env.DB.prepare('SELECT t.*, u.name assignee_name FROM tasks t LEFT JOIN users u ON u.id=t.assignee_id WHERE t.id=?')
      .bind(Number(singleMatch[1])).first();
    if (!row) throw new HttpError(404, 'task_not_found', 'Task not found.');
    return json(taskJson(row));
  }
  const statusMatch = /^\/api\/v1\/tasks\/(\d+)\/status$/.exec(path);
  if (statusMatch && req.method === 'POST') {
    const u = await requireUser(req, env);
    const b = await readJson(req);
    const status = String(b.status || '').toUpperCase();
    if (!TASK_STATUSES.has(status)) throw new HttpError(400, 'invalid_status', 'Unknown task status.');
    const task = await env.DB.prepare('SELECT * FROM tasks WHERE id=?').bind(Number(statusMatch[1])).first();
    if (!task) throw new HttpError(404, 'task_not_found', 'Task not found.');
    const program = task.program_id != null
      ? await env.DB.prepare('SELECT author_id FROM programs WHERE id=?').bind(task.program_id).first() : null;
    const isOwner = Number(task.author_id || 0) === Number(u.id) ||
      (program && Number(program.author_id) === Number(u.id)) || isAdminUser(env, u);
    const isAssignee = task.assignee_id != null && Number(task.assignee_id) === Number(u.id);
    if (!isOwner && !isAssignee) {
      throw new HttpError(403, 'forbidden', 'Only the assignee or program owner can update this task.');
    }
    if (status === 'VERIFIED' && !isOwner) {
      throw new HttpError(403, 'forbidden', 'Only the program owner can verify a task.');
    }
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
    applied: !!applied,
    verification_status: o.verification_status || 'APPROVED',
    rejection_reason: o.rejection_reason || null,
    creation_fee_mrc: Number(o.creation_fee_mrc || 0),
    cover_url: o.cover_url || null,
    author: { id: String(o.author_id), name: o.author_name || 'MASAREEN', avatar_url: o.author_picture || null },
    created_at: o.created_at,
  };
}

async function listOpportunities(env, viewer) {
  const own = viewer ? ' OR o.author_id=?' : '';
  const rows = (await env.DB.prepare(`SELECT o.*, u.name author_name, u.picture author_picture,
    (SELECT COUNT(*) FROM opportunity_applications a WHERE a.opportunity_id=o.id) applications_count
    FROM opportunities o LEFT JOIN users u ON u.id=o.author_id
    WHERE o.status='OPEN' AND (o.verification_status='APPROVED'${own})
    ORDER BY o.created_at DESC LIMIT 100`)
    .bind(...(viewer ? [viewer.id] : [])).all()).results || [];
  const mine = new Set();
  if (viewer) {
    const applied = (await env.DB.prepare('SELECT opportunity_id FROM opportunity_applications WHERE user_id=?').bind(viewer.id).all()).results || [];
    for (const a of applied) mine.add(Number(a.opportunity_id));
  }
  return rows.map((o) => opportunityJson(o, mine.has(Number(o.id))));
}

async function createOpportunity(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 140);
  const description = clean(b.description, 2500);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Opportunity title must be at least 3 characters.');
  assertModerated(title, description);
  const type = OPPORTUNITY_TYPES.has(String(b.type || '').toUpperCase()) ? String(b.type).toUpperCase() : 'VOLUNTEER';
  const isRemote = b.is_remote === true || b.is_remote === 1 || b.is_remote === 'true';
  const fee = await chargeCreationFee(env, u, 'OPPORTUNITY', title);
  const verification = fee.admin ? 'APPROVED' : 'PENDING';
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO opportunities
    (author_id,title,description,type,skills,sdg,location,cover_url,is_remote,deadline,min_pms,status,
     verification_status,creation_fee_mrc,reviewed_at,reviewed_by,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,'OPEN',?,?,?,?,?)`)
    .bind(u.id, title, description || null, type,
      JSON.stringify(skillsArray(b.skills)), validSdg(b.sdg), clean(b.location, 160) || null,
      clean(b.cover_url, 500) || null,
      isRemote ? 1 : 0, clean(b.deadline, 40) || null, num(b.min_pms),
      verification, fee.fee, fee.admin ? at : null, fee.admin ? u.id : null, at).run();
  if (verification === 'PENDING') await alertEntityReview(env, 'Opportunity', r.meta.last_row_id, title, u);
  const row = await env.DB.prepare('SELECT * FROM opportunities WHERE id=?').bind(r.meta.last_row_id).first();
  if (verification === 'APPROVED') {
    await notifyOpportunityMatches(env, row).catch(() => {});
  }
  return json(opportunityJson(row, false), 201);
}

function normalizedTokens(value) {
  return String(value || '').toLowerCase().split(/[^\p{L}\p{N}]+/u).filter((t) => t.length >= 2);
}

function stringList(value) {
  try {
    const parsed = JSON.parse(value || '[]');
    if (!Array.isArray(parsed)) return [];
    return parsed.map((item) => typeof item === 'string' ? item : (item?.skill_name || item?.name || '')).filter(Boolean);
  } catch {
    return [];
  }
}

async function notifyOpportunityMatches(env, opp) {
  if (!opp || !opp.id) return 0;
  const since = new Date(Date.now() - 180 * 86400000).toISOString();
  const rows = (await env.DB.prepare(`SELECT u.id,u.name,u.email,u.city,u.country,u.interest,u.role,u.audience,
      p.skills,p.headline,p.summary,
      EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=u.id AND f.followee_id=?) follows_author
    FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id
    WHERE u.id<>? AND (u.last_login_at IS NULL OR u.last_login_at>?)
      AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
        (b.blocker_id=u.id AND b.blocked_id=?) OR (b.blocker_id=? AND b.blocked_id=u.id))
    LIMIT 800`).bind(opp.author_id, opp.author_id, since, opp.author_id, opp.author_id).all()).results || [];
  if (!rows.length) return 0;
  const settingsRows = (await env.DB.prepare('SELECT user_id,opportunity_alerts FROM user_settings').all()).results || [];
  const settingsMap = new Map(settingsRows.map((row) => [Number(row.user_id), row]));
  const dailyRows = (await env.DB.prepare("SELECT user_id, COUNT(*) c FROM notification_log WHERE kind='opportunity_match' AND created_at>? GROUP BY user_id")
    .bind(new Date(Date.now() - 86400000).toISOString()).all()).results || [];
  const dailyMap = new Map(dailyRows.map((row) => [Number(row.user_id), Number(row.c || 0)]));
  const oppSkills = new Set(skillsArray(opp.skills).map((s) => String(s).toLowerCase()));
  const oppTokens = new Set(normalizedTokens(`${opp.title} ${opp.description || ''}`));
  const location = String(opp.location || '').toLowerCase();
  const scored = [];
  for (const user of rows) {
    const settings = settingsMap.get(Number(user.id));
    if (settings && !boolValue(settings.opportunity_alerts, true)) continue;
    if ((dailyMap.get(Number(user.id)) || 0) >= 3) continue;
    const userSkills = new Set([
      ...stringList(user.skills),
      ...normalizedTokens(user.headline),
      ...normalizedTokens(user.summary),
    ].map((s) => String(s).toLowerCase()));
    let score = 0;
    for (const skill of oppSkills) if (userSkills.has(skill)) score += 45;
    let interestOverlap = 0;
    for (const token of normalizedTokens(user.interest)) if (oppTokens.has(token)) interestOverlap++;
    score += Math.min(30, interestOverlap * 10);
    if (location) {
      const city = String(user.city || '').toLowerCase();
      const country = String(user.country || '').toLowerCase();
      if ((city && (city.includes(location) || location.includes(city))) ||
          (country && (country.includes(location) || location.includes(country)))) score += 18;
    }
    if (opp.is_remote) score += 6;
    if (Number(user.follows_author)) score += 25;
    if (String(user.role || '').toUpperCase() === String(opp.type || '').toUpperCase()) score += 8;
    const threshold = oppSkills.size ? 35 : (location ? 18 : 20);
    if (score >= threshold) scored.push({ user, score });
  }
  scored.sort((a, b) => b.score - a.score);
  const chosen = scored.slice(0, 50);
  const detail = [opp.type, opp.location || (opp.is_remote ? 'Remote' : null), ...skillsArray(opp.skills).slice(0, 3)]
    .filter(Boolean).join(' | ');
  for (const { user } of chosen) {
    await notify(env, user.id, 'opportunity_match', `New opportunity: ${opp.title}`, detail || 'A new opportunity matches your profile.', null, null, {
      dedupeKey: `opportunity_match:${opp.id}`,
    });
  }
  return chosen.length;
}

async function applyOpportunity(req, env, id) {
  const u = await requireUser(req, env);
  const o = await env.DB.prepare('SELECT * FROM opportunities WHERE id=?').bind(id).first();
  if (!o || !canViewEntity(env, u, o)) {
    throw new HttpError(404, 'opportunity_not_found', 'Opportunity not found.');
  }
  if (o.status !== 'OPEN') throw new HttpError(409, 'opportunity_closed', 'This opportunity is closed.');
  const has = await env.DB.prepare('SELECT 1 x FROM opportunity_applications WHERE opportunity_id=? AND user_id=?').bind(id, u.id).first();
  if (has) throw new HttpError(409, 'already_applied', 'You already applied to this opportunity.');
  const b = await readJson(req);
  await env.DB.prepare('INSERT INTO opportunity_applications (opportunity_id,user_id,note,status,created_at) VALUES (?,?,?,?,?)')
    .bind(id, u.id, clean(b.note, 800) || null, 'SUBMITTED', nowIso()).run();
  await notify(env, o.author_id, 'opportunity', `${u.name || 'Someone'} applied to ${o.title}`, 'Review the new application.', u.id, null);
  const row = await env.DB.prepare(`SELECT o.*, u.name author_name,
    (SELECT COUNT(*) FROM opportunity_applications a WHERE a.opportunity_id=o.id) applications_count
    FROM opportunities o LEFT JOIN users u ON u.id=o.author_id WHERE o.id=?`).bind(id).first();
  return json(opportunityJson(row, true));
}

/* ---------------- evidence, verified claims and passports ---------------- */
const EVIDENCE_KINDS = new Set(['PHOTO', 'VIDEO', 'DOCUMENT', 'LINK', 'GPS', 'SENSOR', 'TESTIMONY']);

function evidenceJson(e) {
  return {
    id: String(e.id), submission_id: e.submission_id == null ? null : String(e.submission_id),
    task_id: e.task_id == null ? null : String(e.task_id),
    target_type: e.target_type || 'GENERAL',
    target_id: e.target_id == null ? null : String(e.target_id),
    title: e.title, description: e.description || null, claim: e.claim || null,
    fields: parseJsonValue(e.fields_json, null),
    kind: e.kind || 'DOCUMENT', url: e.url || null, sha256: e.sha256 || null,
    latitude: e.latitude == null ? null : Number(e.latitude), longitude: e.longitude == null ? null : Number(e.longitude),
    captured_at: e.captured_at || null,
    description: e.description || null,
    location_label: e.location_label || null,
    media: parseJsonValue(e.media_json, []),
    files: parseJsonValue(e.files_json, []),
    source_name: e.source_name || null,
    witnesses: parseJsonValue(e.witnesses_json, []),
    metadata: parseJsonValue(e.metadata_json, {}),
    deepfake_score: Number(e.deepfake_score || 0),
    deepfake_verdict: e.deepfake_verdict || 'UNSCANNED',
    deepfake_signals: parseJsonValue(e.deepfake_signals_json, null),
    status: e.status || 'PENDING', created_at: e.created_at,
  };
}

const EVIDENCE_TARGET_TYPES = new Set(['GENERAL', 'POST', 'PROGRAM', 'PROJECT',
  'EVENT', 'TASK', 'OPPORTUNITY', 'SUBMISSION', 'INSTITUTION', 'USER',
  'RESEARCH_STAGE', 'COURSE', 'VOD', 'PODCAST_SHOW']);

async function resolveEvidenceTarget(env, type, id, viewer) {
  const targetType = String(type || 'GENERAL').toUpperCase();
  if (targetType === 'GENERAL') return { type: 'GENERAL', id: null, title: 'General evidence' };
  if (!EVIDENCE_TARGET_TYPES.has(targetType)) {
    throw new HttpError(400, 'invalid_target', 'Choose a valid evidence target.');
  }
  const numericId = Number(id);
  if (!Number.isInteger(numericId) || numericId <= 0) {
    throw new HttpError(400, 'invalid_target', 'Choose the exact entity this evidence belongs to.');
  }
  let row = null;
  let title = null;
  let canAttach = false;
  if (targetType === 'USER' || targetType === 'INSTITUTION') {
    row = await env.DB.prepare('SELECT id,name FROM users WHERE id=?').bind(numericId).first();
    title = row && row.name;
    canAttach = !!row && (targetType === 'INSTITUTION' ||
      Number(row.id) === Number(viewer.id) || isAdminUser(env, viewer));
  } else if (targetType === 'SUBMISSION') {
    row = await env.DB.prepare('SELECT id,owner_id,title FROM submissions WHERE id=?').bind(numericId).first();
    title = row && row.title;
    canAttach = !!row && (Number(row.owner_id) === Number(viewer.id) || isAdminUser(env, viewer));
  } else if (targetType === 'TASK') {
    row = await env.DB.prepare('SELECT id,author_id,assignee_id,title FROM tasks WHERE id=?').bind(numericId).first();
    title = row && row.title;
    canAttach = !!row && (Number(row.author_id) === Number(viewer.id) ||
      Number(row.assignee_id) === Number(viewer.id) || isAdminUser(env, viewer));
  } else if (targetType === 'EVENT') {
    row = await env.DB.prepare('SELECT id,author_id,title FROM events WHERE id=?').bind(numericId).first();
    title = row && row.title;
    canAttach = !!row;
  } else if (targetType === 'PROGRAM' || targetType === 'PROJECT') {
    const table = targetType === 'PROGRAM' ? 'programs' : 'projects';
    row = await env.DB.prepare(`SELECT id,author_id,title FROM ${table} WHERE id=?`).bind(numericId).first();
    title = row && row.title;
    canAttach = !!row;
  } else {
    const table = {
      POST: 'posts', OPPORTUNITY: 'opportunities', RESEARCH_STAGE: 'research_stages',
      COURSE: 'courses', VOD: 'vod_videos', PODCAST_SHOW: 'podcast_shows',
    }[targetType];
    const ownerCol = targetType === 'POST' ? 'author_id' :
      targetType === 'RESEARCH_STAGE' ? 'researcher_id' : 'owner_id';
    row = await env.DB.prepare(`SELECT id,${ownerCol} owner_id,title FROM ${table} WHERE id=?`)
      .bind(numericId).first();
    title = row && (row.title || (targetType === 'POST' ? 'Post' : 'Evidence target'));
    canAttach = !!row && (targetType !== 'POST' ||
      Number(row.owner_id) === Number(viewer.id) || isAdminUser(env, viewer));
  }
  if (!row) throw new HttpError(404, 'target_not_found', 'The evidence target was not found.');
  if (!canAttach) throw new HttpError(403, 'forbidden', 'You cannot attach evidence to this entity.');
  return { type: targetType, id: String(numericId), title: title || targetType };
}
async function createEvidence(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Evidence title must be at least 3 characters.');
  const kind = EVIDENCE_KINDS.has(String(b.kind || '').toUpperCase()) ? String(b.kind).toUpperCase() : 'DOCUMENT';
  const url = clean(b.url, 800) || null;
  if (url && !/^https?:\/\//i.test(url)) {
    throw new HttpError(400, 'invalid_url', 'Evidence URL must start with http:// or https://.');
  }
  let submissionId = num(b.submission_id);
  if (submissionId != null) {
    const sub = await env.DB.prepare('SELECT owner_id FROM submissions WHERE id=?').bind(submissionId).first();
    if (!sub) throw new HttpError(404, 'submission_not_found', 'Submission not found.');
    if (Number(sub.owner_id) !== Number(u.id) && !isAdminUser(env, u)) {
      throw new HttpError(403, 'forbidden', 'This submission belongs to another member.');
    }
  }
  const taskId = num(b.task_id);
  const description = clean(b.description || b.notes, 4000);
  const claim = clean(b.claim, 2000);
  const media = normalizeMediaInput(b);
  const files = normalizeFilesInput(b);
  const witnesses = Array.isArray(b.witnesses)
    ? b.witnesses.map((w) => clean(w, 160)).filter(Boolean).slice(0, 20) : [];
  let fields = null;
  if (b.fields && typeof b.fields === 'object' && !Array.isArray(b.fields)) {
    fields = {};
    for (const [key, value] of Object.entries(b.fields).slice(0, 40)) {
      const k = clean(key, 80);
      if (!k) continue;
      if (['string', 'number', 'boolean'].includes(typeof value)) {
        fields[k] = clean(String(value), 1000);
      }
    }
  }
  let targetType = clean(b.target_type, 40).toUpperCase();
  let targetId = clean(b.target_id, 80);
  if (!targetType) targetType = submissionId ? 'SUBMISSION' : taskId ? 'TASK' : 'GENERAL';
  if (!targetId) targetId = submissionId ? String(submissionId) : taskId ? String(taskId) : '';
  if (targetType === 'GENERAL') {
    throw new HttpError(400, 'target_required',
      'Choose the exact post, programme, project, event, task or entity this evidence proves.');
  }
  const target = await resolveEvidenceTarget(env, targetType, targetId, u);
  const participantId = num(b.participant_id);
  if (participantId != null) {
    if (target.type !== 'EVENT') {
      throw new HttpError(400, 'invalid_participant',
        'Participant evidence must target an event.');
    }
    const participant = await env.DB.prepare(`SELECT id FROM event_participants
      WHERE id=? AND event_id=? AND user_id=?`)
      .bind(participantId, Number(target.id), u.id).first();
    if (!participant) {
      throw new HttpError(404, 'participant_not_found',
        'Your contribution record for this event was not found.');
    }
  }
  if (!description && !claim && !media.length && !files.length && !url && !fields) {
    throw new HttpError(400, 'evidence_required',
      'Add a description, structured field, file, photo or video.');
  }
  const lat = num(b.latitude); const lng = num(b.longitude);
  if (lat != null && (lat < -90 || lat > 90)) {
    throw new HttpError(400, 'invalid_coordinates', 'Latitude must be between -90 and 90.');
  }
  if (lng != null && (lng < -180 || lng > 180)) {
    throw new HttpError(400, 'invalid_coordinates', 'Longitude must be between -180 and 180.');
  }
  const scan = await deepfakeScan(env, {
    text: [title, description, claim, JSON.stringify(fields || {})].join('\n'),
    title, urls: [...media.map((m) => m.url), ...files.map((f) => f.url), url].filter(Boolean),
  });
  if (scan.nsfw_verdict === 'BLOCKED') {
    throw new HttpError(400, 'nsfw_blocked',
      'This evidence contains explicit material and cannot be uploaded.');
  }
  const status = scan.verdict === 'LIKELY_AI' || scan.nsfw_verdict === 'REVIEW'
    ? 'UNDER_REVIEW' : 'PENDING';
  const at = nowIso();
  const metadata = {
    target_title: target.title, target_type: target.type,
    source: clean(b.source_name, 160) || 'MASAREEN evidence capture',
    created_via: 'structured_evidence_v2',
  };
  const r = await env.DB.prepare(`INSERT INTO evidence
    (owner_id,submission_id,task_id,target_type,target_id,title,description,claim,kind,url,sha256,
     location_label,media_json,files_json,source_name,witnesses_json,fields_json,metadata_json,
     latitude,longitude,captured_at,deepfake_score,deepfake_verdict,deepfake_signals_json,status,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(u.id, submissionId, taskId, target.type, target.id, title,
      description || null, claim || null, kind, url, clean(b.sha256, 128) || null,
      clean(b.location_label, 200) || null,
      media.length ? JSON.stringify(media) : null,
      files.length ? JSON.stringify(files) : null,
      clean(b.source_name, 160) || null,
      witnesses.length ? JSON.stringify(witnesses) : null,
      fields ? JSON.stringify(fields) : null,
      JSON.stringify(metadata), lat, lng, clean(b.captured_at, 40) || at,
      scan.score, scan.verdict,
      JSON.stringify({ nsfw_score: scan.nsfw_score, nsfw_verdict: scan.nsfw_verdict,
        signals: scan.signals, provider: scan.provider, scanned_at: scan.scanned_at }),
      status, at).run();
  const evidenceId = r.meta.last_row_id;
  if (target.type === 'EVENT' && num(b.participant_id)) {
    await env.DB.prepare(`UPDATE event_participants SET contribution=COALESCE(?,contribution),
      evidence_json=?,status='SUBMITTED',deepfake_score=?,deepfake_verdict=?,
      deepfake_signals_json=?,updated_at=? WHERE id=? AND event_id=? AND user_id=?`)
      .bind(description || claim || null,
        JSON.stringify([{ type: 'EVIDENCE', evidence_id: String(evidenceId), title,
          description: description || null, url: url || null,
          media: media.map((m) => m.url), files: files.map((f) => f.url) }]),
        scan.score, scan.verdict,
        JSON.stringify({ nsfw_score: scan.nsfw_score, nsfw_verdict: scan.nsfw_verdict,
          signals: scan.signals, provider: scan.provider }),
        at, num(b.participant_id), Number(target.id), u.id).run();
  }
  const row = await env.DB.prepare('SELECT * FROM evidence WHERE id=?').bind(evidenceId).first();
  return json({ ...evidenceJson(row), target }, 201);
}

function pipelineJson(p) {
  let steps = [];
  try { steps = JSON.parse(p.steps || '[]'); } catch { steps = []; }
  return {
    id: String(p.id), submission_id: String(p.submission_id), status: p.status || 'AI_REVIEW',
    stage: Number(p.stage || 0), confidence: Number(p.confidence || 0),
    deepfake_score: Number(p.deepfake_score || 0),
    deepfake_verdict: p.deepfake_verdict || 'UNSCANNED', steps,
    updated_at: p.updated_at, created_at: p.created_at,
  };
}

function submissionJson(s) {
  return {
    id: String(s.id), title: s.title, claim: s.claim || null,
    target_type: s.target_type || 'GENERAL',
    target_id: s.target_id == null ? null : String(s.target_id),
    program_id: s.program_id == null ? null : String(s.program_id),
    task_id: s.task_id == null ? null : String(s.task_id),
    evidence_id: s.evidence_id == null ? null : String(s.evidence_id),
    status: s.status || 'SUBMITTED', confidence: Number(s.confidence || 0),
    deepfake_score: Number(s.deepfake_score || 0),
    deepfake_verdict: s.deepfake_verdict || 'UNSCANNED',
    deepfake_signals: parseJsonValue(s.deepfake_signals_json, null),
    pipeline_id: s.pipeline_id == null ? null : String(s.pipeline_id),
    created_at: s.created_at,
  };
}

async function listSubmissions(env, viewer, userId, url = null) {
  if (!viewer || Number(viewer.id) !== Number(userId))
    throw new HttpError(403, 'forbidden', 'You can only read your own submissions.');
  const limit = clamp(parseInt(url && url.searchParams.get('limit') || '100', 10) || 100, 1, 500);
  const offset = clamp(parseInt(url && url.searchParams.get('offset') || '0', 10) || 0, 0, 100000);
  const rows = (await env.DB.prepare(`SELECT s.*,
    (SELECT p.id FROM verification_pipelines p WHERE p.submission_id=s.id ORDER BY p.id DESC LIMIT 1) pipeline_id
    FROM submissions s WHERE s.owner_id=? ORDER BY s.created_at DESC LIMIT ? OFFSET ?`).bind(userId, limit, offset).all()).results || [];
  return json(rows.map(submissionJson));
}

async function createSubmission(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const title = clean(b.title, 160);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Submission title must be at least 3 characters.');
  const claim = clean(b.claim, 2000);
  const taskId = num(b.task_id);
  if (taskId != null) {
    const task = await env.DB.prepare('SELECT * FROM tasks WHERE id=?').bind(taskId).first();
    if (!task) throw new HttpError(404, 'task_not_found', 'Task not found.');
    const canSubmit = Number(task.assignee_id) === Number(u.id) ||
      Number(task.author_id || 0) === Number(u.id) || isAdminUser(env, u);
    if (!canSubmit) throw new HttpError(403, 'forbidden', 'Only the assignee can submit this task.');
  }
  let evidenceId = num(b.evidence_id);
  if (evidenceId != null) {
    const ev = await env.DB.prepare('SELECT * FROM evidence WHERE id=? AND owner_id=?').bind(evidenceId, u.id).first();
    if (!ev) throw new HttpError(404, 'evidence_not_found', 'Evidence not found.');
    if (ev.submission_id != null) {
      throw new HttpError(409, 'evidence_attached', 'This evidence is already attached to another submission.');
    }
  } else {
    const evidenceUrl = clean(b.evidence_url, 800);
    if (evidenceUrl && !/^https?:\/\//i.test(evidenceUrl)) {
      throw new HttpError(400, 'invalid_url', 'Links in evidence must start with http:// or https://.');
    }
    if (evidenceUrl) {
      const ev = await env.DB.prepare(`INSERT INTO evidence
        (owner_id,title,kind,url,target_type,target_id,captured_at,status,created_at)
        VALUES (?,?,?,?,'GENERAL',NULL,?,'PENDING',?)`)
        .bind(u.id, clean(b.evidence_title, 160) || title + ' evidence',
          EVIDENCE_KINDS.has(String(b.evidence_kind || '').toUpperCase())
            ? String(b.evidence_kind).toUpperCase() : 'LINK',
          evidenceUrl, nowIso(), nowIso()).run();
      evidenceId = ev.meta.last_row_id;
    }
  }
  if (taskId != null) {
    const task = await env.DB.prepare('SELECT * FROM tasks WHERE id=?').bind(taskId).first();
    if (task && task.evidence_required && evidenceId == null) {
      throw new HttpError(400, 'evidence_required', 'Attach evidence before submitting this task.');
    }
  }
  const attached = evidenceId == null ? null : await env.DB.prepare(
    'SELECT * FROM evidence WHERE id=?').bind(evidenceId).first();
  let targetType = clean(b.target_type, 40).toUpperCase() ||
    (attached && attached.target_type) || (taskId ? 'TASK' : 'GENERAL');
  let targetId = clean(b.target_id, 80) ||
    (attached && attached.target_id) || (taskId ? String(taskId) : null);
  if (targetType !== 'GENERAL' && targetId) {
    await resolveEvidenceTarget(env, targetType, targetId, u);
  }
  const scan = await deepfakeScan(env, { text: `${title}\n${claim}`, title,
    urls: [attached && attached.url].filter(Boolean) });
  if (scan.nsfw_verdict === 'BLOCKED') {
    throw new HttpError(400, 'nsfw_blocked',
      'This submission contains explicit material and cannot be sent.');
  }
  const subVerdict = scan.verdict === 'LIKELY_AI' ||
    (attached && attached.deepfake_verdict === 'LIKELY_AI') ? 'LIKELY_AI' : scan.verdict;
  const subScore = Math.max(scan.score, Number(attached && attached.deepfake_score || 0));
  const r = await env.DB.prepare(`INSERT INTO submissions
    (owner_id,title,claim,target_type,target_id,program_id,task_id,evidence_id,
     deepfake_score,deepfake_verdict,deepfake_signals_json,status,confidence,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,'SUBMITTED',0,?)`)
    .bind(u.id, title, claim || null, targetType, targetId, num(b.program_id),
      taskId, evidenceId, subScore, subVerdict,
      JSON.stringify({ nsfw_score: scan.nsfw_score, nsfw_verdict: scan.nsfw_verdict,
        signals: scan.signals, provider: scan.provider, scanned_at: scan.scanned_at }),
      nowIso()).run();
  if (evidenceId != null)
    await env.DB.prepare('UPDATE evidence SET submission_id=?,target_type=?,target_id=? WHERE id=?')
      .bind(r.meta.last_row_id, targetType, targetId, evidenceId).run();
  const row = await env.DB.prepare('SELECT * FROM submissions WHERE id=?').bind(r.meta.last_row_id).first();
  return json(submissionJson(row), 201);
}

async function deleteSubmission(req, env, submissionId) {
  const u = await requireUser(req, env);
  const s = await env.DB.prepare('SELECT * FROM submissions WHERE id=? AND owner_id=?').bind(submissionId, u.id).first();
  if (!s) throw new HttpError(404, 'submission_not_found', 'Submission not found.');
  if (!['SUBMITTED', 'AI_REVIEW'].includes(s.status)) {
    throw new HttpError(409, 'cannot_retract', 'Only pending submissions can be retracted.');
  }
  await env.DB.prepare('UPDATE evidence SET submission_id=NULL WHERE submission_id=? AND owner_id=?')
    .bind(submissionId, u.id).run();
  await env.DB.prepare('DELETE FROM verification_pipelines WHERE submission_id=?').bind(submissionId).run();
  await env.DB.prepare('DELETE FROM submissions WHERE id=?').bind(submissionId).run();
  return json({ ok: true });
}

async function startPipeline(req, env, submissionId) {
  const u = await requireUser(req, env);
  const s = await env.DB.prepare('SELECT * FROM submissions WHERE id=? AND owner_id=?').bind(submissionId, u.id).first();
  if (!s) throw new HttpError(404, 'submission_not_found', 'Submission not found.');
  const existing = await env.DB.prepare('SELECT * FROM verification_pipelines WHERE submission_id=? ORDER BY id DESC LIMIT 1')
    .bind(submissionId).first();
  if (existing) {
    await env.DB.prepare('UPDATE submissions SET status=?,confidence=? WHERE id=?')
      .bind(existing.status || 'AI_REVIEW', Number(existing.confidence || 0), submissionId).run();
    return json({ ok: true, ...pipelineJson(existing) });
  }
  const at = nowIso();
  const evidence = s.evidence_id == null ? null : await env.DB.prepare(
    'SELECT * FROM evidence WHERE id=?').bind(s.evidence_id).first();
  const deepfakeScore = Math.max(Number(s.deepfake_score || 0),
    Number(evidence && evidence.deepfake_score || 0));
  const deepfakeVerdict =
    s.deepfake_verdict === 'LIKELY_AI' || (evidence && evidence.deepfake_verdict === 'LIKELY_AI')
      ? 'LIKELY_AI'
      : (s.deepfake_verdict || (evidence && evidence.deepfake_verdict) || 'UNSCANNED');
  const suspicious = deepfakeVerdict === 'LIKELY_AI' || deepfakeVerdict === 'SUSPICIOUS';
  const status = suspicious ? 'HUMAN_REVIEW' : 'AI_REVIEW';
  const confidence = deepfakeVerdict === 'LIKELY_AI' ? 12 : suspicious ? 25 : 45;
  const stages = ['SUBMITTED', 'AI_REVIEW', 'HUMAN_REVIEW', 'VERIFIED'];
  const evidenceSignals = evidence ? parseJsonValue(evidence.deepfake_signals_json, {}) : {};
  const steps = [
    { stage: stages[0], status: 'COMPLETE', at },
    { stage: 'DEEPFAKE_NSFW_SCAN', status: 'COMPLETE', at,
      verdict: deepfakeVerdict, score: deepfakeScore,
      nsfw_verdict: evidenceSignals.nsfw_verdict || 'SAFE' },
    { stage: stages[1], status: 'IN_PROGRESS', at },
  ];
  const r = await env.DB.prepare(`INSERT INTO verification_pipelines
    (submission_id,status,stage,confidence,steps,deepfake_score,deepfake_verdict,updated_at,created_at)
    VALUES (?,?,?,?,?,?,?,?,?)`)
    .bind(submissionId, status, 1, confidence, JSON.stringify(steps),
      deepfakeScore, deepfakeVerdict, at, at).run();
  await env.DB.prepare('UPDATE submissions SET status=?,confidence=?,deepfake_score=?,deepfake_verdict=? WHERE id=?')
    .bind(status, confidence, deepfakeScore, deepfakeVerdict, submissionId).run();
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

async function passportFor(env, userId, viewer) {
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in to view a passport.');
  const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(userId).first();
  if (!user) throw new HttpError(404, 'user_not_found', 'Member not found.');
  const isSelf = Number(viewer.id) === Number(userId);
  const isAdmin = isAdminUser(env, viewer);
  let canSeeClaims = isSelf || isAdmin;
  if (!canSeeClaims) {
    const settings = await env.DB.prepare('SELECT profile_visibility FROM user_settings WHERE user_id=?').bind(userId).first();
    const isFollowing = await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
      .bind(viewer.id, userId).first();
    canSeeClaims = (settings && settings.profile_visibility === 'public') || !!isFollowing;
  }
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
  const rows = (await env.DB.prepare(`SELECT s.*, (SELECT p.id FROM verification_pipelines p
    WHERE p.submission_id=s.id ORDER BY p.id DESC LIMIT 1) pipeline_id
    FROM submissions s WHERE s.owner_id=? ORDER BY s.created_at DESC LIMIT 20`).bind(userId).all()).results || [];
  const claims = canSeeClaims
    ? rows.map(submissionJson)
    : rows.map((s) => ({ id: String(s.id), title: s.title, status: s.status || 'SUBMITTED', created_at: s.created_at }));
  const generatedAt = nowIso();
  let signature = null;
  if (env.SESSION_SECRET) {
    signature = await signToken({ sub: 'passport', uid: Number(userId), verified, submissions, programs, projects, tasks, generated_at: generatedAt },
      env.SESSION_SECRET);
  }
  return json({
    user_id: String(user.id), name: user.name || 'MASAREEN member', role: user.role || null,
    country: canSeeClaims ? user.country || null : null, city: canSeeClaims ? user.city || null : null,
    avatar_url: canSeeClaims ? user.picture || null : null,
    visibility: canSeeClaims ? 'full' : 'counts_only',
    verified_claims: verified, submissions, programs, projects, tasks_completed: tasks,
    impact_score: Number((verified * 2 + tasks * 1.5 + projects + programs * 0.5).toFixed(1)),
    badges, claims, generated_at: generatedAt,
    signature, signature_algorithm: signature ? 'HS256' : null, signed_at: signature ? generatedAt : null,
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
  return cut.slice(0, cut.lastIndexOf(' ')) + 'â€¦';
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
      start_date: o.start_date, end_date: o.end_date, duration: start ? `${start} â€“ ${end}` : '',
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
  const fullList = await Promise.all(rows.map((row) => personnelJson(env, row, viewer)));
  const out = [];
  for (const full of fullList) {
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
  const body = await readJson(req);
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
  assertModerated(name, bio, merged.headline, merged.summary, merged.mission, merged.beat,
    merged.employment_status, merged.availability);
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
    const body = await readJson(req);
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
    post_id: n.post_id == null ? null : String(n.post_id),
    link: n.link || null, entity_type: n.entity_type || null,
    entity_id: n.entity_id || null })));
}

async function notificationRoutes(req, env, path) {
  if (path === '/api/v1/notifications/test-push' && req.method === 'POST') {
    const viewer = await requireUser(req, env);
    const b = await readJson(req);
    const title = clean(b.title || 'MASAREEN Notification', 140);
    const body = clean(b.body || 'FCM push notifications are active on your device.', 300);
    await env.DB.prepare(`INSERT INTO notifications
      (user_id,type,title,body,read,created_at) VALUES (?, 'system', ?, ?, 0, ?)`)
      .bind(viewer.id, title, body, nowIso()).run();
    const explicitToken = clean(b.token, 4096);
    if (explicitToken) {
      const res = await sendFcmMessageToToken(env, explicitToken, { type: 'system', title, body });
      return json({ ok: res.ok, result: res });
    }
    const res = await sendFcmPushForUser(env, viewer.id, { type: 'system', title, body });
    return json({ ok: true, ...res });
  }
  if (path === '/api/v1/notifications/read-all' && req.method === 'POST') {
    const viewer = await requireUser(req, env);
    await env.DB.prepare('UPDATE notifications SET read=1 WHERE user_id=?').bind(viewer.id).run();
    return json({ ok: true });
  }
  if ((path === '/api/v1/notifications/unread-count' || path === '/api/v1/notifications/unread') && req.method === 'GET') {
    const viewer = await requireUser(req, env);
    const row = await env.DB.prepare('SELECT COUNT(*) c FROM notifications WHERE user_id=? AND read=0').bind(viewer.id).first();
    return json({ ok: true, count: Number(row?.c || 0) });
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
const AUDIO_TYPES = new Set(['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/mpeg', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/x-wav', 'audio/webm', 'audio/opus']);
const FILE_TYPES = new Set([
  'application/pdf', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain', 'text/csv', 'application/zip',
]);

async function uploadMedia(req, env, kind) {
  const u = await requireUser(req, env);
  if (!env.MEDIA) throw new HttpError(503, 'media_unavailable', 'Media uploads are not configured yet.');
  let form;
  try { form = await req.formData(); } catch { throw new HttpError(400, 'bad_upload', 'Choose a file to upload.'); }
  const file = form.get('file');
  if (!file || typeof file === 'string') throw new HttpError(400, 'bad_upload', 'Choose a file to upload.');
  const maxBytes = kind === 'video' ? 80 * 1024 * 1024 : (kind === 'file' || kind === 'audio') ? 25 * 1024 * 1024 : 12 * 1024 * 1024;
  if (file.size > maxBytes) throw new HttpError(413, 'too_large', kind === 'video'
    ? 'Videos must be 80 MB or smaller.' : kind === 'file'
      ? 'Files must be 25 MB or smaller.' : kind === 'audio'
        ? 'Voice notes must be 25 MB or smaller.' : 'Images must be 12 MB or smaller.');
  const ct = String(file.type || '').toLowerCase();
  const isImage = IMAGE_TYPES.has(ct);
  const isVideo = VIDEO_TYPES.has(ct);
  const isFile = FILE_TYPES.has(ct);
  const isAudio = AUDIO_TYPES.has(ct);
  if (kind === 'file' ? !isFile : kind === 'audio' ? !isAudio : (!isImage && !isVideo && !isAudio)) {
    throw new HttpError(415, 'unsupported_type', kind === 'file'
      ? 'Use a PDF, Word, Excel, PowerPoint, TXT, CSV or ZIP file.'
      : kind === 'audio'
        ? 'Use an M4A, MP3, AAC, OGG, WAV or WEBM voice note.'
        : 'Use a JPG, PNG, WEBP, GIF, MP4, WEBM or audio file.');
  }
  if (kind === 'avatar' || kind === 'cover') {
    if (!isImage) throw new HttpError(415, 'unsupported_type', 'Profile photos must be images.');
  }
  const extMap = {
    'image/jpeg': 'jpg', 'video/quicktime': 'mov',
    'application/pdf': 'pdf', 'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.ms-powerpoint': 'ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
    'text/plain': 'txt', 'text/csv': 'csv', 'application/zip': 'zip',
    'audio/mp4': 'm4a', 'audio/m4a': 'm4a', 'audio/x-m4a': 'm4a',
    'audio/mpeg': 'mp3', 'audio/aac': 'aac', 'audio/ogg': 'ogg',
    'audio/wav': 'wav', 'audio/x-wav': 'wav', 'audio/webm': 'webm',
    'audio/opus': 'opus',
  };
  const ext = extMap[ct] || ct.split('/')[1] || 'bin';
  const folder = kind === 'avatar' ? 'avatars' : kind === 'cover' ? 'covers'
    : kind === 'video' ? 'videos' : kind === 'audio' ? 'audio'
    : kind === 'file' ? 'files' : 'posts';
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
    name: kind === 'file' ? clean(file.name, 180) : null,
    job_id: jobId, video_job_id: jobId, status: jobId ? 'queued' : null });
}

/* ---------------- inquiries ---------------- */



function feedbackJson(f) {
  return {
    id: String(f.id),
    user_id: String(f.user_id),
    user_name: f.user_name || null,
    user_email: f.user_email || null,
    role: f.role || null,
    type: f.type,
    message: f.message,
    rating: f.rating == null ? null : Number(f.rating),
    status: f.status,
    created_at: f.created_at,
  };
}

async function createFeedback(req, env) {
  const u = await requireUser(req, env);
  const b = await readJson(req);
  const type = ['bug', 'idea', 'feature', 'praise'].includes(String(b.type || '').toLowerCase())
    ? String(b.type).toLowerCase() : 'idea';
  const message = clean(b.message, 2000);
  if (message.length < 5) {
    throw new HttpError(400, 'feedback_required', 'Tell us a little more (at least 5 characters).');
  }
  const rating = clamp(Math.trunc(Number(b.rating) || 0), 0, 5) || null;
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO feedback
    (user_id,role,type,message,rating,status,created_at)
    VALUES (?,?,?,?,?,'OPEN',?)`)
    .bind(u.id, u.role || null, type, message, rating, at).run();
  const row = await env.DB.prepare('SELECT * FROM feedback WHERE id=?')
    .bind(ins.meta.last_row_id).first();
  await adminAlert(env, {
    type: 'feedback',
    severity: type === 'bug' || type === 'feature' ? 'high' : 'normal',
    title: `New ${type} feedback from ${u.name || 'a member'}`,
    body: message.slice(0, 240),
    link: 'admin:feedback',
    entityType: 'feedback',
    entityId: String(row.id),
    actorId: u.id,
    excludeId: u.id,
    dedupeKey: `feedback:${row.id}`,
  }).catch(() => {});
  return json(feedbackJson({ ...row, user_name: u.name, user_email: u.email }), 201);
}

async function inquiryRoutes(req, env, url, viewer) {
  const path = url.pathname;
  const method = req.method;
  if (path === '/api/v1/inquiries' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const org = url.searchParams.get('org_id');
    const rows = isAdminUser(env, viewer)
      ? (await env.DB.prepare(`SELECT i.*,u.name user_name,u.picture user_picture FROM inquiries i
          LEFT JOIN users u ON u.id=i.user_id ${org ? 'WHERE i.org_id=?' : ''}
          ORDER BY i.created_at DESC LIMIT 200`)
          .bind(...(org ? [Number(org)] : [])).all()).results || []
      : (await env.DB.prepare(`SELECT i.*,u.name user_name,u.picture user_picture FROM inquiries i
          LEFT JOIN users u ON u.id=i.user_id WHERE i.user_id=? OR i.org_id=?
          ORDER BY i.created_at DESC LIMIT 200`).bind(viewer.id, viewer.id).all()).results || [];
    return json(rows.map(inquiryJson));
  }
  if (path === '/api/v1/inquiries' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    const orgId = Number(b.org_id);
    if (!Number.isInteger(orgId) || orgId <= 0) throw new HttpError(400, 'invalid_org', 'Choose a valid recipient.');
    const org = await env.DB.prepare('SELECT id,name FROM users WHERE id=?').bind(orgId).first();
    if (!org) throw new HttpError(404, 'org_not_found', 'Recipient not found.');
    const type = String(b.type || 'general').toLowerCase();
    if (!['general', 'complaint', 'document', 'meeting'].includes(type)) {
      throw new HttpError(400, 'invalid_type', 'Choose a valid request type.');
    }
    const subject = clean(b.subject, 120);
    const message = clean(b.message, 2000);
    if (!subject || subject.length < 3) throw new HttpError(400, 'subject_required', 'Add a subject.');
    if (!message || message.length < 5) throw new HttpError(400, 'message_required', 'Add the request details.');
    const department = clean(b.department, 120) || null;
    const at = nowIso();
    const ins = await env.DB.prepare(`INSERT INTO inquiries
      (user_id,org_id,department,type,subject,message,status,created_at,updated_at)
      VALUES (?,?,?,?,?,?,'OPEN',?,?)`)
      .bind(viewer.id, orgId, department, type, subject, message, at, at).run();
    const row = await env.DB.prepare('SELECT * FROM inquiries WHERE id=?').bind(ins.meta.last_row_id).first();
    await notify(env, orgId, 'inquiry', `${viewer.name || 'Someone'} sent a ${type} request`,
      subject, viewer.id, null);
    await adminAlert(env, {
      type: 'admin_inquiry',
      severity: 'normal',
      title: `New ${type} request`,
      body: `${viewer.name || 'A member'} → ${org.name}: ${subject}`,
      link: 'admin:inquiries',
      entityType: 'inquiry',
      entityId: String(row.id),
      actorId: viewer.id,
      excludeId: viewer.id,
      dedupeKey: `inquiry:${row.id}`,
    }).catch(() => {});
    return json(inquiryJson(row), 201);
  }
  const match = /^\/api\/v1\/inquiries\/(\d+)$/.exec(path);
  if (match) {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const row = await env.DB.prepare('SELECT * FROM inquiries WHERE id=?').bind(Number(match[1])).first();
    if (!row) throw new HttpError(404, 'inquiry_not_found', 'Request not found.');
    const allowed = isAdminUser(env, viewer) || Number(row.user_id) === Number(viewer.id) ||
      Number(row.org_id) === Number(viewer.id);
    if (!allowed) throw new HttpError(403, 'not_allowed', 'You cannot view this request.');
    if (method === 'PATCH') {
      if (!isAdminUser(env, viewer) && Number(row.org_id) !== Number(viewer.id)) {
        throw new HttpError(403, 'not_allowed', 'Only the recipient can update this request.');
      }
      const b = await readJson(req);
      const status = String(b.status || '').toUpperCase();
      if (!['OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED'].includes(status)) {
        throw new HttpError(400, 'invalid_status', 'Choose a valid status.');
      }
      await env.DB.prepare('UPDATE inquiries SET status=?,updated_at=? WHERE id=?')
        .bind(status, nowIso(), row.id).run();
      const updated = await env.DB.prepare('SELECT * FROM inquiries WHERE id=?').bind(row.id).first();
      return json(inquiryJson(updated));
    }
    if (method === 'GET') return json(inquiryJson(row));
  }
  return null;
}

function inquiryJson(r) {
  return {
    id: String(r.id),
    user_id: String(r.user_id),
    org_id: String(r.org_id),
    department: r.department || null,
    type: r.type,
    subject: r.subject,
    message: r.message,
    status: r.status,
    user_name: r.user_name || null,
    user_picture: r.user_picture || null,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
}

/* ---------------- commerce: wallets, coins, payments and pro ---------------- */
const PRO_PLANS = {
  monthly: { id: 'monthly', price_mrc: 500, duration_days: 30 },
  yearly: { id: 'yearly', price_mrc: 4500, duration_days: 365 },
};

// Entity creation pricing. Pro members create courses, events and programs
// for free; projects and opportunities keep their fee because they carry
// external value (contracts, grants, placements).
const ENTITY_PRICES = {
  COURSE: 50,
  EVENT: 25,
  PROGRAM: 100,
  PROJECT: 75,
  OPPORTUNITY: 30,
};
const PRO_FREE_ENTITIES = new Set(['COURSE', 'EVENT', 'PROGRAM']);
const ENTITY_TABLES = {
  COURSE: 'courses',
  EVENT: 'events',
  PROGRAM: 'programs',
  PROJECT: 'projects',
  OPPORTUNITY: 'opportunities',
};

function entityPrice(kind) {
  return Number(ENTITY_PRICES[kind] || 0);
}

async function isProUser(env, userId) {
  if (!userId) return false;
  const row = await env.DB.prepare(`SELECT 1 x FROM pro_subscriptions
    WHERE user_id=? AND status='ACTIVE' AND expires_at>?`)
    .bind(userId, nowIso()).first();
  return !!row;
}

async function creationFeeFor(env, user, kind) {
  if (env.ENTITY_TEST_MODE === 'true') {
    return { fee: 0, pro: false, admin: true };
  }
  if (isAdminUser(env, user)) {
    return { fee: 0, pro: false, admin: true };
  }
  const pro = await isProUser(env, user.id);
  const fee = pro && PRO_FREE_ENTITIES.has(kind) ? 0 : entityPrice(kind);
  return { fee, pro, admin: false };
}

async function chargeCreationFee(env, user, kind, title) {
  const info = await creationFeeFor(env, user, kind);
  if (info.fee <= 0) return info;
  await ensureWallet(env, user.id);
  const at = nowIso();
  const upd = await env.DB.prepare(`UPDATE coin_wallets
    SET balance=balance-?, updated_at=? WHERE owner_id=? AND balance>=?`)
    .bind(info.fee, at, user.id, info.fee).run();
  if (!upd.meta.changes) {
    throw new HttpError(402, 'insufficient_balance',
      `Creating this ${kind.toLowerCase()} costs ${info.fee} MRC. Add coins or use Pro.`);
  }
  await recordCoinTx(env, user.id, 'SPEND', info.fee,
    `Create ${kind.toLowerCase()}: ${clean(title, 80) || kind}`, null);
  return info;
}

async function memberPreviews(env, table, fk, ids, limit = 4) {
  const cleanIds = [...new Set(ids.map(Number).filter((n) => Number.isInteger(n) && n > 0))];
  if (!cleanIds.length) return new Map();
  const marks = cleanIds.map(() => '?').join(',');
  const rows = (await env.DB.prepare(`SELECT j.${fk} key_id, u.id, u.name, u.picture
    FROM ${table} j JOIN users u ON u.id=j.user_id
    WHERE j.${fk} IN (${marks}) ORDER BY j.created_at DESC`)
    .bind(...cleanIds).all()).results || [];
  const map = new Map();
  for (const r of rows) {
    const key = Number(r.key_id);
    const list = map.get(key) || [];
    if (list.length < limit) {
      list.push({
        id: String(r.id),
        name: r.name || 'MASAREEN member',
        avatar_url: r.picture || null,
      });
    }
    map.set(key, list);
  }
  return map;
}

function canViewEntity(env, viewer, row) {
  if (!row) return false;
  if ((row.verification_status || 'APPROVED') === 'APPROVED') return true;
  return isAdminUser(env, viewer) ||
    (viewer && Number(row.author_id) === Number(viewer.id));
}

async function refundCreationFee(env, ownerId, fee, kind, title) {
  if (!(Number(fee) > 0) || !ownerId) return;
  await ensureWallet(env, ownerId);
  await env.DB.prepare('UPDATE coin_wallets SET balance=balance+?,updated_at=? WHERE owner_id=?')
    .bind(Number(fee), nowIso(), ownerId).run();
  await recordCoinTx(env, ownerId, 'EARN', Number(fee),
    `Refund: ${kind.toLowerCase()} ${clean(title, 80) || ''}`.trim(), null);
}

function coinTxJson(r) {
  return {
    id: String(r.id),
    owner_id: String(r.owner_id),
    type: r.type,
    amount: Number(r.amount || 0),
    balance_after: Number(r.balance_after || 0),
    reference: r.reference || null,
    counterparty_id: r.counterparty_id == null ? null : String(r.counterparty_id),
    created_at: r.created_at,
  };
}

function paymentJson(r) {
  return {
    id: String(r.id),
    payment_id: String(r.id),
    user_id: String(r.user_id),
    org_id: r.org_id == null ? null : String(r.org_id),
    amount: Number(r.amount_egp || 0),
    amount_egp: Number(r.amount_egp || 0),
    currency: r.currency || 'EGP',
    method: r.method || 'card',
    status: r.status || 'PENDING',
    order_id: r.paymob_order_id || String(r.id),
    paymob_order_id: r.paymob_order_id || null,
    phone: r.phone || null,
    purpose: r.purpose || 'topup',
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
}

function proJson(r) {
  return {
    id: String(r.id),
    user_id: String(r.user_id),
    plan: r.plan,
    status: r.status,
    started_at: r.started_at,
    expires_at: r.expires_at,
    payment_id: r.payment_id == null ? null : String(r.payment_id),
    created_at: r.created_at,
  };
}

async function ensureWallet(env, ownerId) {
  let row = await env.DB.prepare('SELECT * FROM coin_wallets WHERE owner_id=?').bind(ownerId).first();
  if (!row) {
    const at = nowIso();
    await env.DB.prepare('INSERT OR IGNORE INTO coin_wallets (owner_id,balance,currency,updated_at) VALUES (?,0,\'MRC\',?)')
      .bind(ownerId, at).run();
    row = await env.DB.prepare('SELECT * FROM coin_wallets WHERE owner_id=?').bind(ownerId).first();
  }
  return row;
}

function dailyRewardFor(env) {
  const configured = Number(env && env.DAILY_REWARD_MRC);
  const reward = Number.isFinite(configured) && configured > 0
    ? Math.round(configured * 100) / 100
    : DEFAULT_DAILY_REWARD_MRC;
  return Math.min(reward, MAX_DAILY_REWARD_MRC);
}

async function walletJson(env, ownerId) {
  const row = await ensureWallet(env, ownerId);
  const today = new Date().toISOString().slice(0, 10);
  const claim = await env.DB.prepare('SELECT amount,created_at FROM daily_claims WHERE owner_id=? AND claim_date=?')
    .bind(ownerId, today).first();
  return { owner_id: String(row.owner_id), ownerId: String(row.owner_id), balance: Number(row.balance || 0),
    currency: row.currency || 'MRC', updated_at: row.updated_at,
    daily_reward: dailyRewardFor(env), claimed_today: !!claim,
    last_claim_at: claim ? claim.created_at : null };
}

async function rateFor(env, currency) {
  const code = String(currency || 'EGP').toUpperCase();
  const row = await env.DB.prepare('SELECT * FROM coin_rates WHERE currency=?').bind(code).first();
  if (!row) throw new HttpError(404, 'rate_not_found', 'No exchange rate is configured for this currency.');
  return { currency: row.currency, rate_to_mrc: Number(row.rate_to_mrc), updated_at: row.updated_at };
}

async function recordCoinTx(env, ownerId, type, amount, reference, counterpartyId = null) {
  const wallet = await env.DB.prepare('SELECT * FROM coin_wallets WHERE owner_id=?').bind(ownerId).first();
  const after = Number(wallet && wallet.balance || 0);
  const at = nowIso();
  const ins = await env.DB.prepare(`INSERT INTO coin_transactions
    (owner_id,type,amount,balance_after,reference,counterparty_id,created_at) VALUES (?,?,?,?,?,?,?)`)
    .bind(ownerId, type, amount, after, reference || null, counterpartyId, at).run();
  const quiet = /daily|welcome|recognition|reward/i.test(String(reference || ''));
  const value = Math.abs(Number(amount) || 0);
  if (!quiet && value >= 1) {
    await adminAlert(env, {
      type: 'mrc_transaction',
      severity: 'high',
      amount: value,
      title: `${type === 'SPEND' || type === 'REVERSE' ? 'MRC spent' : 'MRC received'}: ${value} MRC`,
      body: `${reference || 'Wallet activity'} · user #${ownerId} · balance ${after} MRC`,
      link: 'admin:transactions',
      entityType: 'coin_transaction',
      entityId: String(ins.meta.last_row_id || ownerId),
      actorId: ownerId,
      excludeId: ownerId,
      dedupeKey: `tx:${ins.meta.last_row_id || at}`,
    }).catch(() => {});
  }
  return at;
}

function timingSafeHex(a, b) {
  const x = String(a || '').toLowerCase();
  const y = String(b || '').toLowerCase();
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}

function mrcFromEgp(egp, rateToMrc) {
  const rate = Number(rateToMrc);
  if (!Number.isFinite(rate) || rate <= 0) return 0;
  return Math.round((Number(egp) / rate) * 100) / 100;
}

function egpFromMrc(mrc, rateToMrc) {
  return Math.round(Number(mrc) * Number(rateToMrc) * 100) / 100;
}

async function paymobPost(path, body) {
  const res = await fetch('https://accept.paymob.com/api' + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new HttpError(502, 'paymob_error',
      data.message || data.detail || 'The payment provider rejected the request.');
  }
  return data;
}

function paymobIntegration(env, method) {
  if (method === 'card') return env.PAYMOB_INTEGRATION_CARD;
  if (method === 'vodafone_cash') return env.PAYMOB_INTEGRATION_VODAFONE_CASH || env.PAYMOB_INTEGRATION_VODAFONE;
  if (method === 'instapay') return env.PAYMOB_INTEGRATION_INSTAPAY;
  return null;
}

async function paymobWebhook(req, env) {
  const body = await readJson(req, null, 262144);
  const obj = body && (body.obj || body);
  if (!obj || !obj.order || !obj.order.id) return json({ ok: true, ignored: true });
  const secret = env.PAYMOB_HMAC_SECRET;
  if (!secret) {
    throw new HttpError(503, 'hmac_not_configured', 'Payment verification is not configured.');
  }
  const fields = [
    obj.amount_cents, obj.created_at, obj.currency, obj.error_occured,
    obj.has_parent_transaction, obj.id, obj.integration_id, obj.is_3d_secure,
    obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment,
    obj.is_voided, obj.order.id, obj.owner, obj.pending,
    obj.source_data && obj.source_data.pan, obj.source_data && obj.source_data.sub_type,
    obj.source_data && obj.source_data.type, obj.success,
  ];
  const message = fields.map((v) => v == null ? '' : String(v)).join('');
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  const digest = [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
  if (!timingSafeHex(digest, String(body.hmac || obj.hmac || ''))) {
    throw new HttpError(401, 'invalid_hmac', 'Payment signature is invalid.');
  }
  const payment = await env.DB.prepare('SELECT * FROM payments WHERE paymob_order_id=?')
    .bind(String(obj.order.id)).first();
  if (!payment) throw new HttpError(404, 'payment_not_found', 'Payment not found.');
  let meta = {};
  try { meta = JSON.parse(payment.metadata_json || '{}'); } catch { meta = {}; }
  const expectedCents = Math.round(Number(payment.amount_egp) * 100);
  if (Number(obj.amount_cents) !== expectedCents) {
    await env.DB.prepare("UPDATE payments SET status='REVIEW',updated_at=? WHERE id=?")
      .bind(nowIso(), payment.id).run();
    await adminAlert(env, {
      type: 'admin_payment', severity: 'critical',
      title: 'Payment amount mismatch',
      body: `Payment #${payment.id} expected ${expectedCents} cents, received ${obj.amount_cents}.`,
      link: 'admin:payments', entityType: 'payment', entityId: String(payment.id),
      dedupeKey: `amount_mismatch:${payment.id}`,
    }).catch(() => {});
    return json({ ok: false, error: 'amount_mismatch' }, 400);
  }
  const integration = paymobIntegration(env, payment.method);
  if (integration && obj.integration_id != null && Number(obj.integration_id) !== Number(integration)) {
    await env.DB.prepare("UPDATE payments SET status='REVIEW',updated_at=? WHERE id=?")
      .bind(nowIso(), payment.id).run();
    return json({ ok: false, error: 'integration_mismatch' }, 400);
  }
  const pending = obj.pending === true || obj.pending === 'true';
  const success = obj.success === true || obj.success === 'true';
  const refunded = obj.is_refunded === true || obj.is_refunded === 'true';
  const voided = obj.is_voided === true || obj.is_voided === 'true';
  const authOnly = (obj.is_auth === true || obj.is_auth === 'true') &&
    !(obj.is_capture === true || obj.is_capture === 'true');
  const at = nowIso();

  if (refunded || voided) {
    const reversal = await env.DB.prepare(`UPDATE payments SET metadata_json=?
      WHERE id=? AND metadata_json NOT LIKE '%"reversed":true%'`)
      .bind(JSON.stringify({ ...meta, reversed: true }), payment.id).run();
    if (reversal.meta.changes && meta.credited) {
      const rate = await rateFor(env, 'EGP');
      const coins = mrcFromEgp(payment.amount_egp, rate.rate_to_mrc);
      if (coins > 0) {
        await env.DB.prepare(`UPDATE coin_wallets SET balance=CASE WHEN balance>=? THEN balance-? ELSE balance END,updated_at=? WHERE owner_id=?`)
          .bind(coins, coins, at, payment.user_id).run();
        await recordCoinTx(env, payment.user_id, 'REVERSE', coins, 'Refund payment #' + payment.id, null);
      }
    }
    await env.DB.prepare('UPDATE payments SET status=?,updated_at=? WHERE id=?')
      .bind(voided ? 'VOIDED' : 'REFUNDED', at, payment.id).run();
    await adminAlert(env, {
      type: 'admin_payment', severity: 'critical', amount: Number(payment.amount_egp) || 0,
      title: `Payment ${voided ? 'voided' : 'refunded'}: ${payment.amount_egp} EGP`,
      body: `Payment #${payment.id} for user #${payment.user_id}.`,
      link: 'admin:payments', entityType: 'payment', entityId: String(payment.id),
      dedupeKey: `${voided ? 'void' : 'refund'}:${payment.id}`,
    }).catch(() => {});
    return json({ ok: true });
  }
  if (pending || authOnly || !success) {
    await env.DB.prepare("UPDATE payments SET status='PENDING',updated_at=? WHERE id=?").bind(at, payment.id).run();
    return json({ ok: true, pending: true });
  }
  const credited = await env.DB.prepare(`UPDATE payments SET metadata_json=?
    WHERE id=? AND metadata_json NOT LIKE '%"credited":true%'`)
    .bind(JSON.stringify({ ...meta, credited: true, consumed: payment.purpose === 'pro' }), payment.id).run();
  if (credited.meta.changes) {
    if (payment.purpose === 'pro' && meta.plan && PRO_PLANS[meta.plan]) {
      await activatePro(env, payment.user_id, meta.plan, payment.id);
    } else {
      const rate = await rateFor(env, 'EGP');
      const coins = mrcFromEgp(payment.amount_egp, rate.rate_to_mrc);
      if (coins > 0) {
        await ensureWallet(env, payment.user_id);
        await env.DB.prepare('UPDATE coin_wallets SET balance=balance+?,updated_at=? WHERE owner_id=?')
          .bind(coins, at, payment.user_id).run();
        await recordCoinTx(env, payment.user_id, 'TOPUP', coins, 'Top-up ' + payment.id, null);
      }
    }
  }
  await env.DB.prepare("UPDATE payments SET status='SUCCESS',updated_at=? WHERE id=?").bind(at, payment.id).run();
  if (credited.meta.changes) {
    await adminAlert(env, {
      type: 'admin_payment', severity: 'high', amount: Number(payment.amount_egp) || 0,
      title: `Payment received: ${payment.amount_egp} EGP`,
      body: `${payment.purpose === 'pro' ? `Pro plan (${meta.plan || 'plan'})` : 'Wallet top-up'} · payment #${payment.id} · user #${payment.user_id}`,
      link: 'admin:payments', entityType: 'payment', entityId: String(payment.id),
      dedupeKey: `paid:${payment.id}`,
    }).catch(() => {});
  }
  return json({ ok: true });
}

async function paymobIntent(req, env, viewer) {
  if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
  const b = await readJson(req);
  const purpose = String(b.purpose || 'topup').toLowerCase();
  const plan = purpose === 'pro' ? PRO_PLANS[String(b.plan || '')] : null;
  if (purpose === 'pro' && !plan) {
    throw new HttpError(400, 'invalid_plan', 'Choose a valid plan.');
  }
  let amount = Number(b.amount_egp);
  if (purpose === 'pro') {
    const rate = await rateFor(env, 'EGP');
    amount = egpFromMrc(plan.price_mrc, rate.rate_to_mrc);
  }
  const method = String(b.method || 'card').toLowerCase();
  if (!['card', 'vodafone_cash', 'instapay'].includes(method)) {
    throw new HttpError(400, 'invalid_method', 'Choose a valid payment method.');
  }
  if (!Number.isFinite(amount) || amount <= 0 || amount > 100000) {
    throw new HttpError(400, 'invalid_amount', 'Enter a valid amount in EGP.');
  }
  const phone = clean(b.phone, 30);
  if (method === 'vodafone_cash' && !phone) {
    throw new HttpError(400, 'phone_required', 'A wallet phone number is required.');
  }
  const orgId = isAdminUser(env, viewer) && b.org_id != null ? String(b.org_id) : String(viewer.id);
  const at = nowIso();
  const inserted = await env.DB.prepare(`INSERT INTO payments
    (user_id,org_id,amount_egp,currency,method,status,phone,invoice_id,purpose,metadata_json,created_at,updated_at)
    VALUES (?,?,?,'EGP',?,'PENDING',?,?,?,?,?,?)`)
    .bind(viewer.id, orgId, amount, method,
      phone || null, clean(b.invoice_id, 80) || null, purpose,
      JSON.stringify({ plan: purpose === 'pro' ? plan.id : null, credited: false, consumed: false }), at, at).run();
  const paymentId = inserted.meta.last_row_id;
  const apiKey = env.PAYMOB_API_KEY;
  if (!apiKey) {
    const row = await env.DB.prepare('SELECT * FROM payments WHERE id=?').bind(paymentId).first();
    return json({ ok: true, configured: false, payment: paymentJson(row), order_id: String(paymentId),
      redirect_url: null, payment_key: null,
      message: 'Paymob is not configured yet. The payment was recorded for review.' });
  }
  const integrationId = paymobIntegration(env, method);
  if (!integrationId) throw new HttpError(503, 'method_unavailable', 'This payment method is not available yet.');
  const auth = await paymobPost('/auth/tokens', { api_key: apiKey });
  const order = await paymobPost('/ecommerce/orders', {
    auth_token: auth.token, delivery_needed: false, amount_cents: Math.round(amount * 100),
    currency: 'EGP', items: [],
  });
  const nameParts = String(viewer.name || 'MASAREEN User').trim().split(/\s+/);
  const paymentKey = await paymobPost('/acceptance/payment_keys', {
    auth_token: auth.token,
    amount_cents: Math.round(amount * 100),
    expiration: 3600,
    order_id: order.id,
    billing_data: {
      first_name: nameParts[0] || 'MASAREEN', last_name: nameParts.slice(1).join(' ') || 'User',
      email: viewer.email || 'hello@masareen.com', phone_number: phone || '00000000000',
      street: 'NA', building: 'NA', floor: 'NA', apartment: 'NA', city: 'NA',
      state: 'NA', country: 'EG', postal_code: 'NA',
    },
    currency: 'EGP',
    integration_id: Number(integrationId),
  });
  const redirect = env.PAYMOB_IFRAME_ID
    ? `https://accept.paymob.com/api/acceptance/iframes/${env.PAYMOB_IFRAME_ID}?payment_token=${paymentKey.token}`
    : null;
  await env.DB.prepare(`UPDATE payments SET paymob_order_id=?,payment_key=?,redirect_url=?,updated_at=? WHERE id=?`)
    .bind(String(order.id), paymentKey.token, redirect, nowIso(), paymentId).run();
  const row = await env.DB.prepare('SELECT * FROM payments WHERE id=?').bind(paymentId).first();
  return json({ ok: true, configured: true, payment: paymentJson(row), order_id: String(order.id),
    payment_key: paymentKey.token, redirect_url: redirect });
}

async function activatePro(env, userId, planId, paymentId = null) {
  const plan = PRO_PLANS[planId];
  if (!plan) throw new HttpError(400, 'invalid_plan', 'Choose a valid plan.');
  const now = new Date();
  const existing = await env.DB.prepare(`SELECT * FROM pro_subscriptions
    WHERE user_id=? AND status='ACTIVE' AND expires_at>? ORDER BY expires_at DESC`)
    .bind(userId, now.toISOString()).first();
  const start = existing ? new Date(existing.expires_at) : now;
  const expires = new Date(start.getTime() + plan.duration_days * 86400000);
  const at = now.toISOString();
  if (existing) {
    await env.DB.prepare('UPDATE pro_subscriptions SET expires_at=?,plan=?,payment_id=? WHERE id=?')
      .bind(expires.toISOString(), planId, paymentId, existing.id).run();
    return await env.DB.prepare('SELECT * FROM pro_subscriptions WHERE id=?').bind(existing.id).first();
  }
  const ins = await env.DB.prepare(`INSERT INTO pro_subscriptions
    (user_id,plan,status,started_at,expires_at,payment_id,created_at) VALUES (?,?,'ACTIVE',?,?,?,?)`)
    .bind(userId, planId, at, expires.toISOString(), paymentId, at).run();
  return await env.DB.prepare('SELECT * FROM pro_subscriptions WHERE id=?').bind(ins.meta.last_row_id).first();
}

async function commerceRoutes(req, env, url, viewer) {
  const path = url.pathname;
  const method = req.method;

  if (path === '/api/v1/payments/paymob/webhook' && method === 'POST') {
    return await paymobWebhook(req, env);
  }
  if (path === '/api/v1/payments/psp/status' && method === 'GET') {
    return json({ enabled: !!env.PAYMOB_API_KEY, configured: !!env.PAYMOB_API_KEY,
      provider: 'paymob', currency: 'EGP',
      methods: ['card', 'vodafone_cash', 'instapay'], available_methods: ['card', 'vodafone_cash', 'instapay'] });
  }
  if (path === '/api/v1/payments/psp/paymob/intent' && method === 'POST') {
    return await paymobIntent(req, env, viewer);
  }
  if (path === '/api/v1/payments' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const rows = (await env.DB.prepare(`SELECT * FROM payments WHERE user_id=?
      ORDER BY created_at DESC LIMIT 100`).bind(viewer.id).all()).results || [];
    return json(rows.map(paymentJson));
  }
  const paymentStatus = /^\/api\/v1\/payments\/(\d+)\/status$/.exec(path);
  if (paymentStatus && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const row = await env.DB.prepare('SELECT * FROM payments WHERE id=? AND user_id=?')
      .bind(Number(paymentStatus[1]), viewer.id).first();
    if (!row) throw new HttpError(404, 'payment_not_found', 'Payment not found.');
    return json(paymentJson(row));
  }
  const historyMatch = /^\/api\/v1\/payments\/([^/]+)\/history$/.exec(path);
  if (historyMatch && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const org = decodeURIComponent(historyMatch[1]);
    const rows = (await env.DB.prepare(`SELECT * FROM payments WHERE user_id=? AND (org_id=? OR ?=?)
      ORDER BY created_at DESC LIMIT 100`).bind(viewer.id, org, org, String(viewer.id)).all()).results || [];
    return json(rows.map(paymentJson));
  }
  const proPlans = path === '/api/v1/pro/plans' && method === 'GET';
  if (proPlans) {
    return json({ plans: Object.values(PRO_PLANS).map((p) => ({ id: p.id, name: p.id,
      price_mrc: p.price_mrc, duration_days: p.duration_days })) });
  }
  if (path === '/api/v1/pro/me' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const row = await env.DB.prepare(`SELECT * FROM pro_subscriptions WHERE user_id=? AND status='ACTIVE'
      AND expires_at>? ORDER BY expires_at DESC`).bind(viewer.id, nowIso()).first();
    return json({ active: !!row, subscription: row ? proJson(row) : null });
  }
  if (path === '/api/v1/pro/subscribe' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    const planId = String(b.plan || '');
    const plan = PRO_PLANS[planId];
    if (!plan) throw new HttpError(400, 'invalid_plan', 'Choose a valid plan.');
    if (b.payment_id) {
      const pay = await env.DB.prepare('SELECT * FROM payments WHERE id=? AND user_id=?')
        .bind(Number(b.payment_id), viewer.id).first();
      if (!pay || pay.status !== 'SUCCESS') throw new HttpError(400, 'payment_not_completed', 'Complete the payment first.');
      if (pay.purpose !== 'pro') throw new HttpError(400, 'invalid_payment', 'This payment was not made for a plan.');
      let payMeta = {};
      try { payMeta = JSON.parse(pay.metadata_json || '{}'); } catch { payMeta = {}; }
      if (payMeta.plan !== planId) throw new HttpError(400, 'plan_mismatch', 'This payment was made for another plan.');
      const consumed = await env.DB.prepare(`UPDATE payments SET metadata_json=?
        WHERE id=? AND metadata_json NOT LIKE '%"consumed":true%'`)
        .bind(JSON.stringify({ ...payMeta, consumed: true }), pay.id).run();
      if (!consumed.meta.changes) throw new HttpError(409, 'payment_already_used', 'This payment was already used.');
      const row = await activatePro(env, viewer.id, planId, pay.id);
      return json({ ok: true, subscription: proJson(row) });
    }
    await ensureWallet(env, viewer.id);
    const at = nowIso();
    const upd = await env.DB.prepare('UPDATE coin_wallets SET balance=balance-?,updated_at=? WHERE owner_id=? AND balance>=?')
      .bind(plan.price_mrc, at, viewer.id, plan.price_mrc).run();
    if (!upd.meta.changes) {
      throw new HttpError(400, 'insufficient_balance', 'You do not have enough MRC for this plan.');
    }
    await recordCoinTx(env, viewer.id, 'SPEND', plan.price_mrc, 'MASAREEN Pro ' + planId, null);
    const row = await activatePro(env, viewer.id, planId, null);
    return json({ ok: true, subscription: proJson(row) });
  }
  if (path === '/api/v1/pro/cancel' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    await env.DB.prepare(`UPDATE pro_subscriptions SET status='CANCELLED' WHERE user_id=? AND status='ACTIVE'`)
      .bind(viewer.id).run();
    return json({ ok: true });
  }

  if (path === '/api/v1/wallet' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    return json(await walletJson(env, viewer.id));
  }
  if (path === '/api/v1/coin/wallets' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    return json(await walletJson(env, viewer.id));
  }
  if (path === '/api/v1/coin/wallets' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    const owner = Number(b.owner_id || viewer.id);
    if (owner !== Number(viewer.id) && !isAdminUser(env, viewer)) {
      throw new HttpError(403, 'not_allowed', 'You can only create your own wallet.');
    }
    return json(await walletJson(env, owner));
  }
  const walletMatch = /^\/api\/v1\/coin\/wallets\/(\d+)$/.exec(path);
  if (walletMatch && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const owner = Number(walletMatch[1]);
    if (owner !== Number(viewer.id) && !isAdminUser(env, viewer)) {
      throw new HttpError(403, 'not_allowed', 'You can only view your own wallet.');
    }
    const row = await env.DB.prepare('SELECT * FROM coin_wallets WHERE owner_id=?').bind(owner).first();
    if (!row) throw new HttpError(404, 'wallet_not_found', 'Wallet not found.');
    return json(await walletJson(env, owner));
  }
  if (path === '/api/v1/coin/transactions' && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const rows = (await env.DB.prepare('SELECT * FROM coin_transactions WHERE owner_id=? ORDER BY created_at DESC LIMIT 200')
      .bind(viewer.id).all()).results || [];
    return json(rows.map(coinTxJson));
  }
  const txListMatch = /^\/api\/v1\/coin\/transactions\/(\d+)$/.exec(path);
  if (txListMatch && method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const owner = Number(txListMatch[1]);
    if (owner !== Number(viewer.id) && !isAdminUser(env, viewer)) {
      throw new HttpError(403, 'not_allowed', 'You can only view your own transactions.');
    }
    const rows = (await env.DB.prepare('SELECT * FROM coin_transactions WHERE owner_id=? ORDER BY created_at DESC LIMIT 200')
      .bind(owner).all()).results || [];
    return json(rows.map(coinTxJson));
  }
  if (path === '/api/v1/coin/transactions/earn' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    // The reward is set by the server. A client may send an amount for
    // backward compatibility, but it is ignored so the daily reward cannot be
    // inflated from the app.
    const amount = dailyRewardFor(env);
    const today = new Date().toISOString().slice(0, 10);
    const claim = await env.DB.prepare(`INSERT OR IGNORE INTO daily_claims (owner_id,claim_date,amount,created_at)
      VALUES (?,?,?,?)`).bind(viewer.id, today, amount, nowIso()).run();
    if (!claim.meta.changes) throw new HttpError(429, 'daily_claim_used', 'You already claimed today\'s reward.');
    try {
      await ensureWallet(env, viewer.id);
      await env.DB.prepare('UPDATE coin_wallets SET balance=balance+?,updated_at=? WHERE owner_id=?')
        .bind(amount, nowIso(), viewer.id).run();
      await recordCoinTx(env, viewer.id, 'EARN', amount, clean(b.reference, 120) || 'Daily reward', null);
    } catch (e) {
      await env.DB.prepare('DELETE FROM daily_claims WHERE owner_id=? AND claim_date=?').bind(viewer.id, today).run();
      throw e;
    }
    return json(await walletJson(env, viewer.id));
  }
  if (path === '/api/v1/coin/transactions/spend' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    const amount = Number(b.amount);
    if (!Number.isFinite(amount) || amount <= 0) throw new HttpError(400, 'invalid_amount', 'Enter a valid amount.');
    await ensureWallet(env, viewer.id);
    const at = nowIso();
    const upd = await env.DB.prepare('UPDATE coin_wallets SET balance=balance-?,updated_at=? WHERE owner_id=? AND balance>=?')
      .bind(amount, at, viewer.id, amount).run();
    if (!upd.meta.changes) throw new HttpError(400, 'insufficient_balance', 'You do not have enough MRC.');
    await recordCoinTx(env, viewer.id, 'SPEND', amount, clean(b.reference, 120) || 'Spend', null);
    return json(await walletJson(env, viewer.id));
  }
  if (path === '/api/v1/coin/transactions/transfer' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
    const amount = Number(b.amount);
    const target = Number(b.counterparty_id);
    if (!Number.isFinite(amount) || amount <= 0) throw new HttpError(400, 'invalid_amount', 'Enter a valid amount.');
    if (!Number.isInteger(target) || target <= 0) throw new HttpError(400, 'invalid_recipient', 'Choose a valid recipient.');
    if (target === Number(viewer.id)) throw new HttpError(400, 'self_transfer', 'You cannot transfer to yourself.');
    const recipient = await env.DB.prepare('SELECT id,name FROM users WHERE id=?').bind(target).first();
    if (!recipient) throw new HttpError(404, 'recipient_not_found', 'Recipient not found.');
    await ensureWallet(env, viewer.id);
    await ensureWallet(env, target);
    const at = nowIso();
    const reference = clean(b.reference, 120) || 'Transfer';
    const [debit] = await env.DB.batch([
      env.DB.prepare('UPDATE coin_wallets SET balance=balance-?,updated_at=? WHERE owner_id=? AND balance>=?')
        .bind(amount, at, viewer.id, amount),
      env.DB.prepare('UPDATE coin_wallets SET balance=balance+?,updated_at=? WHERE owner_id=?')
        .bind(amount, at, target),
    ]);
    if (!debit.meta.changes) throw new HttpError(400, 'insufficient_balance', 'You do not have enough MRC.');
    const sender = await env.DB.prepare('SELECT balance FROM coin_wallets WHERE owner_id=?').bind(viewer.id).first();
    const receiver = await env.DB.prepare('SELECT balance FROM coin_wallets WHERE owner_id=?').bind(target).first();
    await env.DB.batch([
      env.DB.prepare(`INSERT INTO coin_transactions
        (owner_id,type,amount,balance_after,reference,counterparty_id,created_at) VALUES (?,?,?,?,?,?,?)`)
        .bind(viewer.id, 'TRANSFER_OUT', amount, Number(sender.balance || 0), reference, target, at),
      env.DB.prepare(`INSERT INTO coin_transactions
        (owner_id,type,amount,balance_after,reference,counterparty_id,created_at) VALUES (?,?,?,?,?,?,?)`)
        .bind(target, 'TRANSFER_IN', amount, Number(receiver.balance || 0), reference, viewer.id, at),
    ]);
    return json(await walletJson(env, viewer.id));
  }
  if (path === '/api/v1/coin/exchange/rate' && method === 'GET') {
    return json(await rateFor(env, url.searchParams.get('currency') || 'EGP'));
  }
  if (path === '/api/v1/coin/exchange/rate' && method === 'POST') {
    const admin = await requireAdmin(req, env);
    const b = await readJson(req);
    const currency = String(b.currency || 'EGP').toUpperCase();
    const rate = Number(b.rate_to_mrc);
    if (!Number.isFinite(rate) || rate <= 0) throw new HttpError(400, 'invalid_rate', 'Enter a valid rate.');
    await env.DB.prepare(`INSERT INTO coin_rates (currency,rate_to_mrc,updated_at) VALUES (?,?,?)
      ON CONFLICT(currency) DO UPDATE SET rate_to_mrc=excluded.rate_to_mrc,updated_at=excluded.updated_at`)
      .bind(currency, rate, nowIso()).run();
    return json(await rateFor(env, currency));
  }
  if (path === '/api/v1/coin/exchange/convert' && method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    throw new HttpError(400, 'payouts_disabled', 'Fiat payouts are not available yet. Your MRC balance stays untouched.');
  }
  return null;
}

async function userRoutes(req, env, url, viewer) {
  const path = url.pathname;
  if (path === '/api/v1/users/me' && req.method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    return json(await userJson(env, viewer, viewer));
  }
  if (path === '/api/v1/users/me/profile' && (req.method === 'PATCH' || req.method === 'POST')) {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const b = await readJson(req);
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
  if (path === '/api/v1/users/me/bookmarks' && req.method === 'GET') return await listBookmarks(req, env, url);
  if (path === '/api/v1/users/me/blocked' && req.method === 'GET') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const rows = (await env.DB.prepare(`SELECT u.id,u.name,u.handle,u.picture,u.role,b.created_at blocked_at
      FROM user_blocks b JOIN users u ON u.id=b.blocked_id WHERE b.blocker_id=? ORDER BY b.created_at DESC`)
      .bind(viewer.id).all()).results || [];
    return json(rows.map((u) => ({ id: String(u.id), name: u.name, full_name: u.name,
      handle: u.handle || handleFor(u.name, u.id), avatar_url: u.picture || null, role: u.role,
      blocked_at: u.blocked_at })));
  }
  const blockMatch = /^\/api\/v1\/users\/(\d+)\/block$/.exec(path);
  if (blockMatch && req.method === 'POST') {
    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
    const target = Number(blockMatch[1]);
    if (target === viewer.id) throw new HttpError(400, 'self_block', 'You cannot block yourself.');
    const exists = await env.DB.prepare('SELECT 1 x FROM users WHERE id=?').bind(target).first();
    if (!exists) throw new HttpError(404, 'user_not_found', 'Profile not found.');
    const has = await env.DB.prepare('SELECT 1 x FROM user_blocks WHERE blocker_id=? AND blocked_id=?').bind(viewer.id, target).first();
    if (has) {
      await env.DB.prepare('DELETE FROM user_blocks WHERE blocker_id=? AND blocked_id=?').bind(viewer.id, target).run();
    } else {
      await env.DB.prepare('INSERT INTO user_blocks (blocker_id,blocked_id,created_at) VALUES (?,?,?)')
        .bind(viewer.id, target, nowIso()).run();
      await env.DB.prepare('DELETE FROM follows WHERE (follower_id=? AND followee_id=?) OR (follower_id=? AND followee_id=?)')
        .bind(viewer.id, target, target, viewer.id).run();
    }
    return json({ ok: true, blocked: !has });
  }
  const userReportMatch = /^\/api\/v1\/users\/(\d+)\/report$/.exec(path);
  if (userReportMatch && req.method === 'POST') return await reportTarget(req, env, 'user', Number(userReportMatch[1]));
  const followMatch = /^\/api\/v1\/users\/(\d+)\/follow$/.exec(path);
  if (followMatch && req.method === 'POST') {    if (!viewer) throw new HttpError(401, 'not_signed_in', 'Please sign in.');
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
    try {
      jsonUser.events = (await env.DB.prepare(`SELECT id,title,description,starts_at,ends_at,location,is_online,
        cover_url,event_type,sdg,capacity,activity_verified_at,status
        FROM events WHERE author_id=? AND status='PUBLISHED'
        ORDER BY starts_at DESC LIMIT 30`).bind(u.id).all()).results || [];
    } catch (_) { jsonUser.events = []; }
    try {
      jsonUser.programs = (await env.DB.prepare(`SELECT id,title,description,cover_url,status,organization,
        sdg FROM programs WHERE author_id=? ORDER BY created_at DESC LIMIT 30`)
        .bind(u.id).all()).results || [];
    } catch (_) { jsonUser.programs = []; }
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
    ...career.filter((c) => c.season).map((c) => ({ kind: 'season', title: `${c.season} Â· ${c.team || c.competition || 'Season'}`,
      detail: `${c.appearances} apps Â· ${c.goals} goals Â· ${c.assists} assists`, date: c.season })),
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
  const b = await readJson(req);
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
  const b = await readJson(req);
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

const ENTITY_TYPES = {
  user: { table: 'users', title: 'name' },
  course: { table: 'courses', title: 'title' },
  event: { table: 'events', title: 'title' },
  program: { table: 'programs', title: 'title' },
  project: { table: 'projects', title: 'title' },
  opportunity: { table: 'opportunities', title: 'title' },
  research_stage: { table: 'research_stages', title: 'title' },
  post: { table: 'posts', title: 'text' },
};
const RESEARCH_STAGES = new Set(['IDEA', 'LITERATURE', 'METHODOLOGY', 'FIELDWORK',
  'ANALYSIS', 'RESULTS', 'PUBLISHED']);

function entityType(value) {
  const key = String(value || '').trim().toLowerCase().replace(/s$/, '');
  return key === 'research_stage' || key === 'researchstages' ? 'research_stage' : key;
}

async function loadEntity(env, type, id) {
  const def = ENTITY_TYPES[type];
  if (!def) throw new HttpError(400, 'invalid_entity_type', 'Choose a valid entity type.');
  const row = await env.DB.prepare(`SELECT * FROM ${def.table} WHERE id=?`)
    .bind(Number(id)).first();
  if (!row) throw new HttpError(404, 'entity_not_found', 'That entity does not exist.');
  const rawTitle = row[def.title] || row.name || row.title;
  const title = rawTitle ? String(rawTitle).slice(0, 120) : 'Entity';
  return {
    type, id: String(row.id), title,
    author_id: type === 'user' ? Number(row.id)
      : Number(row.author_id || row.researcher_id || 0),
    row,
  };
}

async function saveEntityLinks(env, sourceType, sourceId, links, actor) {
  if (!Array.isArray(links) || !links.length) return [];
  const out = [];
  for (const item of links.slice(0, 20)) {
    if (!item || typeof item !== 'object') continue;
    const targetType = entityType(item.target_type || item.type);
    const targetId = String(item.target_id || item.id || '').trim();
    if (!targetId) continue;
    const target = await loadEntity(env, targetType, targetId);
    if (sourceType === targetType && String(sourceId) === target.id) continue;
    const relation = clean(item.relation, 40).toUpperCase().replace(/[^A-Z0-9_]/g, '_') || 'RELATED';
    await env.DB.prepare(`INSERT OR IGNORE INTO entity_links
      (source_type,source_id,target_type,target_id,relation,created_by,created_at)
      VALUES (?,?,?,?,?,?,?)`)
      .bind(sourceType, String(sourceId), targetType, target.id, relation, actor.id, nowIso()).run();
    out.push({ source_type: sourceType, source_id: String(sourceId), target_type: targetType,
      target_id: target.id, relation, title: target.title });
  }
  return out;
}

async function linkedEntitiesFor(env, userId) {
  const approved = "verification_status='APPROVED'";
  const [courses, events, programs, projects, opportunities, research, podcasts, vod, outgoing, incoming] =
    await Promise.all([
      env.DB.prepare(`SELECT id,title,provider,thumbnail,level,lessons,is_free,price_mrc
        FROM courses WHERE author_id=? AND ${approved} ORDER BY created_at DESC LIMIT 50`)
        .bind(userId).all(),
      env.DB.prepare(`SELECT e.id,e.author_id,e.title,e.starts_at,e.location,e.is_online,
        e.cover_url,e.funding_goal,e.funding_raised,e.event_type,e.activity_verified_at
        FROM events e WHERE (e.author_id=? OR EXISTS (
          SELECT 1 FROM event_participants p WHERE p.event_id=e.id AND p.user_id=?
            AND p.status IN ('CONFIRMED','VERIFIED'))) AND e.${approved}
        ORDER BY e.starts_at ASC LIMIT 50`)
        .bind(userId, userId).all(),
      env.DB.prepare(`SELECT id,title,cover_url,status FROM programs WHERE author_id=? AND ${approved}
        ORDER BY created_at DESC LIMIT 50`).bind(userId).all(),
      env.DB.prepare(`SELECT id,title,cover,goal,raised,project_type,institution_id
        FROM projects WHERE (author_id=? OR institution_id=?) AND ${approved}
        ORDER BY created_at DESC LIMIT 50`).bind(userId, userId).all(),
      env.DB.prepare(`SELECT id,title,type,location,is_remote,deadline,cover_url
        FROM opportunities WHERE author_id=? AND ${approved} ORDER BY created_at DESC LIMIT 50`)
        .bind(userId).all(),
      env.DB.prepare(`SELECT id,title,stage,summary,status,post_id,project_id,media_url,created_at
        FROM research_stages WHERE (researcher_id=? OR institution_id=?)
        ORDER BY created_at DESC LIMIT 50`).bind(userId, userId).all(),
      env.DB.prepare(`SELECT id,title,description,cover_url,category,episodes_count FROM (
        SELECT s.*,(SELECT COUNT(*) FROM podcast_episodes e WHERE e.show_id=s.id) episodes_count
        FROM podcast_shows s WHERE s.owner_id=? AND s.status='ACTIVE'
          AND s.verification_status='APPROVED') ORDER BY created_at DESC LIMIT 50`)
        .bind(userId).all(),
      env.DB.prepare(`SELECT id,title,description,cover_url,video_url,hls_url,duration_sec,event_id
        FROM vod_videos WHERE owner_id=? AND status='PUBLISHED'
          AND verification_status='APPROVED' ORDER BY created_at DESC LIMIT 50`)
        .bind(userId).all(),
      env.DB.prepare(`SELECT * FROM entity_links WHERE source_type='user' AND source_id=?
        ORDER BY created_at DESC LIMIT 100`).bind(String(userId)).all(),
      env.DB.prepare(`SELECT * FROM entity_links WHERE target_type='user' AND target_id=?
        ORDER BY created_at DESC LIMIT 100`).bind(String(userId)).all(),
    ]);
  const links = [];
  for (const [list, direction] of [[outgoing, 'out'], [incoming, 'in']]) {
    for (const link of list.results || []) {
      const otherType = direction === 'out' ? link.target_type : link.source_type;
      const otherId = direction === 'out' ? link.target_id : link.source_id;
      try {
        const other = await loadEntity(env, otherType, otherId);
        links.push({
          id: String(link.id), relation: link.relation, direction,
          target_type: otherType, target_id: other.id, title: other.title,
        });
      } catch (_) {}
    }
  }
  const mapRows = (result) => (result.results || []).map((r) => ({
    ...r, id: String(r.id),
    ...(r.post_id == null ? {} : { post_id: String(r.post_id) }),
  }));
  return {
    courses: mapRows(courses), events: mapRows(events), programs: mapRows(programs),
    projects: mapRows(projects), opportunities: mapRows(opportunities),
    research_stages: mapRows(research), podcasts: mapRows(podcasts),
    vod: mapRows(vod), links,
  };
}

async function listInstitutions(env, url) {
  const q = clean(url.searchParams.get('q'), 80).toLowerCase();
  const type = clean(url.searchParams.get('type'), 40).toUpperCase();
  const rows = (await env.DB.prepare(`SELECT u.id,u.name,u.handle,u.picture,u.cover_url,
    u.role,u.country,u.city,u.bio,u.email_verified,ip.institution_type,ip.jurisdiction,
    ip.transparency_score,
    (SELECT COUNT(*) FROM courses c WHERE c.author_id=u.id AND c.verification_status='APPROVED') courses,
    (SELECT COUNT(*) FROM events e WHERE e.author_id=u.id AND e.verification_status='APPROVED') events,
    (SELECT COUNT(*) FROM programs p WHERE p.author_id=u.id AND p.verification_status='APPROVED') programs,
    (SELECT COUNT(*) FROM projects x WHERE (x.author_id=u.id OR x.institution_id=u.id)
      AND x.verification_status='APPROVED') projects,
    (SELECT COUNT(*) FROM opportunities o WHERE o.author_id=u.id AND o.verification_status='APPROVED') opportunities,
    (SELECT COUNT(*) FROM research_stages r WHERE r.institution_id=u.id OR r.researcher_id=u.id) research
    FROM users u LEFT JOIN institution_profiles ip ON ip.user_id=u.id
    WHERE ip.user_id IS NOT NULL OR u.role IN
      ('UNIVERSITY','INSTITUTION','ORGANIZATION','GOVERNMENT','MEDIA','SPORTS','FEDERATION','CLUB')
    ORDER BY u.email_verified DESC, u.name ASC LIMIT 250`).all()).results || [];
  return rows
    .map((r) => {
      const kind = String(r.institution_type || r.role || 'INSTITUTION').toUpperCase();
      return {
        id: String(r.id), name: r.name, handle: r.handle || null,
        avatar_url: r.picture || null, cover_url: r.cover_url || null,
        role: r.role, institution_type: kind, jurisdiction: r.jurisdiction || null,
        country: r.country || null, city: r.city || null, bio: r.bio || '',
        verified: !!r.email_verified,
        transparency_score: Number(r.transparency_score || 0),
        counts: {
          courses: Number(r.courses || 0), events: Number(r.events || 0),
          programs: Number(r.programs || 0), projects: Number(r.projects || 0),
          opportunities: Number(r.opportunities || 0), research: Number(r.research || 0),
        },
      };
    })
    .filter((r) => (!type || r.institution_type.includes(type)) &&
      (!q || `${r.name} ${r.handle || ''} ${r.city || ''} ${r.country || ''}`
        .toLowerCase().includes(q)));
}

function researchStageJson(r) {
  return {
    id: String(r.id), researcher_id: String(r.researcher_id),
    researcher_name: r.researcher_name || null,
    institution_id: r.institution_id == null ? null : String(r.institution_id),
    project_id: r.project_id == null ? null : String(r.project_id),
    post_id: r.post_id == null ? null : String(r.post_id),
    title: r.title, stage: r.stage || 'IDEA', summary: r.summary || null,
    status: r.status || 'ACTIVE', media_url: r.media_url || null,
    created_at: r.created_at, updated_at: r.updated_at,
  };
}

async function createResearchStage(req, env) {
  const u = await requireUser(req, env);
  const allowedRoles = new Set(['ACADEMIC', 'RESEARCHER', 'STUDENT', 'PROFESSIONAL',
    'UNIVERSITY', 'INSTITUTION']);
  if (!allowedRoles.has(String(u.role || '').toUpperCase()) && !isAdminUser(env, u)) {
    throw new HttpError(403, 'researcher_only',
      'Research stages are for verified academics, researchers and university members.');
  }
  const b = await readJson(req);
  const title = clean(b.title, 160);
  const summary = clean(b.summary || b.description, 3000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Add a research stage title.');
  assertModerated(title, summary);
  const stage = RESEARCH_STAGES.has(String(b.stage || '').toUpperCase())
    ? String(b.stage).toUpperCase() : 'IDEA';
  let institutionId = num(b.institution_id);
  if (institutionId != null) {
    const inst = await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(institutionId).first();
    if (!inst) institutionId = null;
  }
  let projectId = num(b.project_id);
  if (projectId != null) {
    const project = await env.DB.prepare('SELECT id FROM projects WHERE id=?').bind(projectId).first();
    if (!project) projectId = null;
  }
  const at = nowIso();
  const r = await env.DB.prepare(`INSERT INTO research_stages
    (researcher_id,institution_id,project_id,title,stage,summary,status,media_url,created_at,updated_at)
    VALUES (?,?,?,?,?,?,'ACTIVE',?,?,?)`)
    .bind(u.id, institutionId, projectId, title, stage, summary || null,
      safeMediaUrl(b.media_url), at, at).run();
  const id = r.meta.last_row_id;
  const postText = `${title}\n\n${summary || ''}`.trim();
  const post = await env.DB.prepare(`INSERT INTO posts
    (author_id,text,kind,structured_json,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
    VALUES (?,?,'RESEARCH_STAGE',?,'APPROVED',?,'local-hash','USER',?,?)`)
    .bind(u.id, postText, JSON.stringify({ research_stage: { id: String(id), stage,
      institution_id: institutionId == null ? null : String(institutionId) },
      research_stage_id: String(id) }), JSON.stringify(embeddingFor(postText)), at, at).run();
  const postId = post.meta.last_row_id;
  await env.DB.prepare('UPDATE research_stages SET post_id=? WHERE id=?').bind(postId, id).run();
  if (institutionId) {
    await saveEntityLinks(env, 'research_stage', String(id),
      [{ target_type: 'user', target_id: String(institutionId), relation: 'PUBLISHED_WITH' }], u);
  }
  await saveEntityLinks(env, 'research_stage', String(id),
    [{ target_type: 'post', target_id: String(postId), relation: 'PUBLISHED_AS' }], u);
  const followers = (await env.DB.prepare('SELECT follower_id FROM follows WHERE followee_id=? LIMIT 200')
    .bind(u.id).all()).results || [];
  for (const f of followers) {
    await notify(env, f.follower_id, 'research',
      `${u.name || 'A researcher'} shared a research stage`,
      `${title} · ${stage}`, u.id, postId,
      { link: `post:${postId}`, entityType: 'research_stage', entityId: String(id) }).catch(() => {});
  }
  const row = await env.DB.prepare(`SELECT r.*,u.name researcher_name FROM research_stages r
    LEFT JOIN users u ON u.id=r.researcher_id WHERE r.id=?`).bind(id).first();
  return json(researchStageJson(row), 201);
}

async function fundEvent(req, env, id) {
  const u = await requireUser(req, env);
  const event = await env.DB.prepare('SELECT * FROM events WHERE id=?').bind(id).first();
  if (!event || event.verification_status !== 'APPROVED') {
    throw new HttpError(404, 'event_not_found', 'Event not found.');
  }
  if (Number(event.author_id) === Number(u.id)) {
    throw new HttpError(400, 'own_event', 'You cannot fund your own event.');
  }
  const b = await readJson(req);
  const amount = Math.round((Number(b.amount) || 0) * 100) / 100;
  if (!Number.isFinite(amount) || amount <= 0 || amount > 100000) {
    throw new HttpError(400, 'invalid_amount', 'Enter a valid funding amount.');
  }
  await debitCoins(env, u.id, amount, `Funding event #${id}`);
  await creditCoins(env, event.author_id, amount, `Event funding #${id}`);
  await env.DB.prepare('UPDATE events SET funding_raised=funding_raised+? WHERE id=?')
    .bind(amount, id).run();
  if (Number(event.author_id) !== Number(u.id)) {
    await notify(env, event.author_id, 'funding',
      `${u.name || 'A supporter'} funded your event`,
      `${amount} MRC toward ${event.title}.`, u.id, null,
      { link: `event:${id}`, entityType: 'event', entityId: String(id) }).catch(() => {});
  }
  const row = await env.DB.prepare(`SELECT e.*, u.name author_name, u.picture author_picture
    FROM events e LEFT JOIN users u ON u.id=e.author_id WHERE e.id=?`).bind(id).first();
  return json({ ok: true, amount, event: eventJson(row, false) });
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

  if (path === '/api/v1/institutions' && req.method === 'GET') {
    return json(await listInstitutions(env, url));
  }

  if (path === '/api/v1/research/stages') {
    if (req.method === 'GET') {
      const userId = num(url.searchParams.get('user_id'));
      const institutionId = num(url.searchParams.get('institution_id'));
      const limit = clamp(parseInt(url.searchParams.get('limit') || '50', 10) || 50, 1, 100);
      const rows = (await env.DB.prepare(`SELECT r.*, u.name researcher_name, u.picture researcher_picture
        FROM research_stages r LEFT JOIN users u ON u.id=r.researcher_id
        WHERE (? IS NULL OR r.researcher_id=?) AND (? IS NULL OR r.institution_id=?)
        ORDER BY r.created_at DESC LIMIT ?`)
        .bind(userId, userId, institutionId, institutionId, limit).all()).results || [];
      return json(rows.map(researchStageJson));
    }
    if (req.method === 'POST') return await createResearchStage(req, env);
  }

  if (path === '/api/v1/entity-links') {
    if (req.method === 'GET') {
      const sourceType = entityType(url.searchParams.get('source_type'));
      const sourceId = String(url.searchParams.get('source_id') || '').trim();
      if (!ENTITY_TYPES[sourceType] || !sourceId) {
        throw new HttpError(400, 'invalid_request', 'Specify an entity type and id.');
      }
      const rows = (await env.DB.prepare(`SELECT * FROM entity_links
        WHERE (source_type=? AND source_id=?) OR (target_type=? AND target_id=?)
        ORDER BY created_at DESC LIMIT 200`)
        .bind(sourceType, sourceId, sourceType, sourceId).all()).results || [];
      const links = [];
      for (const link of rows) {
        const out = link.source_type === sourceType && link.source_id === sourceId;
        const otherType = out ? link.target_type : link.source_type;
        const otherId = out ? link.target_id : link.source_id;
        try {
          const other = await loadEntity(env, otherType, otherId);
          links.push({ id: String(link.id), relation: link.relation,
            direction: out ? 'out' : 'in', target_type: otherType,
            target_id: other.id, title: other.title });
        } catch (_) {}
      }
      return json(links);
    }
    if (req.method === 'POST') {
      const u = await requireUser(req, env);
      const b = await readJson(req);
      const sourceType = entityType(b.source_type || 'user');
      const sourceId = String(b.source_id || u.id).trim();
      if (!ENTITY_TYPES[sourceType]) {
        throw new HttpError(400, 'invalid_entity_type', 'Choose a valid entity type.');
      }
      if (sourceType === 'user') {
        if (String(sourceId) !== String(u.id) && !isAdminUser(env, u)) {
          throw new HttpError(403, 'not_allowed', 'You can only link content to your own profile.');
        }
      } else {
        const source = await loadEntity(env, sourceType, sourceId);
        if (Number(source.author_id) !== Number(u.id) && !isAdminUser(env, u)) {
          throw new HttpError(403, 'not_allowed', 'Only the owner can link this entity.');
        }
      }
      const linked = await saveEntityLinks(env, sourceType, sourceId, b.links || [b], u);
      return json({ ok: true, links: linked }, 201);
    }
  }

  const entityLinkMatch = /^\/api\/v1\/entity-links\/(\d+)$/.exec(path);
  if (entityLinkMatch && req.method === 'DELETE') {
    const u = await requireUser(req, env);
    const link = await env.DB.prepare('SELECT * FROM entity_links WHERE id=?')
      .bind(Number(entityLinkMatch[1])).first();
    if (!link) throw new HttpError(404, 'link_not_found', 'Link not found.');
    if (Number(link.created_by) !== Number(u.id) && !isAdminUser(env, u)) {
      throw new HttpError(403, 'not_allowed', 'Only the creator can remove this link.');
    }
    await env.DB.prepare('DELETE FROM entity_links WHERE id=?').bind(link.id).run();
    return json({ ok: true });
  }

  const eventFundMatch = /^\/api\/v1\/events\/(\d+)\/fund$/.exec(path);
  if (eventFundMatch && req.method === 'POST') return await fundEvent(req, env, Number(eventFundMatch[1]));

  const institutionMatch = /^\/api\/v1\/(?:institutions|users)\/(\d+)\/institution$/.exec(path);
  if (institutionMatch && req.method === 'GET') {
    const id = Number(institutionMatch[1]);
    const user = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();
    if (!user) throw new HttpError(404, 'user_not_found', 'Institution not found.');
    const row = await env.DB.prepare('SELECT * FROM institution_profiles WHERE user_id=?').bind(id).first();
    const linked = await linkedEntitiesFor(env, id);
    const following = viewer
      ? await env.DB.prepare('SELECT 1 x FROM follows WHERE follower_id=? AND followee_id=?')
          .bind(viewer.id, id).first()
      : null;
    const followerCount = Number((await env.DB.prepare(
      'SELECT COUNT(*) c FROM follows WHERE followee_id=?').bind(id).first())?.c || 0);
    const profile = {
      user_id: String(user.id), name: user.name, handle: user.handle || null, role: user.role, bio: user.bio || '',
      avatar_url: user.picture || null, cover_url: user.cover_url || null, country: user.country || null,
      city: user.city || null, verified: !!user.email_verified,
      is_following: !!following, followers_count: followerCount,
      institution_type: row?.institution_type || (user.role || 'GOVERNMENT'),
      jurisdiction: row?.jurisdiction || null, services: parseJsonValue(row?.services_json, []),
      departments: parseJsonValue(row?.departments_json, []), metrics: parseJsonValue(row?.metrics_json, {}),
      transparency_score: row ? Number(row.transparency_score || 0) : 0,
      reputation: await organizerReputation(env, id),
      linked,
    };
    return json(profile);
  }
  return null;
}

/* ---------------- internal HLS ingest (secret-protected) ---------------- */
function requireIngest(req, env) {
  if (!env.INGEST_SECRET) throw new HttpError(503, 'ingest_unavailable', 'Video ingest is not configured yet.');
  const supplied = req.headers.get('x-ingest-secret') || '';
  if (!timingSafeHex(supplied, env.INGEST_SECRET)) throw new HttpError(401, 'unauthorized', 'Invalid ingest secret.');
}

async function aiInternalRoutes(req, env, url) {
  const path = url.pathname;
  requireIngest(req, env);
  if (path === '/api/v1/internal/ai/posts' && req.method === 'GET') {
    const status = clean(url.searchParams.get('status'), 40) || 'transcription_queued';
    const limit = clamp(parseInt(url.searchParams.get('limit') || '10', 10) || 10, 1, 50);
    const rows = (await env.DB.prepare(`SELECT id,user_id,text,media_url,media_type,video_hls_url,
      transcript,embedding_status,moderation_status,created_at FROM posts
      WHERE embedding_status=? AND hidden=0 ORDER BY created_at ASC LIMIT ?`)
      .bind(status, limit).all()).results || [];
    return json(rows.map((r) => ({
      id: String(r.id), user_id: String(r.user_id), text: r.text || '',
      media_url: r.media_url || null, media_type: r.media_type || null,
      video_hls_url: r.video_hls_url || null, transcript: r.transcript || null,
      embedding_status: r.embedding_status || 'none',
      moderation_status: r.moderation_status || 'APPROVED', created_at: r.created_at,
    })));
  }
  const match = /^\/api\/v1\/internal\/ai\/posts\/(\d+)$/.exec(path);
  if (match && req.method === 'POST') {
    const id = Number(match[1]);
    const post = await env.DB.prepare(`SELECT id,author_id,text,structured_json,embedding_json,
      embedding_status,transcript FROM posts WHERE id=?`).bind(id).first();
    if (!post) throw new HttpError(404, 'post_not_found', 'Post not found.');
    const b = await readJson(req);
    const transcript = clean(b.transcript, 20000);
    let vector = null;
    if (Array.isArray(b.embedding)) {
      const nums = b.embedding.map((v) => Number(v));
      if (nums.length >= 8 && nums.length <= 4096 && nums.every(Number.isFinite)) {
        vector = nums.map((v) => Math.round(v * 1e6) / 1e6);
      }
    }
    const moderation = moderateText(`${post.text || ''}\n${transcript}`);
    const requested = String(b.moderation_status || '').toUpperCase();
    const moderationStatus = ['APPROVED', 'REVIEW', 'BLOCKED'].includes(requested)
      ? requested : moderation.status;
    const structured = parseJsonValue(post.structured_json, {});
    const ai = {
      provider: clean(b.provider, 40) || null,
      model: clean(b.model, 80) || null,
      language: clean(b.language, 20) || null,
      updated_at: nowIso(),
    };
    const merged = {
      ...(structured && typeof structured === 'object' ? structured : {}),
      ai,
    };
    const suppliedStatus = clean(b.embedding_status, 40).toLowerCase()
      .replace(/[^a-z0-9_-]/g, '');
    const embeddingStatus = vector ? 'embedded'
      : (suppliedStatus || post.embedding_status || 'none');
    const at = nowIso();
    await env.DB.prepare(`UPDATE posts SET transcript=COALESCE(?,transcript),
      embedding_json=COALESCE(?,embedding_json), embedding_status=?, moderation_status=?,
      structured_json=?, hidden=?, updated_at=? WHERE id=?`)
      .bind(transcript || null, vector ? JSON.stringify(vector) : null, embeddingStatus,
        moderationStatus, JSON.stringify(merged), moderationStatus === 'BLOCKED' ? 1 : 0, at, id).run();
    if (moderationStatus === 'BLOCKED') {
      await notify(env, post.author_id, 'moderation', 'Your post was removed',
        moderation.reason || 'It violated the community guidelines.', null, id,
        { link: `post:${id}` }).catch(() => {});
    } else if (moderationStatus === 'REVIEW') {
      await adminAlert(env, {
        type: 'moderation', severity: 'normal',
        title: 'AI flagged a post for review',
        body: (transcript || post.text || '').slice(0, 200),
        link: 'admin:moderation', entityType: 'post', entityId: String(id),
        dedupeKey: `ai_review:${id}`,
      }).catch(() => {});
    }
    return json({
      ok: true, id: String(id), embedding_status: embeddingStatus,
      moderation_status: moderationStatus, dimensions: vector ? vector.length : null,
    });
  }
  throw new HttpError(404, 'not_found', 'Unknown AI route.');
}

async function videoJobRoutes(req, env, url) {
  const path = url.pathname;
  if (!path.startsWith('/api/v1/internal/')) return null;
  requireIngest(req, env);
  if (path === '/api/v1/internal/video-jobs' && req.method === 'GET') {
    const status = clean(url.searchParams.get('status'), 20) || 'queued';
    const limit = clamp(parseInt(url.searchParams.get('limit') || '10', 10) || 10, 1, 50);
    const staleSeconds = clamp(parseInt(url.searchParams.get('stale_seconds') || '0', 10) || 0, 0, 86400);
    let rows;
    if (status === 'processing' && staleSeconds > 0) {
      const cutoff = new Date(Date.now() - staleSeconds * 1000).toISOString();
      rows = (await env.DB.prepare(`SELECT * FROM video_jobs WHERE status='processing' AND updated_at<? ORDER BY created_at ASC LIMIT ?`)
        .bind(cutoff, limit).all()).results || [];
    } else {
      rows = (await env.DB.prepare('SELECT * FROM video_jobs WHERE status=? ORDER BY created_at ASC LIMIT ?')
        .bind(status, limit).all()).results || [];
    }
    return json(rows.map((j) => ({ id: j.id, user_id: String(j.user_id), post_id: j.post_id == null ? null : String(j.post_id),
      status: j.status, original_url: j.original_url, hls_url: j.hls_url || null, poster_url: j.poster_url || null,
      duration_seconds: j.duration_seconds == null ? null : Number(j.duration_seconds), error: j.error || null,
      attempts: Number(j.attempts || 0), created_at: j.created_at, updated_at: j.updated_at })));
  }
  const jobMatch = /^\/api\/v1\/internal\/video-jobs\/([\w-]+)$/.exec(path);
  if (jobMatch && req.method === 'POST') {
    const id = jobMatch[1];
    const b = await readJson(req);
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
const RECOGNITION_MILESTONES = [50, 100, 250, 500, 1000];

async function platformAuthorId(env) {
  const emails = String(env.ADMIN_EMAILS || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  for (const email of emails) {
    const u = await env.DB.prepare('SELECT id FROM users WHERE lower(email)=?')
      .bind(email).first();
    if (u) return Number(u.id);
  }
  const admin = await env.DB.prepare(
    "SELECT id FROM users WHERE upper(role) IN ('ADMIN','PLATFORM') ORDER BY id LIMIT 1"
  ).first();
  return admin ? Number(admin.id) : null;
}

/// Creates one official recognition post for each member who reaches a new
/// impact milestone. Safe to run repeatedly; awards are unique per milestone.
export async function runRecognitionSweep(env, { limit = 50 } = {}) {
  const authorId = await platformAuthorId(env);
  if (!authorId) return { created: 0, reason: 'no_platform_author' };
  const rows = (await env.DB.prepare(`SELECT author_id,
    SUM(COALESCE(impact_value,0)) total FROM posts
    WHERE hidden=0 AND author_id<>?
    GROUP BY author_id HAVING total>0 ORDER BY total DESC LIMIT ?`)
    .bind(authorId, Number(limit)).all()).results || [];
  const awards = [];
  for (const row of rows) {
    const total = Number(row.total || 0);
    const milestone = [...RECOGNITION_MILESTONES]
      .reverse()
      .find((m) => total >= m);
    if (!milestone) continue;
    const already = await env.DB.prepare(
      'SELECT 1 x FROM recognition_awards WHERE user_id=? AND milestone=?'
    ).bind(row.author_id, milestone).first();
    if (already) continue;
    const user = await env.DB.prepare(
      'SELECT id,name,role,handle FROM users WHERE id=?'
    ).bind(row.author_id).first();
    if (!user) continue;
    const at = nowIso();
    const text = `MASAREEN recognition: ${user.name || 'A member'} reached ` +
      `${milestone} impact points through verified field work. Their public ` +
      'record is now part of the impact graph.';
    const ins = await env.DB.prepare(`INSERT INTO posts
      (author_id,text,kind,impact_value,impact_label,confidence_score,
       confidence_label,confidence_factors,media_type,source,created_at,updated_at)
      VALUES (?,?,'RECOGNITION',?,'Verified impact milestone',95,
       'High confidence',?,'TEXT','RECOGNITION',?,?)`)
      .bind(authorId, text, milestone,
        JSON.stringify({ milestone, method: 'automatic recognition' }), at, at)
      .run();
    const postId = ins.meta.last_row_id;
    await env.DB.prepare(`INSERT OR IGNORE INTO recognition_awards
      (user_id,milestone,post_id,created_at) VALUES (?,?,?,?)`)
      .bind(row.author_id, milestone, postId, at).run();
    await notify(env, row.author_id, 'recognition',
      `You reached ${milestone} impact points`,
      'Your verified work earned a MASAREEN recognition post.', authorId, postId);
    awards.push({
      user_id: String(row.author_id),
      milestone,
      post_id: String(postId),
    });
  }
  return { created: awards.length, awards };
}

const OTA_SETTING_KEYS = [
  'app_android_version', 'app_android_build', 'app_android_url',
  'app_ios_version', 'app_ios_build', 'app_ios_url',
  'app_notes', 'app_min_build', 'app_force', 'app_ota_enabled',
  'live_tv_title', 'live_tv_url', 'live_tv_poster', 'live_tv_enabled',
];

export async function readPlatformSettings(env) {
  try {
    const rows = (await env.DB.prepare(
        'SELECT key,value FROM platform_settings').all()).results || [];
    return Object.fromEntries(rows.map((r) => [r.key, r.value]));
  } catch (_) {
    return {};
  }
}

async function liveTvConfig(env) {
  const settings = await readPlatformSettings(env);
  const hlsUrl = safeMediaUrl(settings.live_tv_url || env.LIVE_TV_URL || null);
  const enabledSetting = settings.live_tv_enabled ?? env.LIVE_TV_ENABLED;
  const enabled = enabledSetting == null
    ? !!hlsUrl : !['0', 'false', 'off', 'no'].includes(String(enabledSetting).toLowerCase());
  return json({
    ok: true,
    enabled: enabled && !!hlsUrl,
    title: clean(settings.live_tv_title, 120) || clean(env.LIVE_TV_TITLE, 120) || 'MASAREEN Live TV',
    hls_url: hlsUrl,
    poster_url: safeMediaUrl(settings.live_tv_poster) || null,
    status: enabled && hlsUrl ? 'live' : 'offline',
  });
}

export async function appUpdateManifest(env) {
  const s = await readPlatformSettings(env);
  let size = null;
  let etag = null;
  try {
    const object = env.MEDIA ? await env.MEDIA.head('downloads/masareen.apk') : null;
    size = object ? object.size : null;
    etag = object ? object.httpEtag : null;
  } catch (_) {}
  const androidVersion =
      s.app_android_version || env.APP_ANDROID_VERSION || '0.4.3';
  const androidBuild =
      Number(s.app_android_build || env.APP_ANDROID_BUILD || 8);
  const iosVersion =
      s.app_ios_version || env.APP_IOS_VERSION || androidVersion;
  const iosBuild =
      Number(s.app_ios_build || env.APP_IOS_BUILD || androidBuild);
  const notes = s.app_notes ?? env.APP_NOTES ?? '';
  return {
    ok: true,
    android: {
      version: androidVersion,
      build: androidBuild,
      url: s.app_android_url || env.APP_ANDROID_URL ||
          'https://masareen.com/downloads/masareen.apk',
      size,
      etag,
      notes,
    },
    ios: {
      version: iosVersion,
      build: iosBuild,
      url: s.app_ios_url || env.APP_IOS_URL ||
          'https://masareen.com/downloads/masareen.ipa',
      notes,
    },
    minimumBuild: Number(s.app_min_build || env.APP_MIN_BUILD || 7),
    force: s.app_force === '1',
    otaEnabled: s.app_ota_enabled !== '0',
    ota: {
      provider: 'shorebird',
      appId: env.SHOREBIRD_APP_ID || '',
    },
  };
}

/* ---------------- announcements ---------------- */
function announcementJson(a, dismissed = false) {
  return {
    id: String(a.id),
    title: a.title,
    body: a.body,
    image_url: safeMediaUrl(a.image_url),
    link_url: safeMediaUrl(a.link_url),
    cta_label: a.cta_label || null,
    audience: a.audience || 'ALL',
    audience_value: a.audience_value || null,
    active_from: a.active_from,
    active_until: a.active_until || null,
    created_at: a.created_at,
    author_name: a.author_name || null,
    dismissed: !!dismissed,
  };
}

function announcementAudience(b) {
  const audience = ['ALL', 'ROLE', 'USER'].includes(String(b.audience || '').toUpperCase())
    ? String(b.audience).toUpperCase() : 'ALL';
  const value = audience === 'ALL' ? null : clean(b.audience_value, 120);
  if (audience !== 'ALL' && !value) {
    throw new HttpError(400, 'invalid_audience', 'Choose who should receive this announcement.');
  }
  return { audience, value };
}

async function announcementTargets(env, announcement) {
  if (announcement.audience === 'USER') {
    return [Number(announcement.audience_value)].filter((n) => Number.isInteger(n) && n > 0);
  }
  if (announcement.audience === 'ROLE') {
    const rows = (await env.DB.prepare(
      'SELECT id FROM users WHERE upper(role)=upper(?) LIMIT 5000')
      .bind(announcement.audience_value).all()).results || [];
    return rows.map((r) => Number(r.id));
  }
  const rows = (await env.DB.prepare(
    "SELECT id FROM users WHERE name<>'Deleted member' LIMIT 5000").all()).results || [];
  return rows.map((r) => Number(r.id));
}

async function listAnnouncements(req, env) {
  const viewer = await requireUser(req, env);
  const at = nowIso();
  const rows = (await env.DB.prepare(`SELECT a.*,u.name author_name FROM announcements a
    LEFT JOIN users u ON u.id=a.created_by
    WHERE a.active_from<=? AND (a.active_until IS NULL OR a.active_until>=?)
      AND (a.audience='ALL'
        OR (a.audience='ROLE' AND upper(a.audience_value)=upper(?))
        OR (a.audience='USER' AND a.audience_value=?))
    ORDER BY a.created_at DESC LIMIT 20`)
    .bind(at, at, viewer.role || '', String(viewer.id)).all()).results || [];
  if (!rows.length) return json([]);
  const ids = rows.map((r) => Number(r.id));
  const marks = ids.map(() => '?').join(',');
  const dismissed = new Set(((await env.DB.prepare(
    `SELECT announcement_id FROM announcement_dismissals WHERE user_id=? AND announcement_id IN (${marks})`)
    .bind(viewer.id, ...ids).all()).results || []).map((r) => Number(r.announcement_id)));
  return json(rows.map((a) => announcementJson(a, dismissed.has(Number(a.id)))));
}

async function dismissAnnouncement(req, env, id) {
  const viewer = await requireUser(req, env);
  await env.DB.prepare(`INSERT OR IGNORE INTO announcement_dismissals
    (announcement_id,user_id,dismissed_at) VALUES (?,?,?)`)
    .bind(id, viewer.id, nowIso()).run();
  return json({ ok: true });
}

async function createAnnouncement(req, env, admin) {
  const b = await readJson(req);
  const title = clean(b.title, 140);
  const body = clean(b.body, 2000);
  if (title.length < 3) throw new HttpError(400, 'invalid_title', 'Announcement title is required.');
  if (body.length < 3) throw new HttpError(400, 'invalid_body', 'Write the announcement message.');
  const image = safeMediaUrl(b.image_url);
  const link = safeMediaUrl(b.link_url);
  if (b.image_url && !image) throw new HttpError(400, 'invalid_image', 'Use an https:// image URL.');
  if (b.link_url && !link) throw new HttpError(400, 'invalid_link', 'Use an https:// link URL.');
  const { audience, value } = announcementAudience(b);
  const now = new Date();
  const until = b.active_until ? new Date(String(b.active_until)) : null;
  if (until && Number.isNaN(until.getTime())) {
    throw new HttpError(400, 'invalid_date', 'Choose a valid end date.');
  }
  const at = nowIso();
  const created = await env.DB.prepare(`INSERT INTO announcements
    (title,body,image_url,link_url,cta_label,audience,audience_value,active_from,active_until,created_by,created_at,notified)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,0)`)
    .bind(title, body, image, link, clean(b.cta_label, 60) || null,
      audience, value, at, until ? until.toISOString() : null,
      admin.id, at).run();
  const row = await env.DB.prepare('SELECT * FROM announcements WHERE id=?')
    .bind(created.meta.last_row_id).first();
  if (b.notify !== false) {
    const ids = await announcementTargets(env, row);
    for (let i = 0; i < ids.length; i += 20) {
      await Promise.all(ids.slice(i, i + 20).map((userId) =>
        notify(env, userId, 'announcement', title, body, admin.id, null,
          { dedupeKey: `announcement:${row.id}` }).catch(() => {})));
    }
    await env.DB.prepare('UPDATE announcements SET notified=1 WHERE id=?')
      .bind(row.id).run();
  }
  return json(announcementJson({ ...row, author_name: admin.name }), 201);
}

async function supportConversation(req, env) {
  const viewer = await requireUser(req, env);
  const emails = String(env.ADMIN_EMAILS || '')
    .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (!emails.length) throw new HttpError(503, 'support_unavailable', 'Platform support is not configured.');
  const admin = await env.DB.prepare(
    `SELECT id,name,picture,role FROM users WHERE lower(email) IN (${emails.map(() => '?').join(',')})
     ORDER BY id LIMIT 1`).bind(...emails).first();
  if (!admin) throw new HttpError(503, 'support_unavailable', 'Platform support is not available yet.');
  if (Number(admin.id) === Number(viewer.id)) {
    throw new HttpError(400, 'self_message', 'You are already the platform account.');
  }
  const [a, b] = [Math.min(viewer.id, Number(admin.id)), Math.max(viewer.id, Number(admin.id))];
  let c = await env.DB.prepare('SELECT * FROM conversations WHERE user_a=? AND user_b=?')
    .bind(a, b).first();
  if (!c) {
    await env.DB.prepare('INSERT INTO conversations (user_a,user_b,last_message_at,created_at) VALUES (?,?,?,?)')
      .bind(a, b, null, nowIso()).run();
    c = await env.DB.prepare('SELECT * FROM conversations WHERE user_a=? AND user_b=?')
      .bind(a, b).first();
  }
  return json(await conversationSummary(env, c, viewer.id), 201);
}
export async function socialRoutes(req, env, ctx) {
  const url = new URL(req.url);
  const path = url.pathname;
  try {
    const declared = Number(req.headers.get('content-length') || 0);
    if (declared > 2 * 1024 * 1024) throw new HttpError(413, 'too_large', 'Request body is too large.');
    if (path === '/api/testers' || path === '/api/testers/stats') return await testerRoutes(req, env, url, ctx);
    if (path.startsWith('/api/v1/internal/ai/')) return await aiInternalRoutes(req, env, url);
    if (path.startsWith('/api/v1/internal/')) return await videoJobRoutes(req, env, url);
    if (path === '/api/v1/users/register' && req.method === 'POST') return await register(req, env);
    if (path === '/api/v1/auth/login' && req.method === 'POST') return await login(req, env);
    if (path.startsWith('/api/v1/auth/') || path === '/api/v1/users/me/settings' ||
        path === '/api/v1/users/me/password' || path === '/api/v1/users/me/delete' ||
        path === '/api/v1/users/me/device-token') {
      const viewer = await currentUser(req, env);
      const handled = await authRoutes(req, env, url, viewer);
      if (handled) return handled;
    }
    if (path.startsWith('/api/v1/admin/')) return await adminRoutes(req, env, url);
    if (path === '/api/v1/live/tv' && req.method === 'GET') return await liveTvConfig(env);
    if (path === '/api/v1/feedback' && req.method === 'POST') {
      return await createFeedback(req, env);
    }
    if (path === '/api/v1/leaderboards/options' && req.method === 'GET') {
      return await listLeaderboardOptions(req, env);
    }
    if (path === '/api/v1/leaderboards' && req.method === 'POST') {
      return await createLeaderboard(req, env);
    }
    if (path === '/api/v1/analytics/events' && req.method === 'POST') {
      const viewer = await requireUser(req, env);
      const b = await readJson(req);
      const events = Array.isArray(b.events) ? b.events.slice(0, 60) : [];
      const stmts = [];
      for (const event of events) {
        const type = clean(event.type || event.event_type, 60);
        if (!type) continue;
        const metadata = event.metadata && typeof event.metadata === 'object'
          ? JSON.stringify(event.metadata).slice(0, 2000) : null;
        stmts.push(env.DB.prepare(`INSERT INTO analytics_events
          (user_id,event_type,target_type,target_id,post_id,value,duration_ms,metadata_json,created_at)
          VALUES (?,?,?,?,?,?,?,?,?)`)
          .bind(viewer.id, type, clean(event.target_type, 60) || null,
            clean(event.target_id, 100) || null, num(event.post_id),
            Number.isFinite(Number(event.value)) ? Number(event.value) : null,
            Number.isFinite(Number(event.duration_ms)) ? Math.max(0, Math.trunc(Number(event.duration_ms))) : null,
            metadata, nowIso()));
      }
      if (stmts.length) await env.DB.batch(stmts);
      return json({ ok: true, accepted: stmts.length });
    }
    const aiMatch = /^\/api\/v1\/ai\/(embed|transcribe)\/(\d+)$/.exec(path);
    if (aiMatch && req.method === 'POST') {
      const viewer = await requireUser(req, env);
      const postId = Number(aiMatch[2]);
      const post = await env.DB.prepare('SELECT * FROM posts WHERE id=?').bind(postId).first();
      if (!post) throw new HttpError(404, 'post_not_found', 'Post not found.');
      if (Number(post.author_id) !== Number(viewer.id) && !isAdminUser(env, viewer)) {
        throw new HttpError(403, 'not_allowed', 'Only the author or an admin can run AI tools.');
      }
      if (aiMatch[1] === 'embed') {
        const vector = embeddingFor(`${post.text || ''} ${post.transcript || ''}`);
        await env.DB.prepare(`UPDATE posts SET embedding_json=?,
          embedding_status='local-hash', updated_at=? WHERE id=?`)
          .bind(JSON.stringify(vector), nowIso(), postId).run();
        return json({ ok: true, status: 'local-hash', dimensions: vector.length });
      }
      const provider = env.OPENAI_API_KEY ? 'openai' : 'not_configured';
      await env.DB.prepare(`UPDATE posts SET embedding_status='transcription_queued',
        updated_at=? WHERE id=?`).bind(nowIso(), postId).run();
      return json({
        ok: true, status: 'queued', provider,
        media_url: post.media_url || null,
        message: env.OPENAI_API_KEY
          ? 'Transcription queued. The AI worker will attach the transcript.'
          : 'Transcription is queued. Add OPENAI_API_KEY (or another AI worker) to process it.',
      });
    }
    if (path === '/api/v1/announcements' && req.method === 'GET') {
      return await listAnnouncements(req, env);
    }
    const dismissMatch = /^\/api\/v1\/announcements\/(\d+)\/dismiss$/.exec(path);
    if (dismissMatch && req.method === 'POST') {
      return await dismissAnnouncement(req, env, Number(dismissMatch[1]));
    }
    if (path === '/api/v1/support/conversation' && req.method === 'POST') {
      return await supportConversation(req, env);
    }
    if (path === '/api/v1/inquiries' || path.startsWith('/api/v1/inquiries/')) {
      const handled = await inquiryRoutes(req, env, url, await currentUser(req, env));
      if (handled) return handled;
    }
    if (path === '/api/v1/ads' || path.startsWith('/api/v1/ads/') ||
        path === '/api/v1/campaigns' || path === '/api/v1/campaigns/') {
      const handled = await adsRoutes(req, env, url, await currentUser(req, env));
      if (handled) return handled;
    }
    if (path.startsWith('/api/v1/payments') || path.startsWith('/api/v1/coin/') ||
        path === '/api/v1/wallet' || path.startsWith('/api/v1/pro/')) {
      const handled = await commerceRoutes(req, env, url, await currentUser(req, env));
      if (handled) return handled;
    }
    if (path === '/api/v1/courses' || path === '/api/v1/courses/') {
      if (req.method === 'GET') return json(await listCourses(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createCourse(req, env);
    }
    const lessonsMatch =
      /^\/api\/v1\/courses\/(\d+)\/lessons(?:\/(\d+))?$/.exec(path);
    if (lessonsMatch) {
      const id = Number(lessonsMatch[1]);
      if (!lessonsMatch[2] && req.method === 'GET') {
        return await listCourseLessons(req, env, id);
      }
      if (!lessonsMatch[2] && req.method === 'POST') {
        return await createCourseLesson(req, env, id);
      }
      if (lessonsMatch[2] &&
          (req.method === 'PATCH' || req.method === 'PUT')) {
        return await updateCourseLesson(req, env, id, Number(lessonsMatch[2]));
      }
      if (lessonsMatch[2] && req.method === 'DELETE') {
        return await deleteCourseLesson(req, env, id, Number(lessonsMatch[2]));
      }
    }
    const courseMatch = /^\/api\/v1\/courses\/(\d+)(\/enroll)?$/.exec(path);
    if (courseMatch) {
      if (courseMatch[2] === '/enroll' && req.method === 'POST') return await enrollCourse(req, env, Number(courseMatch[1]));
      if (courseMatch[2] === '/enroll' && req.method === 'DELETE') return await unenrollCourse(req, env, Number(courseMatch[1]));
      if (!courseMatch[2] && req.method === 'GET') {
        const viewer = await currentUser(req, env);
        const row = await env.DB.prepare(`SELECT c.*, u.name author_name,
          (SELECT COUNT(*) FROM course_enrollments e WHERE e.course_id=c.id) enrolled_count
          FROM courses c LEFT JOIN users u ON u.id=c.author_id WHERE c.id=?`).bind(Number(courseMatch[1])).first();
        if (!row || !canViewEntity(env, viewer, row)) {
          throw new HttpError(404, 'course_not_found', 'Course not found.');
        }
        const mine = viewer ? await env.DB.prepare('SELECT 1 x FROM course_enrollments WHERE course_id=? AND user_id=?')
          .bind(row.id, viewer.id).first() : null;
        return json(courseJson(row, !!mine));
      }
    }
    if (path === '/api/v1/events' || path === '/api/v1/events/') {
      if (req.method === 'GET') {
        return json(await listEvents(env, await currentUser(req, env), {
          includePast: url.searchParams.get('include_past') === '1',
          q: clean(url.searchParams.get('q'), 80),
          type: clean(url.searchParams.get('type'), 40).toUpperCase() || null,
        }));
      }
      if (req.method === 'POST') return await createEvent(req, env);
    }
    if (path === '/api/v1/events/managed' && req.method === 'GET') {
      return await getManagedEvents(req, env);
    }
    const organizerMatch = /^\/api\/v1\/events\/organizers\/(\d+)$/.exec(path);
    if (organizerMatch && req.method === 'GET') {
      const reputation = await organizerReputation(env, Number(organizerMatch[1]));
      if (!reputation) throw new HttpError(404, 'organizer_not_found', 'Organizer not found.');
      return json(reputation);
    }
    const eventSubMatch = /^\/api\/v1\/events\/(\d+)\/(participants|media|booths|ratings|attendance|dashboard)(?:\/(\d+))?(?:\/(evidence|verdict|confirm))?$/.exec(path);
    if (eventSubMatch) {
      const eventId = Number(eventSubMatch[1]);
      const sub = eventSubMatch[2];
      const itemId = eventSubMatch[3] ? Number(eventSubMatch[3]) : null;
      const action = eventSubMatch[4] || '';
      if (sub === 'participants') {
        if (req.method === 'GET') return json((await eventDetailData(req, env, eventId)).participants);
        if (req.method === 'POST' && !itemId) return await addEventParticipant(req, env, eventId);
        if (itemId && action === 'evidence' && req.method === 'POST')
          return await addEventEvidence(req, env, eventId, itemId);
        if (itemId && action === 'verdict' && req.method === 'POST')
          return await eventParticipantVerdict(req, env, eventId, itemId);
        if (itemId && action === 'confirm' && req.method === 'POST')
          return await confirmEventParticipant(req, env, eventId, itemId);
      }
      if (sub === 'media') {
        if (req.method === 'GET') return json((await eventDetailData(req, env, eventId)).media);
        if (req.method === 'POST') return await addEventMedia(req, env, eventId);
      }
      if (sub === 'booths') {
        if (req.method === 'GET') return json((await eventDetailData(req, env, eventId)).booths);
        if (req.method === 'POST') return await createEventBooth(req, env, eventId);
      }
      if (sub === 'ratings') {
        if (req.method === 'GET') return json((await eventDetailData(req, env, eventId)).ratings);
        if (req.method === 'POST') return await rateEvent(req, env, eventId);
      }
      if (sub === 'attendance' && req.method === 'POST')
        return await claimEventAttendance(req, env, eventId);
      if (sub === 'dashboard' && req.method === 'GET')
        return await getEventDashboard(req, env, eventId);
    }
    const eventMatch = /^\/api\/v1\/events\/(\d+)(\/join)?$/.exec(path);
    if (eventMatch) {
      if (eventMatch[2] === '/join' && req.method === 'POST') return await joinEvent(req, env, Number(eventMatch[1]));
      if (!eventMatch[2] && req.method === 'GET')
        return json(await eventDetailData(req, env, Number(eventMatch[1])));
      if (!eventMatch[2] && req.method === 'DELETE')
        return await deleteEvent(req, env, Number(eventMatch[1]));
    }
    const boothMatch = /^\/api\/v1\/booths\/(\d+)(?:\/(activate|leads|interact))?(?:\/(\d+)\/status)?$/.exec(path);
    if (boothMatch) {
      const boothId = Number(boothMatch[1]);
      const sub = boothMatch[2] || '';
      const leadId = boothMatch[3] ? Number(boothMatch[3]) : null;
      if (!sub && req.method === 'GET') return json(await getBoothDetail(req, env, boothId));
      if (sub === 'activate' && req.method === 'POST')
        return await activateEventBooth(req, env, boothId);
      if (sub === 'leads' && req.method === 'GET')
        return await listBoothLeads(req, env, boothId);
      if (sub === 'leads' && req.method === 'POST')
        return await createBoothLead(req, env, boothId);
      if (sub === 'interact' && req.method === 'POST') {
        await env.DB.prepare('UPDATE event_booths SET interactions=interactions+1,updated_at=? WHERE id=?')
          .bind(nowIso(), boothId).run();
        return json({ ok: true });
      }
      if (leadId && req.method === 'PATCH')
        return await updateBoothLeadStatus(req, env, boothId, leadId);
    }
    if (path === '/api/v1/podcasts' || path === '/api/v1/podcasts/') {
      if (req.method === 'GET') return json(await listPodcastShows(env, url));
      if (req.method === 'POST') return await createPodcastShow(req, env);
    }
    const podcastMatch = /^\/api\/v1\/podcasts\/(\d+)(?:\/episodes)?$/.exec(path);
    if (podcastMatch) {
      const showId = Number(podcastMatch[1]);
      if (!path.endsWith('/episodes') && req.method === 'GET')
        return json(await getPodcastShow(env, showId));
      if (path.endsWith('/episodes') && req.method === 'POST')
        return await createPodcastEpisode(req, env, showId);
    }
    if (path === '/api/v1/vod' || path === '/api/v1/vod/') {
      const viewer = await currentUser(req, env);
      if (req.method === 'GET') return json(await listVod(env, url, viewer));
      if (req.method === 'POST') return await createVod(req, env);
    }
    const vodMatch = /^\/api\/v1\/vod\/(\d+)$/.exec(path);
    if (vodMatch && req.method === 'GET') return await getVodDetail(req, env, Number(vodMatch[1]));
    if (path === '/api/v1/programs' || path === '/api/v1/programs/') {
      if (req.method === 'GET') return json(await listPrograms(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createProgram(req, env);
    }
    const programMatch = /^\/api\/v1\/programs\/(\d+)(\/enroll|\/tasks|\/members)?$/.exec(path);
    if (programMatch) {
      const id = Number(programMatch[1]);
      const sub = programMatch[2] || '';
      if (!sub && req.method === 'GET') return json(await getProgram(env, await currentUser(req, env), id));
      if (sub === '/enroll' && req.method === 'POST') return await enrollProgram(req, env, id);
      if (sub === '/enroll' && req.method === 'DELETE') return await leaveProgram(req, env, id);
      if (sub === '/members' && req.method === 'GET') return json(await listProgramMembers(env, id));
      if (sub === '/tasks' && req.method === 'POST') return await createTask(req, env, id);
    }
    if (path === '/api/v1/projects' || path === '/api/v1/projects/') {
      if (req.method === 'GET') return json(await listProjects(env, await currentUser(req, env)));
      if (req.method === 'POST') return await createProject(req, env);
    }
    const projectJoin = /^\/api\/v1\/projects\/(\d+)\/join$/.exec(path);
    if (projectJoin && req.method === 'POST') return await joinProject(req, env, Number(projectJoin[1]));
    if (projectJoin && req.method === 'DELETE') return await leaveProject(req, env, Number(projectJoin[1]));
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
        if (!row || !canViewEntity(env, viewer, row)) {
          throw new HttpError(404, 'opportunity_not_found', 'Opportunity not found.');
        }
        const applied = viewer ? await env.DB.prepare('SELECT 1 x FROM opportunity_applications WHERE opportunity_id=? AND user_id=?')
          .bind(id, viewer.id).first() : null;
        return json(opportunityJson(row, !!applied));
      }
    }
    const taskHandled = await taskRoutes(req, env, url, await currentUser(req, env));
    if (taskHandled) return taskHandled;
    if (path === '/api/v1/gps/records' && (req.method === 'GET' || req.method === 'POST')) return await gpsRecords(req, env);
    if (path === '/api/v1/ai/deepfake/scan' && req.method === 'POST') {
      await requireUser(req, env);
      const b = await readJson(req);
      const urls = Array.isArray(b.urls) ? b.urls : (b.url ? [b.url] : []);
      return json(await deepfakeScan(env, {
        text: clean(b.text, 8000), title: clean(b.title, 160), urls,
      }));
    }
    if (path === '/api/v1/admin/ai/deepfake/scan' && req.method === 'POST') {
      const admin = await requireUser(req, env);
      if (!isAdminUser(env, admin)) {
        throw new HttpError(403, 'forbidden', 'Admin only.');
      }
      const b = await readJson(req);
      const urls = Array.isArray(b.urls) ? b.urls : (b.url ? [b.url] : []);
      return json(await deepfakeScan(env, {
        text: clean(b.text, 8000), title: clean(b.title, 160), urls,
      }));
    }
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
      return await listSubmissions(env, await requireUser(req, env), Number(submissionsUser[1]), url);
    const submissionDelete = /^\/api\/v1\/submissions\/(\d+)$/.exec(path);
    if (submissionDelete && req.method === 'DELETE') return await deleteSubmission(req, env, Number(submissionDelete[1]));
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
    if (path === '/api/v1/files/upload' && req.method === 'POST') return await uploadMedia(req, env, 'file');
    if (path === '/api/v1/videos/upload' && req.method === 'POST') return await uploadMedia(req, env, 'video');
    if (path === '/api/v1/media/audio' && req.method === 'POST') return await uploadMedia(req, env, 'audio');
    if (path === '/api/v1/live/interactions' && req.method === 'GET') return await liveInteractions(req, env, url);
    if (path === '/api/v1/discovery/feed' && req.method === 'GET') return await discoveryFeed(req, env, url);
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
        const marked = viewer ? await env.DB.prepare('SELECT 1 x FROM post_bookmarks WHERE post_id=? AND user_id=?').bind(id, viewer.id).first() : null;
        return json(postJson(row, !!liked, null, !!marked));
      }
      if (!sub && req.method === 'PATCH') return await editPost(req, env, id);
      if (!sub && req.method === 'DELETE') return await deletePost(req, env, id);
      if (sub === '/like' && req.method === 'POST') return await toggleLike(req, env, id);
      if (sub === '/bookmark' && req.method === 'POST') return await toggleBookmark(req, env, id);
      if (sub === '/comment' && req.method === 'POST') return await addComment(req, env, id);
      if (sub === '/comments' && req.method === 'GET') return await listComments(req, env, id);
      if (sub === '/impact' && req.method === 'POST') return await castImpactVote(req, env, id);
      if (sub === '/share' && req.method === 'POST') return await sharePost(req, env, id);
      if (sub === '/boost' && req.method === 'POST') return await boostPost(req, env, id);
      if (sub === '/report' && req.method === 'POST') return await reportTarget(req, env, 'post', id);
    }
    const commentMatch = /^\/api\/v1\/comments\/(\d+)(?:\/(like|report))?$/.exec(path);
    if (commentMatch) {
      const commentId = Number(commentMatch[1]);
      if (commentMatch[2] === 'like' && req.method === 'POST') return await toggleCommentLike(req, env, commentId);
      if (commentMatch[2] === 'report' && req.method === 'POST') return await reportTarget(req, env, 'comment', commentId);
      if (!commentMatch[2] && req.method === 'DELETE') return await deleteComment(req, env, commentId);
    }
    if (path === '/api/v1/search' && req.method === 'GET') return await searchSocial(req, env, url);
    if (path === '/api/v1/trends' && req.method === 'GET') return await trendingHashtags(env);
    if (path.startsWith('/api/v1/messages/')) {
      const handled = await messagesRoutes(req, env, url, await currentUser(req, env));
      if (handled) return handled;
    }
    const passportMatch = /^\/api\/v1\/users\/(\d+)\/passport$/.exec(path);
    if (passportMatch && req.method === 'GET') return await passportFor(env, Number(passportMatch[1]), await currentUser(req, env));
    const sportsHandled = await sportsRoutes(req, env, url, await currentUser(req, env));
    if (sportsHandled) return sportsHandled;
    const moderatorHandled = await moderatorRoutes(req, env, url);
    if (moderatorHandled) return moderatorHandled;
    const viewer = await currentUser(req, env);
    const u = await userRoutes(req, env, url, viewer);
    if (u) return u;
    throw new HttpError(404, 'not_found', 'Unknown API route.');
  } catch (e) {
    if (e instanceof HttpError) return json({ ok: false, error: e.code, message: e.message }, e.status);
    console.error('social_api_error', e && e.stack || e);
    return json({ ok: false, error: 'server_error', message: 'Something went wrong. Please try again.' }, 500);
  }
}


