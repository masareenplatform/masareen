"""Authorization service API — permission checks and role management."""
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List

from shared.dtos import ApiResponse
from ..domain.permission import build_role, Action, Permission

router = APIRouter(prefix="/authz", tags=["Authorization"])


class PermissionCheckRequest(BaseModel):
    user_id:  str
    role:     str
    resource: str
    action:   str


class PermissionCheckResponse(BaseModel):
    allowed:    bool
    user_id:    str
    resource:   str
    action:     str
    role:       str


@router.post(
    "/check",
    response_model=ApiResponse[PermissionCheckResponse],
    summary="Check if a role has permission for a resource:action",
)
async def check_permission(body: PermissionCheckRequest):
    try:
        role = build_role(body.role)
        action = Action(body.action.lower())
        allowed = role.has_permission(body.resource, action)
    except (ValueError, KeyError):
        allowed = False

    return ApiResponse.ok(PermissionCheckResponse(
        allowed=allowed,
        user_id=body.user_id,
        resource=body.resource,
        action=body.action,
        role=body.role,
    ))


@router.get(
    "/roles/{role_name}/permissions",
    response_model=ApiResponse[List[str]],
    summary="List all permissions for a role",
)
async def list_role_permissions(role_name: str):
    from ..domain.permission import ROLE_DEFINITIONS
    perms = ROLE_DEFINITIONS.get(role_name.upper())
    if perms is None:
        raise HTTPException(status_code=404, detail=f"Role '{role_name}' not found.")
    return ApiResponse.ok(perms)


@router.get(
    "/roles",
    response_model=ApiResponse[List[str]],
    summary="List all available roles",
)
async def list_roles():
    from ..domain.permission import ROLE_DEFINITIONS
    return ApiResponse.ok(list(ROLE_DEFINITIONS.keys()))
