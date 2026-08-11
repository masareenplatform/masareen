"""Audit Service API endpoints."""
from fastapi import APIRouter, status, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, AsyncGenerator
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.logging import get_logger
from sqlalchemy.ext.asyncio import AsyncSession
from ..application.commands import (
    RecordAuditEventCommand, ExportAuditTrailCommand, 
    RouteToReviewCommand, ResolveReviewCommand
)
from ..application.queries import (
    GetAuditTrailQuery, GetPendingReviewsQuery
)
from ..dependencies import get_command_bus, get_query_bus

log = get_logger(__name__)
router = APIRouter(prefix="/audit", tags=["Audit & Review"])

class RecordEventRequest(BaseModel):
    event_type: str
    aggregate_type: str
    aggregate_id: str
    actor_id: str
    action: str
    details: Optional[dict] = None
    source_service: str = ""

class RouteReviewRequest(BaseModel):
    entity_id: str
    entity_type: str
    confidence_score: float

class ResolveReviewRequest(BaseModel):
    verdict: str # APPROVED | REJECTED | REQUEST_INFO
    comments: str
    admin_id: str

@router.post("/events", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def record_event(body: RecordEventRequest, bus: CommandBus = Depends(get_command_bus)):
    cmd = RecordAuditEventCommand(
        event_type=body.event_type,
        aggregate_type=body.aggregate_type,
        aggregate_id=body.aggregate_id,
        actor_id=body.actor_id,
        action=body.action,
        details=body.details,
        source_service=body.source_service,
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)

@router.get("/aggregate/{aggregate_id}", response_model=ApiResponse[List[dict]])
async def list_events_by_aggregate(aggregate_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    records = await query_bus.dispatch(GetAuditTrailQuery(aggregate_id=aggregate_id))
    return ApiResponse.ok([r.to_dict() for r in records])

@router.post("/review/route", response_model=ApiResponse[dict])
async def route_to_review(body: RouteReviewRequest, bus: CommandBus = Depends(get_command_bus)):
    cmd = RouteToReviewCommand(
        entity_id=body.entity_id, entity_type=body.entity_type, confidence_score=body.confidence_score
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)

@router.get("/review/pending", response_model=ApiResponse[List[Dict[str, Any]]])
async def get_pending_reviews(
    limit: int = Query(20), offset: int = Query(0), 
    query_bus: QueryBus = Depends(get_query_bus)
):
    reviews = await query_bus.dispatch(GetPendingReviewsQuery(limit=limit, offset=offset))
    return ApiResponse.ok([
        {
            "id": r.id, "entity_id": r.entity_id, "entity_type": r.entity_type,
            "confidence_score": r.confidence_score, "status": r.status.value
        } for r in reviews
    ])

@router.patch("/review/{review_id}/resolve", response_model=ApiResponse[dict])
async def resolve_review(review_id: str, body: ResolveReviewRequest, bus: CommandBus = Depends(get_command_bus)):
    cmd = ResolveReviewCommand(
        review_id=review_id, verdict=body.verdict, comments=body.comments, admin_id=body.admin_id
    )
    result = await bus.dispatch(cmd)
    return ApiResponse.ok(result)

