"""
Authentication command handlers.
Responsible for: login, token issuance, refresh, logout, password management.
"""
from __future__ import annotations
from datetime import datetime, timezone

from shared.exceptions import ValidationException, UnauthorizedException, NotFoundException
from shared.middleware import (
    verify_password, hash_password,
    create_access_token, create_refresh_token, decode_token, TokenPayload,
)
from shared.utils.cqrs import CommandHandler
from shared.utils.logging import get_logger

from .commands import (
    LoginCommand, RefreshTokenCommand, LogoutCommand,
    ChangePasswordCommand, RequestPasswordResetCommand, ResetPasswordCommand,
)
from ..domain.session import AuthSession

log = get_logger(__name__)


class LoginHandler(CommandHandler):
    def __init__(self, user_repo, session_repo, token_store, jwt_secret: str, jwt_algo: str = "HS256"):
        self._user_repo    = user_repo
        self._session_repo = session_repo
        self._token_store  = token_store
        self._jwt_secret   = jwt_secret
        self._jwt_algo     = jwt_algo

    async def handle(self, command: LoginCommand) -> dict:
        user = await self._user_repo.get_by_email(command.email)
        if not user or not verify_password(command.password, user.hashed_password):
            raise UnauthorizedException("Invalid email or password.")

        if not user.is_active:
            raise UnauthorizedException(f"Account is {user.status.value.lower()}.")

        payload = TokenPayload(
            sub=user.id, email=user.email, role=user.role.value, org_id=None
        )
        access_token  = create_access_token(payload, self._jwt_secret, self._jwt_algo)
        refresh_token = create_refresh_token(user.id, self._jwt_secret, self._jwt_algo)

        session = AuthSession.create(
            user_id=user.id,
            refresh_token=refresh_token,
            device_info=command.device_info,
            ip_address=command.ip_address,
        )
        await self._session_repo.save(session)
        log.info("user_login", user_id=user.id, ip=command.ip_address)

        return {
            "access_token":  access_token,
            "refresh_token": refresh_token,
            "token_type":    "Bearer",
            "expires_in":    3600,
            "user_id":       user.id,
            "role":          user.role.value,
        }


class RefreshTokenHandler(CommandHandler):
    def __init__(self, session_repo, user_repo, jwt_secret: str, jwt_algo: str = "HS256"):
        self._session_repo = session_repo
        self._user_repo    = user_repo
        self._jwt_secret   = jwt_secret
        self._jwt_algo     = jwt_algo

    async def handle(self, command: RefreshTokenCommand) -> dict:
        session = await self._session_repo.get_by_refresh_token(command.refresh_token)
        if not session or not session.is_valid:
            raise UnauthorizedException("Invalid or expired refresh token.")

        user = await self._user_repo.get_by_id(session.user_id)
        if not user or not user.is_active:
            raise UnauthorizedException("User account is not active.")

        payload = TokenPayload(sub=user.id, email=user.email, role=user.role.value)
        new_access = create_access_token(payload, self._jwt_secret, self._jwt_algo)

        return {
            "access_token": new_access,
            "token_type":   "Bearer",
            "expires_in":   3600,
        }


class LogoutHandler(CommandHandler):
    def __init__(self, session_repo):
        self._session_repo = session_repo

    async def handle(self, command: LogoutCommand) -> dict:
        session = await self._session_repo.get_by_refresh_token(command.refresh_token)
        if session and session.user_id == command.user_id:
            session.revoke()
            await self._session_repo.save(session)
        log.info("user_logout", user_id=command.user_id)
        return {"message": "Logged out successfully."}


class ChangePasswordHandler(CommandHandler):
    def __init__(self, user_repo):
        self._user_repo = user_repo

    async def handle(self, command: ChangePasswordCommand) -> dict:
        user = await self._user_repo.get_by_id(command.user_id)
        if not user:
            raise NotFoundException("User", command.user_id)
        if not verify_password(command.old_password, user.hashed_password):
            raise UnauthorizedException("Current password is incorrect.")
        if len(command.new_password) < 8:
            raise ValidationException("New password must be at least 8 characters.")

        user.hashed_password = hash_password(command.new_password)
        await self._user_repo.save(user)
        log.info("password_changed", user_id=user.id)
        return {"message": "Password changed successfully."}


class RequestPasswordResetHandler(CommandHandler):
    def __init__(self, user_repo, token_store, notification_client=None):
        self._user_repo    = user_repo
        self._token_store  = token_store
        self._notifier     = notification_client

    async def handle(self, command: RequestPasswordResetCommand) -> dict:
        import secrets
        user = await self._user_repo.get_by_email(command.email)
        # Always return success to prevent email enumeration
        if not user:
            return {"message": "If that email exists, a reset link has been sent."}

        token = secrets.token_urlsafe(32)
        await self._token_store.set(f"pwd_reset:{token}", user.id, ttl_seconds=3600)

        # Future: dispatch to notification-service
        log.info("password_reset_requested", user_id=user.id)
        return {"message": "If that email exists, a reset link has been sent."}
