// MASAREN Knowledge Graph, Constraints & Indexes
// Run once on first startup

// Uniqueness constraints
CREATE CONSTRAINT person_id         IF NOT EXISTS FOR (p:Person)         REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT organization_id   IF NOT EXISTS FOR (o:Organization)   REQUIRE o.id IS UNIQUE;
CREATE CONSTRAINT program_id        IF NOT EXISTS FOR (p:Program)        REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT task_id           IF NOT EXISTS FOR (t:Task)           REQUIRE t.id IS UNIQUE;
CREATE CONSTRAINT evidence_id       IF NOT EXISTS FOR (e:Evidence)       REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT impact_asset_id   IF NOT EXISTS FOR (a:ImpactAsset)    REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT certificate_id    IF NOT EXISTS FOR (c:Certificate)    REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT skill_slug        IF NOT EXISTS FOR (s:Skill)          REQUIRE s.slug IS UNIQUE;
CREATE CONSTRAINT opportunity_id    IF NOT EXISTS FOR (o:Opportunity)    REQUIRE o.id IS UNIQUE;
CREATE CONSTRAINT sdg_goal          IF NOT EXISTS FOR (s:SDG)            REQUIRE s.goal IS UNIQUE;

// Full-text indexes
CREATE FULLTEXT INDEX person_search     IF NOT EXISTS FOR (p:Person)       ON EACH [p.name, p.email];
CREATE FULLTEXT INDEX org_search        IF NOT EXISTS FOR (o:Organization)  ON EACH [o.name, o.slug];
CREATE FULLTEXT INDEX opportunity_search IF NOT EXISTS FOR (o:Opportunity)  ON EACH [o.title, o.description];

// Property indexes
CREATE INDEX person_pms_idx   IF NOT EXISTS FOR (p:Person)   ON (p.pms_composite);
CREATE INDEX org_oii_idx      IF NOT EXISTS FOR (o:Organization) ON (o.oii_composite);
