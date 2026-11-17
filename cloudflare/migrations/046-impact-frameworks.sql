-- Entity-specific impact frameworks and weights.
CREATE TABLE IF NOT EXISTS impact_frameworks (
  entity_type    TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  description    TEXT,
  indicators_json TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

INSERT OR REPLACE INTO impact_frameworks
  (entity_type,title,description,indicators_json,updated_at) VALUES
  ('NEWS','News impact','Accuracy, verification and public value.',
   '[{"key":"verification","label":"Verification","weight":0.35,"source":"news_verifications","unit":"verified reviews"},{"key":"reach","label":"Reach","weight":0.20,"source":"views","unit":"views"},{"key":"engagement","label":"Engagement","weight":0.25,"source":"content_reactions/content_comments","unit":"reactions + comments"},{"key":"quality","label":"Quality","weight":0.20,"source":"news_ratings","unit":"reader ratings"}]',datetime('now')),
  ('JOURNALIST','Journalist impact','Verified reporting and trusted reach.',
   '[{"key":"verified_stories","label":"Verified stories","weight":0.35,"source":"news_articles.verification_status","unit":"stories"},{"key":"impact","label":"Story impact","weight":0.30,"source":"news_articles.impact_score","unit":"points"},{"key":"output","label":"Output","weight":0.20,"source":"news_articles","unit":"published stories"},{"key":"trust","label":"Trust","weight":0.15,"source":"verification verdicts","unit":"verified share"}]',datetime('now')),
  ('RESEARCH','Research impact','Evidence, review and uptake.',
   '[{"key":"peer_review","label":"Peer review","weight":0.35,"source":"research_reviews","unit":"review points"},{"key":"funding","label":"Funding","weight":0.25,"source":"research_funding","unit":"MRC"},{"key":"engagement","label":"Engagement","weight":0.20,"source":"content reactions/comments","unit":"signals"},{"key":"publication","label":"Publication","weight":0.20,"source":"peer_review_status","unit":"accepted stages"}]',datetime('now')),
  ('AGRICULTURE','Agricultural impact','Adoption, resilience and resource use.',
   '[{"key":"yield","label":"Yield change","weight":0.25,"source":"field evidence","unit":"%"},{"key":"water","label":"Water saved","weight":0.20,"source":"field evidence","unit":"m3"},{"key":"adoption","label":"Adoption","weight":0.20,"source":"projects/training","unit":"farmers"},{"key":"training","label":"Training","weight":0.15,"source":"courses/rooms","unit":"trained people"},{"key":"resilience","label":"Resilience","weight":0.20,"source":"verified evidence","unit":"score"}]',datetime('now')),
  ('TRAINING','Training impact','Completion, application and reach.',
   '[{"key":"completion","label":"Completion","weight":0.30,"source":"track/course progress","unit":"% completed"},{"key":"assessment","label":"Assessment","weight":0.25,"source":"assessment score","unit":"score"},{"key":"application","label":"Applied evidence","weight":0.25,"source":"evidence","unit":"verified application"},{"key":"reach","label":"Reach","weight":0.20,"source":"participants","unit":"people"}]',datetime('now')),
  ('STUDENT','Student impact','Learning, evidence and contribution.',
   '[{"key":"skills","label":"Skills","weight":0.25,"source":"pathways/courses","unit":"completion"},{"key":"evidence","label":"Evidence","weight":0.30,"source":"verified evidence","unit":"items"},{"key":"participation","label":"Participation","weight":0.20,"source":"events/projects","unit":"activities"},{"key":"opportunity","label":"Opportunity readiness","weight":0.25,"source":"applications/passport","unit":"progress"}]',datetime('now')),
  ('ORGANIZATION','Organisation impact','Delivery, transparency and ecosystem value.',
   '[{"key":"projects","label":"Verified projects","weight":0.25,"source":"projects","unit":"projects"},{"key":"beneficiaries","label":"Beneficiaries","weight":0.20,"source":"project/event metrics","unit":"people"},{"key":"evidence","label":"Evidence coverage","weight":0.20,"source":"evidence","unit":"verified items"},{"key":"funding","label":"Funding","weight":0.15,"source":"funding","unit":"MRC"},{"key":"transparency","label":"Transparency","weight":0.20,"source":"reports/profile","unit":"score"}]',datetime('now')),
  ('EVENT','Event impact','Convening, evidence and outcomes.',
   '[{"key":"attendance","label":"Attendance","weight":0.25,"source":"event attendance","unit":"people"},{"key":"evidence","label":"Evidence","weight":0.25,"source":"event evidence","unit":"verified items"},{"key":"funding","label":"Funding","weight":0.20,"source":"event funding","unit":"MRC"},{"key":"rating","label":"Experience","weight":0.15,"source":"event ratings","unit":"stars"},{"key":"follow_on","label":"Follow-on action","weight":0.15,"source":"opportunities/content","unit":"outcomes"}]',datetime('now'));