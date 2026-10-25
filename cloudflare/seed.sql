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

-- ---------- Impact delivery entities (programs, projects, tasks, marketplace) ----------
INSERT INTO programs (author_id,title,description,category,organization,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,created_at)
SELECT u.id, 'Delta Climate Resilience Program', 'A three-year program restoring mangrove buffers, modernising irrigation and training farmer cooperatives across the Nile Delta. Every activity is tied to verifiable field evidence and a public progress dashboard.', 'Climate', 'Green Delta Initiative', 13, 'ACTIVE', 1800000, 'EGP', 'Egypt', 'Kafr El-Sheikh', '2025-01-15', '2027-12-31', 25000, strftime('%Y-%m-%dT%H:%M:%SZ','now','-100 days')
FROM users u WHERE u.email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM programs WHERE title='Delta Climate Resilience Program');

INSERT INTO programs (author_id,title,description,category,organization,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,created_at)
SELECT u.id, 'National Youth Impact Fellowship', 'A national fellowship placing 5,000 young people in paid community impact placements, with mentoring, measurable tasks and a verified impact passport on completion.', 'Education', 'Ministry of Education', 8, 'ACTIVE', 3200000, 'EGP', 'Egypt', 'Cairo', '2026-02-01', '2027-06-30', 5000, strftime('%Y-%m-%dT%H:%M:%SZ','now','-80 days')
FROM users u WHERE u.email='moe@masareen.example' AND NOT EXISTS (SELECT 1 FROM programs WHERE title='National Youth Impact Fellowship');

INSERT INTO programs (author_id,title,description,category,organization,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,created_at)
SELECT u.id, 'Community Health & Water Access Program', 'Clean water filters, household health follow-up and a community reporting line across Assiut villages. Independent 30-day checks confirm continued use.', 'Health', 'Nile Care Foundation', 6, 'ACTIVE', 950000, 'EGP', 'Egypt', 'Assiut', '2025-06-01', '2026-12-31', 12000, strftime('%Y-%m-%dT%H:%M:%SZ','now','-60 days')
FROM users u WHERE u.email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM programs WHERE title='Community Health & Water Access Program');

INSERT INTO programs (author_id,title,description,category,organization,sdg,status,budget,currency,country,governorate,start_date,end_date,target_beneficiaries,created_at)
SELECT u.id, 'Campus Sustainability Network', 'A student-led network cutting single-use plastic and food waste across five universities, with open audits and monthly public scorecards.', 'Environment', 'MASAREEN Campus Network', 12, 'ACTIVE', 120000, 'EGP', 'Tunisia', 'Tunis', '2026-01-10', '2026-11-30', 2000, strftime('%Y-%m-%dT%H:%M:%SZ','now','-40 days')
FROM users u WHERE u.email='sara@masareen.example' AND NOT EXISTS (SELECT 1 FROM programs WHERE title='Campus Sustainability Network');

INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'OWNER', p.created_at FROM programs p, users u
WHERE p.title='Delta Climate Resilience Program' AND u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-20 days') FROM programs p, users u
WHERE p.title='Delta Climate Resilience Program' AND u.email IN ('sara@masareen.example','omar@masareen.example')
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'OWNER', p.created_at FROM programs p, users u
WHERE p.title='National Youth Impact Fellowship' AND u.email='moe@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-15 days') FROM programs p, users u
WHERE p.title='National Youth Impact Fellowship' AND u.email IN ('amina@masareen.example','youssef@masareen.example')
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'OWNER', p.created_at FROM programs p, users u
WHERE p.title='Community Health & Water Access Program' AND u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-10 days') FROM programs p, users u
WHERE p.title='Community Health & Water Access Program' AND u.email IN ('omar@masareen.example','layla@masareen.example')
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'OWNER', p.created_at FROM programs p, users u
WHERE p.title='Campus Sustainability Network' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);
INSERT INTO program_members (program_id,user_id,role,created_at)
SELECT p.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-8 days') FROM programs p, users u
WHERE p.title='Campus Sustainability Network' AND u.email='amina@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM program_members m WHERE m.program_id=p.id AND m.user_id=u.id);

INSERT INTO projects (program_id,author_id,title,description,category,sdg,cover,goal,raised,status,created_at)
SELECT p.id, u.id, 'Mangrove shoreline restoration', 'Planting and monitoring 20,000 mangrove seedlings along a 6 km shoreline, with 30 and 90-day survival checks published openly.', 'Climate', 13, NULL, 750000, 412000, 'ACTIVE', strftime('%Y-%m-%dT%H:%M:%SZ','now','-55 days')
FROM programs p, users u WHERE p.title='Delta Climate Resilience Program' AND u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM projects WHERE title='Mangrove shoreline restoration');

INSERT INTO projects (program_id,author_id,title,description,category,sdg,cover,goal,raised,status,created_at)
SELECT p.id, u.id, 'Village water filter rollout', 'Household filters plus 30-day usage checks and a community maintenance fund for 300 homes.', 'Water', 6, NULL, 300000, 186000, 'ACTIVE', strftime('%Y-%m-%dT%H:%M:%SZ','now','-45 days')
FROM programs p, users u WHERE p.title='Community Health & Water Access Program' AND u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM projects WHERE title='Village water filter rollout');

