-- Real TIYE profile media, galleries, event coverage and posts.
-- Images are rehosted on MASAREEN R2 from TIYE's published event photography.

UPDATE users SET
  picture='https://masareen.com/media/tiye/tiye-logo.jpg',
  cover_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE email='tiyesolutions@masareen.com';

UPDATE programs SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title LIKE 'Knowledge to Impact%';

UPDATE events SET cover_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title='Al-Ahram Commercial Vehicle Show (ACV) 2026';
UPDATE events SET cover_url='https://masareen.com/media/tiye/avc1.jpg'
WHERE title='Al-Ahram Commercial Vehicle Show (ACV) 2025';
UPDATE events SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title LIKE 'Knowledge to Impact%';
UPDATE events SET cover_url='https://masareen.com/media/tiye/turathna.jpg'
WHERE title='Turathna Exhibition 2024';
UPDATE events SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title='BiznEX Expo 2022';
UPDATE events SET cover_url='https://masareen.com/media/tiye/ers.jpg'
WHERE title='Egypt Retail Summit (ERS) 2022';
UPDATE events SET cover_url='https://masareen.com/media/tiye/twt.jpg'
WHERE title='Tanmia Wa Tatweer (TWT) 2022';
UPDATE events SET cover_url='https://masareen.com/media/tiye/sha3lna.jpg'
WHERE title='Sha3''lna Job Fair';

UPDATE event_media SET url='https://masareen.com/media/tiye/acv2026.jpg',
  thumbnail_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title='ACV 2026 - Cairo International Convention Centre';
UPDATE event_media SET url='https://masareen.com/media/tiye/avc1.jpg',
  thumbnail_url='https://masareen.com/media/tiye/avc1.jpg'
WHERE title='ACV 2026 exhibitor teaser';
UPDATE event_media SET url='https://masareen.com/media/tiye/avc1.jpg',
  thumbnail_url='https://masareen.com/media/tiye/avc1.jpg'
WHERE title='ACV 2025 show floor';
UPDATE event_media SET url='https://masareen.com/media/tiye/acv2026.jpg',
  thumbnail_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title='Podcast: what happens after the exhibition hall closes?';
UPDATE event_media SET url='https://masareen.com/media/tiye/turathna.jpg',
  thumbnail_url='https://masareen.com/media/tiye/turathna.jpg'
WHERE title='Turathna 2024 artisan booths';
UPDATE event_media SET url='https://masareen.com/media/tiye/biznex.jpg',
  thumbnail_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title='BiznEX investor floor';
UPDATE event_media SET url='https://masareen.com/media/tiye/ers.jpg',
  thumbnail_url='https://masareen.com/media/tiye/ers.jpg'
WHERE title='Egypt Retail Summit 2022';
UPDATE event_media SET url='https://masareen.com/media/tiye/twt.jpg',
  thumbnail_url='https://masareen.com/media/tiye/twt.jpg'
WHERE title='Tanmia Wa Tatweer 2022';
UPDATE event_media SET url='https://masareen.com/media/tiye/sha3lna.jpg',
  thumbnail_url='https://masareen.com/media/tiye/sha3lna.jpg'
WHERE title='Sha3''lna Job Fair';

UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title IN ('Al-Sultan Fleet Experience','MCV Transport Solutions');
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/avc1.jpg'
WHERE title='Ghabbour Distribution Fleet';
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title IN ('Raya Logistics Control Tower','TIYE Investment Continuity Desk');
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/datepalm2.jpg'
WHERE title='Siwa Heritage House';
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/turathna.jpg'
WHERE title='Handmade Egypt Export Lab';
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/ers.jpg'
WHERE title='TIYE Academy x ACU Media Lab';
UPDATE event_booths SET cover_url='https://masareen.com/media/tiye/sha3lna.jpg'
WHERE title='Shaghlna Talent Booth';

