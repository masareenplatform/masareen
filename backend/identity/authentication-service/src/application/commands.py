"""Authentication commands."""
from dataclasses import dataclass
from typing import Optional
from shared.utils.cqrs import Command


@dataclass
class LoginCommand(Command):
    email:       str
    password:    str
    device_info: Optional[str] = None
    ip_address:  Optional[str] = None


@dataclass
class RefreshTokenCommand(Command):
    refresh_token: str


@dataclass
class LogoutCommand(Command):
    user_id:       str
    refresh_token: str


@dataclass
class ChangePasswordCommand(Command):
    user_id:      str
    old_password: str
    new_password: str


@dataclass
class RequestPasswordResetCommand(Command):
    email: str


@dataclass
class ResetPasswordCommand(Command):
    token:        str
    new_password: str
