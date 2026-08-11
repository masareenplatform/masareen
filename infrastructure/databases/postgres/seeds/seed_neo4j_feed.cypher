// Persons (creators) — ids, names, avatars
MERGE (p_layla:Person {id:'u-layla'}) SET p_layla.name='Layla Hassan', p_layla.full_name='Layla Hassan', p_layla.email='layla@masaren.org', p_layla.avatar_url='asset://avatars/p2.jpg', p_layla.pms=91.4;
MERGE (p_omar:Person {id:'u-omar'}) SET p_omar.name='Omar Said', p_omar.full_name='Omar Said', p_omar.email='omar@masaren.org', p_omar.avatar_url='asset://avatars/p3.jpg', p_omar.pms=84.2;
MERGE (p_mariam:Person {id:'u-mariam'}) SET p_mariam.name='Mariam Ali', p_mariam.full_name='Mariam Ali', p_mariam.email='mariam@masaren.org', p_mariam.avatar_url='asset://avatars/p4.jpg', p_mariam.pms=78.9;
MERGE (p_youssef:Person {id:'u-youssef'}) SET p_youssef.name='Youssef Khan', p_youssef.full_name='Youssef Khan', p_youssef.email='youssef@masaren.org', p_youssef.avatar_url='asset://avatars/p5.jpg', p_youssef.pms=73.0;
MERGE (p_nina:Person {id:'u-nina'}) SET p_nina.name='Nina Petrova', p_nina.full_name='Nina Petrova', p_nina.email='nina@masaren.org', p_nina.avatar_url='asset://avatars/p6.jpg', p_nina.pms=95.1;
MERGE (p_kofi:Person {id:'u-kofi'}) SET p_kofi.name='Kofi Mensah', p_kofi.full_name='Kofi Mensah', p_kofi.email='kofi@masaren.org', p_kofi.avatar_url='asset://avatars/p7.jpg', p_kofi.pms=69.5;
MERGE (p_ana:Person {id:'u-ana'}) SET p_ana.name='Ana Silva', p_ana.full_name='Ana Silva', p_ana.email='ana@masaren.org', p_ana.avatar_url='asset://avatars/p8.jpg', p_ana.pms=88.0;
MERGE (p_raj:Person {id:'u-raj'}) SET p_raj.name='Raj Patel', p_raj.full_name='Raj Patel', p_raj.email='raj@masaren.org', p_raj.avatar_url='asset://avatars/p9.jpg', p_raj.pms=81.7;

// SDGs
MERGE (s1:SDG {number:1}) MERGE (s2:SDG {number:2}) MERGE (s3:SDG {number:3}) MERGE (s4:SDG {number:4}) MERGE (s6:SDG {number:6}) MERGE (s7:SDG {number:7}) MERGE (s11:SDG {number:11}) MERGE (s12:SDG {number:12}) MERGE (s13:SDG {number:13}) MERGE (s14:SDG {number:14}) MERGE (s15:SDG {number:15});

// Impact assets
MERGE (a1:ImpactAsset {id:'asset-1'}) SET a1.storage_url='', a1.media_type='IMAGE', a1.confidence_score=0.94, a1.created_at=datetime() - duration('P0D');
MERGE (a2:ImpactAsset {id:'asset-2'}) SET a2.storage_url='', a2.media_type='IMAGE', a2.confidence_score=0.88, a2.created_at=datetime() - duration('P1D');
MERGE (a3:ImpactAsset {id:'asset-3'}) SET a3.storage_url='', a3.media_type='IMAGE', a3.confidence_score=0.91, a3.created_at=datetime() - duration('P2D');
MERGE (a4:ImpactAsset {id:'asset-4'}) SET a4.storage_url='', a4.media_type='IMAGE', a4.confidence_score=0.83, a4.created_at=datetime() - duration('P1D');
MERGE (a5:ImpactAsset {id:'asset-5'}) SET a5.storage_url='', a5.media_type='IMAGE', a5.confidence_score=0.97, a5.created_at=datetime() - duration('P0D');
MERGE (a6:ImpactAsset {id:'asset-6'}) SET a6.storage_url='', a6.media_type='IMAGE', a6.confidence_score=0.79, a6.created_at=datetime() - duration('P3D');
MERGE (a7:ImpactAsset {id:'asset-7'}) SET a7.storage_url='', a7.media_type='IMAGE', a7.confidence_score=0.86, a7.created_at=datetime() - duration('P2D');
MERGE (a8:ImpactAsset {id:'asset-8'}) SET a8.storage_url='', a8.media_type='IMAGE', a8.confidence_score=0.82, a8.created_at=datetime() - duration('P1D');

// Relationships
MERGE (p_layla)-[:CREATED]->(a1); MERGE (a1)-[:CONTRIBUTES_TO]->(s13);
MERGE (p_omar)-[:CREATED]->(a2);   MERGE (a2)-[:CONTRIBUTES_TO]->(s6);
MERGE (p_mariam)-[:CREATED]->(a3); MERGE (a3)-[:CONTRIBUTES_TO]->(s4);
MERGE (p_youssef)-[:CREATED]->(a4);MERGE (a4)-[:CONTRIBUTES_TO]->(s15);
MERGE (p_nina)-[:CREATED]->(a5);   MERGE (a5)-[:CONTRIBUTES_TO]->(s7);
MERGE (p_kofi)-[:CREATED]->(a6);   MERGE (a6)-[:CONTRIBUTES_TO]->(s7);
MERGE (p_ana)-[:CREATED]->(a7);    MERGE (a7)-[:CONTRIBUTES_TO]->(s12);
MERGE (p_raj)-[:CREATED]->(a8);    MERGE (a8)-[:CONTRIBUTES_TO]->(s11);
RETURN 'seeded' AS status;
