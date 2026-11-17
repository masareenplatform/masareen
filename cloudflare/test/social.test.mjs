import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { handle } from '../src/index.js';
import { makeDb } from './d1-shim.mjs';

const mkEnv = (extra = {}) => ({
  DB: makeDb(),
  SESSION_SECRET: 's3cret-s3cret',
  ADMIN_EMAILS: 'ceo@example.com',
  // Keep the existing feature tests focused: entity creation is free and
  // auto-approved unless a test opts into the real review workflow.
  ENTITY_TEST_MODE: 'true',
  ...extra,
});

const call = (env, method, path, body, token) => handle(new Request('https://masareen.test' + path, {
  method,
  headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) },
  body: body ? JSON.stringify(body) : undefined,
}), env, {});

async function signup(env, email = 'amina@example.com', name = 'Amina Test') {
  const r = await call(env, 'POST', '/api/v1/users/register', { email, full_name: name, password: 'correct-horse9', role: 'STUDENT' });
  assert.equal(r.status, 201);
  const j = await r.json();
  assert.match(j.access_token, /\./);
  await env.DB.raw.prepare('UPDATE users SET email_verified=1 WHERE email=?').run(email);
  return j.access_token;
}

async function fundWallet(env, token, amount = 1000) {
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  await call(env, 'POST', '/api/v1/coin/wallets', { owner_id: me.id }, token);
  env.DB.raw.prepare('UPDATE coin_wallets SET balance=? WHERE owner_id=?')
    .run(amount, Number(me.id));
  return me;
}

test('social actions create in-app notifications and update unread counts', async () => {
  const env = mkEnv();
  const author = await signup(env, 'notify-author@example.com', 'Notify Author');
  const fan = await signup(env, 'notify-fan@example.com', 'Notify Fan');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, author)).json();
  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A post that should notify its author', kind: 'STORY',
  }, author)).json();
  assert.equal((await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, fan)).status, 200);
  const count1 = await (await call(env, 'GET', '/api/v1/notifications/unread-count', null, author)).json();
  assert.equal(count1.count, 1);
  const feed = await (await call(env, 'GET', `/api/v1/notifications/${me.id}`, null, author)).json();
  assert.ok(feed.some((n) => n.type === 'like' && n.post_id === post.id));
  assert.equal((await call(env, 'POST', `/api/v1/users/${me.id}/follow`, null, fan)).status, 200);
  const count2 = await (await call(env, 'GET', '/api/v1/notifications/unread-count', null, author)).json();
  assert.equal(count2.count, 2);
  assert.equal((await call(env, 'POST', '/api/v1/notifications/read-all', null, author)).status, 200);
  const count3 = await (await call(env, 'GET', '/api/v1/notifications/unread-count', null, author)).json();
  assert.equal(count3.count, 0);
});

test('entity creation is priced, pending and only visible after admin approval', async () => {
  const env = mkEnv({ ENTITY_TEST_MODE: 'false' });
  const author = await signup(env, 'creator@example.com', 'Creator One');
  const other = await signup(env, 'viewer@example.com', 'Viewer Two');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');

  const empty = await call(env, 'POST', '/api/v1/courses', {
    title: 'Clean water field course', lessons: 4, duration_min: 60,
  }, author);
  assert.equal(empty.status, 402);

  const me = await fundWallet(env, author, 1000);
  const created = await call(env, 'POST', '/api/v1/courses', {
    title: 'Clean water field course', lessons: 4, duration_min: 60,
  }, author);
  assert.equal(created.status, 201);
  const course = await created.json();
  assert.equal(course.verification_status, 'PENDING');
  assert.equal(course.creation_fee_mrc, 50);
  const wallet = await (await call(env, 'GET', '/api/v1/wallet', null, author)).json();
  assert.equal(wallet.balance, 950);

  const publicList = await (await call(env, 'GET', '/api/v1/courses', null, other)).json();
  assert.equal(publicList.some((c) => c.id === course.id), false);
  const ownList = await (await call(env, 'GET', '/api/v1/courses', null, author)).json();
  assert.equal(ownList.some((c) => c.id === course.id), true);
  assert.equal((await call(env, 'GET', `/api/v1/courses/${course.id}`, null, other)).status, 404);
  assert.equal((await call(env, 'GET', `/api/v1/courses/${course.id}`, null, author)).status, 200);
  assert.equal((await call(env, 'POST', `/api/v1/courses/${course.id}/enroll`, null, other)).status, 404);

  const pending = await (await call(env, 'GET', '/api/v1/admin/entities?status=PENDING', null, admin)).json();
  assert.ok(pending.some((e) => e.type === 'course' && e.id === course.id));
  const verdict = await call(env, 'POST', `/api/v1/admin/entities/courses/${course.id}/verdict`,
    { status: 'APPROVED' }, admin);
  assert.equal(verdict.status, 200);
  const live = await (await call(env, 'GET', '/api/v1/courses', null, other)).json();
  assert.equal(live.some((c) => c.id === course.id), true);
  assert.equal((await call(env, 'POST', `/api/v1/courses/${course.id}/enroll`, null, other)).status, 200);

  const rejected = await call(env, 'POST', '/api/v1/opportunities', {
    title: 'Rejected opportunity', type: 'VOLUNTEER', is_remote: true,
  }, author);
  assert.equal(rejected.status, 201);
  const opp = await rejected.json();
  assert.equal(opp.creation_fee_mrc, 30);
  const before = await (await call(env, 'GET', '/api/v1/wallet', null, author)).json();
  const rejectVerdict = await call(env, 'POST',
    `/api/v1/admin/entities/opportunities/${opp.id}/verdict`,
    { status: 'REJECTED', reason: 'Add a valid deadline.' }, admin);
  assert.equal(rejectVerdict.status, 200);
  const after = await (await call(env, 'GET', '/api/v1/wallet', null, author)).json();
  assert.equal(after.balance, before.balance + 30);
  const oppList = await (await call(env, 'GET', '/api/v1/opportunities', null, other)).json();
  assert.equal(oppList.some((o) => o.id === opp.id), false);
  assert.equal(me.id != null, true);
});

test('feedback is stored and admins can review it', async () => {
  const env = mkEnv();
  const tester = await signup(env, 'feedback@example.com', 'Feedback Tester');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const created = await call(env, 'POST', '/api/v1/feedback', {
    type: 'bug', message: 'The feed counter sometimes lags behind.', rating: 4,
  }, tester);
  assert.equal(created.status, 201);
  const feedback = await created.json();
  assert.equal(feedback.type, 'bug');
  assert.equal(feedback.status, 'OPEN');
  const list = await (await call(env, 'GET', '/api/v1/admin/feedback', null, admin)).json();
  assert.ok(list.some((f) => f.id === feedback.id));
  const updated = await call(env, 'PATCH', `/api/v1/admin/feedback/${feedback.id}`,
    { status: 'REVIEWED' }, admin);
  assert.equal(updated.status, 200);
  assert.equal((await updated.json()).status, 'REVIEWED');
});

test('admins can publish OTA releases without redeploying', async () => {
  const env = mkEnv();
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const before = await (await call(env, 'GET', '/api/v1/admin/settings', null,
      admin)).json();
  assert.equal(before.ok, true);
  const published = await call(env, 'POST', '/api/v1/admin/ota', {
    platform: 'android',
    version: '0.4.4',
    build: 9,
    url: 'https://masareen.com/downloads/masareen.apk',
    notes: 'OTA test release',
    force: true,
  }, admin);
  assert.equal(published.status, 200, await published.clone().text());
  const manifest = (await published.json()).manifest;
  assert.equal(manifest.android.version, '0.4.4');
  assert.equal(manifest.android.build, 9);
  assert.equal(manifest.force, true);
  const invalid = await call(env, 'POST', '/api/v1/admin/ota', {
    platform: 'android', version: 'latest', build: 9,
    url: 'https://masareen.com/downloads/masareen.apk',
  }, admin);
  assert.equal(invalid.status, 400);
});

test('course lessons respect paid access and pay the author', async () => {
  const env = mkEnv();
  const authorToken = await signup(env, 'teacher@example.com', 'Teacher');
  const author = await fundWallet(env, authorToken, 1000);
  const learnerToken = await signup(env, 'learner@example.com', 'Learner');
  const learner = await fundWallet(env, learnerToken, 100);
  const created = await call(env, 'POST', '/api/v1/courses', {
    title: 'Paid masterclass', description: 'Deep dive', is_free: false,
    price_mrc: 40,
  }, authorToken);
  assert.equal(created.status, 201);
  const course = await created.json();
  assert.equal(course.is_free, false);
  assert.equal(course.price_mrc, 40);
  const lesson = await call(env, 'POST', `/api/v1/courses/${course.id}/lessons`, {
    title: 'Lesson one', content: 'Secret notes', duration_min: 15,
  }, authorToken);
  assert.equal(lesson.status, 201);
  const preview = await call(env, 'POST', `/api/v1/courses/${course.id}/lessons`, {
    title: 'Course intro', content: 'Public intro', is_preview: true,
  }, authorToken);
  assert.equal(preview.status, 201);
  const locked = await (await call(env, 'GET',
      `/api/v1/courses/${course.id}/lessons`, null, learnerToken)).json();
  assert.equal(locked.enrolled, false);
  assert.equal(locked.lessons.find((l) => l.title === 'Lesson one').locked, true);
  assert.equal(locked.lessons.find((l) => l.title === 'Lesson one').content, null);
  assert.equal(locked.lessons.find((l) => l.title === 'Course intro').content,
    'Public intro');
  const enrolled = await (await call(env, 'POST',
      `/api/v1/courses/${course.id}/enroll`, null, learnerToken)).json();
  assert.equal(enrolled.charged, 40);
  const unlocked = await (await call(env, 'GET',
      `/api/v1/courses/${course.id}/lessons`, null, learnerToken)).json();
  assert.equal(unlocked.enrolled, true);
  assert.equal(unlocked.lessons.find((l) => l.title === 'Lesson one').content,
    'Secret notes');
  const learnerWallet = await env.DB.raw.prepare(
      'SELECT balance FROM coin_wallets WHERE owner_id=?').get(learner.id);
  const authorWallet = await env.DB.raw.prepare(
      'SELECT balance FROM coin_wallets WHERE owner_id=?').get(author.id);
  assert.equal(learnerWallet.balance, 60);
  assert.equal(authorWallet.balance, 1040);
});

test('creating an event announces it in the feed', async () => {
  const env = mkEnv();
  const token = await signup(env, 'host@example.com', 'Event Host');
  const created = await call(env, 'POST', '/api/v1/events', {
    title: 'Climate meetup',
    description: 'A meetup about local climate action.',
    starts_at: '2030-04-22T17:00:00.000Z',
    is_online: true,
    link_url: 'https://meet.example.com/climate',
    cover_url: 'https://cdn.example.com/climate.jpg',
  }, token);
  assert.equal(created.status, 201);
  const event = await created.json();
  console.log('EVENTDB', env.DB.raw.prepare('SELECT id,kind,link_url,author_id FROM posts').all());
  const feed = await (await call(env, 'GET',
      '/api/v1/posts?mode=latest&limit=50', null, token)).json();
  const announcement =
      feed.find((p) => p.kind === 'EVENT' && p.url?.endsWith(event.id));
  assert.ok(announcement, 'event announcement appears in the feed');
  assert.match(announcement.text, /Climate meetup/);
  assert.equal(announcement.content_url, 'https://cdn.example.com/climate.jpg');
});

test('announcements reach the right users and can be dismissed', async () => {
  const env = mkEnv();
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const member = await signup(env, 'announce@example.com', 'Announce Member');
  const created = await call(env, 'POST', '/api/v1/admin/announcements', {
    title: 'Ramadan discount',
    body: 'Pro is 50% off this week.',
    audience: 'ALL',
    notify: true,
  }, admin);
  assert.equal(created.status, 201);
  const ann = await created.json();
  const list = await (await call(env, 'GET', '/api/v1/announcements', null,
      member)).json();
  assert.ok(list.some((a) => a.id === ann.id && a.dismissed === false));
  const notes = await (await call(env, 'GET',
      '/api/v1/users/me/notifications', null, member)).json();
  assert.ok(notes.some((n) => n.type === 'announcement' &&
      n.title === 'Ramadan discount'));
  const dismissed = await call(env, 'POST',
      `/api/v1/announcements/${ann.id}/dismiss`, null, member);
  assert.equal(dismissed.status, 200);
  const after = await (await call(env, 'GET', '/api/v1/announcements', null,
      member)).json();
  assert.equal(after.find((a) => a.id === ann.id).dismissed, true);
  const roleAnn = await call(env, 'POST', '/api/v1/admin/announcements', {
    title: 'Students only', body: 'Student discount', audience: 'ROLE',
    audience_value: 'STUDENT', notify: false,
  }, admin);
  assert.equal(roleAnn.status, 201);
  const memberList = await (await call(env, 'GET', '/api/v1/announcements', null,
      member)).json();
  assert.ok(memberList.some((a) => a.title === 'Students only'));

});

test('members can open a support conversation and admins can message anyone', async () => {
  const env = mkEnv();
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const member = await signup(env, 'support@example.com', 'Support Member');
  const opened = await call(env, 'POST', '/api/v1/support/conversation', null,
    member);
  assert.equal(opened.status, 201);
  const conv = await opened.json();
  assert.equal(conv.peer.name, 'Platform CEO');
  const sent = await call(env, 'POST',
    `/api/v1/messages/conversations/${conv.id}`, { text: 'Hello support' },
    member);
  assert.equal(sent.status, 201);
  const adminConvs = await (await call(env, 'GET',
      '/api/v1/messages/conversations', null, admin)).json();
  assert.ok(adminConvs.some((c) => c.id === conv.id &&
      c.last_message === 'Hello support'));
  const direct = await call(env, 'POST', '/api/v1/messages/conversations',
    { user_id: (await (await call(env, 'GET', '/api/v1/users/me', null, member)).json()).id },
    admin);
  assert.equal(direct.status, 201);
});

test('only the course author can manage rich lesson attachments', async () => {
  const env = mkEnv();
  const author = await signup(env, 'author@example.com', 'Course Author');
  const learner = await signup(env, 'viewer@example.com', 'Course Viewer');
  const created = await (await call(env, 'POST', '/api/v1/courses', {
    title: 'Attachment course',
  }, author)).json();
  const denied = await call(env, 'POST',
    `/api/v1/courses/${created.id}/lessons`, {
    title: 'Hijacked lesson',
  }, learner);
  assert.equal(denied.status, 403);
  const lessonRes = await call(env, 'POST',
    `/api/v1/courses/${created.id}/lessons`, {
      title: 'Rich lesson',
      content: 'Watch and read everything.',
      duration_min: 12,
      media: [
        { type: 'VIDEO', url: 'https://cdn.example.com/lesson.mp4' },
        { type: 'AUDIO', url: 'https://cdn.example.com/lesson.m4a' },
        { type: 'IMAGE', url: 'https://cdn.example.com/slide.jpg' },
      ],
      files: [{ url: 'https://cdn.example.com/notes.pdf', name: 'Notes.pdf' }],
      links: [{ url: 'https://example.com/resource', label: 'Resource' }],
    }, author);
  assert.equal(lessonRes.status, 201);
  const lesson = await lessonRes.json();
  assert.equal(lesson.media.length, 3);
  assert.equal(lesson.files[0].name, 'Notes.pdf');
  assert.equal(lesson.links[0].label, 'Resource');
  assert.equal(lesson.video_url, 'https://cdn.example.com/lesson.mp4');
  const edited = await call(env, 'PATCH',
    `/api/v1/courses/${created.id}/lessons/${lesson.id}`,
    { title: 'Renamed lesson', is_preview: true }, author);
  assert.equal(edited.status, 200);
  const updated = await edited.json();
  assert.equal(updated.title, 'Renamed lesson');
  assert.equal(updated.is_preview, true);
  assert.equal(updated.files.length, 1);
  const forbiddenEdit = await call(env, 'PATCH',
    `/api/v1/courses/${created.id}/lessons/${lesson.id}`,
    { title: 'Learner edit' }, learner);
  assert.equal(forbiddenEdit.status, 403);
  const deleted = await call(env, 'DELETE',
    `/api/v1/courses/${created.id}/lessons/${lesson.id}`, null, author);
  assert.equal(deleted.status, 200);
});