INSERT INTO projects (program_id,author_id,title,description,category,sdg,cover,goal,raised,status,created_at)
SELECT p.id, u.id, 'Youth career lab', 'Career coaching, employer partnerships and a 45-day tracer survey for fellowship graduates.', 'Education', 8, NULL, 500000, 240000, 'ACTIVE', strftime('%Y-%m-%dT%H:%M:%SZ','now','-35 days')
FROM programs p, users u WHERE p.title='National Youth Impact Fellowship' AND u.email='moe@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM projects WHERE title='Youth career lab');

INSERT INTO projects (program_id,author_id,title,description,category,sdg,cover,goal,raised,status,created_at)
SELECT p.id, u.id, 'Campus bottle-free campaign', 'Reusable bottle stations and cafeteria audits measuring avoided single-use bottles.', 'Environment', 12, NULL, 60000, 22000, 'ACTIVE', strftime('%Y-%m-%dT%H:%M:%SZ','now','-25 days')
FROM programs p, users u WHERE p.title='Campus Sustainability Network' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM projects WHERE title='Campus bottle-free campaign');

INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'OWNER', x.created_at FROM projects x, users u
WHERE x.title='Mangrove shoreline restoration' AND u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);
INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days') FROM projects x, users u
WHERE x.title='Mangrove shoreline restoration' AND u.email IN ('sara@masareen.example','amina@masareen.example')
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);
INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'OWNER', x.created_at FROM projects x, users u
WHERE x.title='Village water filter rollout' AND u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);
INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'MEMBER', strftime('%Y-%m-%dT%H:%M:%SZ','now','-9 days') FROM projects x, users u
WHERE x.title='Village water filter rollout' AND u.email IN ('omar@masareen.example','layla@masareen.example')
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);
INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'OWNER', x.created_at FROM projects x, users u
WHERE x.title='Youth career lab' AND u.email='moe@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);
INSERT INTO project_members (project_id,user_id,role,created_at)
SELECT x.id, u.id, 'OWNER', x.created_at FROM projects x, users u
WHERE x.title='Campus bottle-free campaign' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id=x.id AND m.user_id=u.id);

INSERT INTO tasks (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
SELECT p.id, x.id, u.id, 'Collect 30-day mangrove survival readings', 'Sample 40 marked plots, upload photo evidence and record seedling batch IDs.', 'IN_PROGRESS', '2026-11-10T09:00:00Z', 'Rosetta shoreline', 1, strftime('%Y-%m-%dT%H:%M:%SZ','now','-14 days')
FROM programs p, projects x, users u WHERE p.title='Delta Climate Resilience Program' AND x.title='Mangrove shoreline restoration'
  AND u.email='amina@masareen.example' AND NOT EXISTS (SELECT 1 FROM tasks WHERE title='Collect 30-day mangrove survival readings');

INSERT INTO tasks (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
SELECT p.id, x.id, u.id, 'Train 20 village water technicians', 'Run the maintenance training and upload attendance plus pre/post assessment results.', 'VERIFIED', '2026-10-05T09:00:00Z', 'Assiut community centre', 1, strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days')
FROM programs p, projects x, users u WHERE p.title='Community Health & Water Access Program' AND x.title='Village water filter rollout'
  AND u.email='omar@masareen.example' AND NOT EXISTS (SELECT 1 FROM tasks WHERE title='Train 20 village water technicians');

INSERT INTO tasks (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
SELECT p.id, x.id, u.id, 'Publish the 45-day fellowship tracer survey', 'Clean the survey data, publish the anonymized dataset and a short methods note.', 'OPEN', '2026-11-20T12:00:00Z', 'Online', 0, strftime('%Y-%m-%dT%H:%M:%SZ','now','-7 days')
FROM programs p, projects x, users u WHERE p.title='National Youth Impact Fellowship' AND x.title='Youth career lab'
  AND u.email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM tasks WHERE title='Publish the 45-day fellowship tracer survey');

INSERT INTO tasks (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
SELECT p.id, x.id, u.id, 'Run the campus cafeteria waste audit', 'Weigh food waste for seven days and publish the baseline dashboard.', 'SUBMITTED', '2026-10-20T08:00:00Z', 'Tunis campus', 1, strftime('%Y-%m-%dT%H:%M:%SZ','now','-11 days')
FROM programs p, projects x, users u WHERE p.title='Campus Sustainability Network' AND x.title='Campus bottle-free campaign'
  AND u.email='sara@masareen.example' AND NOT EXISTS (SELECT 1 FROM tasks WHERE title='Run the campus cafeteria waste audit');

INSERT INTO tasks (program_id,project_id,assignee_id,title,description,status,due_at,location,evidence_required,created_at)
SELECT p.id, x.id, u.id, 'Verify filter usage in 50 households', 'Visit 50 randomly selected homes and record filter condition plus a signed check.', 'OPEN', '2026-11-15T10:00:00Z', 'Assiut villages', 1, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 days')
FROM programs p, projects x, users u WHERE p.title='Community Health & Water Access Program' AND x.title='Village water filter rollout'
  AND u.email='layla@masareen.example' AND NOT EXISTS (SELECT 1 FROM tasks WHERE title='Verify filter usage in 50 households');

-- ---------- Opportunity marketplace ----------
INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'Monitoring & Evaluation Officer', 'Own the impact measurement cycle for a national water program: indicator design, field verification and donor reporting.', 'JOB', '["M&E","Data analysis","Reporting"]', 6, 'Cairo, Egypt', 0, '2026-12-15', 60, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days')
FROM users u WHERE u.email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='Monitoring & Evaluation Officer');

INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'Climate Data Internship', 'Support the Delta team with field data cleaning, survival analysis and open dashboards. Six-month paid internship.', 'INTERNSHIP', '["Python","GIS","Data cleaning"]', 13, 'Tanta, Egypt', 0, '2026-11-30', 20, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-10 days')
FROM users u WHERE u.email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='Climate Data Internship');

INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'Community Micro-Grants 2027', 'Grants of EGP 25,000 to 75,000 for youth-led climate and water projects in the Delta. Evidence plan required.', 'GRANT', '["Project design","Community outreach"]', 13, 'Nile Delta', 0, '2026-12-31', 0, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-8 days')
FROM users u WHERE u.email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='Community Micro-Grants 2027');

INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'Mangrove Volunteer Day Coordinator', 'Coordinate 120 volunteers for a planting day: transport, safety briefing, attendance and photo evidence.', 'VOLUNTEER', '["Event logistics","Volunteer management"]', 13, 'Rosetta, Egypt', 0, '2026-11-05', 0, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-6 days')
FROM users u WHERE u.email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='Mangrove Volunteer Day Coordinator');

INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'Impact Measurement Bootcamp', 'A four-week online bootcamp on indicators, baselines, evidence standards and verification-ready reporting.', 'TRAINING', '["Impact measurement","Evidence","Excel"]', 17, 'Online', 1, '2026-11-10', 0, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 days')
FROM users u WHERE u.email='youssef@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='Impact Measurement Bootcamp');

INSERT INTO opportunities (author_id,title,description,type,skills,sdg,location,is_remote,deadline,min_pms,status,created_at)
SELECT u.id, 'CSR Partnership: Clean Water Access', 'Seeking a corporate partner to co-fund 300 household filters with quarterly public impact reporting.', 'CSR', '["Corporate partnerships","ESG"]', 6, 'Cairo, Egypt', 0, '2027-01-20', 40, 'OPEN', strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 days')
FROM users u WHERE u.email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM opportunities WHERE title='CSR Partnership: Clean Water Access');

INSERT INTO opportunity_applications (opportunity_id,user_id,note,status,created_at)
SELECT o.id, u.id, 'Final-year GIS student, available for six months.', 'SUBMITTED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days')
FROM opportunities o, users u WHERE o.title='Climate Data Internship' AND u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM opportunity_applications a WHERE a.opportunity_id=o.id AND a.user_id=u.id);
INSERT INTO opportunity_applications (opportunity_id,user_id,note,status,created_at)
SELECT o.id, u.id, 'I coordinated two coastal cleanups last year.', 'SUBMITTED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day')
FROM opportunities o, users u WHERE o.title='Mangrove Volunteer Day Coordinator' AND u.email='omar@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM opportunity_applications a WHERE a.opportunity_id=o.id AND a.user_id=u.id);

-- ---------- Evidence, verified claims, pipelines and story packs ----------
INSERT INTO evidence (owner_id,submission_id,title,kind,url,sha256,latitude,longitude,captured_at,status,created_at)
SELECT u.id, NULL, 'Mangrove survival plots 30-day field photos', 'PHOTO', 'https://masareen.com/media/seed/mangrove-survival.jpg', NULL, 31.404, 30.418, '2026-09-12T08:30:00Z', 'VERIFIED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-36 days')
FROM users u WHERE u.email='greendelta@masareen.example' AND NOT EXISTS (SELECT 1 FROM evidence WHERE title='Mangrove survival plots 30-day field photos');

INSERT INTO evidence (owner_id,submission_id,title,kind,url,sha256,latitude,longitude,captured_at,status,created_at)
SELECT u.id, NULL, 'Household filter usage visit log', 'DOCUMENT', 'https://masareen.com/media/seed/filter-visits.pdf', NULL, 27.181, 31.184, '2026-10-02T11:15:00Z', 'UNDER_REVIEW', strftime('%Y-%m-%dT%H:%M:%SZ','now','-20 days')
FROM users u WHERE u.email='nilecare@masareen.example' AND NOT EXISTS (SELECT 1 FROM evidence WHERE title='Household filter usage visit log');

INSERT INTO evidence (owner_id,submission_id,title,kind,url,sha256,latitude,longitude,captured_at,status,created_at)
SELECT u.id, NULL, 'Campus waste audit week one dataset', 'DOCUMENT', 'https://masareen.com/media/seed/campus-waste-audit.csv', NULL, 36.806, 10.181, '2026-10-18T15:40:00Z', 'PENDING', strftime('%Y-%m-%dT%H:%M:%SZ','now','-6 days')
FROM users u WHERE u.email='sara@masareen.example' AND NOT EXISTS (SELECT 1 FROM evidence WHERE title='Campus waste audit week one dataset');

INSERT INTO submissions (owner_id,title,claim,program_id,task_id,evidence_id,status,confidence,reviewer_id,created_at)
SELECT u.id, 'Mangrove survival above 85% at 90 days', 'Across 40 monitored plots, 86.4% of planted seedlings survived the first 90 days.', p.id, NULL, e.id, 'VERIFIED', 92, NULL, strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days')
FROM users u, programs p, evidence e WHERE u.email='greendelta@masareen.example' AND p.title='Delta Climate Resilience Program'
  AND e.title='Mangrove survival plots 30-day field photos'
  AND NOT EXISTS (SELECT 1 FROM submissions WHERE title='Mangrove survival above 85% at 90 days');

