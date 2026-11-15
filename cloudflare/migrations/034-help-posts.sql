-- Help posts that introduce MASAREEN while people scroll the home feed.
INSERT INTO posts (author_id,text,kind,sdg,confidence_score,impact_value,impact_label,
  moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users ORDER BY id LIMIT 1),
  'Welcome to MASAREEN. Everything here follows one loop: real activity → target-linked evidence → host verification → measurable impact → discovery → opportunity. Open Help Center from the menu for the full guide and diagrams.',
  'HELP',17,96,0,'Platform guide','APPROVED','[]','local-hash','SYSTEM',
  '2026-11-15T10:00:00.000Z','2026-11-15T10:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE kind='HELP' AND text LIKE 'Welcome to MASAREEN.%');

INSERT INTO posts (author_id,text,kind,sdg,confidence_score,impact_value,impact_label,
  moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users ORDER BY id LIMIT 1),
  'How verification works: capture evidence for the exact event, programme, project, task or post it proves. Add GPS, photos, video, audio or documents. A host or scoped moderator reviews it. Explicit content is blocked; likely AI-generated evidence needs an explicit override.',
  'HELP',16,95,0,'Verification guide','APPROVED','[]','local-hash','SYSTEM',
  '2026-11-15T09:58:00.000Z','2026-11-15T09:58:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE kind='HELP' AND text LIKE 'How verification works:%');

INSERT INTO posts (author_id,text,kind,sdg,confidence_score,impact_value,impact_label,
  moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users ORDER BY id LIMIT 1),
  'Why impact is a percentage, not a like count: six domains are normalized separately, saturate with diminishing returns, decay over time and combine with GPS confidence, actor history and a consistency penalty. One repeated metric cannot buy a high score.',
  'HELP',4,94,0,'Impact guide','APPROVED','[]','local-hash','SYSTEM',
  '2026-11-15T09:56:00.000Z','2026-11-15T09:56:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE kind='HELP' AND text LIKE 'Why impact is a percentage,%');

INSERT INTO posts (author_id,text,kind,sdg,confidence_score,impact_value,impact_label,
  moderation_status,embedding_json,embedding_status,source,created_at,updated_at)
SELECT (SELECT id FROM users ORDER BY id LIMIT 1),
  'Moderators are scoped, not mini-admins. An owner can give someone permission to remove comments, remove posts, verify contributions or remove a specific event. Owners and moderators can also block harmful accounts. PDF and DOCX files open in a sanitized in-app viewer.',
  'HELP',16,93,0,'Safety guide','APPROVED','[]','local-hash','SYSTEM',
  '2026-11-15T09:54:00.000Z','2026-11-15T09:54:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM posts WHERE kind='HELP' AND text LIKE 'Moderators are scoped,%');
