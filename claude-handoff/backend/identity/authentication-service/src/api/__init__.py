"""Authentication service API router — wired to real JWT handlers."""
from fastapi import APIRouter, Depends, Request, status
from pydantic import BaseModel, EmailStr, Field
from typing import Optional

from shared.dtos import ApiResponse
from shared.middleware import TokenPayload
from shared.utils.cqrs import CommandBus
from ..application.commands import (
    LoginCommand, RefreshTokenCommand, LogoutCommand,
    ChangePasswordCommand, RequestPasswordResetCommand,
)
from ..dependencies import get_command_bus, get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


class LoginRequest(BaseModel):
    email:    EmailStr
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str
    expires_in:    int
    user_id:       str
    role:          str


class RefreshRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8)


class PasswordResetRequest(BaseModel):
    email: EmailStr


@router.post("/login", response_model=ApiResponse[TokenResponse], summary="Login with email and password")
async def login(body: LoginRequest, request: Request, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(LoginCommand(
        email=body.email, password=body.password,
        device_info=request.headers.get("user-agent"),
        ip_address=request.client.host if request.client else None,
    ))
    return ApiResponse.ok(TokenResponse(**result))


@router.post("/refresh", response_model=ApiResponse[dict], summary="Refresh access token")
async def refresh_token(body: RefreshRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(RefreshTokenCommand(refresh_token=body.refresh_token))
    return ApiResponse.ok(result)


@router.post("/logout", response_model=ApiResponse[dict], summary="Revoke refresh token and end session")
async def logout(
    body: RefreshRequest,
    token: TokenPayload = Depends(get_current_user()),
    cmd_bus: CommandBus = Depends(get_command_bus),
):
    result = await cmd_bus.dispatch(LogoutCommand(user_id=token.sub, refresh_token=body.refresh_token))
    return ApiResponse.ok(result)


@router.post("/password/change", response_model=ApiResponse[dict], summary="Change current user password")
async def change_password(
    body: ChangePasswordRequest,
    token: TokenPayload = Depends(get_current_user()),
    cmd_bus: CommandBus = Depends(get_command_bus),
):
    result = await cmd_bus.dispatch(ChangePasswordCommand(
        user_id=token.sub, old_password=body.old_password, new_password=body.new_password,
    ))
    return ApiResponse.ok(result)


@router.post("/password/reset-request", response_model=ApiResponse[dict], summary="Request password reset email")
async def request_password_reset(body: PasswordResetRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(RequestPasswordResetCommand(email=body.email))
    return ApiResponse.ok(result)
