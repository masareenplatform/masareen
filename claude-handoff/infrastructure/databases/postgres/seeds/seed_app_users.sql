-- MASAREN app seed: realistic users + profiles with real avatar images.
-- Idempotent: re-running updates profiles rather than duplicating users.
-- Avatars are bundled app assets referenced as asset://avatars/pN.jpg.

\set hash '$2b$12$BmV6wXMw6.6rQ4/94O1JpeLglqRCmcKkmiAViAB8VNtd8Az8W.v5e'

-- 1) Users (password = "password")
INSERT INTO users (id, email, phone, full_name, role, status, hashed_password, email_verified, phone_verified, pms_score, certificate_count, impact_asset_count, created_at, updated_at, version)
VALUES
  (uuid_generate_v4(), 'layla@masaren.org',  '+201000000001', 'Layla Hassan',  'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 91.4, 4, 18, NOW() - INTERVAL '140 days', NOW(), 0),
  (uuid_generate_v4(), 'omar@masaren.org',   '+201000000002', 'Omar Said',     'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 84.2, 2, 11, NOW() - INTERVAL '120 days', NOW(), 0),
  (uuid_generate_v4(), 'mariam@masaren.org', '+201000000003', 'Mariam Ali',    'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 78.9, 5, 22, NOW() - INTERVAL '110 days', NOW(), 0),
  (uuid_generate_v4(), 'youssef@masaren.org','+201000000004', 'Youssef Khan',  'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 73.0, 1, 7,  NOW() - INTERVAL '98 days',  NOW(), 0),
  (uuid_generate_v4(), 'nina@masaren.org',   '+201000000005', 'Nina Petrova',  'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 95.1, 6, 31, NOW() - INTERVAL '160 days', NOW(), 0),
  (uuid_generate_v4(), 'kofi@masaren.org',   '+201000000006', 'Kofi Mensah',   'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 69.5, 3, 9,  NOW() - INTERVAL '80 days',  NOW(), 0),
  (uuid_generate_v4(), 'ana@masaren.org',    '+201000000007', 'Ana Silva',     'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 88.0, 4, 14, NOW() - INTERVAL '130 days', NOW(), 0),
  (uuid_generate_v4(), 'raj@masaren.org',    '+201000000008', 'Raj Patel',     'INDIVIDUAL', 'ACTIVE', :'hash', true, false, 81.7, 2, 13, NOW() - INTERVAL '105 days', NOW(), 0)
ON CONFLICT (email) DO NOTHING;

-- 2) Profiles (real avatar assets + bio/location)
INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Climate engineer turning rooftops into gardens.', 'asset://avatars/p2.jpg', '', 'Egypt',   'Cairo',   ARRAY['ar','en'], 1840, 210, NOW() - INTERVAL '139 days'
FROM users u WHERE u.email='layla@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Building clean-water co-ops in rural towns.', 'asset://avatars/p3.jpg', '', 'Egypt',   'Giza',    ARRAY['ar','en'], 980,  340, NOW() - INTERVAL '119 days'
FROM users u WHERE u.email='omar@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Education access activist. 22 impact assets shipped.', 'asset://avatars/p4.jpg', '', 'Egypt',   'Alexandria', ARRAY['ar','en'], 2210, 150, NOW() - INTERVAL '109 days'
FROM users u WHERE u.email='mariam@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Reforestation lead. Trees over tweets.', 'asset://avatars/p5.jpg', '', 'Egypt',   'Luxor',  ARRAY['ar','en'], 640,  120, NOW() - INTERVAL '97 days'
FROM users u WHERE u.email='youssef@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Top contributor. Impact at scale.', 'asset://avatars/p6.jpg', '', 'Bulgaria','Sofia',   ARRAY['bg','en'], 5300, 88,  NOW() - INTERVAL '159 days'
FROM users u WHERE u.email='nina@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Community solar organiser in Accra.', 'asset://avatars/p7.jpg', '', 'Ghana',   'Accra',   ARRAY['en'], 1120, 260, NOW() - INTERVAL '79 days'
FROM users u WHERE u.email='kofi@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Circular-economy designer. Less waste, more good.', 'asset://avatars/p8.jpg', '', 'Brazil',   'Sao Paulo', ARRAY['pt','en'], 1750, 190, NOW() - INTERVAL '129 days'
FROM users u WHERE u.email='ana@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'Open-data for public services.', 'asset://avatars/p9.jpg', '', 'India',    'Mumbai',  ARRAY['hi','en'], 1320, 300, NOW() - INTERVAL '104 days'
FROM users u WHERE u.email='raj@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;

-- Admin profile (use a real face too)
INSERT INTO user_profiles (id, user_id, bio, avatar_url, cover_url, country, city, languages, followers_count, following_count, created_at)
SELECT uuid_generate_v4(), u.id, 'MASAREN platform administrator.', 'asset://avatars/p1.jpg', '', 'Global', 'Remote', ARRAY['en'], 500, 50, NOW()
FROM users u WHERE u.email='admin@masaren.org'
ON CONFLICT (user_id) DO UPDATE SET avatar_url=EXCLUDED.avatar_url, bio=EXCLUDED.bio, country=EXCLUDED.country, city=EXCLUDED.city, languages=EXCLUDED.languages, followers_count=EXCLUDED.followers_count, following_count=EXCLUDED.following_count;
