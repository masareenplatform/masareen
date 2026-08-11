// Enrich existing assets with real image URLs + captions + engagement counts.
MATCH (a:ImpactAsset {id:'asset-1'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-1/800/500', a.description='Planted 1,200 native trees along the Nile delta with the local youth collective.', a.likes=342, a.comments=58, a.shares=21;
MATCH (a:ImpactAsset {id:'asset-2'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-2/800/500', a.description='Solar microgrid went live — 400 homes now on clean power.', a.likes=512, a.comments=90, a.shares=64;
MATCH (a:ImpactAsset {id:'asset-3'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-3/800/500', a.description='Coastal restoration: 3km of mangrove belt rehabilitated this quarter.', a.likes=289, a.comments=41, a.shares=12;
MATCH (a:ImpactAsset {id:'asset-4'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-4/800/500', a.description='Zero-waste school program rolled out to 12 campuses.', a.likes=176, a.comments=23, a.shares=8;
MATCH (a:ImpactAsset {id:'asset-5'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-5/800/500', a.description='Community clinic hit 10,000 free consultations milestone.', a.likes=804, a.comments=132, a.shares=99;
MATCH (a:ImpactAsset {id:'asset-6'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-6/800/500', a.description='Clean-water filters distributed across 60 rural households.', a.likes=233, a.comments=19, a.shares=7;
MATCH (a:ImpactAsset {id:'asset-7'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-7/800/500', a.description='Girls-in-STEM bootcamp graduation — 80 new builders certified.', a.likes=455, a.comments=77, a.shares=40;
MATCH (a:ImpactAsset {id:'asset-8'}) SET a.storage_url='https://picsum.photos/seed/masaren-impact-8/800/500', a.description='Urban farm yields first harvest, donated to the food bank.', a.likes=198, a.comments=28, a.shares=11;

// New assets covering every post type the app renders.
MERGE (a9:ImpactAsset {id:'asset-9'})  SET a9.storage_url='https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', a9.media_type='VIDEO', a9.confidence_score=0.92, a9.created_at=datetime() - duration('P0DT2H'), a9.description='Field documentary: a year of clean-water work in rural Egypt.', a9.likes=621, a9.comments=88, a9.shares=54;
MERGE (a10:ImpactAsset {id:'asset-10'}) SET a10.storage_url='https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', a10.media_type='VIDEO', a10.confidence_score=0.95, a10.created_at=datetime() - duration('P0DT5H'), a10.description='LIVE: HLS transcode test stream — verified impact highlights reel.', a10.likes=903, a10.comments=141, a10.shares=120;
MERGE (a11:ImpactAsset {id:'asset-11'}) SET a11.storage_url='https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', a11.media_type='AUDIO', a11.confidence_score=0.81, a11.created_at=datetime() - duration('P1DT1H'), a11.description='Impact story: voices from the reforestation frontline.', a11.likes=144, a11.comments=22, a11.shares=9;
MERGE (a12:ImpactAsset {id:'asset-12'}) SET a12.media_type='ARTICLE', a12.confidence_score=0.88, a12.created_at=datetime() - duration('P1DT3H'), a12.title='How transparent ledgers rebuild trust in aid', a12.summary='A look at the verifiable-impact movement and why proofs beat promises.', a12.source='MASAREEN Journal', a12.image_url='https://picsum.photos/seed/masaren-article/800/450', a12.likes=377, a12.comments=53, a12.shares=61;
MERGE (a13:ImpactAsset {id:'asset-13'}) SET a13.media_type='LINK', a13.confidence_score=0.84, a13.created_at=datetime() - duration('P2DT1H'), a13.title='Egypt Vision 2030 — Sustainable Communities', a13.url='https://www.egyptvision2030.gov.eg/', a13.domain='egyptvision2030.gov.eg', a13.image_url='https://picsum.photos/seed/masaren-link/800/450', a13.likes=262, a13.comments=34, a13.shares=47;
MERGE (a14:ImpactAsset {id:'asset-14'}) SET a14.storage_url='https://picsum.photos/seed/masaren-impact-14/800/500', a14.media_type='IMAGE', a14.confidence_score=0.90, a14.created_at=datetime() - duration('P0DT8H'), a14.description='Newly trained community health volunteers on deployment day.', a14.likes=415, a14.comments=67, a14.shares=33;

// Link new assets to existing creators + SDGs (Cypher vars don't persist across ;).
MATCH (p:Person {id:'u-layla'}) MATCH (a:ImpactAsset {id:'asset-9'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:6}) MATCH (a:ImpactAsset {id:'asset-9'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-omar'}) MATCH (a:ImpactAsset {id:'asset-10'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:7}) MATCH (a:ImpactAsset {id:'asset-10'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-mariam'}) MATCH (a:ImpactAsset {id:'asset-11'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:13}) MATCH (a:ImpactAsset {id:'asset-11'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-youssef'}) MATCH (a:ImpactAsset {id:'asset-12'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:4}) MATCH (a:ImpactAsset {id:'asset-12'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-nina'}) MATCH (a:ImpactAsset {id:'asset-13'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:11}) MATCH (a:ImpactAsset {id:'asset-13'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
MATCH (p:Person {id:'u-kofi'}) MATCH (a:ImpactAsset {id:'asset-14'}) MERGE (p)-[:CREATED]->(a);
MATCH (s:SDG {number:15}) MATCH (a:ImpactAsset {id:'asset-14'}) MERGE (a)-[:CONTRIBUTES_TO]->(s);
RETURN 'seeded-types' AS status;
