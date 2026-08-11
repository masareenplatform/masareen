"""Opportunity service API — real persistence and matching."""
from fastapi import APIRouter, Query, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import date
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import CreateOpportunityCommand, PublishOpportunityCommand, ApplyToOpportunityCommand, CreatePlatformPostCommand
from ..application.queries import GetOpportunityQuery, ListOpportunitiesQuery, ListPlatformContentQuery
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/opportunities", tags=["Opportunities & Platform Content"])

class CreateOpportunityRequest(BaseModel):
    organization_id: str
    title: str = Field(..., min_length=5)
    opp_type: str
    description: Optional[str] = None
    country: Optional[str] = None
    min_pms_score: float = 0.0
    required_skills: List[str] = []
    required_sdgs: List[int] = []
    deadline: Optional[date] = None
    compensation_usd: Optional[float] = None
    remote: bool = False

class OpportunityResponse(BaseModel):
    id: str
    title: str
    opp_type: str
    status: str
    organization_id: str
    country: Optional[str]
    remote: bool
    min_pms_score: float
    required_skills: List[str]
    deadline: Optional[date]
    compensation_usd: Optional[float]
    applicant_count: int

class PlatformPostRequest(BaseModel):
    title: str
    body: str
    content_type: str # AD, EDUCATIONAL, ANNOUNCEMENT
    media_url: Optional[str] = None
    target_audience: List[str] = ["ALL"]
    budget: Optional[float] = None

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_opportunity(body: CreateOpportunityRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreateOpportunityCommand(
        organization_id=body.organization_id, title=body.title, opp_type=body.opp_type,
        description=body.description, country=body.country, min_pms_score=body.min_pms_score,
        required_skills=body.required_skills, required_sdgs=body.required_sdgs,
        deadline=body.deadline, compensation_usd=body.compensation_usd, remote=body.remote,
        created_by=body.organization_id
    ))
    return ApiResponse.ok(result)

@router.get("/", response_model=ApiResponse[list])
async def list_opportunities(opp_type: Optional[str] = Query(None),
                               country: Optional[str] = Query(None),
                               remote: Optional[bool] = Query(None),
                               min_pms: float = Query(0), limit: int = Query(20),
                               offset: int = Query(0),
                               query_bus: QueryBus = Depends(get_query_bus)):
    opps = await query_bus.dispatch(ListOpportunitiesQuery(
        opp_type=opp_type, country=country, remote=remote, min_pms=min_pms, limit=limit, offset=offset
    ))
    return ApiResponse.ok([
        OpportunityResponse(
            id=o.id, title=o.title, opp_type=o.opp_type.value, status=o.status.value,
            organization_id=o.organization_id, country=o.country, remote=o.remote,
            min_pms_score=o.min_pms_score, required_skills=o.required_skills,
            deadline=o.deadline, compensation_usd=o.compensation_usd,
            applicant_count=o.applicant_count,
        ) for o in opps
    ])

@router.get("/{opp_id}", response_model=ApiResponse[OpportunityResponse])
async def get_opportunity(opp_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    opp = await query_bus.dispatch(GetOpportunityQuery(opportunity_id=opp_id))
    if opp is None:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    return ApiResponse.ok(OpportunityResponse(
        id=opp.id, title=opp.title, opp_type=opp.opp_type.value, status=opp.status.value,
        organization_id=opp.organization_id, country=opp.country, remote=opp.remote,
        min_pms_score=opp.min_pms_score, required_skills=opp.required_skills,
        deadline=opp.deadline, compensation_usd=opp.compensation_usd,
        applicant_count=opp.applicant_count))

@router.post("/{opp_id}/publish", response_model=ApiResponse[dict])
async def publish_opportunity(opp_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(PublishOpportunityCommand(opportunity_id=opp_id))
    return ApiResponse.ok(result)

@router.post("/{opp_id}/apply", response_model=ApiResponse[dict])
async def apply(opp_id: str, user_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(ApplyToOpportunityCommand(opportunity_id=opp_id, user_id=user_id))
    return ApiResponse.ok(result)

@router.post("/platform-content", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_platform_post(body: PlatformPostRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreatePlatformPostCommand(
        title=body.title, body=body.body, content_type=body.content_type,
        media_url=body.media_url, target_audience=body.target_audience, budget=body.budget
    ))
    return ApiResponse.ok(result)

@router.get("/platform-content", response_model=ApiResponse[List[Dict[str, Any]]])
async def get_platform_content(audience: str = Query("ALL"), query_bus: QueryBus = Depends(get_query_bus)):
    posts = await query_bus.dispatch(ListPlatformContentQuery(audience=audience))
    return ApiResponse.ok([
        {
            "id": p.id, "title": p.title, "body": p.body, "content_type": p.content_type.value,
            "media_url": p.media_url, "priority": p.priority
        } for p in posts
    ])