test('analytics, AI embeddings and moderated leaderboards work', async () => {
  const env = mkEnv();
  const author = await signup(env, 'leader@example.com', 'Leader Author');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const course = await (await call(env, 'POST', '/api/v1/courses', {
    title: 'Leaderboard course',
  }, author)).json();
  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A searchable update about climate education.',
  }, author)).json();
  const embedded = await call(env, 'POST', `/api/v1/ai/embed/${post.id}`, null, author);
  assert.equal(embedded.status, 200);
  assert.equal((await embedded.json()).dimensions, 128);
  await call(env, 'POST', '/api/v1/analytics/events', {
    events: [
      { type: 'feed_scroll', value: 72, duration_ms: 15000 },
      { type: 'post_click', target_type: 'post', target_id: post.id },
    ],
  }, author);
  const analytics = await (await call(env, 'GET',
      '/api/v1/admin/analytics?days=30', null, admin)).json();
  assert.ok(analytics.events.some((e) => e.event_type === 'feed_scroll'));
  const lb = await call(env, 'POST', '/api/v1/leaderboards', {
    title: 'Course leaders', scope: 'courses', period: 'month',
    metric: 'participants', entity_ids: [course.id],
  }, author);
  assert.equal(lb.status, 201);
  const leaderboard = await lb.json();
  assert.equal(leaderboard.kind, 'LEADERBOARD');
  const pending = await (await call(env, 'GET',
      '/api/v1/admin/leaderboards?status=PENDING', null, admin)).json();
  assert.ok(pending.some((p) => p.id === leaderboard.id));
  const verdict = await call(env, 'POST',
      `/api/v1/admin/leaderboards/${leaderboard.id}/verdict`,
      { status: 'APPROVED' }, admin);
  assert.equal(verdict.status, 200);
  const feed = await (await call(env, 'GET',
      '/api/v1/posts?mode=latest&limit=50', null, author)).json();
  assert.ok(feed.some((p) => p.id === leaderboard.id));
  const insightRes = await call(env, 'GET',
      '/api/v1/admin/impact-reports?days=30', null, admin);
  const insight = await insightRes.json();
  assert.ok(insight.top_users.length >= 1);
});

test('recognition sweep creates one official post per milestone', async () => {
  const env = mkEnv();
  const author = await signup(env, 'impact-hero@example.com', 'Impact Hero');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  for (let i = 0; i < 5; i++) {
    const r = await call(env, 'POST', '/api/v1/posts', {
      text: `Verified impact update ${i}`,
      impact_value: 10,
      kind: 'STORY',
    }, author);
    assert.equal(r.status, 201);
  }
  const first = await (await call(env, 'POST',
    '/api/v1/admin/recognition/sweep', {}, admin)).json();
  assert.equal(first.created, 1);
  const feed = await (await call(env, 'GET',
    '/api/v1/posts?mode=latest&limit=50', null, author)).json();
  const recognition = feed.filter((p) => p.kind === 'RECOGNITION');
  assert.equal(recognition.length, 1);
  assert.match(recognition[0].text, /Impact Hero/);
  assert.equal(Number(recognition[0].impactValue), 50);
  const award = env.DB.raw.prepare(
    'SELECT COUNT(*) c FROM recognition_awards WHERE milestone=50').get();
  assert.equal(award.c, 1);
  const notifications = env.DB.raw.prepare(
    "SELECT COUNT(*) c FROM notifications WHERE user_id=(SELECT id FROM users WHERE email='impact-hero@example.com') AND type='recognition'").get();
  assert.equal(notifications.c, 1);
  const second = await (await call(env, 'POST',
    '/api/v1/admin/recognition/sweep', {}, admin)).json();
  assert.equal(second.created, 0);
});

test('Pro members create courses, events and programs for free but pay for opportunities', async () => {
  const env = mkEnv({ ENTITY_TEST_MODE: 'false' });
  const pro = await signup(env, 'pro@example.com', 'Pro Member');
  const me = await fundWallet(env, pro, 0);
  const now = new Date();
  env.DB.raw.prepare(`INSERT INTO pro_subscriptions
    (user_id,plan,status,started_at,expires_at,created_at) VALUES (?,?,'ACTIVE',?,?,?)`)
    .run(Number(me.id), 'monthly', now.toISOString(),
      new Date(now.getTime() + 30 * 86400000).toISOString(), now.toISOString());

  const course = await (await call(env, 'POST', '/api/v1/courses', {
    title: 'Pro free course', lessons: 2,
  }, pro)).json();
  assert.equal(course.verification_status, 'PENDING');
  assert.equal(course.creation_fee_mrc, 0);

  const insufficient = await call(env, 'POST', '/api/v1/opportunities', {
    title: 'Pro paid opportunity', type: 'GRANT',
  }, pro);
  assert.equal(insufficient.status, 402);
  env.DB.raw.prepare('UPDATE coin_wallets SET balance=100 WHERE owner_id=?').run(Number(me.id));
  const opportunity = await (await call(env, 'POST', '/api/v1/opportunities', {
    title: 'Pro paid opportunity', type: 'GRANT',
  }, pro)).json();
  assert.equal(opportunity.creation_fee_mrc, 30);
});

test('register, login and profile shape match the app models', async () => {
  const env = mkEnv();
  const token = await signup(env);
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  assert.equal(me.full_name, 'Amina Test');
  assert.equal(me.email, 'amina@example.com');
  assert.equal(me.role, 'STUDENT');
  assert.ok(me.profile);
  assert.equal(me.profile.followers_count, 0);

  const bad = await call(env, 'POST', '/api/v1/auth/login', { email: 'amina@example.com', password: 'wrong-pass' });
  assert.equal(bad.status, 401);
  const ok = await call(env, 'POST', '/api/v1/auth/login', { email: 'amina@example.com', password: 'correct-horse9' });
  const login = await ok.json();
  assert.ok(login.access_token);
  assert.equal(login.user.email, 'amina@example.com');

  const dup = await call(env, 'POST', '/api/v1/users/register', { email: 'amina@example.com', full_name: 'Amina', password: 'correct-horse9' });
  assert.equal(dup.status, 409);
});

test('social lifecycle: post, like, comment, impact vote and ranking metadata', async () => {
  const env = mkEnv();
  const author = await signup(env, 'author@example.com', 'Yara Author');

  const created = await call(env, 'POST', '/api/v1/posts', {
    text: 'We installed 12 solar water pumps in rural schools this week. Verified with local partners.',
    kind: 'IMPACT', sdg: 6,
  }, author);
  assert.equal(created.status, 201);
  const post = await created.json();
  assert.equal(post.kind, 'IMPACT');
  assert.equal(post.sdg, 6);

  const reader = await signup(env, 'reader@example.com', 'Omar Reader');
  const feed = await (await call(env, 'GET', '/api/v1/posts?mode=for_you', null, reader)).json();
  assert.equal(feed.length, 1);
  assert.ok(feed[0].ranking_reason);
  assert.ok(Array.isArray(feed[0].ranking_reasons));

  const like = await (await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader)).json();
  assert.equal(like.liked, true);
  assert.equal(like.likes, 1);
  const unlike = await (await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader)).json();
  assert.equal(unlike.liked, false);

  const comment = await (await call(env, 'POST', `/api/v1/posts/${post.id}/comment`, { text: 'This matters.' }, reader)).json();
  assert.equal(comment.text, 'This matters.');
  const comments = await (await call(env, 'GET', `/api/v1/posts/${post.id}/comments`)).json();
  assert.equal(comments.length, 1);
  assert.equal(comments[0].author_name, 'Omar Reader');

  const vote = await (await call(env, 'POST', `/api/v1/posts/${post.id}/impact`, {
    stars: 5, categories: ['verified_evidence', 'scale'], note: 'Saw the pumps in person.',
  }, reader)).json();
  assert.equal(vote.my_vote.stars, 5);
  assert.ok(vote.impact_value > 0);
  assert.match(vote.impact_label, /impact/i);

  const selfVote = await call(env, 'POST', `/api/v1/posts/${post.id}/impact`, { stars: 5 }, author);
  assert.equal(selfVote.status, 400);

  const detail = await (await call(env, 'GET', `/api/v1/posts/${post.id}`, null, reader)).json();
  assert.equal(detail.impactValue, vote.impact_value);
  assert.equal(detail.likedByMe, false);
});

test('follow graph changes the following feed and profile counts', async () => {
  const env = mkEnv();
  const author = await signup(env, 'author2@example.com', 'Nour Author');
  const reader = await signup(env, 'reader2@example.com', 'Ali Reader');
  const p = await (await call(env, 'POST', '/api/v1/posts', { text: 'New water station is live.', kind: 'UPDATE' }, author)).json();
  const authorId = (await (await call(env, 'GET', '/api/v1/users/me', null, author)).json()).id;

  const follow = await (await call(env, 'POST', `/api/v1/users/${authorId}/follow`, null, reader)).json();
  assert.equal(follow.following, true);
  assert.equal(follow.followers_count, 1);

  const following = await (await call(env, 'GET', '/api/v1/posts?mode=following', null, reader)).json();
  assert.equal(following.length, 1);
  assert.equal(following[0].id, p.id);

  const profile = await (await call(env, 'GET', `/api/v1/users/${authorId}`, null, reader)).json();
  assert.equal(profile.followers_count, 1);
  assert.equal(profile.is_following, true);
  assert.equal(profile.posts.length, 1);
});

test('modes: latest and impact order deterministically', async () => {
  const env = mkEnv();
  const a = await signup(env, 'a3@example.com', 'A Three');
  const b = await signup(env, 'b3@example.com', 'B Three');
  const p1 = await (await call(env, 'POST', '/api/v1/posts', { text: 'First post about clean energy.', sdg: 7 }, a)).json();
  const p2 = await (await call(env, 'POST', '/api/v1/posts', { text: 'Second post about education.', sdg: 4 }, b)).json();
  const voter = await signup(env, 'v3@example.com', 'V Three');
  await call(env, 'POST', `/api/v1/posts/${p2.id}/impact`, { stars: 4 }, voter);

  const latest = await (await call(env, 'GET', '/api/v1/posts?mode=latest')).json();
  assert.equal(latest[0].id, p2.id);
  const impact = await (await call(env, 'GET', '/api/v1/posts?mode=impact')).json();
  assert.equal(impact[0].id, p2.id);
  assert.ok(impact[0].impactValue > (impact[1].impactValue || 0));
  assert.equal(p1.sdg, 7);
});

test('testers: signup is idempotent, countable and admin can manage them', async () => {
  const env = mkEnv();
  const first = await (await call(env, 'POST', '/api/testers', {
    name: 'Mona Tester', email: 'Mona@Example.com', country: 'Egypt', device: 'Pixel 7', android_version: '14',
  })).json();
  assert.equal(first.ok, true);
  assert.equal(first.already, false);
  const second = await (await call(env, 'POST', '/api/testers', {
    name: 'Mona T', email: 'mona@example.com', country: 'Egypt',
  })).json();
  assert.equal(second.already, true);
  const stats = await (await call(env, 'GET', '/api/testers/stats')).json();
  assert.equal(stats.count, 1);

  const denied = await call(env, 'GET', '/api/v1/admin/testers');
  assert.equal(denied.status, 401);
  const admin = await signup(env, 'ceo@example.com', 'The CEO');
  const list = await (await call(env, 'GET', '/api/v1/admin/testers', null, admin)).json();
  assert.equal(list.total, 1);
  assert.equal(list.rows[0].email, 'mona@example.com');

  const id = list.rows[0].id;
  assert.equal((await call(env, 'POST', `/api/v1/admin/testers/${id}/status`, { status: 'invited' }, admin)).status, 200);
  const csv = await (await call(env, 'GET', '/api/v1/admin/testers.csv', null, admin)).text();
  assert.match(csv, /mona@example\.com/);
});

test('invalid input is rejected with helpful codes', async () => {
  const env = mkEnv();
  const token = await signup(env, 'x@example.com', 'X User');
  assert.equal((await call(env, 'POST', '/api/v1/users/register', { email: 'nope', full_name: 'N', password: 'longenough' })).status, 400);
  assert.equal((await call(env, 'POST', '/api/v1/posts', { text: '' }, token)).status, 400);
  assert.equal((await call(env, 'POST', '/api/v1/posts/999/like', null, token)).status, 404);
  assert.equal((await call(env, 'GET', '/api/v1/posts?limit=5000', null, token)).status, 200);
  assert.equal((await call(env, 'POST', '/api/v1/posts/1/impact', { stars: 0 }, token)).status, 400);
});


test('courses: create, list, enroll and validate', async () => {
  const env = mkEnv();
  const author = await signup(env, 'teacher@example.com', 'Mona Teacher');
  const short = await call(env, 'POST', '/api/v1/courses', { title: 'A' }, author);
  assert.equal(short.status, 400);
  const created = await call(env, 'POST', '/api/v1/courses', {
    title: 'Measuring community impact', description: 'A practical course for field teams.',
    level: 'Intermediate', sdg: 4, lessons: 6, duration_min: 90,
  }, author);
  assert.equal(created.status, 201);
  const course = await created.json();
  assert.equal(course.title, 'Measuring community impact');
  assert.equal(course.enrolled_count, 0);

  const listed = await (await call(env, 'GET', '/api/v1/courses', null, author)).json();
  assert.equal(listed.length, 1);
  assert.equal(listed[0].enrolled_by_me, false);

  const student = await signup(env, 'student@example.com', 'Omar Student');
  const enrolled = await (await call(env, 'POST', `/api/v1/courses/${course.id}/enroll`, null, student)).json();
  assert.equal(enrolled.enrolled_count, 1);
  const again = await (await call(env, 'POST', `/api/v1/courses/${course.id}/enroll`, null, student)).json();
  assert.equal(again.enrolled_count, 1);
  const mine = await (await call(env, 'GET', '/api/v1/courses', null, student)).json();
  assert.equal(mine[0].enrolled_by_me, true);
});

test('events: create, list, join and capacity validation', async () => {
  const env = mkEnv();
  const host = await signup(env, 'host@example.com', 'Nour Host');
  const bad = await call(env, 'POST', '/api/v1/events', { title: 'Cleanup day', starts_at: 'not-a-date', location: 'Cairo' }, host);
  assert.equal(bad.status, 400);
  const created = await call(env, 'POST', '/api/v1/events', {
    title: 'Nile cleanup day', description: 'Bring gloves.', starts_at: '2030-06-05T09:00:00Z',
    location: 'Cairo', sdg: 6, capacity: 1,
  }, host);
  assert.equal(created.status, 201);
  const event = await created.json();
  assert.equal(event.attendees_count, 0);

  const a = await signup(env, 'a4@example.com', 'A Four');
  const joined = await (await call(env, 'POST', `/api/v1/events/${event.id}/join`, null, a)).json();
  assert.equal(joined.attending, true);
  assert.equal(joined.attendees_count, 1);

  const b = await signup(env, 'b4@example.com', 'B Four');
  const full = await call(env, 'POST', `/api/v1/events/${event.id}/join`, null, b);
  assert.equal(full.status, 409);

  const left = await (await call(env, 'POST', `/api/v1/events/${event.id}/join`, null, a)).json();
  assert.equal(left.attending, false);
  const canJoin = await (await call(env, 'POST', `/api/v1/events/${event.id}/join`, null, b)).json();
  assert.equal(canJoin.attending, true);
});

test('notifications are created by social actions and stay private', async () => {
  const env = mkEnv();
  const author = await signup(env, 'notify-author@example.com', 'Yara Notify');
  const reader = await signup(env, 'notify-reader@example.com', 'Ali Notify');
  const post = await (await call(env, 'POST', '/api/v1/posts', { text: 'A new community clinic opened today.' }, author)).json();
  await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader);
  await call(env, 'POST', `/api/v1/posts/${post.id}/comment`, { text: 'Great news.' }, reader);
  const authorId = (await (await call(env, 'GET', '/api/v1/users/me', null, author)).json()).id;
  const readerId = (await (await call(env, 'GET', '/api/v1/users/me', null, reader)).json()).id;

  const list = await (await call(env, 'GET', `/api/v1/notifications/${authorId}`, null, author)).json();
  assert.ok(list.length >= 2);
  assert.ok(list.some((n) => n.type === 'like'));
  assert.ok(list.some((n) => n.type === 'comment'));
  assert.equal(list[0].read, false);

  const denied = await call(env, 'GET', `/api/v1/notifications/${authorId}`, null, reader);
  assert.equal(denied.status, 403);

  const marked = await call(env, 'POST', '/api/v1/notifications/read-all', null, author);
  assert.equal(marked.status, 200);
  const after = await (await call(env, 'GET', `/api/v1/notifications/${authorId}`, null, author)).json();
  assert.equal(after.every((n) => n.read), true);

  assert.equal((await call(env, 'GET', `/api/v1/notifications/${readerId}`)).status, 401);
});

