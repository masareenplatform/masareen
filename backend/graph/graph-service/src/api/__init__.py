"""
Graph service API, Neo4j knowledge graph operations.
Exposes REST endpoints for node CRUD, relationship management,
and complex traversal queries. All endpoints perform real Neo4j operations;
when Neo4j is unreachable they return an honest error rather than fabricated data.
"""
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from typing import Any, Dict, List, Optional
from shared.dtos import ApiResponse

try:
    from neo4j import time as _neo4j_time
    from neo4j.graph import Node as _Neo4jNode, Relationship as _Neo4jRel
    _HAS_NEO4J = True
except Exception:  # pragma: no cover
    _HAS_NEO4J = False

try:
    from config import settings
except Exception:  # pragma: no cover
    from ...config import settings  # type: ignore
from ..infrastructure.neo4j_client import Neo4jClient, GraphRepository

router = APIRouter(prefix="/graph", tags=["Knowledge Graph"])


def _sanitize(value: Any) -> Any:
    """Convert neo4j driver result values into JSON-serialisable primitives.

    Neo4j returns temporal types (DateTime/Date/Time/Duration) and graph
    objects (Node/Relationship) that FastAPI cannot serialise. Convert nodes to
    plain dicts (with their label) and temporal types to ISO-8601 strings.
    """
    if _HAS_NEO4J and isinstance(value, (_Neo4jNode, _Neo4jRel)):
        node = dict(value)
        if isinstance(value, _Neo4jNode):
            node["_labels"] = list(value.labels)
        return node
    if isinstance(value, dict):
        return {k: _sanitize(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_sanitize(v) for v in value]
    if _HAS_NEO4J and isinstance(value, (_neo4j_time.DateTime, _neo4j_time.Date,
                                         _neo4j_time.Time, _neo4j_time.Duration)):
        try:
            return value.isoformat()
        except Exception:
            return str(value)
    return value

_repo: Optional[GraphRepository] = None


def get_repo() -> GraphRepository:
    global _repo
    if _repo is None:
        driver = Neo4jClient.get_driver(
            settings.neo4j_url, settings.neo4j_user, settings.neo4j_password
        )
        _repo = GraphRepository(driver)
    return _repo


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(
        status_code=503,
        detail="Neo4j graph store unavailable: " + str(exc),
    )


class UpsertNodeRequest(BaseModel):
    node_id: str
    label: str
    properties: Dict[str, Any] = {}


class CreateRelationshipRequest(BaseModel):
    from_id: str
    from_label: str
    to_id: str
    to_label: str
    relationship_type: str
    properties: Dict[str, Any] = {}


class CypherQueryRequest(BaseModel):
    query: str
    parameters: Dict[str, Any] = {}
    read_only: bool = True


class ImpactNetworkResponse(BaseModel):
    person_id: str
    tasks: List[dict]
    programs: List[dict]
    sdgs: List[dict]
    skills: List[dict]
    impact_assets: List[dict]


@router.post("/nodes", response_model=ApiResponse[dict])
async def upsert_node(body: UpsertNodeRequest):
    try:
        await get_repo().upsert_node(body.node_id, body.label, body.properties)
    except Exception as exc:  # neo4j unavailable
        raise _unavailable(exc)
    return ApiResponse.ok({"node_id": body.node_id, "label": body.label,
                           "message": "Node upserted"})


@router.post("/relationships", response_model=ApiResponse[dict])
async def create_relationship(body: CreateRelationshipRequest):
    try:
        await get_repo().create_relationship(
            body.from_id, body.from_label, body.to_id, body.to_label,
            body.relationship_type, body.properties,
        )
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({"from": body.from_id, "to": body.to_id,
                           "type": body.relationship_type})


@router.post("/query", response_model=ApiResponse[list])
async def execute_query(body: CypherQueryRequest):
    """Execute a read-only Cypher query. Write queries require explicit admin permission."""
    if not body.read_only:
        return ApiResponse.error(["Write queries must go through domain services."])
    try:
        rows = await get_repo().run_read_query(body.query, body.parameters)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok([_sanitize(r) for r in rows])


@router.get("/person/{user_id}/network", response_model=ApiResponse[ImpactNetworkResponse])
async def get_impact_network(user_id: str, depth: int = Query(2, ge=1, le=4)):
    try:
        data = await get_repo().get_impact_network(user_id)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(ImpactNetworkResponse(**_sanitize(data)).model_dump())


@router.get("/organization/{org_id}/network", response_model=ApiResponse[dict])
async def get_org_network(org_id: str):
    query = """
    MATCH (o:Organization {id: $org_id})
    OPTIONAL MATCH (o)-[:HAS_MEMBER]->(m:Person)
    OPTIONAL MATCH (o)-[:RUNS]->(p:Program)
    OPTIONAL MATCH (p)-[:CONTRIBUTES_TO]->(s:SDG)
    OPTIONAL MATCH (o)-[:PARTNERS_WITH]->(partner:Organization)
    RETURN o,
       collect(DISTINCT m) AS members,
       collect(DISTINCT p) AS programs,
       collect(DISTINCT s) AS sdgs,
       collect(DISTINCT partner) AS partners
    """
    try:
        rows = await get_repo().run_read_query(query, {"org_id": org_id})
    except Exception as exc:
        raise _unavailable(exc)
    row = rows[0] if rows else {}
    return ApiResponse.ok(_sanitize({
        "organization_id": org_id,
        "programs": [dict(p) for p in (row.get("programs") or [])],
        "members": [dict(m) for m in (row.get("members") or [])],
        "partners": [dict(p) for p in (row.get("partners") or [])],
        "sdgs": [dict(s) for s in (row.get("sdgs") or [])],
    }))


@router.get("/sdg/{sdg_number}/contributors", response_model=ApiResponse[list])
async def sdg_contributors(sdg_number: int, country: Optional[str] = Query(None),
                           limit: int = Query(20)):
    query = """
    MATCH (sdg:SDG {number: $sdg_number})<-[:CONTRIBUTES_TO]-(p:Program)
    OPTIONAL MATCH (p)<-[:RUNS]-(o:Organization)
    RETURN sdg, collect(DISTINCT p) AS programs, collect(DISTINCT o) AS orgs
    LIMIT $limit
    """
    try:
        rows = await get_repo().run_read_query(query, {"sdg_number": sdg_number, "limit": limit})
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok([_sanitize(dict(r)) for r in rows])


@router.get("/match/talent", response_model=ApiResponse[list])
async def graph_talent_match(opportunity_id: str, limit: int = Query(10)):
    """Graph-based talent matching using relationship traversal."""
    try:
        rows = await get_repo().talent_match(opportunity_id, limit)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(rows)


@router.get("/health/neo4j", response_model=ApiResponse[dict])
async def neo4j_health():
    try:
        repo = get_repo()
        nodes = await repo.node_count()
        rels = await repo.relationship_count()
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok({"status": "connected", "node_count": nodes,
                           "relationship_count": rels})
