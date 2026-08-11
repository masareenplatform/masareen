"""Notification service API — real notification persistence + device tokens."""
from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel
from typing import Any, Dict, List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import SendNotificationCommand, MarkNotificationReadCommand, UpdateNotificationPreferencesCommand
from ..application.queries import GetUserNotificationsQuery
from ..dependencies import get_command_bus, get_query_bus, get_db_session
from ..infrastructure.postgres_repository import NotificationRepository

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _repo(session: AsyncSession) -> NotificationRepository:
    return NotificationRepository(session)

class SendNotificationRequest(BaseModel):
    user_id: str
    channel: str  # PUSH | EMAIL | SMS | IN_APP
    title: str
    body: str
    data: Optional[Dict[str, Any]] = None

class NotificationPreferencesRequest(BaseModel):
    push: bool = True
    email: bool = True
    sms: bool = False
    in_app: bool = True


class RegisterDeviceTokenRequest(BaseModel):
    user_id: str
    device_token: str
    platform: str = "android"  # android | ios | web

@router.post("/send", status_code=202, response_model=ApiResponse[dict])
async def send_notification(body: SendNotificationRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(SendNotificationCommand(
        user_id=body.user_id, channel=body.channel, title=body.title, body=body.body, data=body.data
    ))
    return ApiResponse.ok(result)

@router.get("/{user_id}", response_model=ApiResponse[list])
async def get_user_notifications(user_id: str, unread_only: bool = False, limit: int = 20,
                                 query_bus: QueryBus = Depends(get_query_bus)):
    notifications = await query_bus.dispatch(GetUserNotificationsQuery(user_id=user_id, unread_only=unread_only, limit=limit))
    return ApiResponse.ok(notifications)

@router.patch("/{user_id}/{notification_id}/read", response_model=ApiResponse[dict])
async def mark_read(user_id: str, notification_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(MarkNotificationReadCommand(user_id=user_id, notification_id=notification_id))
    return ApiResponse.ok(result)

@router.put("/{user_id}/preferences", response_model=ApiResponse[dict])
async def update_preferences(user_id: str, body: NotificationPreferencesRequest,
                             cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(UpdateNotificationPreferencesCommand(
        user_id=user_id, push=body.push, email=body.email, sms=body.sms, in_app=body.in_app
    ))
    return ApiResponse.ok(result)


@router.post("/{user_id}/device-tokens", status_code=201, response_model=ApiResponse[dict])
async def register_device_token(user_id: str, body: RegisterDeviceTokenRequest,
                              session: AsyncSession = Depends(get_db_session)):
    """Persist a real device push token so push is deliverable at scale."""
    try:
        data = await _repo(session).register_device_token(
            user_id, body.device_token, body.platform
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"device_token_store_unavailable: {exc}")
    return ApiResponse.ok(data)


@router.get("/{user_id}/device-tokens", response_model=ApiResponse[list])
async def list_device_tokens(user_id: str,
                              session: AsyncSession = Depends(get_db_session)):
    try:
        data = await _repo(session).list_device_tokens(user_id)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"device_token_store_unavailable: {exc}")
    return ApiResponse.ok(data)