test('registration accepts the tester flag and exposes it on the profile', async () => {
  const env = mkEnv();
  const r = await call(env, 'POST', '/api/v1/users/register', {
    email: 'tester@example.com', full_name: 'Tester One', password: 'beta-test-9',
    role: 'STUDENT', is_tester: true, audience: 'STUDENT', consent: true,
  });
  assert.equal(r.status, 201);
  const j = await r.json();
  assert.equal(j.user.is_tester, true);
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, j.access_token)).json();
  assert.equal(me.is_tester, true);
});

test('programs run end to end: create, discover, enroll, tasks and linked projects', async () => {
  const env = mkEnv();
  const owner = await signup(env, 'program-owner@example.com', 'Mona Program');
  const member = await signup(env, 'program-member@example.com', 'Hassan Member');

  const created = await call(env, 'POST', '/api/v1/programs', {
    title: 'Delta Water Resilience Program', description: 'Restoring village water systems.',
    category: 'Climate', sdg_goals: [6, 13], budget: 250000, target_beneficiaries: 1200,
  }, owner);
  assert.equal(created.status, 201);
  const program = await created.json();
  assert.equal(program.sdg, 6);
  assert.equal(program.members_count, 1);
  assert.equal(program.enrolled_by_me, true);

  const list = await (await call(env, 'GET', '/api/v1/programs', null, member)).json();
  assert.equal(list.length, 1);
  assert.equal(list[0].enrolled_by_me, false);

  const joined = await (await call(env, 'POST', `/api/v1/programs/${program.id}/enroll`, null, member)).json();
  assert.equal(joined.members_count, 2);
  assert.equal(joined.enrolled_by_me, true);

  const task = await (await call(env, 'POST', `/api/v1/programs/${program.id}/tasks`, {
    title: 'Collect baseline water quality readings', due_at: '2026-11-30T10:00:00Z', evidence_required: true,
  }, owner)).json();
  assert.equal(task.status, 'OPEN');

  const project = await (await call(env, 'POST', '/api/v1/projects', {
    program_id: program.id, title: 'Village filter rollout', category: 'Water', goal: 50000, sdg: 6,
  }, owner)).json();
  assert.equal(project.program_id, program.id);
  assert.equal(project.members, 1);
  assert.equal(project.author.name, 'Mona Program');

  const detail = await (await call(env, 'GET', `/api/v1/programs/${program.id}`, null, owner)).json();
  assert.equal(detail.tasks.length, 1);
  assert.equal(detail.projects.length, 1);
  assert.equal(detail.projects[0].author.id, project.author.id);

  const passportId = (await (await call(env, 'GET', '/api/v1/users/me', null, member)).json()).id;
  const blocked = await call(env, 'GET', `/api/v1/users/${passportId}/passport`);
  assert.equal(blocked.status, 401);
  const passport = await (await call(env, 'GET', `/api/v1/users/${passportId}/passport`, null, member)).json();
  assert.equal(passport.programs, 1);
  assert.ok(passport.badges.includes('Program member'));
  const members = await (await call(env, 'GET', `/api/v1/programs/${program.id}/members`, null, member)).json();
  assert.equal(members.length, 2);
  assert.ok(members.some((m) => m.program_role === 'OWNER'));
});

test('opportunity marketplace: publish, filter, apply once and notify the owner', async () => {
  const env = mkEnv();
  const owner = await signup(env, 'opportunity-owner@example.com', 'Nour Employer');
  const applicant = await signup(env, 'opportunity-applicant@example.com', 'Dina Applicant');

  const created = await call(env, 'POST', '/api/v1/opportunities', {
    title: 'Monitoring & Evaluation Officer', description: 'Own the impact measurement cycle.',
    type: 'JOB', skills: ['M&E', 'SQL', 'Reporting'], sdg: 8, location: 'Cairo', min_pms: 40,
    deadline: '2026-12-15',
  }, owner);
  assert.equal(created.status, 201);
  const opp = await created.json();
  assert.equal(opp.type, 'JOB');
  assert.deepEqual(opp.skills, ['M&E', 'SQL', 'Reporting']);

  const list = await (await call(env, 'GET', '/api/v1/opportunities', null, applicant)).json();
  assert.equal(list.length, 1);
  assert.equal(list[0].applied, false);

  const applied = await (await call(env, 'POST', `/api/v1/opportunities/${opp.id}/apply`, { note: 'Five years in the field.' }, applicant)).json();
  assert.equal(applied.applied, true);
  assert.equal(applied.applications_count, 1);

  const dup = await call(env, 'POST', `/api/v1/opportunities/${opp.id}/apply`, {}, applicant);
  assert.equal(dup.status, 409);

  const ownerId = (await (await call(env, 'GET', '/api/v1/users/me', null, owner)).json()).id;
  const notes = await (await call(env, 'GET', `/api/v1/notifications/${ownerId}`, null, owner)).json();
  assert.ok(notes.some((n) => n.type === 'opportunity'));
});

test('evidence, submissions and verification pipeline produce a working passport', async () => {
  const env = mkEnv();
  const token = await signup(env, 'verifier@example.com', 'Rami Verifier');

  const sub = await call(env, 'POST', '/api/v1/submissions', {
    title: '20 solar pumps installed and running',
    claim: 'Twenty pumps now serve 600 households in three villages.',
    evidence_url: 'https://example.org/evidence/pumps.jpg',
    evidence_kind: 'PHOTO',
  }, token);
  assert.equal(sub.status, 201);
  const submission = await sub.json();
  assert.equal(submission.status, 'SUBMITTED');
  assert.ok(submission.evidence_id);

  const pipeline = await (await call(env, 'POST', `/api/v1/submissions/${submission.id}/pipeline`, null, token)).json();
  assert.equal(pipeline.status, 'AI_REVIEW');
  assert.equal(pipeline.steps.length, 3);

  const tracked = await (await call(env, 'GET', `/api/v1/verification/pipelines/evidence/${submission.evidence_id}`, null, token)).json();
  assert.equal(tracked.pipeline.status, 'AI_REVIEW');

  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const mine = await (await call(env, 'GET', `/api/v1/submissions/users/${me.id}`, null, token)).json();
  assert.equal(mine.length, 1);
  assert.equal(mine[0].pipeline_id, pipeline.id);

  const passport = await (await call(env, 'GET', `/api/v1/users/${me.id}/passport`, null, token)).json();
  assert.equal(passport.submissions, 1);
  assert.equal(passport.verified_claims, 0);
});

test('professional profile domain: edit, aggregate, endorse, follow and discover', async () => {
  const env = mkEnv();
  const token = await signup(env, 'layla@example.com', 'Layla Profile');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();

  const patched = await call(env, 'PATCH', `/api/v1/personnel/${me.id}`, {
    headline: 'Environmental Journalist',
    summary: 'Independent climate and water reporting across the region.',
    mission: 'Make evidence visible.',
    beat: 'Climate & water',
    expertise: ['Climate policy', 'Investigative reporting'],
    skills: ['Data journalism', 'Interviewing'],
    languages: ['Arabic', 'English'],
    coverage_regions: ['Lebanon', 'Jordan'],
    employment_status: 'Journalist',
    availability: 'Open to collaborations',
    website: 'https://example.org/layla',
    social_links: { linkedin: 'https://linkedin.com/in/layla' },
    coverage_hours: 120,
  }, token);
  assert.equal(patched.status, 200);
  const profile = await patched.json();
  assert.equal(profile.headline, 'Environmental Journalist');
  assert.equal(profile.skills[0].name, 'Data journalism');
  assert.equal(profile.pms.total > 0, true);
  assert.ok(profile.completeness > 50);
  assert.equal(profile.coverage_regions.length, 2);

  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A verified field investigation into coastal water use and the communities adapting to it.',
    kind: 'IMPACT', sdg: 6,
  }, token)).json();
  const reports = await (await call(env, 'GET', `/api/v1/personnel/${me.id}/reports`, null, token)).json();
  assert.equal(reports.length, 1);
  assert.equal(reports[0].sdg, 6);
  assert.equal(reports[0].verification_status, 'REVIEW');

  const analytics = await (await call(env, 'GET', `/api/v1/personnel/${me.id}/analytics`, null, token)).json();
  assert.equal(analytics.series.length, 6);
  assert.ok(analytics.series.some((p) => p.reach > 0));

  const timeline = await (await call(env, 'GET', `/api/v1/personnel/${me.id}/timeline`, null, token)).json();
  assert.ok(timeline.some((t) => t.kind === 'report'));

  const coverage = await (await call(env, 'GET', `/api/v1/personnel/${me.id}/coverage`, null, token)).json();
  assert.equal(coverage.coverage_hours, 120);
  assert.equal(coverage.countries_covered, 2);

  const other = await signup(env, 'reader-profile@example.com', 'Profile Reader');
  const otherMe = await (await call(env, 'GET', '/api/v1/users/me', null, other)).json();
  const followed = await (await call(env, 'POST', `/api/v1/personnel/${me.id}/follow`, null, other)).json();
  assert.equal(followed.following, true);
  assert.equal(followed.followers_count, 1);

  const endorsed = await (await call(env, 'POST', `/api/v1/personnel/${me.id}/endorse`, { skill: 'Data journalism' }, other)).json();
  assert.equal(endorsed.endorsements, 1);
  const refreshed = await (await call(env, 'GET', `/api/v1/personnel/${me.id}`, null, other)).json();
  assert.equal(refreshed.skills.find((s) => s.name === 'Data journalism').endorsements, 1);
  assert.equal(refreshed.is_following, true);
  assert.equal(refreshed.email, '');

  const list = await (await call(env, 'GET', '/api/v1/personnel?q=Layla', null, other)).json();
  assert.equal(list.length, 1);
  assert.equal(list[0].headline, 'Environmental Journalist');

  const forbidden = await call(env, 'PATCH', `/api/v1/personnel/${me.id}`, { headline: 'Hijacked' }, other);
  assert.equal(forbidden.status, 403);
  const selfEndorse = await call(env, 'POST', `/api/v1/personnel/${me.id}/endorse`, { skill: 'Data journalism' }, token);
  assert.equal(selfEndorse.status, 400);
  assert.ok(otherMe.id !== me.id);
  assert.ok(post.id);
});

test('feed pagination is stable and never repeats a post across pages', async () => {
  const env = mkEnv();
  const token = await signup(env, 'pager@example.com', 'Pager User');
  for (let i = 0; i < 25; i++) {
    const created = await call(env, 'POST', '/api/v1/posts', {
      text: `Pager post ${i}`,
      kind: 'STORY',
    }, token);
    assert.equal(created.status, 201);
  }
  const page = async (offset) => (await call(env, 'GET',
    `/api/v1/posts?limit=10&offset=${offset}&mode=for_you`, null, token)).json();
  const pages = [await page(0), await page(10), await page(20)];
  assert.equal(pages[0].length, 10);
  assert.equal(pages[1].length, 10);
  assert.equal(pages[2].length, 5);
  const ids = pages.flat().map((p) => p.id);
  assert.equal(new Set(ids).size, ids.length);
  assert.equal(ids.length, 25);
  const beyond = await page(30);
  assert.deepEqual(beyond, []);
});

test('media posts keep galleries, video metadata, files, location and verified ranking', async () => {
  const env = mkEnv();
  const token = await signup(env, 'media@example.com', 'Maya Media');
  const created = await call(env, 'POST', '/api/v1/posts', {
    text: 'A photo story from the field with two captioned moments.',
    kind: 'IMPACT',
    impact_value: 9.2,
    latitude: 33.5138,
    longitude: 36.2765,
    media: [
      { url: 'https://cdn.example.org/one.jpg', caption: 'Before the works' },
      { url: 'https://cdn.example.org/two.jpg', caption: 'After the works' },
    ],
    files: [{
      url: 'https://cdn.example.org/field-report.pdf',
      name: 'Field report.pdf', size: 248000,
      content_type: 'application/pdf',
    }],
  }, token);
  assert.equal(created.status, 201);
  const gallery = await created.json();
  assert.equal(gallery.media_type, 'GALLERY');
  assert.equal(gallery.media.length, 2);
  assert.equal(gallery.media[1].caption, 'After the works');
  assert.equal(gallery.latitude, 33.5138);
  assert.equal(gallery.impactValue, 9.2);
  assert.equal(gallery.files.length, 1);
  assert.equal(gallery.files[0].name, 'Field report.pdf');
  assert.equal(gallery.files[0].content_type, 'application/pdf');

  const video = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A short field clip from the community event.',
    kind: 'EVIDENCE',
    media: [{
      type: 'VIDEO',
      url: 'https://cdn.example.org/clip.mp4',
      hls_url: 'https://cdn.example.org/clip.m3u8',
      poster_url: 'https://cdn.example.org/clip.jpg',
    }],
  }, token)).json();
  assert.equal(video.media_type, 'VIDEO');
  assert.equal(video.video_hls_url, 'https://cdn.example.org/clip.m3u8');
  assert.equal(video.video_poster_url, 'https://cdn.example.org/clip.jpg');

  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  await env.DB.prepare('UPDATE users SET email_verified=1 WHERE id=?').bind(me.id).run();
  await env.DB.prepare('UPDATE posts SET confidence_score=92 WHERE id=?').bind(gallery.id).run();
  const feed = await (await call(env, 'GET', '/api/v1/posts?mode=for_you', null, token)).json();
  const ranked = feed.find((p) => p.id === gallery.id);
  assert.equal(ranked.verified_content, true);
  assert.ok(ranked.ranking_reasons.includes('Verified source'));

  const secondPage = await (await call(env, 'GET', '/api/v1/posts?mode=latest&limit=1&offset=1', null, token)).json();
  assert.equal(secondPage.length, 1);
  assert.equal(secondPage[0].id, gallery.id);
  const pastEnd = await (await call(env, 'GET', '/api/v1/posts?mode=latest&limit=1&offset=8', null, token)).json();
  assert.equal(pastEnd.length, 0);
});