UPDATE podcast_shows SET cover_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title='TIYE Events Podcast';
UPDATE podcast_shows SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title='Knowledge to Impact';
UPDATE vod_videos SET cover_url='https://masareen.com/media/tiye/avc1.jpg'
WHERE title LIKE 'ACV 2025%';
UPDATE vod_videos SET cover_url='https://masareen.com/media/tiye/turathna.jpg'
WHERE title LIKE 'Turathna 2024%';
UPDATE vod_videos SET cover_url='https://masareen.com/media/tiye/biznex.jpg'
WHERE title LIKE 'Knowledge to Impact%';
UPDATE vod_videos SET cover_url='https://masareen.com/media/tiye/acv2026.jpg'
WHERE title LIKE 'ACV 2026%';

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'ACV 2026: TIYE and MASAREEN document the Al-Ahram Commercial Vehicles Show. A real event gallery, verified partners and a digital continuity path after the halls close.',
  'EVENT',9,'https://masareen.com/media/tiye/acv2026.jpg',
  '[{"url":"https://masareen.com/media/tiye/acv2026.jpg","type":"IMAGE","caption":"ACV 2026 opening address and exhibitor floor"},{"url":"https://masareen.com/media/tiye/avc1.jpg","type":"IMAGE","caption":"Al-Ahram Commercial Vehicles Show brand stage"}]',
  90,9.1,'High impact','APPROVED','[]','local-hash','USER','2026-11-14T09:00:00.000Z','2026-11-14T09:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'ACV 2026: TIYE and MASAREEN document%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'ACV 2025: 6,000 participants, 180,000 EGP funding goal and a verified exhibitor network. TIYE turned the show floor into a year-round opportunity graph.',
  'EVENT',9,'https://masareen.com/media/tiye/avc1.jpg',
  '[{"url":"https://masareen.com/media/tiye/avc1.jpg","type":"IMAGE","caption":"ACV show identity"},{"url":"https://masareen.com/media/tiye/acv2026.jpg","type":"IMAGE","caption":"Commercial vehicle leaders on stage"},{"url":"https://masareen.com/media/tiye/twt.jpg","type":"IMAGE","caption":"Partners and exhibitors during the show"}]',
  88,9.2,'High impact','APPROVED','[]','local-hash','USER','2025-11-23T10:00:00.000Z','2025-11-23T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'ACV 2025: 6,000 participants%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'Turathna 2024: real artisan stories, date-palm heritage and a digital identity for 20,000 visitors. TIYE connected heritage producers to export and wholesale buyers.',
  'EVENT',8,'https://masareen.com/media/tiye/turathna.jpg',
  '[{"url":"https://masareen.com/media/tiye/turathna.jpg","type":"IMAGE","caption":"Turathna artisan exhibition"},{"url":"https://masareen.com/media/tiye/datepalm.jpg","type":"IMAGE","caption":"Date palm heritage showcase"},{"url":"https://masareen.com/media/tiye/datepalm2.jpg","type":"IMAGE","caption":"Siwa producers and handmade collections"}]',
  86,8.7,'High impact','APPROVED','[]','local-hash','USER','2024-10-21T09:00:00.000Z','2024-10-21T09:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Turathna 2024: real artisan stories%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'BiznEX 2022: matching investors, founders and institutional buyers across MENA. A verified conference record with 5,000 participants and a continuing partner desk.',
  'EVENT',8,'https://masareen.com/media/tiye/biznex.jpg',
  '[{"url":"https://masareen.com/media/tiye/biznex.jpg","type":"IMAGE","caption":"BiznEX investor and founder floor"},{"url":"https://masareen.com/media/tiye/twt.jpg","type":"IMAGE","caption":"Partners during the BiznEX programme"}]',
  84,8.4,'High impact','APPROVED','[]','local-hash','USER','2022-12-04T10:00:00.000Z','2022-12-04T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'BiznEX 2022: matching investors%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'Egypt Retail Summit 2022: TIYE produced verified conference coverage for retailers, brands and institutional partners, linking the sessions to follow-up opportunities.',
  'EVENT',8,'https://masareen.com/media/tiye/ers.jpg',
  '[{"url":"https://masareen.com/media/tiye/ers.jpg","type":"IMAGE","caption":"Egypt Retail Summit audience and speakers"},{"url":"https://masareen.com/media/tiye/biznex.jpg","type":"IMAGE","caption":"Retail and investor networking floor"}]',
  82,8.2,'High impact','APPROVED','[]','local-hash','USER','2022-03-24T10:00:00.000Z','2022-03-24T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Egypt Retail Summit 2022: TIYE produced%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'Tanmia Wa Tatweer 2022: training, media coverage and partnership follow-through. TIYE documented the full learning-to-execution journey with its partners.',
  'EVENT',8,'https://masareen.com/media/tiye/twt.jpg',
  '[{"url":"https://masareen.com/media/tiye/twt.jpg","type":"IMAGE","caption":"Tanmia Wa Tatweer partners and participants"},{"url":"https://masareen.com/media/tiye/turathna.jpg","type":"IMAGE","caption":"Community and heritage programme showcase"}]',
  80,7.9,'Strong impact','APPROVED','[]','local-hash','USER','2022-04-19T10:00:00.000Z','2022-04-19T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Tanmia Wa Tatweer 2022: training%');

