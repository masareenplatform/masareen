"""
Users router, identity-service.
Provides CRUD for user profiles, skills, and Impact Passport.
"""
from __future__ import annotations
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession
from ..infrastructure.orm_models import FollowORM, UserProfileORM
from ..dependencies import get_db_session

from shared.dtos import ApiResponse, PaginatedResponse
from shared.middleware import TokenPayload, make_auth_dependency, require_role
from shared.utils.cqrs import CommandBus, QueryBus

from ..application.commands import (
    RegisterUserCommand, UpdateUserProfileCommand,
    AddSkillToUserCommand, SuspendUserCommand,
)
from ..application.queries import (
    GetUserByIdQuery, ListUsersQuery, GetImpactPassportQuery,
)
from .schemas import (
    RegisterUserRequest, UpdateProfileRequest, AddSkillRequest,
    UserResponse, ImpactPassportResponse, RegisterUserResponse,
)
from ..dependencies import get_command_bus, get_query_bus, get_current_user

router = APIRouter(prefix="/users", tags=["Users"])


@router.post(
    "/register",
    response_model=ApiResponse[RegisterUserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
async def register_user(
    body: RegisterUserRequest,
    cmd_bus: CommandBus = Depends(get_command_bus),
):
    result = await cmd_bus.dispatch(RegisterUserCommand(
        email=body.email,
        full_name=body.full_name,
        password=body.password,
        phone=body.phone,
        role=body.role,
    ))
    return ApiResponse.ok(RegisterUserResponse(**result))


@router.get(
    "/me",
    response_model=ApiResponse[UserResponse],
    summary="Get current authenticated user",
)
async def get_me(
    token: TokenPayload = Depends(get_current_user()),
    query_bus: QueryBus = Depends(get_query_bus),
):
    user = await query_bus.dispatch(GetUserByIdQuery(user_id=token.sub))
    return ApiResponse.ok(UserResponse(
        id=user.id, email=user.email, full_name=user.full_name,
        phone=user.phone, role=user.role.value, status=user.status.value,
        pms_score=user.pms_score, email_verified=user.email_verified,
        skills=[s.__dict__ for s in user.skills],
        profile=user.profile.__dict__ if user.profile else None,
        created_at=user.created_at, updated_at=user.updated_at,
    ))


@router.get(
    "/suggested",
    response_model=ApiResponse[dict],
    summary="Public user directory for follow suggestions",
)
async def user_directory(
    limit: int = Query(30, ge=1, le=100),
    _: TokenPayload = Depends(get_current_user()),
    session: AsyncSession = Depends(get_db_session),
):
    from ..infrastructure.orm_models import UserORM
    rows = (await session.execute(
        select(UserORM, UserProfileORM)
        .join(UserProfileORM, UserProfileORM.user_id == UserORM.id, isouter=True)
        .order_by(UserORM.full_name)
        .limit(limit)
    )).all()
    items = [
        {
            "id": str(u.id),
            "full_name": u.full_name,
            "avatar_url": (p.avatar_url if p else None),
            "followers_count": (p.followers_count if p else 0),
        }
        for u, p in rows
    ]
    return ApiResponse.ok({"items": items, "total": len(items)})


@router.get(
    "/{user_id}",
    response_model=ApiResponse[UserResponse],
    summary="Get user by ID",
)
async def get_user(
    user_id: str,
    _: TokenPayload = Depends(get_current_user()),
    query_bus: QueryBus = Depends(get_query_bus),
):
    user = await query_bus.dispatch(GetUserByIdQuery(user_id=user_id))
    return ApiResponse.ok(UserResponse(
        id=user.id, email=user.email, full_name=user.full_name,
        phone=user.phone, role=user.role.value, status=user.status.value,
        pms_score=user.pms_score, email_verified=user.email_verified,
        skills=[s.__dict__ for s in user.skills],
        profile=user.profile.__dict__ if user.profile else None,
        created_at=user.created_at, updated_at=user.updated_at,
    ))


@router.patch(
    "/me/profile",
    response_model=ApiResponse[dict],
    summary="Update current user's profile",
)
async def update_profile(
    body: UpdateProfileRequest,
    token: TokenPayload = Depends(get_current_user()),
    cmd_bus: CommandBus = Depends(get_command_bus),
):
    result = await cmd_bus.dispatch(UpdateUserProfileCommand(
        user_id=token.sub, **body.model_dump(exclude_none=True)
    ))
    return ApiResponse.ok(result)


@router.post(
    "/me/skills",
    response_model=ApiResponse[dict],
    status_code=status.HTTP_201_CREATED,
    summary="Add a skill to current user",
)
async def add_skill(
    body: AddSkillRequest,
    token: TokenPayload = Depends(get_current_user()),
    cmd_bus: CommandBus = Depends(get_command_bus),
):
    result = await cmd_bus.dispatch(AddSkillToUserCommand(
        user_id=token.sub,
        skill_id=body.skill_id,
        skill_name=body.skill_name,
        proficiency=body.proficiency,
    ))
    return ApiResponse.ok(result)


@router.get(
    "/{user_id}/impact-passport",
    response_model=ApiResponse[ImpactPassportResponse],
    summary="Get a user's Impact Passport",
)
async def get_impact_passport(
    user_id: str,
    _: TokenPayload = Depends(get_current_user()),
    query_bus: QueryBus = Depends(get_query_bus),
):
    passport = await query_bus.dispatch(GetImpactPassportQuery(user_id=user_id))
    return ApiResponse.ok(ImpactPassportResponse(**passport))


@router.get(
    "/",
    response_model=ApiResponse[PaginatedResponse[UserResponse]],
    summary="List users (Admin only)",
)
async def list_users(
    limit:  int = Query(20, ge=1, le=100),
    offset: int = Query(0,  ge=0),
    role:   str = Query(None),
    token:  TokenPayload = Depends(get_current_user()),
    query_bus: QueryBus = Depends(get_query_bus),
):
    require_role("ADMIN", "SUPER_ADMIN")(token)
    users, total = await query_bus.dispatch(ListUsersQuery(limit=limit, offset=offset, role=role))
    items = [
        UserResponse(
            id=u.id, email=u.email, full_name=u.full_name,
            phone=u.phone, role=u.role.value, status=u.status.value,
            pms_score=u.pms_score, email_verified=u.email_verified,
            skills=[s.__dict__ for s in u.skills],
            profile=u.profile.__dict__ if u.profile else None,
            created_at=u.created_at, updated_at=u.updated_at,
        )
        for u in users
    ]
    return ApiResponse.ok(PaginatedResponse.build(items, total, limit, offset))


# --------------------------------------------------------------------------
# Social following
# --------------------------------------------------------------------------
async def _counts(session: AsyncSession, followee_id: str) -> int:
    return (await session.execute(
        select(func.count()).select_from(FollowORM).where(FollowORM.followee_id == followee_id)
    )).scalar() or 0


@router.post(
    "/{user_id}/follow",
    response_model=ApiResponse[dict],
    summary="Follow or unfollow a user (toggle)",
)
async def toggle_follow(
    user_id: str,
    token: TokenPayload = Depends(get_current_user()),
    session: AsyncSession = Depends(get_db_session),
):
    follower_id = token.sub
    if follower_id == user_id:
        return ApiResponse.ok({"following": False, "followers_count": await _counts(session, user_id)})
    existing = (await session.execute(
        select(FollowORM).where(FollowORM.follower_id == follower_id, FollowORM.followee_id == user_id)
    )).scalar_one_or_none()
    following = existing is None
    if existing is None:
        session.add(FollowORM(follower_id=follower_id, followee_id=user_id))
    else:
        await session.delete(existing)
    await session.commit()
    # keep the denormalised counters in sync
    fc = await _counts(session, user_id)
    await session.execute(
        update(UserProfileORM).where(UserProfileORM.user_id == user_id).values(followers_count=fc)
    )
    await session.commit()
    return ApiResponse.ok({"following": following, "followers_count": fc})


@router.get(
    "/{user_id}/is-following",
    response_model=ApiResponse[dict],
    summary="Whether the current user follows this user",
)
async def is_following(
    user_id: str,
    token: TokenPayload = Depends(get_current_user()),
    session: AsyncSession = Depends(get_db_session),
):
    following = (await session.execute(
        select(FollowORM).where(FollowORM.follower_id == token.sub, FollowORM.followee_id == user_id)
    )).scalar_one_or_none() is not None
    return ApiResponse.ok({"following": following})


@router.get(
    "/{user_id}/followers",
    response_model=ApiResponse[dict],
    summary="List followers of a user",
)
async def list_followers(
    user_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    _: TokenPayload = Depends(get_current_user()),
    session: AsyncSession = Depends(get_db_session),
):
    rows = (await session.execute(
        select(FollowORM.follower_id)
        .where(FollowORM.followee_id == user_id)
        .order_by(FollowORM.created_at.desc())
        .limit(limit).offset(offset)
    )).scalars().all()
    return ApiResponse.ok({"items": [str(r) for r in rows], "total": await _counts(session, user_id)})
