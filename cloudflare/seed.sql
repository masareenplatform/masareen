-- Seed content so a fresh MASAREEN database opens to a real-looking impact feed.
-- Safe to run repeatedly: users are unique by email, posts are guarded by text.

INSERT OR IGNORE INTO users (email, email_verified, name, role, country, city, interest, profile_complete, signup_method, created_at, handle, bio) VALUES
('amina@masareen.example',  0, 'Amina El-Sayed',        'STUDENT',      'Egypt',   'Cairo',    '4,5,10', 1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-60 days'), 'amina',      'Computer science student and literacy volunteer.'),
('youssef@masareen.example',0, 'Dr. Youssef Haddad',    'ACADEMIC',     'Jordan',  'Amman',    '2,4,6',  1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-90 days'), 'youssefh',   'Researcher in water systems and agricultural resilience.'),
('nilecare@masareen.example',1,'Nile Care Foundation',   'ORGANIZATION', 'Egypt',   'Assiut',   '3,6,11', 1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-120 days'),'nilecare',   'Community health and clean water programs in Upper Egypt.'),
('moe@masareen.example',    1, 'Ministry of Education',  'GOVERNMENT',   'Egypt',   'Cairo',    '4,8,17', 1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-150 days'),'moe',        'Official updates on national education programs.'),
('layla@masareen.example',  0, 'Layla Mansour',          'JOURNALIST',   'Lebanon', 'Beirut',   '12,13,14',1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-70 days'), 'laylam',     'Environmental journalist covering the Eastern Mediterranean.'),
('omar@masareen.example',   0, 'Omar Farouk',            'VOLUNTEER',    'Morocco', 'Rabat',    '1,11,16',1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-45 days'), 'omarf',      'Volunteer coordinator for neighborhood food and recycling drives.'),
('greendelta@masareen.example',1,'Green Delta Initiative','ORGANIZATION', 'Egypt',   'Tanta',    '6,13,15',1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-110 days'),'greendelta', 'Restoring Nile Delta ecosystems with local farming communities.'),
('sara@masareen.example',   0, 'Sara Nabil',             'STUDENT',      'Tunisia', 'Tunis',    '5,12,13',1, 'seed', strftime('%Y-%m-%dT%H:%M:%SZ','now','-35 days'), 'saran',      'Engineering student running a girls coding club.');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'We just finished the first month of the neighborhood literacy circle. 24 women now read their own medicine labels without help. Attendance is 92% and two participants have started tutoring others.', 'IMPACT', 4, 6.4, 'Strong impact', 72, 'Moderate confidence', '{"ratings":4,"average_stars":4.3,"method":"seed"}', 23, 4, 3, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 hours')
FROM users WHERE email='amina@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'We just finished the first month%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, '12 solar-powered water pumps are now running in three villages. 1,140 people no longer walk 40 minutes for irrigation water. Every installation has a site photo, a timestamp and a village committee signature in the evidence vault.', 'IMPACT', 6, 8.7, 'Verified high impact', 88, 'High confidence', '{"ratings":9,"average_stars":4.8,"method":"seed"}', 64, 12, 9, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 hours')
FROM users WHERE email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE '12 solar-powered water pumps%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'National reading challenge results: 310,000 students completed 20 books this term, up 41% from last year. Full school-level dataset is being published for independent review.', 'MILESTONE', 4, 9.1, 'Verified high impact', 93, 'High confidence', '{"ratings":12,"average_stars":4.9,"method":"seed"}', 120, 27, 34, strftime('%Y-%m-%dT%H:%M:%SZ','now','-9 hours')
FROM users WHERE email='moe@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'National reading challenge results%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Our new paper compares drip and furrow irrigation across 38 wheat farms. Drip cut water use by 31% with no yield loss. Preprint and anonymized dataset are linked in the comments.', 'ARTICLE', 2, 7.2, 'Strong impact', 81, 'High confidence', '{"ratings":6,"average_stars":4.4,"method":"seed"}', 41, 8, 15, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day')
FROM users WHERE email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Our new paper compares drip%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Reported from the Tyre coast this morning: 2.3 tonnes of plastic pulled out by 60 volunteers in four hours. Local municipality has agreed to a weekly collection pilot.', 'ARTICLE', 14, 6.8, 'Strong impact', 70, 'Moderate confidence', '{"ratings":3,"average_stars":4.2,"method":"seed"}', 37, 6, 11, strftime('%Y-%m-%dT%H:%M:%SZ','now','-8 hours')
FROM users WHERE email='layla@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Reported from the Tyre coast%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, '40 volunteers packed 1,200 food parcels in one afternoon for families in Rabat. Each parcel carries a QR code linking to its distribution record so donors can see where it went.', 'IMPACT', 1, 7.5, 'Strong impact', 76, 'High confidence', '{"ratings":5,"average_stars":4.5,"method":"seed"}', 52, 9, 7, strftime('%Y-%m-%dT%H:%M:%SZ','now','-18 hours')
FROM users WHERE email='omar@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE '40 volunteers packed%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, '300 households in Assiut received household water filters. Independent follow-up after 30 days found 87% still in use and a measurable drop in reported stomach illness among children.', 'IMPACT', 6, 8.2, 'Verified high impact', 85, 'High confidence', '{"ratings":7,"average_stars":4.6,"method":"seed"}', 58, 11, 8, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days')
FROM users WHERE email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE '300 households in Assiut%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Girls coding club week 6: the team shipped a small app that maps safe walking routes to school. Twelve students, four mentors, zero dropouts so far.', 'UPDATE', 5, 6.1, 'Strong impact', 64, 'Moderate confidence', '{"ratings":2,"average_stars":4.0,"method":"seed"}', 29, 5, 4, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 hours')
FROM users WHERE email='sara@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Girls coding club week 6%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, '5,000 mangrove seedlings planted along a 2 km stretch of the Delta. Survival checks at 30 and 90 days are scheduled with university partners. Coordinates and seedling batch IDs are in the vault.', 'IMPACT', 13, 8.9, 'Verified high impact', 90, 'High confidence', '{"ratings":10,"average_stars":4.7,"method":"seed"}', 76, 14, 19, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day','-4 hours')
FROM users WHERE email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE '5,000 mangrove seedlings%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, '1,200 young people completed the national vocational training track this quarter. 68% have a job interview within 45 days. Tracer survey methodology is open for review.', 'MILESTONE', 8, 8.4, 'Verified high impact', 87, 'High confidence', '{"ratings":8,"average_stars":4.6,"method":"seed"}', 93, 18, 22, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 days')
FROM users WHERE email='moe@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE '1,200 young people completed%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'New open dataset: school attendance by district, cleaned and anonymized, 2019 to 2025. Documentation includes every transformation so other researchers can reproduce the analysis.', 'ARTICLE', 4, 7.0, 'Strong impact', 79, 'High confidence', '{"ratings":4,"average_stars":4.4,"method":"seed"}', 34, 7, 26, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days','-3 hours')
FROM users WHERE email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'New open dataset: school attendance%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Our street recycling pilot now covers 180 households. Contamination dropped from 22% to 9% after two weeks of door-to-door coaching. Scaling to three more streets next month.', 'UPDATE', 11, 5.9, 'Emerging impact', 60, 'Moderate confidence', '{"ratings":2,"average_stars":3.9,"method":"seed"}', 21, 3, 2, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 hours')
FROM users WHERE email='omar@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Our street recycling pilot%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Interview: how a farmer cooperative in the Bekaa cut post-harvest losses by a third using shared cold storage. They are now negotiating directly with two supermarket chains.', 'ARTICLE', 12, 6.5, 'Strong impact', 68, 'Moderate confidence', '{"ratings":3,"average_stars":4.1,"method":"seed"}', 27, 4, 6, strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 hours')
FROM users WHERE email='layla@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Interview: how a farmer cooperative%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Campus reusable bottle campaign: 1,800 single-use bottles avoided in three weeks, measured from cafeteria sales. Small win, fully auditable.', 'UPDATE', 12, 5.2, 'Emerging impact', 55, 'Moderate confidence', '{"ratings":1,"average_stars":3.8,"method":"seed"}', 18, 2, 1, strftime('%Y-%m-%dT%H:%M:%SZ','now','-6 days')
FROM users WHERE email='sara@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Campus reusable bottle campaign%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'The mental health support line answered 940 calls last month. Average wait time is 38 seconds. We are publishing anonymized call outcome categories quarterly from now on.', 'IMPACT', 3, 7.8, 'Strong impact', 82, 'High confidence', '{"ratings":6,"average_stars":4.5,"method":"seed"}', 47, 8, 12, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 days')
FROM users WHERE email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'The mental health support line%');

INSERT INTO posts (author_id, text, kind, sdg, impact_value, impact_label, confidence_score, confidence_label, confidence_factors, like_count, comment_count, share_count, created_at)
SELECT id, 'Exam prep sessions for 60 students in my neighborhood start tonight. We need three more volunteer tutors for physics and chemistry. Reply here if you can help.', 'UPDATE', 4, 6.0, 'Emerging impact', 63, 'Moderate confidence', '{"ratings":2,"average_stars":4.0,"method":"seed"}', 14, 6, 3, strftime('%Y-%m-%dT%H:%M:%SZ','now','-45 minutes')
FROM users WHERE email='amina@masareen.example' AND NOT EXISTS (SELECT 1 FROM posts WHERE text LIKE 'Exam prep sessions for 60 students%');

-- ── Courses ────────────────────────────────────────────────────────────────
INSERT INTO courses (author_id,title,description,provider,level,sdg,lessons,duration_min,status,created_at)
SELECT id, 'Impact Measurement Fundamentals', 'Learn to design indicators, collect credible evidence and report outcomes that funders and communities trust. Includes templates for baseline surveys and verification logs.', 'MASAREEN Academy', 'Beginner', 17, 6, 95, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days')
FROM users WHERE email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM courses WHERE title='Impact Measurement Fundamentals');

INSERT INTO courses (author_id,title,description,provider,level,sdg,lessons,duration_min,status,created_at)
SELECT id, 'Community Organizing for SDG Action', 'Practical field course on mapping stakeholders, running listening sessions and turning community priorities into a measurable action plan.', 'MASAREEN Academy', 'Intermediate', 11, 5, 70, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-8 days')
FROM users WHERE email='amina@masareen.example' AND NOT EXISTS (SELECT 1 FROM courses WHERE title='Community Organizing for SDG Action');

INSERT INTO courses (author_id,title,description,provider,level,sdg,lessons,duration_min,status,created_at)
SELECT id, 'Climate Resilience in Practice', 'Adaptation planning for local teams: risk screening, nature-based options, community early warning and financing pathways.', 'Green Delta', 'Advanced', 13, 8, 140, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 days')
FROM users WHERE email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM courses WHERE title='Climate Resilience in Practice');

