from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Dict
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import UpdatePMSCommand
from ..application.queries import GetPMSQuery, GetPMSHistoryQuery
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/pms", tags=["Proof of Mission Score"])


class UpdatePMSRequest(BaseModel):
    dimension_deltas: Dict[str, float]
    source: str = "GRAPH_SYNTHESIS"


class PMSResponse(BaseModel):
    user_id: str
    composite_score: float
    tier: str
    dimensions: Dict[str, float]
    version: int


@router.get("/{user_id}", response_model=ApiResponse[PMSResponse])
async def get_pms(user_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    snapshot = await query_bus.dispatch(GetPMSQuery(user_id=user_id))
    return ApiResponse.ok(PMSResponse(
        user_id=snapshot.user_id,
        composite_score=snapshot.composite_score,
        tier=snapshot.tier,
        dimensions=snapshot.dimensions,
        version=snapshot.version,
    ))


@router.patch("/{user_id}", response_model=ApiResponse[PMSResponse])
async def update_pms(user_id: str, body: UpdatePMSRequest,
                     cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(UpdatePMSCommand(
        user_id=user_id,
        dimension_deltas=body.dimension_deltas,
        source=body.source,
    ))
    return ApiResponse.ok(PMSResponse(**result))


@router.get("/{user_id}/history", response_model=ApiResponse[list])
async def get_pms_history(user_id: str, limit: int = 20,
                          query_bus: QueryBus = Depends(get_query_bus)):
    history = await query_bus.dispatch(GetPMSHistoryQuery(user_id=user_id, limit=limit))
    return ApiResponse.ok(history)
