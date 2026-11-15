-- Non-linear multi-domain Impact Score (ISA v2) and feed stochasticity support.
ALTER TABLE posts ADD COLUMN isa_score REAL;
ALTER TABLE posts ADD COLUMN impact_domains_json TEXT;
ALTER TABLE posts ADD COLUMN impact_metrics_json TEXT;
ALTER TABLE posts ADD COLUMN geo_adjusted INTEGER NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN actor_factor REAL;
ALTER TABLE posts ADD COLUMN consistency_factor REAL;
ALTER TABLE posts ADD COLUMN location_claim TEXT;
ALTER TABLE posts ADD COLUMN boosted_until TEXT;
ALTER TABLE posts ADD COLUMN boost_weight REAL NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN paid_mrc REAL NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_posts_isa ON posts(isa_score);
CREATE INDEX IF NOT EXISTS idx_posts_moderation_created ON posts(moderation_status, created_at);

UPDATE posts SET
  impact_metrics_json='{"environmental":{"water_liters":45000,"trees":120},"social":{"people_reached":8000,"volunteer_hours":90},"economic":{"income_egp":250000,"jobs":12},"educational":{"students_reached":140,"learning_hours":60}}',
  impact_domains_json='{"environmental":{"score":82.4,"decay":0.98,"weight":0.2,"code":"ENV"},"social":{"score":76.1,"decay":1.0,"weight":0.24,"code":"SOC"},"economic":{"score":68.5,"decay":0.95,"weight":0.16,"code":"ECO"},"educational":{"score":71.2,"decay":0.99,"weight":0.16,"code":"EDU"}}',
  isa_score=880, impact_value=9.2, geo_adjusted=2, latitude=30.0444, longitude=31.2357,
  location_claim='Cairo International Convention Centre', confidence_score=88,
  confidence_label='High confidence'
WHERE text LIKE 'ACV 2025%';

UPDATE posts SET
  impact_metrics_json='{"social":{"people_reached":400,"volunteer_hours":60},"educational":{"students_reached":120,"learning_hours":80}}',
  impact_domains_json='{"social":{"score":64.0,"decay":1.0,"weight":0.24,"code":"SOC"},"educational":{"score":72.0,"decay":0.99,"weight":0.16,"code":"EDU"}}',
  isa_score=760, impact_value=7.6, geo_adjusted=2, latitude=29.9285, longitude=30.9188,
  location_claim='Ahram Canadian University, 6th of October', confidence_score=82,
  confidence_label='High confidence'
WHERE kind='RESEARCH_STAGE' AND confidence_score>=80;
