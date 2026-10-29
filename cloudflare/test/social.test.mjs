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

  const detail = await (await call(env, 'GET', `/api/v1/programs/${program.id}`, null, owner)).json();
  assert.equal(detail.tasks.length, 1);
  assert.equal(detail.projects.length, 1);

  const passportId = (await (await call(env, 'GET', '/api/v1/users/me', null, member)).json()).id;
  const passport = await (await call(env, 'GET', `/api/v1/users/${passportId}/passport`)).json();
  assert.equal(passport.programs, 1);
  assert.ok(passport.badges.includes('Program member'));
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
  assert.equal(pipeline.steps.length, 2);

  const tracked = await (await call(env, 'GET', `/api/v1/verification/pipelines/evidence/${submission.evidence_id}`, null, token)).json();
  assert.equal(tracked.pipeline.status, 'AI_REVIEW');

  const me = await (await call(env, 'GET', '/api/v1/users/me', null, token)).json();
  const mine = await (await call(env, 'GET', `/api/v1/submissions/users/${me.id}`, null, token)).json();
  assert.equal(mine.length, 1);
  assert.equal(mine[0].pipeline_id, pipeline.id);

  const passport = await (await call(env, 'GET', `/api/v1/users/${me.id}/passport`)).json();
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

test('media posts keep galleries, HLS metadata, location and verified ranking', async () => {
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
  }, token);
  assert.equal(created.status, 201);
  const gallery = await created.json();
  assert.equal(gallery.media_type, 'GALLERY');
  assert.equal(gallery.media.length, 2);
  assert.equal(gallery.media[1].caption, 'After the works');
  assert.equal(gallery.latitude, 33.5138);
  assert.equal(gallery.impactValue, 9.2);

  const video = await (await call(env, 'POST', '/api/v1/posts', {
    text: 'A short field clip waiting for HLS transcoding.',
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



test('FCM device tokens register, delete and trigger push notifications', async () => {
  const env = mkEnv();
  const alice = await signup(env, 'alice-fcm@example.com', 'Alice FCM');
  const bob = await signup(env, 'bob-fcm@example.com', 'Bob FCM');
  const aliceMe = await (await call(env, 'GET', '/api/v1/users/me', null, alice)).json();

  const reg = await call(env, 'POST', '/api/v1/users/me/device-token', {
    token: 'fcm_test_token_ios_123',
    platform: 'ios',
  }, alice);
  assert.equal(reg.status, 200);

  const row = await env.DB.prepare('SELECT token, platform FROM device_tokens WHERE user_id=?').bind(Number(aliceMe.id)).first();
  assert.equal(row.token, 'fcm_test_token_ios_123');
  assert.equal(row.platform, 'ios');

  const follow = await call(env, 'POST', `/api/v1/users/${aliceMe.id}/follow`, null, bob);
  assert.equal(follow.status, 200);

  const del = await call(env, 'DELETE', '/api/v1/users/me/device-token', {
    token: 'fcm_test_token_ios_123',
  }, alice);
  assert.equal(del.status, 200);

  const afterDel = await env.DB.prepare('SELECT token FROM device_tokens WHERE user_id=?').bind(Number(aliceMe.id)).first();
  assert.equal(afterDel, null);
});
