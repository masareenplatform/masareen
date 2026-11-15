-- Clearly labelled house ads used in the blended feed during the pilot.
INSERT INTO ad_campaigns (user_id,name,objective,placement,status,budget_coins,funded_coins,
  spent_coins,currency,start_at,end_at,targeting_json,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='tiyesolutions@masareen.com'),
  'TIYE x ACU · Knowledge to Impact','awareness','feed','ACTIVE',2000,2000,0,'MRC',
  '2026-11-15T00:00:00.000Z','2027-12-31T23:59:59.000Z','{"house":true}',
  '2026-11-15T11:00:00.000Z','2026-11-15T11:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM ad_campaigns WHERE name='TIYE x ACU · Knowledge to Impact');

INSERT INTO ad_campaigns (user_id,name,objective,placement,status,budget_coins,funded_coins,
  spent_coins,currency,start_at,end_at,targeting_json,created_at,updated_at)
SELECT (SELECT id FROM users WHERE email='acu@masareen.com'),
  'ACU · Verify your impact','traffic','feed','ACTIVE',1200,1200,0,'MRC',
  '2026-11-15T00:00:00.000Z','2027-12-31T23:59:59.000Z','{"house":true}',
  '2026-11-15T11:00:00.000Z','2026-11-15T11:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM ad_campaigns WHERE name='ACU · Verify your impact');

INSERT INTO ad_creatives (campaign_id,title,body,media_url,media_type,cta_label,cta_url,
  sort_order,created_at,updated_at)
SELECT (SELECT id FROM ad_campaigns WHERE name='TIYE x ACU · Knowledge to Impact'),
  'Knowledge to Impact','A verified ACU x TIYE programme connecting field evidence to opportunity.',
  'https://masareen.com/media/tiye/biznex.jpg','image','Open the programme',
  'https://masareen.com/events/10',0,'2026-11-15T11:00:00.000Z','2026-11-15T11:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM ad_creatives WHERE title='Knowledge to Impact');

INSERT INTO ad_creatives (campaign_id,title,body,media_url,media_type,cta_label,cta_url,
  sort_order,created_at,updated_at)
SELECT (SELECT id FROM ad_campaigns WHERE name='ACU · Verify your impact'),
  'Your impact deserves proof','Capture evidence, get it verified and turn activity into an opportunity.',
  'https://masareen.com/media/partners/acu.png','image','Verify with ACU',
  'https://masareen.com',0,'2026-11-15T11:00:00.000Z','2026-11-15T11:00:00.000Z'
WHERE NOT EXISTS (SELECT 1 FROM ad_creatives WHERE title='Your impact deserves proof');