test('sports organisations, squads, results and player careers are served', async () => {
  const env = mkEnv();
  const owner = await signup(env, 'club@example.com', 'Club Owner');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, owner)).json();
  const at = new Date().toISOString();
  const org = await env.DB.prepare(`INSERT INTO organizations
    (owner_id,name,slug,type,description,country,city,verified,verification_level,pms_score,oii_score,metadata_json,created_at)
    VALUES (?,?,?,?,?,?,?,1,'VERIFIED',88,72,?,?)`)
    .bind(me.id, 'Al Noor FC', 'al-noor-fc', 'CLUB', 'Community football club', 'Jordan', 'Amman',
      JSON.stringify({ league: 'Jordan League', stadium: 'Al Noor Park', capacity: 4200, founded: '1998' }), at).run();
  const orgId = org.meta.last_row_id;

  const athlete = await signup(env, 'player@example.com', 'Nour Player');
  const player = await (await call(env, 'GET', '/api/v1/users/me', null, athlete)).json();
  await env.DB.prepare(`INSERT INTO sports_profiles
    (user_id,sport,position,club,team_id,nationality,height_cm,weight_kg,preferred_foot,jersey_number,metrics_json,verified,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,1,?,?)`)
    .bind(player.id, 'FOOTBALL', 'Forward', 'Al Noor FC', orgId, 'Jordan', 181, 76, 'Right', 9,
      JSON.stringify({ trophies: [{ name: 'Cup', year: '2024' }] }), at, at).run();
  await env.DB.prepare(`INSERT INTO sports_metrics
    (user_id,sport,season,competition,team,appearances,starts,minutes,goals,assists,rating,yellow_cards,red_cards,clean_sheets,saves,source,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    .bind(player.id, 'FOOTBALL', '2024/25', 'Jordan League', 'Al Noor FC', 18, 16, 1440, 7, 4, 7.8, 2, 0, 0, 0, 'MANUAL', at, at).run();
  await env.DB.prepare(`INSERT INTO sports_roster (org_id,athlete_id,position,jersey_number,season,status,created_at)
    VALUES (?,?,?,?,?,?,?)`).bind(orgId, player.id, 'Forward', 9, '2024/25', 'ACTIVE', at).run();
  await env.DB.prepare(`INSERT INTO sports_events
    (org_id,opponent_name,competition,starts_at,venue,home_away,status,home_score,away_score,created_at)
    VALUES (?,?,?,?,?,?,?,?,?,?)`)
    .bind(orgId, 'Amman United', 'Jordan League', '2026-09-12T17:00:00Z', 'Al Noor Park', 'HOME', 'FINISHED', 2, 1, at).run();
  await env.DB.prepare(`INSERT INTO sports_events
    (org_id,opponent_name,competition,starts_at,venue,home_away,status,created_at)
    VALUES (?,?,?,?,?,?,?,?)`)
    .bind(orgId, 'Zarqa Stars', 'Jordan League', '2026-10-01T17:00:00Z', 'Zarqa Arena', 'AWAY', 'SCHEDULED', at).run();

  const team = await (await call(env, 'GET', `/api/v1/orgs/${orgId}`, null, owner)).json();
  assert.equal(team.name, 'Al Noor FC');
  assert.equal(team.league, 'Jordan League');
  assert.equal(team.wins, 1);
  assert.equal(team.points, 3);

  const squad = await (await call(env, 'GET', `/api/v1/orgs/${orgId}/squad`, null, owner)).json();
  assert.equal(squad.length, 1);
  assert.equal(squad[0].goals, 7);
  const results = await (await call(env, 'GET', `/api/v1/orgs/${orgId}/results`, null, owner)).json();
  assert.equal(results.length, 1);
  assert.equal(results[0].opponent, 'Amman United');
  const fixtures = await (await call(env, 'GET', `/api/v1/orgs/${orgId}/fixtures`, null, owner)).json();
  assert.equal(fixtures.length, 1);

  const record = await (await call(env, 'GET', `/api/v1/players/${player.id}`, null, owner)).json();
  assert.equal(record.position, 'Forward');
  assert.equal(record.goals, 7);
  assert.equal(record.assists, 4);
  assert.equal(record.email, '');
  assert.equal(record.achievements.some((a) => a.kind === 'TROPHY'), true);
  const career = await (await call(env, 'GET', `/api/v1/players/${player.id}/career`, null, owner)).json();
  assert.equal(career[0].season, '2024/25');
});

test('social graph: bookmarks, search, threads, messages, blocks and reports', async () => {
  const env = mkEnv();
  const author = await signup(env, 'graph-author@example.com', 'Graph Author');
  const authorMe = await (await call(env, 'GET', '/api/v1/users/me', null, author)).json();
  const reader = await signup(env, 'graph-reader@example.com', 'Graph Reader');

  const created = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'Community cleanup #environment #amman starts this Friday.',
    kind: 'IMPACT', sdg: 11,
  }, author)).json();
  assert.equal(created.bookmarkedByMe, false);

  const marked = await (await call(env, 'POST', `/api/v1/posts/${created.id}/bookmark`, null, reader)).json();
  assert.equal(marked.bookmarked, true);
  const saved = await (await call(env, 'GET', '/api/v1/users/me/bookmarks', null, reader)).json();
  assert.equal(saved.length, 1);
  assert.equal(saved[0].bookmarkedByMe, true);
  const unmarked = await (await call(env, 'POST', `/api/v1/posts/${created.id}/bookmark`, null, reader)).json();
  assert.equal(unmarked.bookmarked, false);

  const edited = await (await call(env, 'PATCH', `/api/v1/posts/${created.id}`, {
    text: 'Community cleanup #environment #amman moved to Saturday.',
  }, author)).json();
  assert.match(edited.text, /Saturday/);
  assert.ok(edited.edited_at);

  const top = await (await call(env, 'POST', `/api/v1/posts/${created.id}/comment`, { text: 'I can volunteer.' }, reader)).json();
  const reply = await (await call(env, 'POST', `/api/v1/posts/${created.id}/comment`, {
    text: 'Great, see you there.', parent_id: top.id,
  }, author)).json();
  assert.equal(reply.parent_id, top.id);
  const comments = await (await call(env, 'GET', `/api/v1/posts/${created.id}/comments`, null, reader)).json();
  assert.equal(comments.length, 2);
  assert.equal(comments.find((c) => c.id === reply.id).parent_id, top.id);
  const likedComment = await (await call(env, 'POST', `/api/v1/comments/${top.id}/like`, null, author)).json();
  assert.equal(likedComment.liked, true);
  assert.equal(likedComment.likes, 1);
  const deletedComment = await call(env, 'DELETE', `/api/v1/comments/${reply.id}`, null, author);
  assert.equal(deletedComment.status, 200);

  const search = await (await call(env, 'GET', '/api/v1/search?q=environment', null, reader)).json();
  assert.equal(search.posts.length, 1);
  assert.equal(search.hashtags.some((h) => h.tag === 'environment'), true);
  const people = await (await call(env, 'GET', '/api/v1/search?q=Graph%20Author', null, reader)).json();
  assert.equal(people.users[0].name, 'Graph Author');
  const trends = await (await call(env, 'GET', '/api/v1/trends', null, reader)).json();
  assert.equal(trends.some((h) => h.tag === 'environment'), true);

  const conversation = await (await call(env, 'POST', '/api/v1/messages/conversations', { user_id: authorMe.id }, reader)).json();
  assert.equal(conversation.peer.id, authorMe.id);
  const sent = await call(env, 'POST', `/api/v1/messages/conversations/${conversation.id}`, { text: 'Hello from the app' }, reader);
  assert.equal(sent.status, 201);
  const unread = await (await call(env, 'GET', '/api/v1/messages/unread', null, author)).json();
  assert.equal(unread.count, 1);
  const inbox = await (await call(env, 'GET', '/api/v1/messages/conversations', null, author)).json();
  assert.equal(inbox[0].unread_count, 1);
  assert.equal(inbox[0].last_message, 'Hello from the app');
  const thread = await (await call(env, 'GET', `/api/v1/messages/conversations/${conversation.id}`, null, author)).json();
  assert.equal(thread.messages.length, 1);
  assert.equal(thread.messages[0].mine, false);
  const afterRead = await (await call(env, 'GET', '/api/v1/messages/unread', null, author)).json();
  assert.equal(afterRead.count, 0);

  const report = await call(env, 'POST', `/api/v1/posts/${created.id}/report`, {
    reason: 'misinformation', details: 'Needs a source',
  }, reader);
  assert.equal(report.status, 201);
  const reportRow = await env.DB.prepare('SELECT id FROM reports LIMIT 1').first();
  const admin = await signup(env, 'ceo@example.com', 'Admin User');
  const queue = await (await call(env, 'GET', '/api/v1/admin/reports', null, admin)).json();
  assert.equal(queue.length, 1);
  const queueWithCounts = await (await call(env, 'GET', '/api/v1/admin/reports?with_counts=1', null, admin)).json();
  assert.equal(queueWithCounts.items.length, 1);
  assert.equal(queueWithCounts.counts.open, 1);
  const resolved = await (await call(env, 'POST', `/api/v1/admin/reports/${reportRow.id}/resolve`, {
    status: 'RESOLVED',
  }, admin)).json();
  assert.equal(resolved.status, 'RESOLVED');
  const remark = await (await call(env, 'POST', `/api/v1/posts/${created.id}/bookmark`, null, reader)).json();
  assert.equal(remark.bookmarked, true);
  const block = await (await call(env, 'POST', `/api/v1/users/${authorMe.id}/block`, null, reader)).json();
  assert.equal(block.blocked, true);
  const feed = await (await call(env, 'GET', '/api/v1/posts', null, reader)).json();
  assert.equal(feed.length, 0);
  const savedAfterBlock = await (await call(env, 'GET', '/api/v1/users/me/bookmarks', null, reader)).json();
  assert.equal(savedAfterBlock.length, 0);
  const searchAfterBlock = await (await call(env, 'GET', '/api/v1/search?q=Graph%20Author', null, reader)).json();
  assert.equal(searchAfterBlock.users.length, 0);
  const blockedMsg = await call(env, 'POST', `/api/v1/messages/conversations/${conversation.id}`, { text: 'blocked?' }, reader);
  assert.equal(blockedMsg.status, 403);
  const unblock = await (await call(env, 'POST', `/api/v1/users/${authorMe.id}/block`, null, reader)).json();
  assert.equal(unblock.blocked, false);
  const savedAfterUnblock = await (await call(env, 'GET', '/api/v1/users/me/bookmarks', null, reader)).json();
  assert.equal(savedAfterUnblock.length, 1);
});



test('email verification and password reset work end to end', async () => {
  const env = mkEnv();
  const sent = [];
  env.RESEND_API_KEY = 're_test';
  env.__fetch = async (_url, options) => {
    sent.push(JSON.parse(options.body));
    return new Response(JSON.stringify({ id: 'mail_test' }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };
  const email = 'verify@example.com';
  const created = await call(env, 'POST', '/api/v1/users/register', {
    email, full_name: 'Verify User', password: 'correct-horse9', role: 'STUDENT',
  });
  assert.equal(created.status, 201);
  const body = await created.json();
  assert.equal(body.email_verification_required, true);
  assert.equal(body.verification_email_sent, true);
  const verifyMail = sent.find((m) => m.subject.includes('Confirm'));
  assert.ok(verifyMail);
  const verifyLink = /href="([^"]+)"/.exec(verifyMail.html)[1].replace(/&amp;/g, '&');
  const verifyToken = new URL(verifyLink).searchParams.get('token');
  const verified = await call(env, 'POST', '/api/v1/auth/verify-email', { token: verifyToken });
  assert.equal(verified.status, 200);
  const verifiedBody = await verified.json();
  assert.equal(verifiedBody.verified, true);
  assert.equal(verifiedBody.user.email_verified, true);
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, body.access_token)).json();
  assert.equal(me.email_verified, true);

  const forgot = await call(env, 'POST', '/api/v1/auth/forgot-password', { email });
  assert.equal(forgot.status, 200);
  const resetMail = sent.find((m) => m.subject.includes('Reset'));
  assert.ok(resetMail);
  const resetLink = /href="([^"]+)"/.exec(resetMail.html)[1].replace(/&amp;/g, '&');
  const resetToken = new URL(resetLink).searchParams.get('token');
  const reset = await call(env, 'POST', '/api/v1/auth/reset-password', {
    token: resetToken, password: 'new-horse123',
  });
  assert.equal(reset.status, 200);
  const oldLogin = await call(env, 'POST', '/api/v1/auth/login', { email, password: 'correct-horse9' });
  assert.equal(oldLogin.status, 401);
  const newLogin = await call(env, 'POST', '/api/v1/auth/login', { email, password: 'new-horse123' });
  assert.equal(newLogin.status, 200);
  const reused = await call(env, 'POST', '/api/v1/auth/reset-password', {
    token: resetToken, password: 'another-horse123',
  });
  assert.equal(reused.status, 400);
});

test('settings control privacy, messaging and notification categories', async () => {
  const env = mkEnv();
  const author = await signup(env, 'settings-author@example.com', 'Settings Author');
  const reader = await signup(env, 'settings-reader@example.com', 'Settings Reader');
  const authorMe = await (await call(env, 'GET', '/api/v1/users/me', null, author)).json();
  const readerMe = await (await call(env, 'GET', '/api/v1/users/me', null, reader)).json();

  const initial = await (await call(env, 'GET', '/api/v1/users/me/settings', null, author)).json();
  assert.equal(initial.settings.push_enabled, true);
  assert.equal(initial.settings.opportunity_alerts, true);
  const updated = await (await call(env, 'PATCH', '/api/v1/users/me/settings', {
    opportunity_alerts: false,
    profile_visibility: 'private',
    message_privacy: 'nobody',
    show_email: false,
    quiet_start: 1320,
    quiet_end: 420,
  }, author)).json();
  assert.equal(updated.settings.opportunity_alerts, false);
  assert.equal(updated.settings.profile_visibility, 'private');
  assert.equal(updated.settings.message_privacy, 'nobody');
  assert.equal(updated.settings.quiet_start, 1320);
  const persisted = await (await call(env, 'GET', '/api/v1/users/me/settings', null, author)).json();
  assert.equal(persisted.settings.message_privacy, 'nobody');

  const hiddenProfile = await (await call(env, 'GET', `/api/v1/users/${authorMe.id}`, null, reader)).json();
  assert.equal(hiddenProfile.email, '');
  assert.equal(hiddenProfile.profile_private, true);
  assert.equal(hiddenProfile.bio, '');

  const messageBlocked = await call(env, 'POST', '/api/v1/messages/conversations', {
    user_id: authorMe.id,
  }, reader);
  assert.equal(messageBlocked.status, 403);

  await call(env, 'PATCH', '/api/v1/users/me/settings', {
    show_email: true, profile_visibility: 'public', message_privacy: 'everyone',
  }, author);
  const visibleProfile = await (await call(env, 'GET', `/api/v1/users/${authorMe.id}`, null, reader)).json();
  assert.equal(visibleProfile.email, 'settings-author@example.com');
  assert.equal(visibleProfile.profile_private, false);

  await call(env, 'PATCH', '/api/v1/users/me/settings', { social_alerts: false }, author);
  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'Settings notification test', kind: 'UPDATE',
  }, author)).json();
  await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader);
  const authorNotes = await (await call(env, 'GET', `/api/v1/notifications/${authorMe.id}`, null, author)).json();
  assert.equal(authorNotes.filter((n) => n.type === 'like').length, 0);

  await call(env, 'PATCH', '/api/v1/users/me/settings', { social_alerts: true }, author);
  await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader);
  await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader);
  const afterEnable = await (await call(env, 'GET', `/api/v1/notifications/${authorMe.id}`, null, author)).json();
  assert.equal(afterEnable.filter((n) => n.type === 'like').length, 1);
});

test('opportunity matching notifies relevant members without duplicates', async () => {
  const env = mkEnv();
  const author = await signup(env, 'opp-author@example.com', 'Opportunity Author');
  const candidate = await signup(env, 'opp-candidate@example.com', 'Solar Candidate');
  const candidateMe = await (await call(env, 'GET', '/api/v1/users/me', null, candidate)).json();
  await env.DB.prepare('INSERT INTO user_profiles (user_id,skills,updated_at) VALUES (?,?,?)')
    .bind(Number(candidateMe.id), JSON.stringify(['solar', 'community']), new Date().toISOString()).run();

  const created = await call(env, 'POST', '/api/v1/opportunities/', {
    title: 'Solar installer for rural schools',
    description: 'Install solar panels with a community team.',
    type: 'VOLUNTEER',
    skills: ['solar'],
    location: 'Cairo',
  }, author);
  assert.equal(created.status, 201);
  const opportunity = await created.json();
  const notes = await (await call(env, 'GET', `/api/v1/notifications/${candidateMe.id}`, null, candidate)).json();
  const matches = notes.filter((n) => n.type === 'opportunity_match');
  assert.equal(matches.length, 1);
  assert.match(matches[0].title, /Solar installer/);

  const again = await call(env, 'POST', '/api/v1/opportunities/', {
    title: 'Solar installer for rural schools',
    description: 'Second posting.',
    type: 'VOLUNTEER',
    skills: ['solar'],
    location: 'Cairo',
  }, author);
  assert.equal(again.status, 201);
  const second = await again.json();
  assert.notEqual(second.id, opportunity.id);
  const notesAgain = await (await call(env, 'GET', `/api/v1/notifications/${candidateMe.id}`, null, candidate)).json();
  assert.equal(notesAgain.filter((n) => n.type === 'opportunity_match').length, 2);
});

test('daily reward defaults to 10 MRC, is server-set and capped at 500', async () => {
  const env = mkEnv();
  const token = await signup(env, 'reward-default@example.com', 'Reward Default');
  const wallet = await (await call(env, 'GET', '/api/v1/wallet', null, token)).json();
  assert.equal(wallet.daily_reward, 10);
  assert.equal(wallet.claimed_today, false);
  const earned = await (await call(env, 'POST', '/api/v1/coin/transactions/earn', { amount: 9999 }, token)).json();
  assert.equal(earned.balance, 10);
  assert.equal(earned.daily_reward, 10);
  const duplicate = await call(env, 'POST', '/api/v1/coin/transactions/earn', {}, token);
  assert.equal(duplicate.status, 429);

  const cappedEnv = mkEnv();
  cappedEnv.DAILY_REWARD_MRC = '9999';
  const capped = await signup(cappedEnv, 'reward-capped@example.com', 'Reward Capped');
  const cappedEarn = await (await call(cappedEnv, 'POST', '/api/v1/coin/transactions/earn', {}, capped)).json();
  assert.equal(cappedEarn.balance, 500);
});

test('wallet, coins, payments and pro subscriptions work end to end', async () => {
  const env = mkEnv();
  env.DAILY_REWARD_MRC = '500';
  const token = await signup(env, 'wallet@example.com', 'Waleed Wallet');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const missing = await call(env, 'GET', `/api/v1/coin/wallets/${me.id}`, null, token);
  assert.equal(missing.status, 404);
  const created = await (await call(env, 'POST', '/api/v1/coin/wallets', { owner_id: me.id }, token)).json();
  assert.equal(created.balance, 0);
  assert.equal(created.currency, 'MRC');

  const earned = await (await call(env, 'POST', '/api/v1/coin/transactions/earn', { amount: 999, reference: 'Reward' }, token)).json();
  assert.equal(earned.balance, 500);
  assert.equal(earned.daily_reward, 500);
  assert.equal(earned.claimed_today, true);
  assert.ok(earned.last_claim_at);
  const allTx = await (await call(env, 'GET', '/api/v1/coin/transactions', null, token)).json();
  assert.ok(Array.isArray(allTx) && allTx.length >= 1);
  assert.equal(allTx[0].type, 'EARN');
  const duplicate = await call(env, 'POST', '/api/v1/coin/transactions/earn', { amount: 10 }, token);
  assert.equal(duplicate.status, 429);

  const status = await (await call(env, 'GET', '/api/v1/payments/psp/status', null, token)).json();
  assert.equal(status.enabled, false);
  assert.deepEqual(status.methods, ['card', 'vodafone_cash', 'instapay']);
  const intent = await (await call(env, 'POST', '/api/v1/payments/psp/paymob/intent', {
    org_id: me.id, amount_egp: 100, method: 'card',
  }, token)).json();
  assert.equal(intent.configured, false);
  assert.ok(intent.order_id);
  const history = await (await call(env, 'GET', `/api/v1/payments/${me.id}/history`, null, token)).json();
  assert.equal(history.length, 1);
  const myPayments = await (await call(env, 'GET', '/api/v1/payments', null, token)).json();
  assert.equal(myPayments.length, 1);
  assert.equal(history[0].status, 'PENDING');

  const plans = await (await call(env, 'GET', '/api/v1/pro/plans', null, token)).json();
  assert.equal(plans.plans.length, 2);
  const sub = await (await call(env, 'POST', '/api/v1/pro/subscribe', { plan: 'monthly' }, token)).json();
  assert.ok(sub.subscription);
  assert.equal(sub.subscription.plan, 'monthly');
  const wallet = await (await call(env, 'GET', `/api/v1/coin/wallets/${me.id}`, null, token)).json();
  assert.equal(wallet.balance, 0);
  const pro = await (await call(env, 'GET', '/api/v1/pro/me', null, token)).json();
  assert.equal(pro.active, true);
});

test('coin transfers debit the sender and credit the recipient', async () => {
  const env = mkEnv();
  env.DAILY_REWARD_MRC = '500';
  const a = await signup(env, 'sender@example.com', 'Sender One');
  const b = await signup(env, 'receiver@example.com', 'Receiver Two');
  const am = await (await call(env, 'GET', '/api/v1/users/me', null, a)).json();
  const bm = await (await call(env, 'GET', '/api/v1/users/me', null, b)).json();
  await call(env, 'POST', '/api/v1/coin/wallets', { owner_id: am.id }, a);
  await call(env, 'POST', '/api/v1/coin/wallets', { owner_id: bm.id }, b);
  const earned = await (await call(env, 'POST', '/api/v1/coin/transactions/earn', { amount: 200 }, a)).json();
  assert.equal(earned.balance, 500);
  const sent = await (await call(env, 'POST', '/api/v1/coin/transactions/transfer', {
    counterparty_id: Number(bm.id), amount: 50,
  }, a)).json();
  assert.equal(sent.balance, 450);
  const receiver = await (await call(env, 'GET', `/api/v1/coin/wallets/${bm.id}`, null, b)).json();
  assert.equal(receiver.balance, 50);
  const txs = await (await call(env, 'GET', `/api/v1/coin/transactions/${bm.id}`, null, b)).json();
  assert.equal(txs[0].type, 'TRANSFER_IN');
  assert.equal(txs[0].amount, 50);
  const tooMuch = await call(env, 'POST', '/api/v1/coin/transactions/transfer', {
    counterparty_id: Number(bm.id), amount: 1000,
  }, a);
  assert.equal(tooMuch.status, 400);
});

test('government inquiries can be submitted and managed by the recipient', async () => {
  const env = mkEnv();
  const citizen = await signup(env, 'citizen-inquiry@example.com', 'Citizen Inquiry');
  const office = await signup(env, 'office-inquiry@example.com', 'Office Inquiry');
  const om = await (await call(env, 'GET', '/api/v1/users/me', null, office)).json();
  const created = await call(env, 'POST', '/api/v1/inquiries', {
    org_id: Number(om.id), department: 'Water Department', type: 'document',
    subject: 'Water quality report', message: 'Please share the latest water quality report for our village.',
  }, citizen);
  assert.equal(created.status, 201);
  const inquiry = await created.json();
  assert.equal(inquiry.status, 'OPEN');
  assert.equal(inquiry.department, 'Water Department');
  const mine = await (await call(env, 'GET', '/api/v1/inquiries', null, citizen)).json();
  assert.equal(mine.length, 1);
  const inbox = await (await call(env, 'GET', '/api/v1/inquiries', null, office)).json();
  assert.equal(inbox.length, 1);
  const updated = await (await call(env, 'PATCH', `/api/v1/inquiries/${inquiry.id}`, { status: 'RESOLVED' }, office)).json();
  assert.equal(updated.status, 'RESOLVED');
  const forbidden = await call(env, 'PATCH', `/api/v1/inquiries/${inquiry.id}`, { status: 'CLOSED' }, citizen);
  assert.equal(forbidden.status, 403);
});
test('ads manager funds campaigns with coins, serves non-spammy feed ads and exposes admin metrics', async () => {
  const env = mkEnv();
  env.DAILY_REWARD_MRC = '500';
  const advertiser = await signup(env, 'ads-owner@example.com', 'Advertiser One');
  const viewer = await signup(env, 'ads-viewer@example.com', 'Ad Viewer');
  const ownerMe = await (await call(env, 'GET', '/api/v1/users/me', null, advertiser)).json();
  await call(env, 'POST', '/api/v1/coin/wallets', { owner_id: ownerMe.id }, advertiser);
  await call(env, 'POST', '/api/v1/coin/transactions/earn', { amount: 500 }, advertiser);

  const created = await call(env, 'POST', '/api/v1/ads/campaigns', {
    name: 'Clean water awareness', objective: 'awareness', placement: 'feed',
    budget_coins: 100, targeting: { roles: ['STUDENT'] },
  }, advertiser);
  assert.equal(created.status, 201);
  const campaign = await created.json();
  assert.equal(campaign.status, 'DRAFT');
  assert.equal(campaign.funded_coins, 0);
  const legacyCampaigns = await (await call(env, 'GET', '/api/v1/campaigns', null, advertiser)).json();
  assert.equal(legacyCampaigns.length, 1);
  assert.equal(legacyCampaigns[0].id, campaign.id);

  const creative = await call(env, 'POST', `/api/v1/ads/campaigns/${campaign.id}/creatives`, {
    title: 'Every drop counts', body: 'Support clean water projects in Upper Egypt.',
    media_type: 'image', media_url: 'https://example.com/water.jpg',
    cta_label: 'Learn more', cta_url: 'https://example.com/water',
  }, advertiser);
  assert.equal(creative.status, 201);

  const activated = await (await call(env, 'PATCH', `/api/v1/ads/campaigns/${campaign.id}/status`, {
    status: 'ACTIVE',
  }, advertiser)).json();
  assert.equal(activated.status, 'ACTIVE');
  assert.equal(activated.funded_coins, 100);
  const fundedWallet = await (await call(env, 'GET', `/api/v1/coin/wallets/${ownerMe.id}`, null, advertiser)).json();
  assert.equal(fundedWallet.balance, 400);

  const feed = await (await call(env, 'GET', '/api/v1/ads/feed?placement=feed&limit=3', null, viewer)).json();
  assert.equal(feed.length, 1);
  assert.equal(feed[0].id, campaign.id);
  assert.equal(feed[0].creative.title, 'Every drop counts');
  const ownFeed = await (await call(env, 'GET', '/api/v1/ads/feed?placement=feed&limit=3', null, advertiser)).json();
  assert.equal(ownFeed.length, 0);

  const impression = await call(env, 'POST', `/api/v1/ads/campaigns/${campaign.id}/events`, {
    type: 'impression', creative_id: feed[0].creative.id,
  }, viewer);
  assert.equal(impression.status, 200);
  const click = await (await call(env, 'POST', `/api/v1/ads/campaigns/${campaign.id}/events`, {
    type: 'click', creative_id: feed[0].creative.id,
  }, viewer)).json();
  assert.equal(click.cost_coins, 2);
  assert.equal(click.remaining_coins, 97.8);
  const repeated = await call(env, 'POST', `/api/v1/ads/campaigns/${campaign.id}/events`, {
    type: 'impression', creative_id: feed[0].creative.id,
  }, viewer);
  assert.equal(repeated.status, 429);

  const stats = await (await call(env, 'GET', `/api/v1/ads/campaigns/${campaign.id}/stats`, null, advertiser)).json();
  assert.equal(stats.campaign.impressions, 1);
  assert.equal(stats.campaign.clicks, 1);
  assert.equal(stats.series.length, 1);

  const completed = await (await call(env, 'PATCH', `/api/v1/ads/campaigns/${campaign.id}/status`, {
    status: 'COMPLETED',
  }, advertiser)).json();
  assert.equal(completed.status, 'COMPLETED');
  const refundedWallet = await (await call(env, 'GET', `/api/v1/coin/wallets/${ownerMe.id}`, null, advertiser)).json();
  assert.equal(refundedWallet.balance, 497.8);

  const admin = await signup(env, 'ceo@example.com', 'Ads Admin');
  const adminStats = await (await call(env, 'GET', '/api/v1/admin/stats', null, admin)).json();
  assert.ok(adminStats.totals.campaigns_total >= 1);
  assert.ok(adminStats.totals.ad_impressions >= 1);
  assert.ok(adminStats.totals.ad_clicks >= 1);
  const adminAds = await (await call(env, 'GET', '/api/v1/admin/ads', null, admin)).json();
  assert.equal(adminAds.length, 1);
  assert.equal(adminAds[0].owner_name, 'Advertiser One');
});

test('live interactions, presence metrics and GPS capture stay in sync', async () => {
  const env = mkEnv();
  const author = await signup(env, 'live-author@example.com', 'Live Author');
  const reader = await signup(env, 'live-reader@example.com', 'Live Reader');
  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'Live counter test post for the community.',
    kind: 'UPDATE',
  }, author)).json();

  await call(env, 'POST', `/api/v1/posts/${post.id}/like`, null, reader);
  await call(env, 'POST', `/api/v1/posts/${post.id}/comment`, { text: 'Watching this live.' }, reader);
  const live = await (await call(env, 'GET',
    `/api/v1/live/interactions?post_ids=${post.id}`, null, reader)).json();
  assert.equal(live.posts.length, 1);
  assert.equal(live.posts[0].likes, 1);
  assert.equal(live.posts[0].comments, 1);
  assert.equal(live.posts[0].liked_by_me, true);
  assert.ok(live.posts[0].latest_comment_id);

  const gps = await call(env, 'POST', '/api/v1/gps/records', {
    latitude: 33.5138, longitude: 36.2765, accuracy: 8,
  }, reader);
  assert.equal(gps.status, 201);
  const saved = await gps.json();
  assert.equal(saved.latitude, 33.5138);
  const records = await (await call(env, 'GET', '/api/v1/gps/records', null, reader)).json();
  assert.equal(records.length, 1);

  const admin = await signup(env, 'ceo@example.com', 'The CEO');
  const stats = await (await call(env, 'GET', '/api/v1/admin/stats', null, admin)).json();
  assert.ok(stats.totals.active_users_24h >= 2);
});

async function hmacFor(obj, secret) {
  const fields = [
    obj.amount_cents, obj.created_at, obj.currency, obj.error_occured,
    obj.has_parent_transaction, obj.id, obj.integration_id, obj.is_3d_secure,
    obj.is_auth, obj.is_capture, obj.is_refunded, obj.is_standalone_payment,
    obj.is_voided, obj.order.id, obj.owner, obj.pending,
    obj.source_data && obj.source_data.pan, obj.source_data && obj.source_data.sub_type,
    obj.source_data && obj.source_data.type, obj.success,
  ];
  const message = fields.map((v) => v == null ? '' : String(v)).join('');
  const key = await webcrypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const sig = await webcrypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

test('paymob webhook verifies HMAC, credits once and reverses refunds', async () => {
  const env = mkEnv({ PAYMOB_HMAC_SECRET: 'wh-secret' });
  const token = await signup(env, 'payer-webhook@example.com', 'Payer Webhook');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const now = new Date().toISOString();
  env.DB.raw.prepare(`INSERT INTO payments (user_id,org_id,amount_egp,currency,method,status,paymob_order_id,purpose,metadata_json,created_at,updated_at)
    VALUES (?,?,'100','EGP','card','PENDING','ord-1','topup','{"credited":false}',?,?)`).run(me.id, String(me.id), now, now);
  const baseObj = {
    amount_cents: 10000, created_at: now, currency: 'EGP', error_occured: false,
    has_parent_transaction: false, id: 5001, integration_id: 101,
    is_3d_secure: false, is_auth: false, is_capture: false, is_refunded: false,
    is_standalone_payment: true, is_voided: false, order: { id: 'ord-1' },
    owner: 501, pending: false, source_data: { pan: '****', sub_type: 'Visa', type: 'card' },
    success: true,
  };
  const ok = await call(env, 'POST', '/api/v1/payments/paymob/webhook',
    { obj: baseObj, hmac: await hmacFor(baseObj, 'wh-secret') });
  assert.equal(ok.status, 200);
  const wallet = await (await call(env, 'GET', `/api/v1/coin/wallets/${me.id}`, null, token)).json();
  assert.equal(wallet.balance, 1000);
  const txs = await (await call(env, 'GET', `/api/v1/coin/transactions/${me.id}`, null, token)).json();
  assert.ok(txs.some((t) => t.type === 'TOPUP' && t.amount === 1000));

  const replay = await call(env, 'POST', '/api/v1/payments/paymob/webhook',
    { obj: baseObj, hmac: await hmacFor(baseObj, 'wh-secret') });
  assert.equal(replay.status, 200);
  const afterReplay = await (await call(env, 'GET', `/api/v1/coin/wallets/${me.id}`, null, token)).json();
  assert.equal(afterReplay.balance, 1000);

  const forged = await call(env, 'POST', '/api/v1/payments/paymob/webhook', { obj: baseObj, hmac: 'beef' });
  assert.equal(forged.status, 401);

  const status = await (await call(env, 'GET', `/api/v1/payments/1/status`, null, token)).json();
  assert.equal(status.status, 'SUCCESS');
  assert.equal(status.payment_key, undefined);

  const refundObj = { ...baseObj, is_refunded: true, success: false };
  const refunded = await call(env, 'POST', '/api/v1/payments/paymob/webhook',
    { obj: refundObj, hmac: await hmacFor(refundObj, 'wh-secret') });
  assert.equal(refunded.status, 200);
  const afterRefund = await (await call(env, 'GET', `/api/v1/coin/wallets/${me.id}`, null, token)).json();
  assert.equal(afterRefund.balance, 0);
  const reversed = await (await call(env, 'GET', `/api/v1/coin/transactions/${me.id}`, null, token)).json();
  assert.ok(reversed.some((t) => t.type === 'REVERSE' && t.amount === 1000));
});

test('paymob rejects mismatched amounts and uses server prices for pro', async () => {
  const env = mkEnv({ PAYMOB_HMAC_SECRET: 'wh-secret' });
  const token = await signup(env, 'payer-mismatch@example.com', 'Payer Mismatch');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const now = new Date().toISOString();
  env.DB.raw.prepare(`INSERT INTO payments (user_id,org_id,amount_egp,currency,method,status,paymob_order_id,purpose,metadata_json,created_at,updated_at)
    VALUES (?,?,'100','EGP','card','PENDING','ord-2','topup','{"credited":false}',?,?)`).run(me.id, String(me.id), now, now);
  const mismatch = {
    amount_cents: 9999, created_at: now, currency: 'EGP', error_occured: false,
    has_parent_transaction: false, id: 5002, integration_id: 101, is_3d_secure: false,
    is_auth: false, is_capture: false, is_refunded: false, is_standalone_payment: true,
    is_voided: false, order: { id: 'ord-2' }, owner: 501, pending: false,
    source_data: { pan: '****', sub_type: 'Visa', type: 'card' }, success: true,
  };
  const res = await call(env, 'POST', '/api/v1/payments/paymob/webhook',
    { obj: mismatch, hmac: await hmacFor(mismatch, 'wh-secret') });
  assert.equal(res.status, 400);

  const intent = await (await call(env, 'POST', '/api/v1/payments/psp/paymob/intent', {
    purpose: 'pro', plan: 'monthly', method: 'card', amount_egp: 1,
  }, token)).json();
  assert.equal(intent.configured, false);
  assert.equal(intent.payment.amount_egp, 50);

  const convert = await call(env, 'POST', '/api/v1/coin/exchange/convert', { amount: 10 }, token);
  assert.equal(convert.status, 400);
});

test('pro payments cannot be replayed and wallet subscribe is atomic', async () => {
  const env = mkEnv({ PAYMOB_HMAC_SECRET: 'wh-secret' });
  const token = await signup(env, 'payer-pro@example.com', 'Payer Pro');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const now = new Date().toISOString();
  env.DB.raw.prepare(`INSERT INTO payments (user_id,org_id,amount_egp,currency,method,status,paymob_order_id,purpose,metadata_json,created_at,updated_at)
    VALUES (?,?,'50','EGP','card','PENDING','ord-3','pro','{"credited":false,"consumed":false,"plan":"monthly"}',?,?)`)
    .run(me.id, String(me.id), now, now);
  const obj = {
    amount_cents: 5000, created_at: now, currency: 'EGP', error_occured: false,
    has_parent_transaction: false, id: 5003, integration_id: 101, is_3d_secure: false,
    is_auth: false, is_capture: false, is_refunded: false, is_standalone_payment: true,
    is_voided: false, order: { id: 'ord-3' }, owner: 501, pending: false,
    source_data: { pan: '****', sub_type: 'Visa', type: 'card' }, success: true,
  };
  const ok = await call(env, 'POST', '/api/v1/payments/paymob/webhook',
    { obj, hmac: await hmacFor(obj, 'wh-secret') });
  assert.equal(ok.status, 200);
  const pro = await (await call(env, 'GET', '/api/v1/pro/me', null, token)).json();
  assert.equal(pro.active, true);
  assert.equal(pro.subscription.plan, 'monthly');
  const reuse = await call(env, 'POST', '/api/v1/pro/subscribe', { plan: 'monthly', payment_id: 1 }, token);
  assert.equal(reuse.status, 409);
});

test('verification hardening: evidence ownership, retract and verdict sync', async () => {
  const env = mkEnv();
  const token = await signup(env, 'verify-hard@example.com', 'Verify Hard');
  const admin = await signup(env, 'ceo@example.com', 'The CEO');

  const badUrl = await call(env, 'POST', '/api/v1/evidence', { title: 'Bad evidence', url: 'javascript:alert(1)' }, token);
  assert.equal(badUrl.status, 400);

  const foreign = await call(env, 'POST', '/api/v1/evidence', { title: 'Foreign', submission_id: 999 }, token);
  assert.equal(foreign.status, 404);

  const sub = await (await call(env, 'POST', '/api/v1/submissions', {
    title: 'Pumps verified', claim: 'Pumps work.',
    evidence_url: 'https://example.org/pumps.jpg', evidence_kind: 'PHOTO',
  }, token)).json();
  assert.ok(sub.evidence_id);

  const rebind = await call(env, 'POST', '/api/v1/submissions', {
    title: 'Second claim', claim: 'Reuses evidence.', evidence_id: Number(sub.evidence_id),
  }, token);
  assert.equal(rebind.status, 409);

  const pipeline = await (await call(env, 'POST', `/api/v1/submissions/${sub.id}/pipeline`, null, token)).json();
  assert.equal(pipeline.status, 'AI_REVIEW');

  const verdict = await (await call(env, 'POST', `/api/v1/admin/submissions/${sub.id}/verdict`,
    { status: 'VERIFIED' }, admin)).json();
  assert.equal(verdict.status, 'VERIFIED');
  assert.ok(verdict.confidence >= 80);

  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const mine = await (await call(env, 'GET', `/api/v1/submissions/users/${me.id}`, null, token)).json();
  assert.equal(mine[0].status, 'VERIFIED');
  const tracked = await (await call(env, 'GET', `/api/v1/verification/pipelines/evidence/${sub.evidence_id}`, null, token)).json();
  assert.equal(tracked.pipeline.status, 'VERIFIED');
  assert.equal(tracked.pipeline.stage, 3);
  const passport = await (await call(env, 'GET', `/api/v1/users/${me.id}/passport`, null, token)).json();
  assert.equal(passport.verified_claims, 1);

  const second = await (await call(env, 'POST', '/api/v1/submissions', {
    title: 'Retractable claim', claim: 'Pending review.',
  }, token)).json();
  const retract = await call(env, 'DELETE', `/api/v1/submissions/${second.id}`, null, token);
  assert.equal(retract.status, 200);
  const gone = await call(env, 'DELETE', `/api/v1/submissions/${sub.id}`, null, token);
  assert.equal(gone.status, 409);
});

test('task ownership rules: owners create and verify, assignees submit', async () => {
  const env = mkEnv();
  const owner = await signup(env, 'task-owner@example.com', 'Task Owner');
  const member = await signup(env, 'task-member@example.com', 'Task Member');
  const memberId = (await (await call(env, 'GET', '/api/v1/users/me', null, member)).json()).id;

  const program = await (await call(env, 'POST', '/api/v1/programs', {
    title: 'Task Rules Program', sdg: 4,
  }, owner)).json();
  await call(env, 'POST', `/api/v1/programs/${program.id}/enroll`, null, member);

  const denied = await call(env, 'POST', `/api/v1/programs/${program.id}/tasks`,
    { title: 'Member-made task' }, member);
  assert.equal(denied.status, 403);

  const task = await (await call(env, 'POST', `/api/v1/programs/${program.id}/tasks`, {
    title: 'Assigned reading task', assignee_id: Number(memberId),
  }, owner)).json();
  assert.ok(task.author_id);

  const verifiedDenied = await call(env, 'POST', `/api/v1/tasks/${task.id}/status`, { status: 'VERIFIED' }, member);
  assert.equal(verifiedDenied.status, 403);
  const submitted = await (await call(env, 'POST', `/api/v1/tasks/${task.id}/status`, { status: 'SUBMITTED' }, member)).json();
  assert.equal(submitted.status, 'SUBMITTED');
  const single = await (await call(env, 'GET', `/api/v1/tasks/${task.id}`, null, owner)).json();
  assert.equal(single.id, task.id);
  const verified = await (await call(env, 'POST', `/api/v1/tasks/${task.id}/status`, { status: 'VERIFIED' }, owner)).json();
  assert.equal(verified.status, 'VERIFIED');

  const left = await (await call(env, 'DELETE', `/api/v1/programs/${program.id}/enroll`, null, member)).json();
  assert.equal(left.enrolled_by_me, false);
  const ownerLeave = await call(env, 'DELETE', `/api/v1/programs/${program.id}/enroll`, null, owner);
  assert.equal(ownerLeave.status, 409);
});

test('course and project leave routes work', async () => {
  const env = mkEnv();
  const teacher = await signup(env, 'course-teacher@example.com', 'Course Teacher');
  const student = await signup(env, 'course-student@example.com', 'Course Student');
  const course = await (await call(env, 'POST', '/api/v1/courses', {
    title: 'Water Systems 101', description: 'Basics.', sdg: 6, lessons: 5, duration_min: 60,
  }, teacher)).json();
  const enrolled = await (await call(env, 'POST', `/api/v1/courses/${course.id}/enroll`, null, student)).json();
  assert.equal(enrolled.enrolled_count, 1);
  const left = await (await call(env, 'DELETE', `/api/v1/courses/${course.id}/enroll`, null, student)).json();
  assert.equal(left.enrolled, false);

  const project = await (await call(env, 'POST', '/api/v1/projects', {
    title: 'Filters project', goal: 1000, sdg: 6,
  }, teacher)).json();
  assert.equal(project.joined, true);
  const join = await (await call(env, 'POST', `/api/v1/projects/${project.id}/join`, null, student)).json();
  assert.equal(join.joined, true);
  const quit = await (await call(env, 'DELETE', `/api/v1/projects/${project.id}/join`, null, student)).json();
  assert.equal(quit.joined, false);
  const ownerQuit = await call(env, 'DELETE', `/api/v1/projects/${project.id}/join`, null, teacher);
  assert.equal(ownerQuit.status, 409);
});

test('security & feed hardening: empty secret, oversized body, POST-only enroll, relative media URLs and empty following feed', async () => {
  // Empty SESSION_SECRET must fail closed (500) rather than signing with an empty HMAC key
  const noSecretEnv = mkEnv({ SESSION_SECRET: '' });
  const failReg = await call(noSecretEnv, 'POST', '/api/v1/users/register', {
    email: 'nosecret@example.com', full_name: 'No Secret', password: 'correct-horse9', role: 'STUDENT',
  });
  assert.equal(failReg.status, 500);

  const env = mkEnv();
  const alice = await signup(env, 'alice-hard@example.com', 'Alice Hardening');
  const bob = await signup(env, 'bob-hard@example.com', 'Bob Stranger');

  // Stranger posts globally, Alice follows nobody -> Alice's following feed must be empty
  await call(env, 'POST', '/api/v1/posts', {
    text: 'Stranger global post that should not leak into following feed.',
    media: [{ url: '/media/posts/sample.jpg', type: 'IMAGE' }],
  }, bob);
  const emptyFollowing = await (await call(env, 'GET', '/api/v1/posts?mode=following', null, alice)).json();
  assert.equal(emptyFollowing.length, 0);

  // Relative /media/... URL is normalized to an absolute HTTPS URL
  const latest = await (await call(env, 'GET', '/api/v1/posts?mode=latest', null, alice)).json();
  assert.equal(latest.length, 1);
  assert.equal(latest[0].media[0].url, 'https://masareen.com/media/posts/sample.jpg');

  // GET /api/v1/programs/:id/enroll must be rejected (state mutation requires POST)
  const program = await (await call(env, 'POST', '/api/v1/programs', { title: 'Strict Enroll', sdg: 4 }, alice)).json();
  const getEnroll = await call(env, 'GET', `/api/v1/programs/${program.id}/enroll`, null, bob);
  assert.equal(getEnroll.status, 404);

  // Oversized JSON body (>64 KB) must be rejected with 413
  const huge = await handle(new Request('https://masareen.test/api/v1/posts', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer ' + alice },
    body: JSON.stringify({ text: 'x'.repeat(70000) }),
  }), env, {});
  assert.equal(huge.status, 413);
});

test('admin operations cover AI, moderation, exports, behavior and Live TV', async () => {
  const env = mkEnv({ OPENAI_API_KEY: 'test-key' });
  const author = await signup(env, 'ops-author@example.com', 'Ops Author');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const me = await (await call(env, 'GET', '/api/v1/users/me', null, author)).json();

  const blocked = await call(env, 'POST', '/api/v1/posts', {
    text: 'kill all muslims now',
  }, author);
  assert.equal(blocked.status, 400);
  assert.match(JSON.stringify(await blocked.json()), /Hate speech|moderation/i);

  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'Clean water research update from the field.',
  }, author)).json();
  await call(env, 'POST', '/api/v1/analytics/events', {
    events: [
      { type: 'feed_impression', target_type: 'post', target_id: post.id },
      { type: 'post_dwell', target_type: 'post', target_id: post.id, duration_ms: 4200 },
    ],
  }, author);
  env.DB.raw.prepare("UPDATE posts SET moderation_status='REVIEW' WHERE id=?")
    .run(Number(post.id));

  const aiStatus = await (await call(env, 'GET', '/api/v1/admin/ai/status', null, admin)).json();
  assert.equal(aiStatus.ai_provider, 'openai');
  assert.ok(Array.isArray(aiStatus.embedding));

  const backfill = await (await call(env, 'POST', '/api/v1/admin/ai/backfill',
    { post_ids: [post.id] }, admin)).json();
  assert.equal(backfill.updated, 1);

  const moderation = await (await call(env, 'GET',
    '/api/v1/admin/moderation?status=REVIEW', null, admin)).json();
  assert.ok(moderation.posts.some((p) => p.id === post.id));
  const approve = await call(env, 'POST',
    `/api/v1/admin/posts/${post.id}/moderate`, { status: 'APPROVED' }, admin);
  assert.equal(approve.status, 200);
  assert.equal((await approve.json()).moderation_status, 'APPROVED');

  const jobs = await (await call(env, 'GET',
    '/api/v1/admin/video-jobs', null, admin)).json();
  assert.ok(Array.isArray(jobs.jobs));
  assert.equal((await call(env, 'POST',
    '/api/v1/admin/video-jobs/does-not-exist/requeue', null, admin)).status, 404);

  const behavior = await (await call(env, 'GET',
    `/api/v1/admin/users/${me.id}/behavior?days=30`, null, admin)).json();
  assert.equal(behavior.user.id, String(me.id));
  assert.ok(behavior.summary.events >= 2);
  assert.ok(behavior.events.some((e) => e.event_type === 'post_dwell'));

  const csv = await call(env, 'GET', '/api/v1/admin/exports/users.csv', null, admin);
  assert.equal(csv.status, 200);
  assert.match(csv.headers.get('content-type'), /text\/csv/);
  assert.match(await csv.text(), /ops-author@example\.com/);

  const publicLive = await (await call(env, 'GET', '/api/v1/live/tv')).json();
  assert.equal(publicLive.enabled, false);
  const saved = await call(env, 'POST', '/api/v1/admin/settings', {
    settings: {
      live_tv_title: 'MASAREEN Test TV',
      live_tv_url: 'https://masareen.com/live/tv/index.m3u8',
      live_tv_enabled: '1',
    },
  }, admin);
  assert.equal(saved.status, 200);
  const live = await (await call(env, 'GET', '/api/v1/live/tv')).json();
  assert.equal(live.enabled, true);
  assert.equal(live.title, 'MASAREEN Test TV');
  assert.equal(live.hls_url, 'https://masareen.com/live/tv/index.m3u8');
  assert.equal((await call(env, 'POST', '/api/v1/admin/settings', {
    settings: { live_tv_enabled: '1' },
  }, author)).status, 403);
});

test('universities, research stages, entity links and event funding connect the ecosystem', async () => {
  const env = mkEnv();
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');
  const director = await signup(env, 'university@example.com', 'Cairo University');
  const student = await signup(env, 'capstone@example.com', 'Nadia Student');
  const researcher = await signup(env, 'researcher@example.com', 'Dr. Youssef Research');

  const directorMe = await (await call(env, 'GET', '/api/v1/users/me', null, director)).json();
  env.DB.raw.prepare('UPDATE users SET role=?, email_verified=1 WHERE id=?')
    .run('UNIVERSITY', Number(directorMe.id));
  env.DB.raw.prepare(`INSERT INTO institution_profiles
    (user_id,institution_type,jurisdiction,services_json,departments_json,metrics_json,transparency_score,updated_at)
    VALUES (?,'UNIVERSITY','Egypt',?,?,?,88,?)`)
    .run(Number(directorMe.id), JSON.stringify(['Research', 'Community programs']),
      JSON.stringify([{ name: 'Engineering' }]), JSON.stringify({ graduates: 4200 }), new Date().toISOString());

  const course = await (await call(env, 'POST', '/api/v1/courses', {
    title: 'Community Water Engineering', description: 'Field course for engineering students.',
  }, director)).json();
  const event = await (await call(env, 'POST', '/api/v1/events', {
    title: 'University water hackathon', description: 'Students build local water solutions.',
    starts_at: '2030-05-10T09:00:00Z', location: 'Cairo University',
    funding_goal: 500,
  }, director)).json();
  assert.equal(event.funding_goal, 500);

  const capstone = await (await call(env, 'POST', '/api/v1/projects', {
    title: 'Solar-powered campus water station', project_type: 'GRADUATION',
    institution_id: directorMe.id, academic_year: '2026', student_names: 'Nadia Student, Omar Ali',
    supervisor: 'Dr. Youssef Research', goal: 2500,
  }, student)).json();
  assert.equal(capstone.project_type, 'GRADUATION');
  assert.equal(capstone.institution_id, String(directorMe.id));
  assert.equal(capstone.verification_status, 'APPROVED');

  const institutions = await (await call(env, 'GET',
    '/api/v1/institutions?q=cairo&type=UNIVERSITY')).json();
  assert.ok(institutions.some((i) => i.id === String(directorMe.id)));
  assert.equal(institutions.find((i) => i.id === String(directorMe.id)).counts.courses, 1);
  assert.equal(institutions.find((i) => i.id === String(directorMe.id)).counts.projects, 1);

  const profile = await (await call(env, 'GET',
    `/api/v1/users/${directorMe.id}/institution`)).json();
  assert.equal(profile.institution_type, 'UNIVERSITY');
  assert.equal(profile.linked.courses.length, 1);
  assert.equal(profile.linked.events[0].funding_goal, 500);
  assert.equal(profile.linked.projects[0].title, 'Solar-powered campus water station');
  assert.equal(profile.is_following, false);
  await call(env, 'POST', `/api/v1/users/${directorMe.id}/follow`, null, student);
  const followedProfile = await (await call(env, 'GET',
    `/api/v1/users/${directorMe.id}/institution`, null, student)).json();
  assert.equal(followedProfile.is_following, true);
  assert.equal(followedProfile.followers_count, 1);

  const researcherMe = await (await call(env, 'GET', '/api/v1/users/me', null, researcher)).json();
  env.DB.raw.prepare('UPDATE users SET role=?, email_verified=1 WHERE id=?')
    .run('RESEARCHER', Number(researcherMe.id));
  const stage = await call(env, 'POST', '/api/v1/research/stages', {
    title: 'Rainwater harvesting field experiment', stage: 'FIELDWORK',
    summary: 'Measuring rooftop catchment yield across campus buildings.',
    institution_id: directorMe.id,
  }, researcher);
  assert.equal(stage.status, 201);
  const stageBody = await stage.json();
  assert.equal(stageBody.stage, 'FIELDWORK');
  assert.ok(stageBody.post_id);
  const stageList = await (await call(env, 'GET',
    `/api/v1/research/stages?institution_id=${directorMe.id}`)).json();
  assert.equal(stageList.length, 1);
  assert.equal(stageList[0].researcher_name, 'Dr. Youssef Research');

  const linked = await call(env, 'POST', '/api/v1/entity-links', {
    source_type: 'user', source_id: directorMe.id,
    links: [{ target_type: 'course', target_id: course.id, relation: 'TEACHES' }],
  }, director);
  assert.equal(linked.status, 201);
  const links = await (await call(env, 'GET',
    `/api/v1/entity-links?source_type=user&source_id=${directorMe.id}`)).json();
  assert.ok(links.some((l) => l.target_type === 'course' && l.title === 'Community Water Engineering'));
  const linkId = links.find((l) => l.target_type === 'course').id;
  assert.equal((await call(env, 'DELETE', `/api/v1/entity-links/${linkId}`, null, student)).status, 403);
  assert.equal((await call(env, 'DELETE', `/api/v1/entity-links/${linkId}`, null, director)).status, 200);
  assert.equal((await call(env, 'POST', '/api/v1/entity-links', {
    source_type: 'user', source_id: directorMe.id,
    links: [{ target_type: 'event', target_id: event.id }],
  }, student)).status, 403);

  await fundWallet(env, student, 100);
  const funded = await call(env, 'POST', `/api/v1/events/${event.id}/fund`, { amount: 25 }, student);
  assert.equal(funded.status, 200);
  assert.equal((await funded.json()).event.funding_raised, 25);
  const wallet = await (await call(env, 'GET', '/api/v1/wallet', null, student)).json();
  assert.equal(wallet.balance, 75);
  assert.equal((await call(env, 'POST', `/api/v1/events/${event.id}/fund`, { amount: 0 }, student)).status, 400);
  assert.equal((await call(env, 'POST', `/api/v1/events/${event.id}/fund`, { amount: 5 }, director)).status, 400);

  const individual = await signup(env, 'plain@example.com', 'Plain Member');
  env.DB.raw.prepare("UPDATE users SET role='INDIVIDUAL' WHERE email='plain@example.com'").run();
  assert.equal((await call(env, 'POST', '/api/v1/research/stages', {
    title: 'Unverified research claim',
  }, individual)).status, 403);

  assert.ok(admin);
});

test('event hubs connect hosts, exhibitors, verified proof, booths, leads and MRC rewards', async () => {
  const env = mkEnv();
  const organizer = await signup(env, 'tiye-organizer@example.com', 'TIYE Organizer');
  const host = await signup(env, 'acu-host@example.com', 'ACU Host');
  const exhibitor = await signup(env, 'booth-exhibitor@example.com', 'Al-Sultan Exhibitor');
  const visitor = await signup(env, 'remote-buyer@example.com', 'Remote Buyer');
  const organizerMe = await fundWallet(env, organizer, 100);
  const hostMe = await fundWallet(env, host, 100);
  const exhibitorMe = await fundWallet(env, exhibitor, 100);
  const visitorMe = await fundWallet(env, visitor, 100);

  const created = await call(env, 'POST', '/api/v1/events', {
    title: 'ACV 2026 Commercial Vehicle Show',
    description: 'Egypt�s commercial transport exhibition with permanent digital continuity.',
    starts_at: '2030-10-12T09:00:00Z', ends_at: '2030-10-14T18:00:00Z',
    location: 'Cairo International Convention Centre', event_type: 'EXPO',
    source_url: 'https://tiyesolutions.com/events-conferences/', funding_goal: 500,
    cover_url: 'https://tiyesolutions.com/wp-content/uploads/2025/10/725319237_1018083840587345_6334555748974539303_n-1024x681.jpg',
  }, organizer);
  assert.equal(created.status, 201);
  const event = await created.json();
  assert.equal(event.event_type, 'EXPO');
  assert.equal(event.source_url, 'https://tiyesolutions.com/events-conferences/');

  const hostInvite = await call(env, 'POST', `/api/v1/events/${event.id}/participants`, {
    user_id: hostMe.id, role: 'HOST', role_title: 'Official host university',
    contribution: 'Hosts the conference and verifies activities.',
  }, organizer);
  assert.equal(hostInvite.status, 201);
  const hostParticipant = await hostInvite.json();
  assert.equal(hostParticipant.status, 'INVITED');
  assert.equal((await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${hostParticipant.id}/confirm`, null, host)).status, 200);

  const exhibitorInvite = await (await call(env, 'POST',
    `/api/v1/events/${event.id}/participants`, {
      user_id: exhibitorMe.id, role: 'EXHIBITOR', role_title: 'Commercial vehicles',
      contribution: 'Interactive fleet demo booth.',
    }, organizer)).json();
  await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${exhibitorInvite.id}/confirm`, null, exhibitor);

  const organizerRole = await (await call(env, 'POST',
    `/api/v1/events/${event.id}/participants`, {
      user_id: organizerMe.id, role: 'ORGANIZER', role_title: 'Digital campaign partner',
      contribution: 'Organized and marketed the exhibition.',
    }, organizer)).json();
  assert.equal(organizerRole.status, 'CONFIRMED');
  await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${organizerRole.id}/evidence`, {
      contribution: 'Full digital campaign, exhibitor onboarding and verified lead reporting.',
      evidence: ['https://tiyesolutions.com/events-conferences/'],
    }, organizer);

  const verdict = await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${organizerRole.id}/verdict`, {
      status: 'VERIFIED', note: 'Host reviewed the campaign evidence.',
    }, host);
  assert.equal(verdict.status, 200);

  const hostWallet = await (await call(env, 'GET', '/api/v1/wallet', null, host)).json();
  const organizerWallet = await (await call(env, 'GET', '/api/v1/wallet', null, organizer)).json();
  assert.equal(hostWallet.balance, 150);
  assert.equal(organizerWallet.balance, 150);

  const media = await call(env, 'POST', `/api/v1/events/${event.id}/media`, {
    type: 'PODCAST', title: 'ACV podcast: the 365-day exhibition',
    url: 'https://tiyesolutions.com/events-conferences/',
    thumbnail_url: 'https://tiyesolutions.com/wp-content/uploads/2025/10/avc-1.webp',
  }, host);
  assert.equal(media.status, 201);

  const boothRes = await call(env, 'POST', `/api/v1/events/${event.id}/booths`, {
    title: 'Al-Sultan Fleet Experience',
    description: 'Explore commercial fleet solutions and request a quote.',
    cta_type: 'TRIAL', cta_label: 'Book a fleet trial', trial_price_mrc: 10,
    cover_url: 'https://tiyesolutions.com/wp-content/uploads/2025/10/avc-1.webp',
    products: [{ title: 'Fleet logistics package', price_note: 'Request quote' }],
  }, exhibitor);
  assert.equal(boothRes.status, 201);
  const booth = await boothRes.json();
  assert.equal(booth.active, false);
  const activated = await (await call(env, 'POST',
    `/api/v1/booths/${booth.id}/activate`, null, exhibitor)).json();
  assert.equal(activated.active, true);
  const exhibitorAfterActivation = await (await call(env, 'GET', '/api/v1/wallet', null, exhibitor)).json();
  assert.equal(exhibitorAfterActivation.balance, 75);

  await call(env, 'GET', `/api/v1/booths/${booth.id}`, null, visitor);
  const lead = await call(env, 'POST', `/api/v1/booths/${booth.id}/leads`, {
    type: 'TRIAL', message: 'We need 20 fleet vehicles in Luxor.',
  }, visitor);
  assert.equal(lead.status, 201);
  const leadBody = await lead.json();
  assert.equal(leadBody.charged, 10);
  assert.equal(leadBody.reward_mrc, 2);

  const leads = await (await call(env, 'GET',
    `/api/v1/booths/${booth.id}/leads`, null, exhibitor)).json();
  assert.equal(leads.length, 1);
  assert.equal((await call(env, 'GET',
    `/api/v1/booths/${booth.id}/leads`, null, visitor)).status, 403);
  assert.equal((await call(env, 'PATCH',
    `/api/v1/booths/${booth.id}/leads/${leads[0].id}/status`, { status: 'QUALIFIED' },
    exhibitor)).status, 200);

  await call(env, 'POST', `/api/v1/events/${event.id}/join`, null, visitor);
  assert.equal((await call(env, 'POST',
    `/api/v1/events/${event.id}/ratings`, { rating: 5, review: 'The digital booth worked.' },
    visitor)).status, 200);
  const attendance = await (await call(env, 'POST',
    `/api/v1/events/${event.id}/attendance`, null, visitor)).json();
  assert.equal(attendance.reward_mrc, 5);
  const visitorWallet = await (await call(env, 'GET', '/api/v1/wallet', null, visitor)).json();
  assert.equal(visitorWallet.balance, 97);
  const repeat = await (await call(env, 'POST',
    `/api/v1/events/${event.id}/attendance`, null, visitor)).json();
  assert.equal(repeat.reward_mrc, 0);

  const detail = await (await call(env, 'GET',
    `/api/v1/events/${event.id}`, null, visitor)).json();
  assert.equal(detail.activity_verified, true);
  assert.equal(detail.participants.length, 3);
  assert.equal(detail.media.length, 1);
  assert.equal(detail.booths.length, 1);
  assert.equal(detail.booths[0].leads_count, 1);
  assert.equal(detail.ratings.length, 1);
  assert.equal(detail.rating_avg, 5);
  assert.equal(detail.organizer_reputation.verified_events, 1);
  assert.equal(detail.host.name, 'ACU Host');

  const dashboard = await call(env, 'GET',
    `/api/v1/events/${event.id}/dashboard`, null, host);
  assert.equal(dashboard.status, 200);
  const dashboardBody = await dashboard.json();
  assert.equal(dashboardBody.stats.pending_verifications, 0);
  assert.equal(dashboardBody.stats.active_booths, 1);
  assert.equal(dashboardBody.stats.leads, 1);
  assert.ok(dashboardBody.stats.reward_total >= 107);
  assert.equal((await call(env, 'GET',
    `/api/v1/events/${event.id}/dashboard`, null, visitor)).status, 403);

  const managed = await (await call(env, 'GET', '/api/v1/events/managed', null, organizer)).json();
  assert.ok(managed.events.some((e) => e.id === event.id));
  assert.equal(managed.reputation.verified_events, 1);
  assert.equal(managed.reputation.clients, 2);
  const reputation = await (await call(env, 'GET',
    `/api/v1/events/organizers/${organizerMe.id}`)).json();
  assert.equal(reputation.verified_events, 1);
  assert.equal(reputation.rating_avg, 5);
  assert.ok(reputation.rank >= 1);
});

test('TIYE x ACU demo seed signs in and exposes connected event hubs', async () => {
  const env = mkEnv();
  env.DB.raw.exec(readFileSync(new URL('../migrations/028-tiye-acu-demo-seed.sql', import.meta.url), 'utf8'));

  const login = await call(env, 'POST', '/api/v1/auth/login', {
    email: 'tiyesolutions@masareen.com', password: 'MasareenDemo2026!',
  });
  assert.equal(login.status, 200);
  const session = await login.json();
  const tiye = session.access_token;
  assert.equal(session.user.name, 'TIYE Solutions');

  const list = await (await call(env, 'GET', '/api/v1/events?include_past=1')).json();
  assert.equal(list.length, 8);
  assert.ok(list.some((e) => e.title.includes('Commercial Vehicle Show') && e.title.includes('2026')));
  const acv = list.find((e) => e.title.includes('Commercial Vehicle Show') && e.title.includes('2025'));
  const detail = await (await call(env, 'GET', `/api/v1/events/${acv.id}`)).json();
  assert.equal(detail.activity_verified, true);
  assert.ok(detail.participants.length >= 7);
  assert.ok(detail.booths.length >= 4);
  assert.ok(detail.media.length >= 2);
  assert.ok(detail.ratings.length >= 3);
  assert.ok(detail.organizer_reputation.verified_events >= 3);
  const booth = detail.booths.find((b) => b.title === 'Al-Sultan Fleet Experience');
  assert.ok(booth);
  const leads = await (await call(env, 'GET', `/api/v1/booths/${booth.id}/leads`, null, tiye)).json();
  assert.equal(leads.length, 1);

  const managed = await (await call(env, 'GET', '/api/v1/events/managed', null, tiye)).json();
  assert.equal(managed.events.length, 8);
  assert.equal(managed.summary.verified_events, 7);
  assert.ok(managed.summary.leads >= 4);
  const dashboard = await (await call(env, 'GET', `/api/v1/events/${acv.id}/dashboard`, null, tiye)).json();
  assert.equal(dashboard.stats.active_booths, 4);
  assert.equal(dashboard.stats.pending_verifications, 0);

  const acu = env.DB.raw.prepare("SELECT id FROM users WHERE email='acu@masareen.com'").get();
  const profile = await (await call(env, 'GET', `/api/v1/users/${acu.id}/institution`)).json();
  assert.equal(profile.institution_type, 'UNIVERSITY');
  assert.ok(profile.linked.events.some((e) => e.title.includes('Knowledge to Impact')));
  assert.ok(profile.linked.projects.length >= 3);
  assert.ok(profile.linked.research_stages.length >= 1);
  assert.ok(profile.reputation.verified_events >= 1);

  const kti = list.find((e) => e.title.includes('Knowledge to Impact'));
  const ktiDetail = await (await call(env, 'GET', `/api/v1/events/${kti.id}`)).json();
  assert.ok(ktiDetail.booths.some((b) => b.title.includes('TIYE Academy')));
  assert.ok(ktiDetail.media.some((m) => m.type === 'PODCAST'));
  assert.ok(ktiDetail.program && ktiDetail.program.title.includes('Knowledge to Impact'));
  assert.ok(ktiDetail.projects.length >= 3);
  assert.ok(ktiDetail.research_stages.length >= 1);
  assert.ok(ktiDetail.opportunities.length >= 2);
  assert.ok(ktiDetail.participants.some((p) => p.role === 'STUDENT'));
  assert.ok(ktiDetail.participants.some((p) => p.role === 'HOST' && p.user_id === String(acu.id)));
});

test('podcast and VOD entities are linked, playable and shareable', async () => {
  const env = mkEnv();
  env.DB.raw.exec(readFileSync(new URL('../migrations/028-tiye-acu-demo-seed.sql', import.meta.url), 'utf8'));
  const login = await (await call(env, 'POST', '/api/v1/auth/login', {
    email: 'tiyesolutions@masareen.com', password: 'MasareenDemo2026!',
  })).json();
  const tiye = login.access_token;

  const shows = await (await call(env, 'GET', '/api/v1/podcasts')).json();
  assert.equal(shows.length, 2);
  const ktiShow = shows.find((s) => s.title === 'Knowledge to Impact');
  assert.equal(ktiShow.verified, true);
  const show = await (await call(env, 'GET', `/api/v1/podcasts/${ktiShow.id}`)).json();
  assert.equal(show.episodes.length, 3);
  assert.ok(show.episodes.every((e) => e.audio_url.startsWith('https://')));
  assert.ok(show.episodes.some((e) => e.event_title?.includes('Knowledge to Impact')));

  const vod = await (await call(env, 'GET', '/api/v1/vod')).json();
  assert.equal(vod.length, 4);
  const acvVod = vod.find((v) => v.title.includes('ACV 2025'));
  assert.ok(acvVod && acvVod.verified);
  const played = await (await call(env, 'GET', `/api/v1/vod/${acvVod.id}`)).json();
  assert.equal(played.views, acvVod.views + 1);
  assert.ok(played.video_url || played.hls_url);

  const kti = (await (await call(env, 'GET', '/api/v1/events?include_past=1')).json())
    .find((e) => e.title.includes('Knowledge to Impact'));
  const detail = await (await call(env, 'GET', `/api/v1/events/${kti.id}`)).json();
  assert.ok(detail.podcast_episodes.length >= 1);
  assert.ok(detail.vod_videos.length >= 1);

  const feed = await (await call(env, 'GET', '/api/v1/posts?mode=latest&limit=50')).json();
  const verifiedPost = feed.find((p) => p.text.includes('ACV 2025'));
  assert.ok(verifiedPost);
  assert.equal(verifiedPost.verified_content, true);
  assert.equal((await call(env, 'POST', `/api/v1/posts/${verifiedPost.id}/share`, null, tiye)).status, 200);
  const draft = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'An unverified draft that can still be shared inside the platform.',
  }, tiye)).json();
  const draftShare = await call(env, 'POST', `/api/v1/posts/${draft.id}/share`, null, tiye);
  assert.equal(draftShare.status, 200);
  const draftBody = await draftShare.json();
  assert.equal(draftBody.shares, 1);
  assert.equal(draftBody.shared_by.length, 1);
});

test('non-linear ISA, GPS integrity, paid promotion and seeded feed rotation work', async () => {
  const env = mkEnv();
  const token = await signup(env, 'impact-author@example.com', 'Impact Author');
  await fundWallet(env, token, 1000);

  const withGps = await call(env, 'POST', '/api/v1/posts', {
    text: 'Community water and solar field work with verified outcomes.',
    kind: 'IMPACT',
    impact_metrics: {
      environmental: { water_liters: 45000, trees: 120 },
      social: { people_reached: 800, volunteer_hours: 90 },
      educational: { students_reached: 140, learning_hours: 60 },
    },
    latitude: 30.0444, longitude: 31.2357,
    location_claim: 'Cairo, Egypt',
  }, token);
  assert.equal(withGps.status, 201);
  const post = await withGps.json();
  assert.ok(post.isa_score > 0);
  assert.equal(post.geo_verified, true);
  assert.equal(post.geo_level, 2);
  assert.ok(post.impact_domains.social.score > 0);
  assert.match(post.impact_method, /ISA v2/);

  const withoutGps = await call(env, 'POST', '/api/v1/posts', {
    text: 'Impact metrics without location proof must be rejected.',
    kind: 'IMPACT',
    impact_metrics: { social: { people_reached: 100 } },
  }, token);
  assert.equal(withoutGps.status, 400);
  assert.equal((await withoutGps.json()).error, 'gps_required');

  for (let i = 0; i < 9; i++) {
    const created = await call(env, 'POST', '/api/v1/posts', {
      text: `Seed rotation story ${i}`,
      kind: 'STORY',
      latitude: 30.05, longitude: 31.24,
    }, token);
    assert.equal(created.status, 201);
  }

  const boosted = await call(env, 'POST', `/api/v1/posts/${post.id}/boost`, { amount: 50 }, token);
  assert.equal(boosted.status, 200);
  const boostBody = await boosted.json();
  assert.equal(boostBody.post.promoted, true);
  assert.equal(boostBody.amount, 50);
  assert.equal(boostBody.days, 2);
  const wallet = await (await call(env, 'GET', '/api/v1/wallet', null, token)).json();
  assert.equal(wallet.balance, 950);

  const feedA = await (await call(env, 'GET',
    '/api/v1/posts?mode=for_you&limit=10&seed=alpha', null, token)).json();
  const feedA2 = await (await call(env, 'GET',
    '/api/v1/posts?mode=for_you&limit=10&seed=alpha', null, token)).json();
  const feedB = await (await call(env, 'GET',
    '/api/v1/posts?mode=for_you&limit=10&seed=beta', null, token)).json();
  assert.deepEqual(feedA.map((p) => p.id), feedA2.map((p) => p.id));
  assert.notDeepEqual(feedA.map((p) => p.id), feedB.map((p) => p.id));
  assert.ok(feedA.slice(0, 2).some((p) => p.id === post.id));
});

test('deepfake and NSFW detection block explicit content and gate verification', async () => {
  const env = mkEnv();
  const author = await signup(env, 'ai-author@example.com', 'AI Author');
  const admin = await signup(env, 'ceo@example.com', 'Platform CEO');

  const explicit = await call(env, 'POST', '/api/v1/posts', {
    text: 'porn nude explicit sex adult video',
  }, author);
  assert.equal(explicit.status, 400);
  assert.equal((await explicit.json()).error, 'nsfw_blocked');

  const aiText = [
    'In conclusion, it is important to note that we must delve into the tapestry of this landscape.',
    'Furthermore, this pivotal and seamless framework will leverage robust solutions and foster a testament to meticulous work.',
    'Moreover, the realm of intricate systems underscores the pivotal nature of this seamless framework.',
    'In summary, it is important to note that the landscape of robust frameworks underscores a testament to meticulous execution.',
    'Furthermore, we leverage a seamless and robust framework to foster a pivotal landscape of intricate solutions.',
    'In conclusion, this meticulous and robust framework is a testament to the pivotal realm of seamless execution.',
  ].join(' ');
  const aiPost = await call(env, 'POST', '/api/v1/posts', {
    text: aiText,
    kind: 'STORY',
    media: [{ type: 'IMAGE', url: 'https://cdn.example.org/midjourney-output.png' }],
    latitude: 30.04, longitude: 31.23,
  }, author);
  assert.equal(aiPost.status, 201);
  const aiBody = await aiPost.json();
  assert.ok(['LIKELY_AI', 'SUSPICIOUS'].includes(aiBody.deepfake_verdict));
  assert.equal(aiBody.moderation_status, 'REVIEW');

  const program = await (await call(env, 'POST', '/api/v1/programs', {
    title: 'Deepfake-safe field programme', description: 'Evidence programme.',
  }, author)).json();
  const evidenceRes = await call(env, 'POST', '/api/v1/evidence', {
    title: 'Field distribution proof',
    description: 'Distributed 50 pumps to five villages; list and photos attached.',
    kind: 'PHOTO',
    target_type: 'PROGRAM', target_id: program.id,
    fields: { activity_date: '2026-11-10', beneficiaries: 240, outputs: '50 pumps' },
    media: [{ type: 'IMAGE', url: 'https://cdn.example.org/field-pumps.jpg' }],
    latitude: 30.05, longitude: 31.24, location_label: 'Faiyum',
    witnesses: ['Village coordinator'],
  }, author);
  assert.equal(evidenceRes.status, 201);
  const evidence = await evidenceRes.json();
  assert.equal(evidence.target_type, 'PROGRAM');
  assert.equal(evidence.target_id, String(program.id));
  assert.equal(evidence.fields.beneficiaries, '240');
  assert.equal(evidence.media.length, 1);

  const submission = await (await call(env, 'POST', '/api/v1/submissions', {
    title: 'Pump distribution claim', claim: 'Fifty pumps delivered to five villages.',
    evidence_id: Number(evidence.id),
  }, author)).json();
  assert.equal(submission.target_type, 'PROGRAM');
  const pipeline = await (await call(env, 'POST',
    `/api/v1/submissions/${submission.id}/pipeline`, null, author)).json();
  assert.ok(pipeline.steps.some((s) => s.stage === 'DEEPFAKE_NSFW_SCAN'));
  assert.ok(pipeline.deepfake_verdict);

  const scan = await (await call(env, 'POST', '/api/v1/ai/deepfake/scan', {
    text: aiText,
    urls: ['https://cdn.example.org/midjourney-output.png'],
  }, author)).json();
  assert.ok(scan.score >= 0.8);
  assert.equal(scan.provider.includes('local'), true);

  const event = await (await call(env, 'POST', '/api/v1/events', {
    title: 'Verification gate event', description: 'Event for deepfake gate.',
    starts_at: '2030-01-10T09:00:00Z', location: 'Cairo',
  }, author)).json();
  const self = await (await call(env, 'POST', `/api/v1/events/${event.id}/participants`, {
    user_id: String((await (await call(env, 'GET', '/api/v1/users/me', null, author)).json()).id),
    role: 'ORGANIZER',
  }, author)).json();
  await call(env, 'POST', `/api/v1/events/${event.id}/participants/${self.id}/evidence`, {
    contribution: aiText, evidence: ['https://cdn.example.org/midjourney-output.png'],
  }, author);
  const blockedVerdict = await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${self.id}/verdict`, { status: 'VERIFIED' }, admin);
  assert.equal(blockedVerdict.status, 409);
  const overrideVerdict = await call(env, 'POST',
    `/api/v1/events/${event.id}/participants/${self.id}/verdict`, {
      status: 'VERIFIED', override_deepfake: true,
    }, admin);
  assert.equal(overrideVerdict.status, 200);
});

