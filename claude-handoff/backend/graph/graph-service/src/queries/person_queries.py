"""Cypher queries for Person node operations."""

CREATE_PERSON = """
MERGE (p:Person {id: $id})
SET p.name = $name,
    p.email = $email,
    p.pms = $pms,
    p.created_at = $created_at
RETURN p
"""

GET_PERSON_IMPACT_NETWORK = """
MATCH (p:Person {id: $person_id})
OPTIONAL MATCH (p)-[:COMPLETED]->(t:Task)
OPTIONAL MATCH (t)<-[:CONTAINS]-(prog:Program)
OPTIONAL MATCH (prog)-[:CONTRIBUTES_TO]->(sdg:SDG)
    OPTIONAL MATCH (p)-[:HAS_SKILL]->(s:Skill)
    OPTIONAL MATCH (p)-[:GENERATED]->(ia:ImpactAsset)
    RETURN p, collect(DISTINCT t) as tasks,
           collect(DISTINCT prog) as programs,
           collect(DISTINCT sdg) as sdgs,
           collect(DISTINCT s) as skills,
           collect(DISTINCT ia) as impact_assets
    """

MATCH_PERSON_TO_OPPORTUNITIES = """
MATCH (p:Person {id: $person_id})-[:HAS_SKILL]->(s:Skill)
MATCH (o:Opportunity)-[:REQUIRES]->(s)
WHERE NOT (p)-[:APPLIED_TO]->(o)
WITH o, count(s) as skill_overlap, p
ORDER BY skill_overlap DESC
LIMIT $limit
RETURN o, skill_overlap
"""