INSERT INTO submissions (owner_id,title,claim,program_id,task_id,evidence_id,status,confidence,reviewer_id,created_at)
SELECT u.id, '300 households still using filters after 30 days', 'Independent follow-up found 87% of installed filters still in use, with a reported drop in child stomach illness.', p.id, NULL, e.id, 'HUMAN_REVIEW', 68, NULL, strftime('%Y-%m-%dT%H:%M:%SZ','now','-14 days')
FROM users u, programs p, evidence e WHERE u.email='nilecare@masareen.example' AND p.title='Community Health & Water Access Program'
  AND e.title='Household filter usage visit log'
  AND NOT EXISTS (SELECT 1 FROM submissions WHERE title='300 households still using filters after 30 days');

INSERT INTO submissions (owner_id,title,claim,program_id,task_id,evidence_id,status,confidence,reviewer_id,created_at)
SELECT u.id, 'Campus waste audit baseline completed', 'Seven-day baseline shows 38 kg of food waste per day across two cafeterias; intervention starts next week.', p.id, NULL, e.id, 'AI_REVIEW', 42, NULL, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 days')
FROM users u, programs p, evidence e WHERE u.email='sara@masareen.example' AND p.title='Campus Sustainability Network'
  AND e.title='Campus waste audit week one dataset'
  AND NOT EXISTS (SELECT 1 FROM submissions WHERE title='Campus waste audit baseline completed');

UPDATE evidence SET submission_id = (SELECT s.id FROM submissions s WHERE s.evidence_id = evidence.id LIMIT 1)
WHERE submission_id IS NULL AND EXISTS (SELECT 1 FROM submissions s WHERE s.evidence_id = evidence.id);

INSERT INTO verification_pipelines (submission_id,status,stage,confidence,steps,updated_at,created_at)
SELECT s.id, 'VERIFIED', 3, 92, '[{"stage":"SUBMITTED","status":"COMPLETE","at":"2026-09-20T09:00:00Z"},{"stage":"AI_REVIEW","status":"COMPLETE","at":"2026-09-20T09:04:00Z"},{"stage":"HUMAN_REVIEW","status":"COMPLETE","at":"2026-09-22T14:10:00Z"},{"stage":"VERIFIED","status":"COMPLETE","at":"2026-09-22T14:12:00Z"}]', strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days')
FROM submissions s WHERE s.title='Mangrove survival above 85% at 90 days'
  AND NOT EXISTS (SELECT 1 FROM verification_pipelines p WHERE p.submission_id=s.id);

INSERT INTO verification_pipelines (submission_id,status,stage,confidence,steps,updated_at,created_at)
SELECT s.id, 'HUMAN_REVIEW', 2, 68, '[{"stage":"SUBMITTED","status":"COMPLETE","at":"2026-10-02T11:20:00Z"},{"stage":"AI_REVIEW","status":"COMPLETE","at":"2026-10-02T11:24:00Z"},{"stage":"HUMAN_REVIEW","status":"IN_PROGRESS","at":"2026-10-04T09:00:00Z"}]', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','-14 days')
FROM submissions s WHERE s.title='300 households still using filters after 30 days'
  AND NOT EXISTS (SELECT 1 FROM verification_pipelines p WHERE p.submission_id=s.id);

INSERT INTO verification_pipelines (submission_id,status,stage,confidence,steps,updated_at,created_at)
SELECT s.id, 'AI_REVIEW', 1, 42, '[{"stage":"SUBMITTED","status":"COMPLETE","at":"2026-10-19T16:00:00Z"},{"stage":"AI_REVIEW","status":"IN_PROGRESS","at":"2026-10-19T16:01:00Z"}]', strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 days')
FROM submissions s WHERE s.title='Campus waste audit baseline completed'
  AND NOT EXISTS (SELECT 1 FROM verification_pipelines p WHERE p.submission_id=s.id);

INSERT INTO story_packs (submission_id,author_id,title,summary,status,created_at)
SELECT s.id, s.owner_id, 'How 20,000 mangroves are stabilising the Delta shoreline', 'A verified field story: survival rates, community monitors and what the next planting season will measure.', 'READY', strftime('%Y-%m-%dT%H:%M:%SZ','now','-28 days')
FROM submissions s WHERE s.title='Mangrove survival above 85% at 90 days'
  AND NOT EXISTS (SELECT 1 FROM story_packs WHERE title='How 20,000 mangroves are stabilising the Delta shoreline');

