import test from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/index.js';
import { makeDb } from './d1-shim.mjs';

const mkEnv = () => ({ DB: makeDb(), SESSION_SECRET: 's3cret-s3cret', ADMIN_EMAILS: 'ceo@example.com' });

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
  return j.access_token;
}

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

