from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import CreateOrganizationCommand, VerifyOrganizationCommand, AddMemberCommand, UpdateOrganizationProfileCommand, AddTimelineEventCommand
from ..application.queries import GetOrganizationByIdQuery, ListOrganizationsQuery, GetTimelineQuery
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/organizations", tags=["Organizations"])


class CreateOrgRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    org_type: str
    country: str
    description: Optional[str] = None
    website: Optional[str] = None


class UpdateProfileRequest(BaseModel):
    profile_data: Dict[str, Any]


class TimelineEventRequest(BaseModel):
    entity_id: str
    event_type: str
    title: str
    description: Optional[str] = None
    date: Optional[str] = None
    media_url: Optional[str] = None
    metric_value: Optional[float] = None
    metadata: Optional[Dict[str, Any]] = None


class OrgResponse(BaseModel):
    id: str
    name: str
    slug: str
    org_type: str
    status: str
    description: Optional[str] = None
    website: Optional[str] = None
    oii_score: float = 0.0
    verified: bool = False
    member_count: int = 0
    profile: Optional[Dict[str, Any]] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_organization(body: CreateOrgRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreateOrganizationCommand(
        name=body.name, org_type=body.org_type, country=body.country,
        created_by="system", description=body.description, website=body.website,
    ))
    return ApiResponse.ok(result)


@router.get("/{org_id}", response_model=ApiResponse[OrgResponse])
async def get_organization(org_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    org = await query_bus.dispatch(GetOrganizationByIdQuery(org_id=org_id))
    return ApiResponse.ok(OrgResponse(
        id=org.id, name=org.name, slug=org.slug,
        org_type=org.org_type.value, status=org.status.value,
        description=org.description, website=org.website,
        oii_score=org.oii_score, verified=org.verified,
        member_count=len(org.member_ids or []),
        profile=org.profile.data if org.profile else None,
        created_at=org.created_at.isoformat() if org.created_at else None,
        updated_at=org.updated_at.isoformat() if org.updated_at else None,
    ))


@router.get("/", response_model=ApiResponse[dict])
async def list_organizations(
    limit: int = Query(20), offset: int = Query(0),
    org_type: Optional[str] = Query(None),
    query_bus: QueryBus = Depends(get_query_bus),
):
    orgs, total = await query_bus.dispatch(ListOrganizationsQuery(limit=limit, offset=offset, org_type=org_type))
    items = [OrgResponse(
        id=o.id, name=o.name, slug=o.slug, org_type=o.org_type.value,
        status=o.status.value, description=o.description, website=o.website,
        oii_score=o.oii_score, verified=o.verified,
        member_count=len(o.member_ids or []),
        profile=o.profile.data if o.profile else None,
        created_at=o.created_at.isoformat() if o.created_at else None,
        updated_at=o.updated_at.isoformat() if o.updated_at else None,
    ) for o in orgs]
    return ApiResponse.ok({"items": items, "total": total, "limit": limit, "offset": offset})


@router.post("/{org_id}/verify", response_model=ApiResponse[dict])
async def verify_organization(org_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(VerifyOrganizationCommand(org_id=org_id, admin_id="system"))
    return ApiResponse.ok(result)


@router.post("/{org_id}/members", response_model=ApiResponse[dict])
async def add_member(org_id: str, user_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(AddMemberCommand(org_id=org_id, user_id=user_id, added_by="system"))
    return ApiResponse.ok(result)

@router.patch("/{org_id}/profile", response_model=ApiResponse[dict])
async def update_profile(org_id: str, body: UpdateProfileRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(UpdateOrganizationProfileCommand(org_id=org_id, profile_data=body.profile_data))
    return ApiResponse.ok(result)

@router.post("/timeline", response_model=ApiResponse[dict])
async def add_timeline_event(body: TimelineEventRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(AddTimelineEventCommand(
        entity_id=body.entity_id, event_type=body.event_type, title=body.title,
        description=body.description, date=body.date, media_url=body.media_url,
        metric_value=body.metric_value, metadata=body.metadata
    ))
    return ApiResponse.ok(result)

@router.get("/timeline/{entity_id}", response_model=ApiResponse[List[Dict[str, Any]]])
async def get_timeline(entity_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    events = await query_bus.dispatch(GetTimelineQuery(entity_id=entity_id))
    return ApiResponse.ok([
        {
            "id": e.id, "entity_id": e.entity_id, "event_type": e.event_type,
            "title": e.title, "description": e.description, "date": e.date.isoformat(),
            "media_url": e.media_url, "metric_value": e.metric_value, "metadata": e.metadata
        } for e in events
    ])