INSERT INTO story_packs (submission_id,author_id,title,summary,status,created_at)
SELECT s.id, s.owner_id, 'Water filters that stay in use: the 30-day check', 'Why independent follow-up matters and what 300 household visits revealed about maintenance.', 'READY', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days')
FROM submissions s WHERE s.title='300 households still using filters after 30 days'
  AND NOT EXISTS (SELECT 1 FROM story_packs WHERE title='Water filters that stay in use: the 30-day check');

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Computer Science Student & Literacy Volunteer', 'Computer science student building community-led learning circles and simple digital tools for first-generation readers.', 'Make digital inclusion practical for every neighbourhood in Cairo.', 'Digital inclusion', '["Youth literacy","Community technology","SDG 4"]', '["Community learning","Web development"]', '["Python","Flutter","Data analysis","Facilitation"]', '["Arabic","English"]', '[{"school":"Cairo University","degree":"BSc Computer Science","from":"2023","to":"2027"}]', '[{"role":"Literacy Circle Lead","org":"Neighbourhood Learning Collective","from":"2025","to":"Present"}]', '[]', '[]', '[]', '["Cairo University Student Union"]', 'Student', 'Open to internships', NULL, '{}', '["Cairo","Giza"]', 180, 'PUBLIC', 86, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='amina@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Water Systems Researcher & Impact Measurement Lead', 'Researcher translating water-system evidence into programmes that survive the first dry season and the second budget cycle.', 'Put credible measurement behind every water and agriculture investment in the region.', 'Water & agriculture', '["Water systems","Agricultural resilience","Impact measurement"]', '["Hydrology","Remote sensing","Programme evaluation"]', '["Hydrology","GIS","Research design","R","Impact evaluation"]', '["Arabic","English","French"]', '[{"school":"University of Jordan","degree":"PhD Water Resources","from":"2014","to":"2019"}]', '[{"role":"Research Fellow","org":"Cairo University","from":"2021","to":"Present"}]', '[{"name":"Impact Measurement Fundamentals","issuer":"MASAREEN","year":"2026"}]', '["Regional Water Research Award 2025"]', '[{"title":"Groundwater recharge in the lower Jordan basin","outlet":"Journal of Arid Environments","year":"2024","url":null}]', '["International Water Association"]', 'Research Fellow', 'Open to research collaborations', 'https://example.org/youssef', '{"linkedin":"https://linkedin.com/in/youssefhaddad","orcid":"0000-0002-1825-0097"}', '["Jordan","Egypt","Lebanon"]', 920, 'PUBLIC', 94, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='youssef@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Community Health & Clean Water Programmes', 'Community health foundation operating water, sanitation and primary-care programmes with village health teams in Upper Egypt.', 'Every household in our coverage area should have safe water within a ten-minute walk.', 'WASH & public health', '["WASH","Public health","Community health"]', '["Rural water systems","Health worker training"]', '["Program management","Monitoring & evaluation","Field operations","Partnership building"]', '["Arabic","English"]', '[]', '[{"role":"Programme Owner","org":"Nile Care Foundation","from":"2018","to":"Present"}]', '[]', '["Ministry of Health partner 2025"]', '[]', '["Egypt WASH Alliance"]', 'Nonprofit', 'Open to CSR partnerships', 'https://example.org/nilecare', '{}', '["Assiut","Sohag","Minya"]', 2400, 'PUBLIC', 91, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'National Education Programmes & Teacher Development', 'Official channel for national education initiatives, teacher development and school-level impact reporting.', 'Make national education progress visible, measurable and open to public scrutiny.', 'Education policy', '["Education policy","Teacher development","SDG 4"]', '["National programmes","Learning assessment"]', '["Policy design","Partnership building","Public communication"]', '["Arabic","English"]', '[]', '[]', '[]', '[]', '[]', '["Global Partnership for Education"]', 'Government', 'Open to implementation partners', NULL, '{}', '["Egypt"]', 0, 'PUBLIC', 78, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='moe@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Environmental Journalist, Eastern Mediterranean', 'Independent environmental journalist covering climate, water and coastal livelihoods across the Eastern Mediterranean.', 'Report the climate transition with evidence, context and the voices of the people living it.', 'Climate & water', '["Investigative reporting","Climate policy","Water diplomacy"]', '["Cross-border investigations","Data journalism"]', '["Investigative journalism","Data journalism","Interviewing","Photojournalism"]', '["Arabic","English","French"]', '[{"school":"American University of Beirut","degree":"MA Media Studies","from":"2015","to":"2017"}]', '[{"role":"Senior Environmental Correspondent","org":"Masareen Media Network","from":"2023","to":"Present"}]', '[]', '["Climate Journalism Fellowship 2025"]', '[{"title":"The disappearing delta","outlet":"Masareen Media","year":"2025","url":null},{"title":"Water diplomacy after the drought","outlet":"Masareen Media","year":"2024","url":null}]', '["Investigative Reporters and Editors"]', 'Journalist', 'Open to editorial collaborations', 'https://example.org/layla', '{"x":"https://x.com/laylam","linkedin":"https://linkedin.com/in/laylamansour"}', '["Lebanon","Syria","Jordan","Egypt","Cyprus"]', 1680, 'PUBLIC', 97, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='layla@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Community Volunteer Coordinator', 'Volunteer coordinator connecting neighbourhood food, recycling and mutual-aid drives with reliable logistics.', 'Make volunteering dependable for the people who show up every week.', 'Community mobilisation', '["Food security","Recycling","Volunteer mobilisation"]', '["Local logistics","Mutual aid"]', '["Community organizing","Logistics","Facilitation","Partnership building"]', '["Arabic","French","English"]', '[]', '[{"role":"Volunteer Coordinator","org":"Green Delta Initiative","from":"2024","to":"Present"}]', '[]', '["Neighbourhood Volunteer of the Year 2025"]', '[]', '["Rabat Mutual Aid Network"]', 'Volunteer', 'Open to volunteer leadership roles', NULL, '{}', '["Rabat","Sale"]', 640, 'PUBLIC', 88, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='omar@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Restoring Nile Delta Ecosystems', 'Restoration initiative working with farming communities on mangroves, soil health and climate adaptation.', 'Restore the Delta with the people who depend on it.', 'Climate adaptation', '["Mangroves","Climate adaptation","Sustainable agriculture"]', '["Community restoration","Coastal resilience"]', '["Restoration","Community engagement","Remote sensing","Monitoring & evaluation"]', '["Arabic","English"]', '[]', '[{"role":"Founding Director","org":"Green Delta Initiative","from":"2019","to":"Present"}]', '[]', '["Delta Restoration Award 2025"]', '[]', '["Egypt Climate Coalition"]', 'Nonprofit', 'Open to programme partnerships', 'https://example.org/greendelta', '{}', '["Tanta","Kafr El-Sheikh","Damietta"]', 3100, 'PUBLIC', 95, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT OR IGNORE INTO user_profiles (user_id, headline, summary, mission, beat, expertise, specializations, skills, languages, education, experience, certificates, awards, publications, memberships, employment_status, availability, website, social_links, coverage_regions, coverage_hours, visibility, completeness, updated_at)
SELECT u.id, 'Engineering Student & Girls Coding Club Lead', 'Engineering student running a girls coding club and building accessible STEM pathways for public-school students.', 'Make a first line of code normal for every girl in Tunis.', 'STEM education', '["STEM education","Gender equality","Web development"]', '["Youth mentoring","Curriculum design"]', '["JavaScript","Mentoring","Curriculum design","Public speaking"]', '["Arabic","French","English"]', '[{"school":"Tunis Engineering School","degree":"BSc Software Engineering","from":"2023","to":"2028"}]', '[{"role":"Coding Club Lead","org":"Tunis Engineering School","from":"2025","to":"Present"}]', '[]', '["National STEM Hackathon Winner 2025"]', '[]', '["Girls Who Code Tunis"]', 'Student', 'Open to mentorships', NULL, '{}', '["Tunis"]', 240, 'PUBLIC', 84, strftime('%Y-%m-%dT%H:%M:%SZ','now')
FROM users u WHERE u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.user_id=u.id);

