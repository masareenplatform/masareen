from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Dict, Optional
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import UpdateOIICommand
from ..application.queries import GetOIIQuery, GetOIIHistoryQuery, OIILeaderboardQuery
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/oii", tags=["Organisational Impact Index"])


class OIIUpdateRequest(BaseModel):
    dimension_values: Dict[str, float]


class OIIResponse(BaseModel):
    organization_id: str
    composite_index: float
    tier: str
    dimensions: Dict[str, float]
    version: int


@router.get("/leaderboard", response_model=ApiResponse[list])
async def oii_leaderboard(limit: int = 20, org_type: Optional[str] = None,
                          query_bus: QueryBus = Depends(get_query_bus)):
    board = await query_bus.dispatch(OIILeaderboardQuery(limit=limit, org_type=org_type))
    return ApiResponse.ok(board)


@router.get("/{org_id}", response_model=ApiResponse[OIIResponse])
async def get_oii(org_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    result = await query_bus.dispatch(GetOIIQuery(organization_id=org_id))
    return ApiResponse.ok(OIIResponse(
        organization_id=result["organization_id"],
        composite_index=result["composite_index"],
        tier=result["tier"],
        dimensions=result["dimensions"],
        version=result["version"],
    ))


@router.patch("/{org_id}", response_model=ApiResponse[OIIResponse])
async def update_oii(org_id: str, body: OIIUpdateRequest,
                     cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(UpdateOIICommand(
        organization_id=org_id, dimension_values=body.dimension_values))
    return ApiResponse.ok(OIIResponse(
        organization_id=result["organization_id"],
        composite_index=result["composite_index"],
        tier=result["tier"],
        dimensions=result["dimensions"],
        version=result["version"],
    ))


@router.get("/{org_id}/history", response_model=ApiResponse[list])
async def get_oii_history(org_id: str, limit: int = 20,
                         query_bus: QueryBus = Depends(get_query_bus)):
    history = await query_bus.dispatch(GetOIIHistoryQuery(organization_id=org_id, limit=limit))
    return ApiResponse.ok(history)
