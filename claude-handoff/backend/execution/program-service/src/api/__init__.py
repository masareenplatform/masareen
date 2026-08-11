from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import CreateProgramCommand, PublishProgramCommand, EnrollParticipantCommand
from ..application.queries import GetProgramByIdQuery, ListProgramsQuery
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/programs", tags=["Programs"])


class CreateProgramRequest(BaseModel):
    organization_id: str
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    sdg_goals: List[int] = []
    country: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    max_participants: Optional[int] = None


class ProgramResponse(BaseModel):
    id: str
    title: str
    organization_id: str
    status: str
    description: Optional[str] = None
    country: Optional[str] = None
    sdg_goals: List[int] = []
    enrolled_count: int = 0
    max_participants: Optional[int] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_program(body: CreateProgramRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(CreateProgramCommand(
        organization_id=body.organization_id, title=body.title,
        description=body.description, sdg_goals=body.sdg_goals,
        country=body.country, start_date=body.start_date,
        end_date=body.end_date, max_participants=body.max_participants,
        created_by="system",
    ))
    return ApiResponse.ok(result)


@router.get("/{program_id}", response_model=ApiResponse[ProgramResponse])
async def get_program(program_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    p = await query_bus.dispatch(GetProgramByIdQuery(program_id=program_id))
    return ApiResponse.ok(ProgramResponse(
        id=p.id, title=p.title, organization_id=p.organization_id,
        status=p.status.value, description=p.description, country=p.country,
        sdg_goals=p.sdg_goals, enrolled_count=p.enrolled_count,
        max_participants=p.max_participants, start_date=p.start_date, end_date=p.end_date,
        created_at=p.created_at.isoformat() if p.created_at else None,
        updated_at=p.updated_at.isoformat() if p.updated_at else None,
    ))


@router.post("/{program_id}/publish", response_model=ApiResponse[dict])
async def publish_program(program_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(PublishProgramCommand(program_id=program_id, published_by="system"))
    return ApiResponse.ok(result)


@router.post("/{program_id}/enroll", response_model=ApiResponse[dict])
async def enroll(program_id: str, user_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(EnrollParticipantCommand(program_id=program_id, user_id=user_id))
    return ApiResponse.ok(result)


@router.get("/", response_model=ApiResponse[list])
async def list_programs(
    limit: int = Query(20), offset: int = Query(0),
    status: Optional[str] = Query(None), country: Optional[str] = Query(None),
    query_bus: QueryBus = Depends(get_query_bus),
):
    programs, total = await query_bus.dispatch(ListProgramsQuery(limit=limit, offset=offset, status=status, country=country))
    items = [ProgramResponse(
        id=p.id, title=p.title, organization_id=p.organization_id,
        status=p.status.value, description=p.description, country=p.country,
        sdg_goals=p.sdg_goals, enrolled_count=p.enrolled_count,
        max_participants=p.max_participants, start_date=p.start_date, end_date=p.end_date,
        created_at=p.created_at.isoformat() if p.created_at else None,
        updated_at=p.updated_at.isoformat() if p.updated_at else None,
    ) for p in programs]
    return ApiResponse.ok(items)