test('timeline sharing, manual MRC payments and call signaling stay consistent', async () => {
  const env = mkEnv();
  const host = await signup(env, 'call-host@example.com', 'Call Host');
  const guest = await signup(env, 'call-guest@example.com', 'Call Guest');
  const admin = await signup(env, 'ceo@example.com', 'Platform Admin');
  const guestMe = await (await call(env, 'GET', '/api/v1/users/me', null, guest)).json();

  const post = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A post that can be shared inside the timeline.', kind: 'STORY',
  }, host)).json();
  const shared = await call(env, 'POST', `/api/v1/posts/${post.id}/share`, null, guest);
  assert.equal(shared.status, 200);
  const sharedBody = await shared.json();
  assert.equal(sharedBody.shares, 1);
  assert.equal(sharedBody.shared_by.length, 1);
  const repeated = await (await call(env, 'POST', `/api/v1/posts/${post.id}/share`, null, guest)).json();
  assert.equal(repeated.shares, 1);
  assert.equal(repeated.shared_by.length, 1);
  const feed = await (await call(env, 'GET', '/api/v1/posts?mode=latest&limit=50')).json();
  const feedPost = feed.find((p) => p.id === post.id);
  assert.ok(feedPost);
  assert.equal(feedPost.shared_by.length, 1);

  const buy = await call(env, 'POST', '/api/v1/wallet/requests', {
    kind: 'BUY', amount_mrc: 100, method: 'InstaPay', account_ref: 'TEST-BUY-1',
  }, guest);
  assert.equal(buy.status, 201);
  const buyBody = await buy.json();
  assert.equal(buyBody.status, 'PENDING');
  assert.equal(buyBody.amount_egp, 100);
  assert.match(buyBody.invoice_number, /^INV-\d{4}-\d{6}$/);
  const invoices = await (await call(env, 'GET', '/api/v1/invoices', null, guest)).json();
  assert.equal(invoices.find((i) => i.id === buyBody.invoice_id).status, 'PENDING');

  const adminList = await (await call(env, 'GET', '/api/v1/admin/wallet/requests', null, admin)).json();
  assert.ok(adminList.rows.some((r) => r.id === Number(buyBody.id)));
  const approved = await call(env, 'POST',
    `/api/v1/admin/wallet/requests/${buyBody.id}`, { status: 'APPROVED' }, admin);
  assert.equal(approved.status, 200);
  assert.equal((await (await call(env, 'GET', '/api/v1/wallet', null, guest)).json()).balance, 100);
  assert.equal((await call(env, 'POST',
    `/api/v1/admin/wallet/requests/${buyBody.id}`, { status: 'APPROVED' }, admin)).status, 409);

  const cashout = await (await call(env, 'POST', '/api/v1/wallet/requests', {
    kind: 'CASHOUT', amount_mrc: 40, method: 'InstaPay', account_ref: 'TEST-OUT-1',
  }, guest)).json();
  assert.equal((await (await call(env, 'GET', '/api/v1/wallet', null, guest)).json()).balance, 60);
  const rejected = await call(env, 'POST',
    `/api/v1/admin/wallet/requests/${cashout.id}`, { status: 'REJECTED', note: 'Missing reference' }, admin);
  assert.equal(rejected.status, 200);
  assert.equal((await (await call(env, 'GET', '/api/v1/wallet', null, guest)).json()).balance, 100);
  const cashoutInvoice = (await (await call(env, 'GET', '/api/v1/invoices', null, guest)).json())
    .find((i) => i.id === cashout.invoice_id);
  assert.equal(cashoutInvoice.status, 'REJECTED');

  const noEntityReward = await call(env, 'POST', '/api/v1/calls', {
    title: 'Rewarded call without an entity', reward_mrc: 10,
  }, host);
  assert.equal(noEntityReward.status, 400);
  const created = await call(env, 'POST', '/api/v1/calls', {
    title: 'Community check-in', description: 'Quick alignment call.',
  }, host);
  assert.equal(created.status, 201);
  const room = await created.json();
  const rooms = await (await call(env, 'GET', '/api/v1/calls', null, guest)).json();
  assert.ok(rooms.some((r) => r.id === room.id));
  const joined = await call(env, 'POST', `/api/v1/calls/${room.id}/join`, {}, guest);
  assert.equal(joined.status, 200);
  assert.ok((await joined.json()).ice_servers.length >= 1);
  const detail = await (await call(env, 'GET', `/api/v1/calls/${room.id}`, null, host)).json();
  assert.ok(detail.participants.some((p) => p.user_id === guestMe.id && p.left_at == null));

  const signal = await call(env, 'POST', `/api/v1/calls/${room.id}/signal`, {
    to_user: guestMe.id, type: 'offer', payload: { sdp: 'v=0', type: 'offer' },
  }, host);
  assert.equal(signal.status, 200);
  const signals = await (await call(env, 'GET', `/api/v1/calls/${room.id}/signals`, null, guest)).json();
  assert.equal(signals.length, 1);
  assert.equal(signals[0].type, 'offer');
  assert.equal((await call(env, 'POST', `/api/v1/calls/${room.id}/end`, {}, guest)).status, 403);
  assert.equal((await call(env, 'POST', `/api/v1/calls/${room.id}/end`, {}, host)).status, 200);
});