INSERT INTO course_enrollments (course_id,user_id,created_at)
SELECT c.id, u.id, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 days')
FROM courses c, users u WHERE c.title='Impact Measurement Fundamentals' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM course_enrollments e WHERE e.course_id=c.id AND e.user_id=u.id);

INSERT INTO course_enrollments (course_id,user_id,created_at)
SELECT c.id, u.id, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days')
FROM courses c, users u WHERE c.title='Impact Measurement Fundamentals' AND u.email='omar@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM course_enrollments e WHERE e.course_id=c.id AND e.user_id=u.id);

-- ── Events ─────────────────────────────────────────────────────────────────
INSERT INTO events (author_id,title,description,starts_at,ends_at,location,is_online,link_url,sdg,capacity,status,created_at)
SELECT id, 'Impact Verification Clinic', 'Bring one project and walk out with a verification plan. Small-group clinic with mentors from the MASAREEN review team.', strftime('%Y-%m-%dT%H:%M:%SZ','now','+7 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+7 days','+2 hours'), 'Cairo Innovation Hub', 0, NULL, 17, 40, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 days')
FROM users WHERE email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM events WHERE title='Impact Verification Clinic');

INSERT INTO events (author_id,title,description,starts_at,ends_at,location,is_online,link_url,sdg,capacity,status,created_at)
SELECT id, 'Delta Mangrove Volunteer Day', 'Join the planting team for a morning on the Delta shoreline. Transportation from the city meeting point is provided.', strftime('%Y-%m-%dT%H:%M:%SZ','now','+12 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+12 days','+5 hours'), 'Rosetta meeting point', 0, NULL, 13, 120, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days')
FROM users WHERE email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM events WHERE title='Delta Mangrove Volunteer Day');

INSERT INTO events (author_id,title,description,starts_at,ends_at,location,is_online,link_url,sdg,capacity,status,created_at)
SELECT id, 'Open Data for SDGs · Online Session', 'How to publish reproducible, anonymized datasets that communities and researchers can actually reuse.', strftime('%Y-%m-%dT%H:%M:%SZ','now','+3 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+3 days','+90 minutes'), 'Online', 1, 'https://masareen.com', 17, 500, 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day')
FROM users WHERE email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM events WHERE title='Open Data for SDGs · Online Session');

INSERT INTO event_attendees (event_id,user_id,created_at)
SELECT e.id, u.id, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day')
FROM events e, users u WHERE e.title='Open Data for SDGs · Online Session' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM event_attendees a WHERE a.event_id=e.id AND a.user_id=u.id);
