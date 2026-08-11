// Clean up any unlabeled nodes created by the previous broken MERGE
MATCH (n) WHERE size(labels(n)) = 0 DETACH DELETE n;

// Link creators + SDGs by id (variables don't persist across statements)
MATCH (p:Person {id:'u-layla'}),  (a:ImpactAsset {id:'asset-1'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-1'}),(s:SDG {number:13}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-omar'}),   (a:ImpactAsset {id:'asset-2'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-2'}),(s:SDG {number:6})  MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-mariam'}), (a:ImpactAsset {id:'asset-3'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-3'}),(s:SDG {number:4})  MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-youssef'}),(a:ImpactAsset {id:'asset-4'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-4'}),(s:SDG {number:15}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-nina'}),   (a:ImpactAsset {id:'asset-5'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-5'}),(s:SDG {number:7})  MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-kofi'}),   (a:ImpactAsset {id:'asset-6'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-6'}),(s:SDG {number:7})  MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-ana'}),    (a:ImpactAsset {id:'asset-7'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-7'}),(s:SDG {number:12}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-raj'}),    (a:ImpactAsset {id:'asset-8'}) MERGE (p)-[:CREATED]->(a);
MATCH (a:ImpactAsset {id:'asset-8'}),(s:SDG {number:11}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
RETURN 'relinked' AS status;