INSERT INTO posts (author_id,text,kind,sdg,media_url,media_json,confidence_score,impact_value,
  impact_label,moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'Sha3''lna Job Fair: from a job fair to a verified talent pathway. TIYE and ACU documented roles, interviews and follow-up opportunities for young professionals.',
  'EVENT',8,'https://masareen.com/media/tiye/sha3lna.jpg',
  '[{"url":"https://masareen.com/media/tiye/sha3lna.jpg","type":"IMAGE","caption":"Sha3''lna Job Fair floor"},{"url":"https://masareen.com/media/tiye/twt.jpg","type":"IMAGE","caption":"Hiring teams and career sessions"}]',
  81,8.0,'Strong impact','APPROVED','[]','local-hash','USER','2019-02-24T10:00:00.000Z','2019-02-24T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Sha3''lna Job Fair: from a job fair%');

INSERT INTO event_media (event_id,created_by,type,title,url,thumbnail_url,created_at)
SELECT (SELECT id FROM events WHERE title='Al-Ahram Commercial Vehicle Show (ACV) 2026'),
  (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),'IMAGE',
  'ACV 2026 - commercial vehicle leaders','https://masareen.com/media/tiye/acv2026.jpg',
  'https://masareen.com/media/tiye/acv2026.jpg','2026-11-14T09:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM event_media WHERE url='https://masareen.com/media/tiye/acv2026.jpg'
  AND event_id=(SELECT id FROM events WHERE title='Al-Ahram Commercial Vehicle Show (ACV) 2026'));

INSERT INTO event_media (event_id,created_by,type,title,url,thumbnail_url,created_at)
SELECT (SELECT id FROM events WHERE title='Turathna Exhibition 2024'),
  (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),'IMAGE',
  'Turathna 2024 - date palm heritage','https://masareen.com/media/tiye/datepalm.jpg',
  'https://masareen.com/media/tiye/datepalm.jpg','2024-10-21T09:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM event_media WHERE url='https://masareen.com/media/tiye/datepalm.jpg'
  AND event_id=(SELECT id FROM events WHERE title='Turathna Exhibition 2024'));

INSERT INTO event_media (event_id,created_by,type,title,url,thumbnail_url,created_at)
SELECT (SELECT id FROM events WHERE title='Turathna Exhibition 2024'),
  (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),'IMAGE',
  'Turathna 2024 - Siwa producers','https://masareen.com/media/tiye/datepalm2.jpg',
  'https://masareen.com/media/tiye/datepalm2.jpg','2024-10-21T09:05:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM event_media WHERE url='https://masareen.com/media/tiye/datepalm2.jpg'
  AND event_id=(SELECT id FROM events WHERE title='Turathna Exhibition 2024'));