INSERT INTO organizations (owner_id, name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT u.id, 'Green Delta Initiative', 'green-delta', 'NGO', 'Community-led mangrove and soil restoration across the Nile Delta.', 'Egypt', 'Tanta', 1, 'VERIFIED', 81, 76, strftime('%Y-%m-%dT%H:%M:%SZ','now','-400 days')
FROM users u WHERE u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM organizations WHERE name='Green Delta Initiative');

INSERT INTO organizations (owner_id, name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT u.id, 'Nile Care Foundation', 'nile-care', 'NGO', 'Clean water, sanitation and community health programmes in Upper Egypt.', 'Egypt', 'Assiut', 1, 'VERIFIED', 76, 72, strftime('%Y-%m-%dT%H:%M:%SZ','now','-500 days')
FROM users u WHERE u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM organizations WHERE name='Nile Care Foundation');

INSERT INTO organizations (owner_id, name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT u.id, 'Ministry of Education', 'ministry-of-education', 'GOVERNMENT', 'National education programmes, teacher development and learning assessment.', 'Egypt', 'Cairo', 1, 'VERIFIED', 88, 84, strftime('%Y-%m-%dT%H:%M:%SZ','now','-600 days')
FROM users u WHERE u.email='moe@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM organizations WHERE name='Ministry of Education');

INSERT INTO organizations (name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT 'Masareen Media Network', 'masareen-media', 'MEDIA', 'Independent regional newsroom covering climate, water and public accountability.', 'Lebanon', 'Beirut', 1, 'VERIFIED', 79, 74, strftime('%Y-%m-%dT%H:%M:%SZ','now','-300 days')
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE name='Masareen Media Network');

INSERT INTO organizations (name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT 'Cairo University', 'cairo-university', 'ACADEMIC', 'Public research university and partner for water, health and education research.', 'Egypt', 'Cairo', 1, 'VERIFIED', 90, 87, strftime('%Y-%m-%dT%H:%M:%SZ','now','-800 days')
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE name='Cairo University');

INSERT INTO organizations (name, slug, type, description, country, city, verified, verification_level, pms_score, oii_score, created_at)
SELECT 'Tunis Engineering School', 'tunis-engineering', 'ACADEMIC', 'Engineering school supporting student-led STEM outreach.', 'Tunisia', 'Tunis', 1, 'VERIFIED', 73, 69, strftime('%Y-%m-%dT%H:%M:%SZ','now','-700 days')
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE name='Tunis Engineering School');

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'SENIOR_CORRESPONDENT', 'Senior Environmental Correspondent', '2023-01-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-300 days')
FROM organizations o, users u WHERE o.name='Masareen Media Network' AND u.email='layla@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'RESEARCH_FELLOW', 'Research Fellow', '2021-09-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-800 days')
FROM organizations o, users u WHERE o.name='Cairo University' AND u.email='youssef@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'STUDENT', 'Computer Science Student', '2023-09-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-700 days')
FROM organizations o, users u WHERE o.name='Cairo University' AND u.email='amina@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'STUDENT', 'Software Engineering Student', '2023-09-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-700 days')
FROM organizations o, users u WHERE o.name='Tunis Engineering School' AND u.email='sara@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'VOLUNTEER_COORDINATOR', 'Community Volunteer Coordinator', '2024-03-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-400 days')
FROM organizations o, users u WHERE o.name='Green Delta Initiative' AND u.email='omar@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'OWNER', 'Founding Director', '2019-01-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-400 days')
FROM organizations o, users u WHERE o.name='Green Delta Initiative' AND u.email='greendelta@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'OWNER', 'Executive Director', '2018-01-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-500 days')
FROM organizations o, users u WHERE o.name='Nile Care Foundation' AND u.email='nilecare@masareen.example';