test('pulse surveys are rate limited and reward once', async () => {
  const env = mkEnv();
  const token = await signup(env, 'pulse@example.com', 'Pulse Member');
  const first = await (await call(env, 'GET',
    '/api/v1/pulse/survey?trigger=home', null, token)).json();
  assert.ok(first.survey);
  assert.equal(first.survey.reward_mrc, 5);
  assert.equal(first.survey.options.length, 4);
  assert.equal((await call(env, 'POST',
    `/api/v1/pulse/survey/${first.survey.id}/respond`,
    { answer: 'Not an option' }, token)).status, 400);
  const answered = await call(env, 'POST',
    `/api/v1/pulse/survey/${first.survey.id}/respond`,
    { answer: first.survey.options[0] }, token);
  assert.equal(answered.status, 200);
  assert.equal((await answered.json()).reward_mrc, 5);
  assert.equal((await call(env, 'POST',
    `/api/v1/pulse/survey/${first.survey.id}/respond`,
    { answer: first.survey.options[1] }, token)).status, 409);
  const wallet = await (await call(env, 'GET', '/api/v1/wallet', null, token)).json();
  assert.equal(wallet.balance, 5);
  const next = await (await call(env, 'GET',
    '/api/v1/pulse/survey?trigger=home', null, token)).json();
  assert.equal(next.survey, null);
  assert.ok(next.next_at);
});
