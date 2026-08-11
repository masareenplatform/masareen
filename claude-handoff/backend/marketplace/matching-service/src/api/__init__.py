"""Matching service API — real graph-backed matching and personalised feed.

All graph access goes through the graph-service REST API via ``GraphClient``.
If the graph-service is unreachable, endpoints return an honest 503 rather than
fabricated matches.
"""
from fastapi import APIRouter, Query, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List

from shared.dtos import ApiResponse
from ..infrastructure.graph_client import GraphClient
from ..application.feed_service import FeedService

try:
    from config import settings
except Exception:  # pragma: no cover
    from ...config import settings  # type: ignore

router = APIRouter(prefix="/matching", tags=["Matching"])


def get_graph_client() -> GraphClient:
    return GraphClient(settings.graph_service_url)


class MatchRequest(BaseModel):
    user_id: str
    top_k: int = Field(default=10, ge=1, le=50)


class TalentSearchRequest(BaseModel):
    opportunity_id: str
    top_k: int = Field(default=20, ge=1, le=100)


@router.post("/opportunities-for-user", response_model=ApiResponse[List[dict]])
async def match_opportunities_to_user(body: MatchRequest, graph: GraphClient = Depends(get_graph_client)):
    try:
        results = await graph.execute_query(
            "MATCH (p:Person {id: $id})-[:CONTRIBUTES_TO]->(s:SDG)<-[:CONTRIBUTES_TO]-(o:Opportunity) "
            "RETURN DISTINCT o",
            {"id": body.user_id},
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"graph_service_unavailable: {e}")
    return ApiResponse.ok(results[:body.top_k])


@router.post("/users-for-opportunity", response_model=ApiResponse[list])
async def match_users_to_opportunity(body: TalentSearchRequest, graph: GraphClient = Depends(get_graph_client)):
    try:
        results = await graph.get("/match/talent",
                                  {"opportunity_id": body.opportunity_id, "limit": body.top_k})
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"graph_service_unavailable: {e}")
    return ApiResponse.ok(results)


@router.get("/recommendations/{user_id}", response_model=ApiResponse[list])
async def get_recommendations(user_id: str, limit: int = Query(5), graph: GraphClient = Depends(get_graph_client)):
    try:
        results = await graph.execute_query(
            "MATCH (p:Person {id: $id})-[:CONTRIBUTES_TO]->(s:SDG)<-[:CONTRIBUTES_TO]-(o:Opportunity) "
            "RETURN o LIMIT $limit",
            {"id": user_id, "limit": limit},
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"graph_service_unavailable: {e}")
    return ApiResponse.ok(results)


@router.get("/feed", response_model=ApiResponse[list])
async def get_personalized_feed(user_id: str, limit: int = Query(20), offset: int = Query(0),
                                graph: GraphClient = Depends(get_graph_client)):
    """The Impact Feed — graph-based SDG relevance + verification confidence."""
    try:
        feed_service = FeedService(graph_client=graph)
        feed = await feed_service.get_personalized_feed(user_id, limit, offset)
        return ApiResponse.ok(feed)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"graph_service_unavailable: {e}")