INSERT OR IGNORE INTO organization_members (organization_id, user_id, role, title, start_date, created_at)
SELECT o.id, u.id, 'OWNER', 'Official Account', '2020-01-01', strftime('%Y-%m-%dT%H:%M:%SZ','now','-600 days')
FROM organizations o, users u WHERE o.name='Ministry of Education' AND u.email='moe@masareen.example';

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Climate Journalism Fellowship 2025', 'Selected for a regional investigative climate reporting fellowship.', 'FELLOWSHIP', strftime('%Y-%m-%dT%H:%M:%SZ','now','-120 days')
FROM users u WHERE u.email='layla@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Climate Journalism Fellowship 2025');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Verified cross-border investigation', 'A five-part water investigation passed full evidence review.', 'VERIFICATION', strftime('%Y-%m-%dT%H:%M:%SZ','now','-60 days')
FROM users u WHERE u.email='layla@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Verified cross-border investigation');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Published 12 peer-reviewed papers', 'Water systems, recharge and agricultural resilience.', 'PUBLICATION', strftime('%Y-%m-%dT%H:%M:%SZ','now','-200 days')
FROM users u WHERE u.email='youssef@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Published 12 peer-reviewed papers');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Regional Water Research Award 2025', 'Recognised for applied groundwater research.', 'AWARD', strftime('%Y-%m-%dT%H:%M:%SZ','now','-150 days')
FROM users u WHERE u.email='youssef@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Regional Water Research Award 2025');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Literacy circle founder', 'Founded a neighbourhood literacy circle with 92 percent attendance.', 'COMMUNITY', strftime('%Y-%m-%dT%H:%M:%SZ','now','-45 days')
FROM users u WHERE u.email='amina@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Literacy circle founder');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Women Techmakers scholar', 'Selected for a regional women in technology scholarship.', 'SCHOLARSHIP', strftime('%Y-%m-%dT%H:%M:%SZ','now','-90 days')
FROM users u WHERE u.email='amina@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Women Techmakers scholar');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, '1,200 volunteers mobilised', 'Coordinated food, recycling and mutual-aid drives across Rabat.', 'COMMUNITY', strftime('%Y-%m-%dT%H:%M:%SZ','now','-75 days')
FROM users u WHERE u.email='omar@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='1,200 volunteers mobilised');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'Girls coding club founder', 'Weekly coding club reaching 60 public-school students.', 'COMMUNITY', strftime('%Y-%m-%dT%H:%M:%SZ','now','-50 days')
FROM users u WHERE u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='Girls coding club founder');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, 'National STEM Hackathon Winner 2025', 'First place for an accessible learning platform.', 'AWARD', strftime('%Y-%m-%dT%H:%M:%SZ','now','-110 days')
FROM users u WHERE u.email='sara@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='National STEM Hackathon Winner 2025');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, '20,000 mangroves planted', 'Verified survival above 85 percent at 90 days.', 'IMPACT', strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days')
FROM users u WHERE u.email='greendelta@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='20,000 mangroves planted');

INSERT INTO profile_achievements (user_id, title, detail, kind, earned_at)
SELECT u.id, '300 households with clean water', 'Independent 30-day follow-up confirmed continued filter use.', 'IMPACT', strftime('%Y-%m-%dT%H:%M:%SZ','now','-12 days')
FROM users u WHERE u.email='nilecare@masareen.example'
  AND NOT EXISTS (SELECT 1 FROM profile_achievements a WHERE a.user_id=u.id AND a.title='300 households with clean water');

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Research collaborator', 'Layla turns complex water evidence into reporting that policymakers can act on. Her field notes are unusually rigorous.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-40 days')
FROM users target, users author WHERE target.email='layla@masareen.example' AND author.email='youssef@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Mentee', 'Layla opened her newsroom to our coding club and showed the students what evidence-led storytelling looks like.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-25 days')
FROM users target, users author WHERE target.email='layla@masareen.example' AND author.email='sara@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Journalist partner', 'Dr. Haddad is the first person I call when a water story needs a number that will survive scrutiny.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-38 days')
FROM users target, users author WHERE target.email='youssef@masareen.example' AND author.email='layla@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Programme partner', 'Youssef helped our team rebuild its monitoring framework around evidence we could actually defend.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-70 days')
FROM users target, users author WHERE target.email='youssef@masareen.example' AND author.email='nilecare@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Club mentor', 'Amina is the reason our literacy circle kept going after the first difficult month. She makes learning feel possible.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-18 days')
FROM users target, users author WHERE target.email='amina@masareen.example' AND author.email='sara@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Volunteer lead', 'Amina shows up prepared, follows through and brings other students with her. That is rare.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-22 days')
FROM users target, users author WHERE target.email='amina@masareen.example' AND author.email='omar@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Programme director', 'Omar can turn a WhatsApp group into a functioning distribution network in a day. Our field teams trust him completely.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-35 days')
FROM users target, users author WHERE target.email='omar@masareen.example' AND author.email='greendelta@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Peer coordinator', 'Omar is the person who makes sure nobody is left with the hardest job alone.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-28 days')
FROM users target, users author WHERE target.email='omar@masareen.example' AND author.email='nilecare@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Programme partner', 'Green Delta measures restoration honestly, including the plots that fail. That is why we co-fund their work.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-55 days')
FROM users target, users author WHERE target.email='greendelta@masareen.example' AND author.email='nilecare@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Community partner', 'Green Delta brings farmers into the design from day one. The result is restoration that local people protect.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-48 days')
FROM users target, users author WHERE target.email='greendelta@masareen.example' AND author.email='omar@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Student mentee', 'Sara built a coding club that makes space for beginners, not just the students who already code.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-20 days')
FROM users target, users author WHERE target.email='sara@masareen.example' AND author.email='amina@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Journalist mentor', 'Sara is a natural teacher. She explains technical ideas without making anyone feel behind.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 days')
FROM users target, users author WHERE target.email='sara@masareen.example' AND author.email='layla@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Health partner', 'Nile Care shares its follow-up data even when the results are inconvenient. That transparency is the standard.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-42 days')
FROM users target, users author WHERE target.email='nilecare@masareen.example' AND author.email='greendelta@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Media partner', 'Nile Care gets journalists to the field safely and gives them the context they need to report accurately.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-33 days')
FROM users target, users author WHERE target.email='nilecare@masareen.example' AND author.email='layla@masareen.example';

INSERT OR IGNORE INTO profile_recommendations (user_id, author_id, relation, text, status, created_at)
SELECT target.id, author.id, 'Education partner', 'The Ministry team publishes programme data in a form that schools can actually use.', 'PUBLISHED', strftime('%Y-%m-%dT%H:%M:%SZ','now','-65 days')
FROM users target, users author WHERE target.email='moe@masareen.example' AND author.email='amina@masareen.example';

INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'May', 42, 18400, 860, 3, 4, 61, 54, 38, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 months') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jun', 51, 22600, 1040, 4, 5, 64, 58, 44, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 months') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jul', 58, 28300, 1310, 5, 7, 68, 63, 51, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 months') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Aug', 63, 31900, 1490, 6, 8, 71, 67, 56, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 months') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Sep', 69, 36200, 1680, 7, 9, 74, 71, 61, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 months') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Oct', 78, 42800, 2010, 9, 11, 79, 76, 68, strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='layla@masareen.example';

INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'May', 48, 12200, 540, 2, 6, 72, 68, 33, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 months') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jun', 54, 14800, 660, 3, 7, 74, 71, 37, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 months') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jul', 59, 17100, 720, 3, 8, 76, 74, 41, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 months') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Aug', 66, 19400, 830, 4, 9, 78, 78, 46, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 months') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Sep', 71, 21900, 910, 5, 10, 81, 81, 50, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 months') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Oct', 79, 25400, 1080, 6, 12, 84, 85, 57, strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='youssef@masareen.example';

INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'May', 12, 3200, 190, 0, 1, 42, 28, 8, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 months') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jun', 18, 4100, 240, 1, 1, 46, 32, 11, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 months') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jul', 24, 5200, 310, 1, 2, 51, 37, 14, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 months') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Aug', 31, 6800, 390, 2, 2, 55, 43, 18, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 months') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Sep', 38, 7900, 460, 2, 3, 59, 49, 22, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 months') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Oct', 46, 9400, 560, 3, 4, 63, 55, 27, strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='amina@masareen.example';

INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'May', 44, 15200, 720, 2, 5, 68, 61, 31, strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 months') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jun', 52, 18100, 860, 3, 6, 71, 65, 36, strftime('%Y-%m-%dT%H:%M:%SZ','now','-4 months') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Jul', 61, 22400, 1030, 4, 7, 74, 69, 43, strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 months') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Aug', 68, 26700, 1190, 5, 8, 77, 73, 49, strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 months') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Sep', 73, 30100, 1340, 6, 9, 80, 77, 54, strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 months') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO profile_analytics (user_id, bucket, impact_score, reach, engagement, verified_reports, evidence, trust_score, knowledge, influence, created_at)
SELECT u.id, 'Oct', 82, 35600, 1580, 8, 11, 84, 82, 62, strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='greendelta@masareen.example';

INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 82, 80, 71, 88, 79, 74, 77, 69, 84, 78, 79, 'GOLD', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='layla@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 91, 88, 82, 92, 86, 79, 89, 81, 90, 80, 86, 'PLATINUM', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='youssef@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 66, 58, 61, 57, 54, 78, 64, 63, 60, 58, 62, 'SILVER', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='amina@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 84, 79, 77, 72, 70, 68, 66, 74, 78, 83, 76, 'GOLD', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='nilecare@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 92, 90, 94, 89, 88, 72, 80, 84, 91, 93, 88, 'PLATINUM', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='moe@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 76, 72, 74, 64, 63, 70, 58, 66, 73, 81, 71, 'GOLD', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='omar@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 87, 84, 82, 86, 83, 71, 84, 79, 85, 88, 83, 'GOLD', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='greendelta@masareen.example';
INSERT OR IGNORE INTO pms_scores (user_id, reliability, execution_quality, leadership, documentation_quality, verification_confidence, learning_velocity, technical_skills, innovation, consistency, community_impact, total, tier, updated_at)
SELECT u.id, 62, 57, 64, 53, 50, 82, 71, 76, 59, 61, 60, 'SILVER', strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM users u WHERE u.email='sara@masareen.example';
